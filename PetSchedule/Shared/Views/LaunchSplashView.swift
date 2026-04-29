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

/// Two cats orbit **together on the inner ring** (opposite each other); two dogs orbit **together on the outer ring**
/// (opposite each other). Inner and outer use **different** speeds/phases so dogs aren’t “linked” to the cats — four independent sprites,
/// species grouped only by radius as requested (“two of each”).
private struct OrbitingPetIconsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let innerRadius: CGFloat = 78
    private let outerRadius: CGFloat = 118
    private let assetSize: CGFloat = 76

    /// Inner-ring angular velocity (rad/s).
    private let innerAngularSpeed: Double = 0.72
    /// Outer ring differs slightly so cats/dogs don’t rotate as one rigid crosshair.
    private let outerAngularSpeed: Double = -0.61

    private var orbitExtent: CGFloat {
        outerRadius * 2 + assetSize + 28
    }

    var body: some View {
        Group {
            if reduceMotion {
                quadRing(innerAngleBase: .pi * 0.25, outerAngleBase: .pi * 0.85)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let inner = t * innerAngularSpeed
                    let outer = t * outerAngularSpeed + 0.42
                    quadRing(innerAngleBase: inner, outerAngleBase: outer)
                }
            }
        }
        .frame(width: orbitExtent, height: orbitExtent)
    }

    /// Two cats opposite on inner circle; two dogs opposite on outer circle.
    private func quadRing(innerAngleBase: Double, outerAngleBase: Double) -> some View {
        ZStack {
            orbitingPetAsset("SplashCat", radius: innerRadius, angle: innerAngleBase)
            orbitingPetAsset("SplashCat", radius: innerRadius, angle: innerAngleBase + .pi)
            orbitingPetAsset("SplashDog", radius: outerRadius, angle: outerAngleBase)
            orbitingPetAsset("SplashDog", radius: outerRadius, angle: outerAngleBase + .pi)
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
