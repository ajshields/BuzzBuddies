import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthFormView: View {
    enum Mode {
        case signIn, signUp
    }

    var mode: Mode
    var onSuccess: () -> Void
    var onBack: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text(mode == .signUp ? "Create Account" : "Sign In")
                    .font(.largeTitle)
                    .bold()
                
                // Only show name fields during sign up
                if mode == .signUp {
                    TextField("First Name", text: $firstName)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)

                    TextField("Last Name", text: $lastName)
                        .autocapitalization(.words)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Button(action: {
                    isLoading = true
                    if mode == .signUp {
                        handleSignUp()
                    } else {
                        handleSignIn()
                    }
                }) {
                    Text(mode == .signUp ? "Sign Up" : "Sign In")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(isLoading)

                Button("Back") {
                    onBack()
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding()

            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2)
                        Text("Loading...")
                            .foregroundColor(.white)
                            .bold()
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func handleSignIn() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            isLoading = false
            if let error = error {
                self.errorMessage = "Sign In Error: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil
                NotificationManager.requestNotificationPermissions()
                onSuccess()
            }
        }
    }

    private func handleSignUp() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.isLoading = false
                self.errorMessage = "Sign Up Error: \(error.localizedDescription)"
            } else if let user = result?.user {
                self.saveUserData(uid: user.uid)
            } else {
                self.isLoading = false
                self.errorMessage = "Unexpected error during sign up."
            }
        }
    }
    // Save name + email to Firestore
    private func saveUserData(uid: String) {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email
        ]

        db.collection("users").document(uid).setData(userData) { error in
            isLoading = false
            if let error = error {
                self.errorMessage = "Firestore Error: \(error.localizedDescription)"
            } else {
                self.errorMessage = nil
                NotificationManager.requestNotificationPermissions()
                onSuccess()
            }
        }
    }
}
