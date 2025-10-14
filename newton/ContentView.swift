//
//  ContentView.swift
//  newton
//
//  Created by Robin Augereau on 13/10/2025.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var currentWindow: UIWindow? = nil

    var body: some View {
        Group {
            if let window = currentWindow {
                // Once the window is available, show the AuthenticationView
                AuthenticationView(presentationAnchor: window)
            } else {
                // Temporary placeholder until the window becomes available
                ProgressView("Loading...")
                    .onAppear {
                        // Get the first connected UIWindowScene
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            self.currentWindow = windowScene.windows.first
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
