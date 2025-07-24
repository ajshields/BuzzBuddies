import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FriendRequest: Identifiable {
    let id: String
    let fromUID: String
    let firstName: String
    let lastName: String

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

struct FriendRequestsView: View {
    @State private var friendRequests: [FriendRequest] = []
    private var db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack {
                if friendRequests.isEmpty {
                    Text("No incoming friend requests")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(friendRequests) { request in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(request.fullName)
                                    .font(.headline)

                                HStack {
                                    Button(action: {
                                        acceptRequest(request)
                                    }) {
                                        Text("Accept")
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 16)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .contentShape(Rectangle())

                                    Button(action: {
                                        declineRequest(request)
                                    }) {
                                        Text("Decline")
                                            .foregroundColor(.white)
                                            .padding(.vertical, 6)
                                            .padding(.horizontal, 16)
                                            .background(Color.red)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .contentShape(Rectangle())
                                }
                            }
                            .padding(.vertical, 8)
                            // **No tap gesture on the entire row!**
                        }
                    }
                }
            }
            .navigationTitle("Friend Requests")
            .onAppear(perform: loadFriendRequests)
        }
    }

    private func loadFriendRequests() {
        guard let currentUser = Auth.auth().currentUser else {
            print("No current user.")
            return
        }

        db.collection("users")
            .document(currentUser.uid)
            .collection("friendRequests")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error loading friend requests: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No friend request documents found.")
                    return
                }

                var loadedRequests: [FriendRequest] = []
                let group = DispatchGroup()

                for doc in documents {
                    let data = doc.data()
                    let fromUID = data["fromUID"] as? String ?? ""

                    if !fromUID.isEmpty {
                        group.enter()
                        db.collection("users").document(fromUID).getDocument { snapshot, error in
                            defer { group.leave() }

                            guard let userData = snapshot?.data() else {
                                print("No user data for fromUID \(fromUID)")
                                return
                            }

                            let firstName = userData["firstName"] as? String ?? "Unknown"
                            let lastName = userData["lastName"] as? String ?? ""

                            loadedRequests.append(FriendRequest(
                                id: doc.documentID,
                                fromUID: fromUID,
                                firstName: firstName,
                                lastName: lastName
                            ))
                        }
                    } else {
                        print("Skipping request with empty fromUID")
                    }
                }

                group.notify(queue: .main) {
                    self.friendRequests = loadedRequests
                }
            }
    }

    private func acceptRequest(_ request: FriendRequest) {
        guard let currentUser = Auth.auth().currentUser else { return }

        let currentUserRef = db.collection("users").document(currentUser.uid)
        let senderRef = db.collection("users").document(request.fromUID)

        // Add sender to current user's friends
        currentUserRef.collection("friends").document(request.fromUID).setData([
            "firstName": request.firstName,
            "lastName": request.lastName,
            "timestamp": FieldValue.serverTimestamp()
        ])

        // Add current user to sender's friends (fetching current user's name)
        currentUserRef.getDocument { snapshot, error in
            if let data = snapshot?.data() {
                let myFirstName = data["firstName"] as? String ?? "Me"
                let myLastName = data["lastName"] as? String ?? ""

                senderRef.collection("friends").document(currentUser.uid).setData([
                    "firstName": myFirstName,
                    "lastName": myLastName,
                    "timestamp": FieldValue.serverTimestamp()
                ])
            }
        }

        // Remove the friend request
        currentUserRef.collection("friendRequests").document(request.id).delete()
    }

    private func declineRequest(_ request: FriendRequest) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUserRef = db.collection("users").document(currentUser.uid)
        currentUserRef.collection("friendRequests").document(request.id).delete()
    }
}
