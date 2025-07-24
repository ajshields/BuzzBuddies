import SwiftUI
import Firebase

@main
struct BuzzBuddiesApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
