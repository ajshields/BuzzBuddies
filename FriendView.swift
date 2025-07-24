import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

struct FriendView: View {
    let friend: Friend
    @State private var currentUserFirstName: String = ""
    private let db = Firestore.firestore()

    @State private var time: CGFloat = 0.0
    @State private var peaks: [WavePeak] = []

    private let baseRadius: CGFloat = 130
    private let pointsCount = 360

    // Wave cycle duration (seconds)
    private let cycleDuration: CGFloat = 4.0

    // Vibration state
    @State private var isVibrating = false
    @State private var vibrationStartTime: Date?

    var body: some View {
        VStack(spacing: 40) {
            Text(friend.name)
                .font(.largeTitle)
                .bold()

            ZStack {
                RadialWaveShape(time: time, peaks: peaks, baseRadius: baseRadius)
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: 300, height: 300)  // changed height to 300 to keep circle shape

                Button(action: {
                    buzzFriend(friend)
                    triggerHaptic()
                    startVibration()
                }) {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.white)
                        .padding(40)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                }
                .accessibilityLabel("Buzz \(friend.name)")
            }

            Spacer()
        }
        .padding()
        .onAppear {
            fetchCurrentUserFirstName()
            regeneratePeaks()
            startTimer()
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            if isVibrating {
                updateVibrationPeaks()
                return
            }

            withAnimation(.linear(duration: 0)) {
                time += 1 / 60 / cycleDuration
                if time > 1 {
                    time = 0
                    // Removed regeneratePeaks() to avoid jumpy resets
                }
            }
        }
    }

    private func regeneratePeaks() {
        peaks = (0..<12).map { _ in
            WavePeak(
                angle: CGFloat.random(in: 0..<360),
                maxAmplitude: CGFloat.random(in: 20...60),
                width: CGFloat.random(in: 10...30),
                phase: CGFloat.random(in: 0..<2 * .pi)
            )
        }
    }

    private func startVibration() {
        guard !isVibrating else { return }
        isVibrating = true
        vibrationStartTime = Date()
    }

    private func updateVibrationPeaks() {
        guard let start = vibrationStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)

        let vibrationDuration = 1.0
        let vibrationFrequency = 50.0 // faster vibration for effect
        let vibrationPeakCount = 20   // more peaks around the circle during vibration
        let vibrationBaseAmplitude: CGFloat = 15
        let vibrationAmplitudeOscillation: CGFloat = 8
        let vibrationWidth: CGFloat = 12

        if elapsed > vibrationDuration {
            isVibrating = false
            regeneratePeaks()
            time = 0
            return
        }

        // Create evenly spaced peaks around the circle, oscillating quickly
        peaks = (0..<vibrationPeakCount).map { i in
            let angle = CGFloat(i) * (360 / CGFloat(vibrationPeakCount))
            let phase = CGFloat(i) * (.pi / 4)  // offset phases so peaks don't vibrate in sync
            let oscillation = CGFloat(sin(elapsed * vibrationFrequency * 2 * .pi + Double(phase)))
            return WavePeak(
                angle: angle,
                maxAmplitude: vibrationBaseAmplitude + oscillation * vibrationAmplitudeOscillation,
                width: vibrationWidth,
                phase: 0  // phase unused in vibration mode since oscillation handled manually
            )
        }
    }

    private func fetchCurrentUserFirstName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).getDocument { document, error in
            if let document = document, document.exists {
                if let firstName = document.data()?["firstName"] as? String {
                    self.currentUserFirstName = firstName
                }
            }
        }
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
                    showLocalNotification(from: currentUserFirstName)
                }
            }
    }

    private func showLocalNotification(from senderName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Buzz sent!"
        content.body = "You buzzed \(friend.name)"
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

    private func triggerHaptic() {
#if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
#endif
    }
}

// MARK: - Wave Model and Shape

struct WavePeak {
    var angle: CGFloat       // degrees location on circle
    var maxAmplitude: CGFloat  // max height of peak
    var width: CGFloat       // width of peak in degrees (controls how quickly amplitude falls off)
    var phase: CGFloat       // phase offset for oscillation
}

struct RadialWaveShape: Shape {
    var time: CGFloat        // normalized 0->1 progress of current wave cycle
    var peaks: [WavePeak]
    var baseRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        for i in 0...360 {
            let angle = CGFloat(i)
            var radius = baseRadius

            for peak in peaks {
                let rawDist = abs(angle - peak.angle)
                let distance = min(rawDist, 360 - rawDist)

                let falloff = exp(-pow(distance / peak.width, 2))

                // Use sine oscillation only if not vibrating (phase is 0 when vibrating)
                let oscillation: CGFloat
                if peak.phase == 0 {
                    oscillation = 1  // constant amplitude during vibration, oscillation handled in updateVibrationPeaks
                } else {
                    oscillation = (sin(2 * .pi * time + peak.phase) + 1) / 2
                }

                radius += falloff * peak.maxAmplitude * oscillation
            }

            let radian = angle * .pi / 180
            let x = center.x + radius * cos(radian)
            let y = center.y + radius * sin(radian)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.closeSubpath()
        return path
    }

    var animatableData: CGFloat {
        get { time }
        set { time = newValue }
    }
}
