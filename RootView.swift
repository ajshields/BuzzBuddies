import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isAuthenticated: Bool? = nil

    var body: some View {
        Group {
            if isAuthenticated == nil {
                ProgressView("Checking auth status...")
                    .onAppear(perform: checkAuth)
            } else if isAuthenticated == true {
                HomeView()
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UserDidSignOut"))) { _ in
                        isAuthenticated = false
                    }
            } else {
                AuthView {
                    self.isAuthenticated = true
                }
            }
        }
    }

    private func checkAuth() {
        isAuthenticated = Auth.auth().currentUser != nil
    }
}
