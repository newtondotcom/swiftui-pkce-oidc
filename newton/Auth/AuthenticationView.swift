//
//  AuthenticationView.swift
//  newton
//
//  Created by Robin Augereau on 13/10/2025.
//

import AuthenticationServices
import Combine
import CryptoKit
import SwiftUI

extension AuthenticationProvider {
    static let customProvider = AuthenticationProvider(
        authorizeBaseURL: URL(string: "https://myr-project.eu/application/o/authorize/")!,
        accessTokenURL: URL(string: "https://myr-project.eu/application/o/token/")!,
        clientId: "t9xFI53nHMTMRduUB1Kt2fUpV1IcFOfNXUZHjpmZ",
        redirectUri: "myapp://oauth-callback"
    )
}

// add discovery ?


struct AuthenticationView: View {
    @ObservedObject var session: AuthenticationSession

    init(presentationAnchor: ASPresentationAnchor) {
        session = AuthenticationSession(provider: .customProvider, presentationAnchor: presentationAnchor)
    }

    var body: some View {
        currentStateView()
    }

    private func currentStateView() -> AnyView {
        switch session.state {
        case .initialized:
            return AnyView(Button("Authenticate now") {
                self.session.start()
            })
        case .authenticating:
            return AnyView(Text("Authenticating..."))
        case .accessCodeReceived:
            return AnyView(Text("Exchanging code for access token..."))
        case .authenticated(_):
            return AnyView(VStack {
                Text("Authenticated")
                Button("Refresh"){
                    session.refreshAccessToken { token in
                        print(token?.token)
                    }
                }
            }.padding())
        case .failed:
            return AnyView(authenticationEnded("Authentication failed"))
        case .error:
            return AnyView(authenticationEnded("Authentication error"))
        case .cancelled:
            return AnyView(authenticationEnded("Authentication cancelled"))
        }
    }

    private func authenticationEnded(_ message: String) -> some View {
        VStack {
            Text(message)
            Button("Reset") {
                self.session.reset()
            }
        }
    }
}
