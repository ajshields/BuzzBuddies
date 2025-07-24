import SwiftUI

struct LightningSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: -6) {
            ForEach(0..<3) { index in
                Image(systemName: "bolt.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 30)
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation
                            .linear(duration: 1)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct LightningSpinner_Previews: PreviewProvider {
    static var previews: some View {
        LightningSpinner()
    }
}
