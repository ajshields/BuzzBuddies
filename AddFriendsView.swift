import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AddFriendsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email: String = ""
    @State private var message: String = ""         // For success/error messages
    @State private var isLoading: Bool = false      // For UI loading state
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add a Friend")
                    .font(.title)
                    .padding(.top)
                
                TextField("Enter friend's email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                
                if isLoading {
                    ProgressView()
                }
                
                Button(action: {
                    sendFriendRequestToEmail(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                }) {
                    Text("Send Friend Request")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(email.isEmpty || isLoading)
                
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(message.contains("success") ? .green : .red)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Friend")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    //Find user by email
    private func findUserByEmail(_ email: String, completion: @escaping (String?) -> Void) {
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error searching user by email: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                if let documents = snapshot?.documents, let doc = documents.first {
                    completion(doc.documentID)  // Return UID of user found
                } else {
                    completion(nil)  // No user found
                }
            }
    }
    
    //Send friend request logic
    private func sendFriendRequestToEmail(_ email: String) {
        guard !email.isEmpty else {
            message = "Please enter an email."
            return
        }
        
        isLoading = true
        message = ""
        
        findUserByEmail(email) { userUID in
            DispatchQueue.main.async {
                isLoading = false
                
                guard let userUID = userUID else {
                    message = "No user found with that email."
                    return
                }
                
                guard let currentUID = Auth.auth().currentUser?.uid else {
                    message = "User not logged in."
                    return
                }
                
                if userUID == currentUID {
                    message = "You cannot add yourself."
                    return
                }
                
                // Call the function that sends the friend request to Firestore
                sendFriendRequest(to: userUID)
            }
        }
    }
    
    //Actual Firestore write to send friend request
    private func sendFriendRequest(to recipientUID: String) {
        guard let senderUID = Auth.auth().currentUser?.uid else { return }
        
        let requestData: [String: Any] = [
            "fromUID": senderUID,
            "timestamp": Timestamp()
        ]
        
        db.collection("users")
            .document(recipientUID)
            .collection("friendRequests")
            .document(senderUID) // use senderUID as doc ID to prevent duplicates
            .setData(requestData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error sending friend request: \(error.localizedDescription)")
                        message = "Failed to send friend request."
                    } else {
                        print("Friend request sent!")
                        message = "Friend request sent successfully."
                        email = ""
                    }
                }
            }
    }
}

struct AddFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        AddFriendsView()
    }
}
