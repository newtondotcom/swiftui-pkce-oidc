//
//  AuthenticationSession.swift
//  newton
//
//  Created by Robin Augereau on 13/10/2025.
//

import AuthenticationServices
import Combine
import CryptoKit
import SwiftUI

/// Handles authentication using OAuth 2.0 + PKCE flow through ASWebAuthenticationSession.
/// Manages authorization code exchange, token persistence, refresh, and error handling.
class AuthenticationSession: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    
    // MARK: - Properties
    
    /// OAuth 2.0 provider configuration
    let provider: AuthenticationProvider
    
    /// Anchor used to present the authentication web session
    let presentationAnchor: ASPresentationAnchor
    
    /// The current web authentication session
    var session: ASWebAuthenticationSession?
    
    /// PKCE code verifier used during token exchange
    var codeVerifier: String?
    
    /// Combine cancellable for token request
    var cancellable: AnyCancellable?
    
    /// Published authentication state (used by SwiftUI)
    @Published var state: State = .initialized
    
    /// The last authenticated access token (if any)
    private(set) var currentToken: AccessToken?
    
    // MARK: - State Definition
    
    /// Represents the current authentication state
    enum State {
        case initialized
        case authenticating
        case accessCodeReceived(code: String)
        case authenticated(accessToken: AccessToken)
        case error(Error)
        case failed
        case cancelled
    }

    // MARK: - Initialization
    
    /// Initializes the authentication session.
    /// Attempts to load any stored token from the Keychain.
    init(provider: AuthenticationProvider, presentationAnchor: ASPresentationAnchor) {
        self.provider = provider
        self.presentationAnchor = presentationAnchor
        
        // Attempt to restore a token from Keychain at initialization
        if let tokenData = KeychainHelper.read(service: "myapp", account: "accessToken"),
           let token = try? JSONDecoder().decode(AccessToken.self, from: tokenData) {
            self.currentToken = token
            self.state = .authenticated(accessToken: token)
            print("✅ Token restored from Keychain")
        } else {
            self.state = .initialized
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    /// Provides the presentation anchor for the web authentication session
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return presentationAnchor
    }

    // MARK: - Authentication Flow
    
    /// Starts the OAuth 2.0 authorization process using PKCE.
    func start() {
        let codeVerifier = PKCE.generateCodeVerifier()
        self.codeVerifier = codeVerifier
        
        // Build authorization URL with PKCE code challenge
        let authURL = provider.authorizeURL(codeChallenge: PKCE.generateCodeChallenge(from: codeVerifier))
        
        // Create and configure the authentication session
        session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "myapp", // must match redirect URI scheme
            completionHandler: { [weak self] in
                self?.handleCallback($0, $1)
            }
        )
        
        session!.presentationContextProvider = self
        session!.start()
        state = .authenticating
    }

    /// Cancels the authentication process.
    func cancel() {
        session?.cancel()
        state = .cancelled
    }

    /// Logs out the user and clears stored credentials.
    func reset() {
        state = .initialized
        currentToken = nil
        KeychainHelper.delete(service: "myapp", account: "accessToken")
        print("🧹 Cleared token from Keychain")
    }

    // MARK: - Callback Handling
    
    /// Handles the callback returned by the web authentication session.
    private func handleCallback(_ callbackURL: URL?, _ error: Error?) {
        if let error = error {
            state = .error(error)
            return
        }
        
        guard let callbackURL = callbackURL else {
            state = .failed
            return
        }

        // Extract authorization code
        let queryItems = URLComponents(string: callbackURL.absoluteString)?.queryItems
        if let authCode = queryItems?.first(where: { $0.name == "code" })?.value {
            state = .accessCodeReceived(code: authCode)
            obtainAccessTokenFromAccessCode(authCode)
        } else {
            state = .failed
        }
    }

    // MARK: - Token Exchange
    
    /// Exchanges an authorization code for an access token.
    private func obtainAccessTokenFromAccessCode(_ code: String) {
        var request = URLRequest(url: provider.accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        guard let verifier = codeVerifier else {
            state = .failed
            return
        }
        
        // Build form-encoded request body
        let bodyParams = [
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": provider.redirectUri,
            "client_id": provider.clientId,
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Perform token exchange
        cancellable = URLSession.shared
            .dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { [weak self] data, response in
                guard let self = self,
                      let response = response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    self?.state = .failed
                    return
                }

                // Parse JSON token response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let accessToken = json["access_token"] as? String {
                        
                        let token = AccessToken(
                            token: accessToken,
                            refreshToken: json["refresh_token"] as? String,
                            scope: json["scope"] as? String,
                            type: json["token_type"] as? String,
                            expiresIn: json["expires_in"] as? Int,
                            issuedAt: Date.now
                        )

                        // Store and publish new token
                        self.currentToken = token
                        self.state = .authenticated(accessToken: token)
                        if let tokenData = try? JSONEncoder().encode(token) {
                            KeychainHelper.save(tokenData, service: "myapp", account: "accessToken")
                        }
                        self.codeVerifier = nil
                        
                        print("🔐 Access token stored in Keychain")
                    } else {
                        self.state = .failed
                    }
                } catch {
                    self.state = .failed
                }
            }
    }

    // MARK: - Token Refresh
    
    /// Refreshes an expired access token using the refresh token.
    /// - Parameter completion: Returns a new AccessToken or nil if refresh fails.
    func refreshAccessToken(completion: @escaping (AccessToken?) -> Void) {
        guard let currentToken = currentToken,
              let refreshToken = currentToken.refreshToken else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: provider.accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        
        // Build refresh request body
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": provider.clientId,
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        // Execute refresh request
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let accessToken = json["access_token"] as? String {
                    
                    let newToken = AccessToken(
                        token: accessToken,
                        refreshToken: json["refresh_token"] as? String ?? refreshToken,
                        scope: json["scope"] as? String,
                        type: json["token_type"] as? String,
                        expiresIn: json["expires_in"] as? Int,
                        issuedAt: Date.now
                    )
                    
                    // Save refreshed token
                    if let tokenData = try? JSONEncoder().encode(newToken) {
                        KeychainHelper.save(tokenData, service: "myapp", account: "accessToken")
                    }
                    
                    DispatchQueue.main.async {
                        self.currentToken = newToken
                        self.state = .authenticated(accessToken: newToken)
                        print("🔄 Access token refreshed and stored in Keychain")
                        completion(newToken)
                    }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
