import SwiftUI

/// Short branded splash: pink field with app-icon artwork orbiting before the main UI appears.
struct LaunchSplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.appPink
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                OrbitingPetIconsView()

                Text("PetSchedule")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 48)
        }
        .onAppear {
            let seconds = reduceMotion ? 1.0 : 2.3
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                onFinished()
            }
        }
    }
}

// MARK: - Orbiting icons

private struct OrbitingPetIconsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Left/right halves of `AppIcon.png` — same cat & dog faces as the home-screen icon.
    private let orbitingAssets = ["SplashCat", "SplashDog", "SplashCat", "SplashDog"]
    private let radius: CGFloat = 100
    private let assetSize: CGFloat = 76

    var body: some View {
        Group {
            if reduceMotion {
                staticRing
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { timeline in
                    let spin = timeline.date.timeIntervalSinceReferenceDate * 0.72
                    ring(angleOffset: spin)
                }
            }
        }
        .frame(width: radius * 2 + assetSize + 24, height: radius * 2 + assetSize + 24)
    }

    private var staticRing: some View {
        ring(angleOffset: 0)
    }

    private func ring(angleOffset: Double) -> some View {
        ZStack {
            ForEach(Array(orbitingAssets.enumerated()), id: \.offset) { index, assetName in
                let base = 2 * Double.pi * Double(index) / Double(orbitingAssets.count)
                let angle = base + angleOffset
                Image(assetName)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: assetSize, height: assetSize)
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
                    .offset(
                        x: radius * CGFloat(sin(angle)),
                        y: -radius * CGFloat(cos(angle))
                    )
            }
        }
    }
}

#Preview {
    LaunchSplashView(onFinished: {})
}
