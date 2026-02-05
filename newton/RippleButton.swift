//
//  RippleButton.swift
//  newton
//
//  Created by Robin Augereau on 13/10/2025.
//

import SwiftUI

struct RippleButton: View {
    let title: String
    let action: () -> Void
    
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var rippleLocation: CGPoint = .zero
    @State private var isPressed = false
    
    // Gradient colors
    private let gradientColors = [
        Color(red: 0.42, green: 0.07, blue: 0.80), // #6a11cb
        Color(red: 0.15, green: 0.46, blue: 0.99)  // #2575fc
    ]
    
    var body: some View {
        Button(action: {
            action()
        }) {
            ZStack {
                // Main button background
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.29, green: 0.0, blue: 0.88), // #4a00e0
                                        Color(red: 0.15, green: 0.46, blue: 0.99)  // #2575fc
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(0.3),
                        radius: isPressed ? 2 : 8,
                        x: 0,
                        y: isPressed ? 1 : 4
                    )
                    .scaleEffect(isPressed ? 0.98 : 1.0)
                
                // Button text
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                
                // Ripple effect overlay
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 100, height: 100)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                    .position(rippleLocation)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let location = value.location
                    rippleLocation = location
                    
                    withAnimation(.easeOut(duration: 0.6)) {
                        rippleScale = 3.0
                        rippleOpacity = 0.8
                    }
                    
                    // Reset ripple effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            rippleScale = 0
                            rippleOpacity = 0
                        }
                    }
                }
        )
    }
}

#Preview {
    VStack(spacing: 30) {
        RippleButton(title: "Login") {
            print("Login tapped!")
        }
        
        RippleButton(title: "Sign Up") {
            print("Sign Up tapped!")
        }
        
        RippleButton(title: "Continue") {
            print("Continue tapped!")
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

