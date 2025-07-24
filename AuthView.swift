import SwiftUI

enum AuthScreen {
    case choice
    case signUp
    case signIn
}

struct AuthView: View {
    @State private var currentScreen: AuthScreen = .choice
    var onAuthSuccess: () -> Void

    var body: some View {
        switch currentScreen {
        case .choice:
            VStack(spacing: 20) {
                Spacer()

                Text("Welcome to BuzzBuddies")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Button("Sign Up") {
                    currentScreen = .signUp
                }
                .font(.title2)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)

                Button("Sign In") {
                    currentScreen = .signIn
                }
                .font(.title2)
                .foregroundColor(.blue)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .padding(.horizontal)

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .edgesIgnoringSafeArea(.all)

        case .signUp:
            AuthFormView(mode: .signUp, onSuccess: onAuthSuccess) {
                currentScreen = .choice
            }

        case .signIn:
            AuthFormView(mode: .signIn, onSuccess: onAuthSuccess) {
                currentScreen = .choice
            }
        }
    }
}
