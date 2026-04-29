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

/// Cat and dog each follow **their own** circular path (nested rings), so they never sit side-by-side as duplicated pairs.
private struct OrbitingPetIconsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Inner path — cat only (`SplashCat` matches app-icon artwork).
    private let innerRadius: CGFloat = 78
    /// Outer path — dog only.
    private let outerRadius: CGFloat = 118
    private let assetSize: CGFloat = 76

    /// Rad/s — same feel as the previous single-ring splash.
    private let angularSpeed: Double = 0.72

    private var orbitExtent: CGFloat {
        outerRadius * 2 + assetSize + 28
    }

    var body: some View {
        Group {
            if reduceMotion {
                dualRing(catAngle: .pi * 0.5, dogAngle: -.pi * 0.5)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { timeline in
                    let spin = timeline.date.timeIntervalSinceReferenceDate * angularSpeed
                    // Cat on inner ring clockwise; dog on outer ring counter-clockwise so they weave instead of lining up.
                    dualRing(catAngle: spin, dogAngle: -spin)
                }
            }
        }
        .frame(width: orbitExtent, height: orbitExtent)
    }

    private func dualRing(catAngle: Double, dogAngle: Double) -> some View {
        ZStack {
            orbitingPetAsset("SplashCat", radius: innerRadius, angle: catAngle)
            orbitingPetAsset("SplashDog", radius: outerRadius, angle: dogAngle)
        }
    }

    private func orbitingPetAsset(_ name: String, radius: CGFloat, angle: Double) -> some View {
        Image(name)
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

#Preview {
    LaunchSplashView(onFinished: {})
}
