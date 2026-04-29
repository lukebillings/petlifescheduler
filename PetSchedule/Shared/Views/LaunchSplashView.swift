import SwiftUI

/// Short branded splash: pink field with dog & cat icons orbiting the center before the main UI appears.
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
                    .font(.system(size: 34, weight: .bold, design: .rounded))
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

    private let icons = ["dog.fill", "cat.fill", "dog.fill", "cat.fill"]
    private let radius: CGFloat = 92

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
        .frame(width: radius * 2 + 56, height: radius * 2 + 56)
    }

    private var staticRing: some View {
        ring(angleOffset: 0)
    }

    private func ring(angleOffset: Double) -> some View {
        ZStack {
            ForEach(Array(icons.enumerated()), id: \.offset) { index, name in
                let base = 2 * Double.pi * Double(index) / Double(icons.count)
                let angle = base + angleOffset
                Image(systemName: name)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
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
