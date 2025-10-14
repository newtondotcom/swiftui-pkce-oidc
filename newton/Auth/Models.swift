//
//  Models.swift
//  newton
//
//  Created by Robin Augereau on 14/10/2025.
//

import Foundation
import AuthenticationServices
import Combine
import CryptoKit

struct AuthenticationProvider {
    let authorizeBaseURL: URL
    let accessTokenURL: URL
    let clientId: String
    let redirectUri: String

    func authorizeURL(codeChallenge: String) -> URL {
        var components = URLComponents(string: authorizeBaseURL.absoluteString)!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value : "code"),
            URLQueryItem(name: "scope", value: "profile offline_access openid"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        return components.url!
    }
}


struct AccessToken: Equatable, Codable {
    var token: String
    var refreshToken: String?
    var scope: String?
    var type: String?
    var expiresIn: Int?
    var issuedAt: Date
    
    /// The date when the access token expires
    var expiresAt: Date? {
        guard let expiresIn = expiresIn else { return nil }
        return issuedAt.addingTimeInterval(TimeInterval(expiresIn))
    }
}
