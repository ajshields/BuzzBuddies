import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import AudioToolbox

struct Friend: Identifiable, Hashable {
    let id: String
    let name: String
}

struct HomeView: View {
    @State private var friends: [Friend] = []
    @State private var showAddFriendSheet = false
    @State private var showFriendRequests = false
    @State private var pendingFriendRequestCount: Int = 0
    @State private var selectedFriend: Friend? = nil
    @State private var showFriendView: Bool = false

    private var db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            List {
                ForEach(friends) { friend in
                    HStack {
                        Text(friend.name)
                            .font(.headline)

                        Spacer()

                        Button(action: {
                            buzzFriend(friend)
                        }) {
                            Image(systemName: "bolt.fill")
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle()) // Makes the whole row tappable
                    .onTapGesture {
                        navigateToFriend(friend)
                    }
                }
            }
            .navigationTitle("Your Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddFriendSheet = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add Friend")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ZStack(alignment: .topTrailing) {
                        Menu {
                            Button(action: {
                                showFriendRequests = true
                            }) {
                                Label("Friend Requests", systemImage: "bell")
                            }

                            Button(role: .destructive, action: {
                                signOut()
                            }) {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }

                        if pendingFriendRequestCount > 0 {
                            BadgeView(count: pendingFriendRequestCount)
                                .offset(x: 10, y: -10)
                        }
                    }
                    .accessibilityLabel("Menu")
                }
            }
            .onAppear {
                requestNotificationPermission()
                loadFriends()
                listenForBuzzes()
                loadPendingFriendRequestCount()
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendsView()
            }
            .sheet(isPresented: $showFriendRequests) {
                FriendRequestsView()
            }
            .navigationDestination(isPresented: $showFriendView) {
                if let friend = selectedFriend {
                    FriendView(friend: friend)
                }
            }
        }
    }

    struct BadgeView: View {
        let count: Int

        var body: some View {
            Text("\(count)")
                .font(.caption2).bold()
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.red)
                .clipShape(Circle())
                .shadow(radius: 1)
        }
    }

    private func loadPendingFriendRequestCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).collection("friendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading friend requests count: \(error.localizedDescription)")
                    return
                }

                let count = snapshot?.documents.count ?? 0
                DispatchQueue.main.async {
                    pendingFriendRequestCount = count
                }
            }
    }

    private func loadFriends() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No current user UID")
            return
        }

        db.collection("users").document(uid).collection("friends").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error loading friends: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No friend documents found")
                return
            }

            var loadedFriends: [Friend] = []

            let group = DispatchGroup()

            for doc in documents {
                let friendUID = doc.documentID
                group.enter()

                db.collection("users").document(friendUID).getDocument { friendDoc, error in
                    defer { group.leave() }

                    if let error = error {
                        print("Error fetching friend data: \(error.localizedDescription)")
                        return
                    }

                    guard let friendData = friendDoc?.data() else {
                        print("No data found for friend: \(friendUID)")
                        return
                    }

                    let firstName = friendData["firstName"] as? String ?? ""
                    let lastName = friendData["lastName"] as? String ?? ""
                    let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

                    let friend = Friend(id: friendUID, name: fullName.isEmpty ? "No Name" : fullName)
                    loadedFriends.append(friend)
                }
            }

            group.notify(queue: .main) {
                self.friends = loadedFriends
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    private func listenForBuzzes() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).collection("buzzes")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening for buzzes: \(error.localizedDescription)")
                    return
                }

                guard let doc = snapshot?.documents.first,
                      let fromId = doc.data()["from"] as? String else { return }

                fetchSenderName(fromId) { name in
                    triggerHapticFeedback()
                    showLocalNotification(from: name)
                }
            }
    }

    private func fetchSenderName(_ userId: String, completion: @escaping (String) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let first = data["firstName"] as? String,
               let last = data["lastName"] as? String {
                completion("\(first) \(last)")
            } else {
                completion("Someone")
            }
        }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func buzzFriend(_ friend: Friend) {
        guard let senderUID = Auth.auth().currentUser?.uid else { return }

        let buzzData: [String: Any] = [
            "from": senderUID,
            "timestamp": Timestamp()
        ]

        db.collection("users")
            .document(friend.id)
            .collection("buzzes")
            .addDocument(data: buzzData) { error in
                if let error = error {
                    print("Error sending buzz: \(error.localizedDescription)")
                } else {
                    print("Buzz sent to \(friend.name)")
                }
            }
    }

    private func showLocalNotification(from senderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Buzz received!"
        content.body = "\(senderName) buzzed you"
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    private func navigateToFriend(_ friend: Friend) {
        selectedFriend = friend
        showFriendView = true
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            NotificationCenter.default.post(name: Notification.Name("UserDidSignOut"), object: nil)
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
}
