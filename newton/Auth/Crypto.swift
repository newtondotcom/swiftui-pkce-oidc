//
//  Crypto.swift
//  newton
//
//  Created by Robin Augereau on 13/10/2025.
//

import CryptoKit
import Foundation
import Security


extension Data {
    // Returns a base64 encoded string, replacing reserved characters
    // as per the PKCE spec https://tools.ietf.org/html/rfc7636#section-4.2
    func pkce_base64EncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

enum PKCE {
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).pkce_base64EncodedString()
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).pkce_base64EncodedString()
    }
}
