import SwiftUI

/// Capsule-shaped pink header fill; bottom edge is a smooth wave into the screen body.
private struct PinkWaveHeaderCapShape: Shape {
    var waveAmplitude: CGFloat = 9
    /// Number of full wave cycles across the width.
    var cycles: CGFloat = 2.5
    /// Horizontal phase (radians) — advances over time so the wave appears to travel.
    var wavePhase: CGFloat = 0

    var animatableData: CGFloat {
        get { wavePhase }
        set { wavePhase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(24, Int(rect.width / 8))
        let baseline = rect.maxY - waveAmplitude * 1.25

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: waveY(x: rect.maxX, baseline: baseline, width: rect.width)))

        for s in stride(from: steps - 1, through: 0, by: -1) {
            let t = CGFloat(s) / CGFloat(steps)
            let x = rect.maxX * t
            path.addLine(to: CGPoint(x: x, y: waveY(x: x, baseline: baseline, width: rect.width)))
        }

        path.closeSubpath()
        return path
    }

    private func waveY(x: CGFloat, baseline: CGFloat, width: CGFloat) -> CGFloat {
        let phase = Double((x / width) * cycles * 2 * CGFloat.pi + wavePhase)
        return baseline + CGFloat(sin(phase)) * waveAmplitude
    }
}

/// Matches the Schedule tab title: large bold title aligned with horizontal padding; optional accessory sits inside the pink wave area.
struct PinkWaveScreenHeader<Accessory: View, Trailing: View>: View {
    let title: String
    /// Vertical gap between the title row and `accessory` (e.g. Schedule pet strip).
    var titleAccessorySpacing: CGFloat
    /// Space below `accessory` before the wavy bottom edge.
    var contentBottomPadding: CGFloat
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var trailing: () -> Trailing

    init(
        _ title: String,
        titleAccessorySpacing: CGFloat = 14,
        contentBottomPadding: CGFloat = 28,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.titleAccessorySpacing = titleAccessorySpacing
        self.contentBottomPadding = contentBottomPadding
        self.accessory = accessory
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: titleAccessorySpacing) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                trailing()
            }
            .padding(.horizontal)

            accessory()
        }
        .padding(.top, 20)
        .padding(.bottom, contentBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        /// Keeps clock / cellular / battery legible against `appPink` when the header reaches into the status bar.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                GeometryReader { proxy in
                    let topInset = proxy.safeAreaInsets.top
                    let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate * 1.15)
                    let width = proxy.size.width
                    let height = proxy.size.height + topInset
                    ZStack(alignment: .top) {
                        // Wave path leaves the troughs unfilled; match the screen body (grouped grey).
                        Color(.systemGroupedBackground)
                            .frame(width: width, height: height)
                            .offset(y: -topInset)
                        PinkWaveHeaderCapShape(wavePhase: phase)
                            .fill(Color.appPink)
                            .frame(width: width, height: height)
                            .offset(y: -topInset)
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
    }
}

extension PinkWaveScreenHeader where Accessory == EmptyView {
    init(
        _ title: String,
        titleAccessorySpacing: CGFloat = 14,
        contentBottomPadding: CGFloat = 28,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(
            title,
            titleAccessorySpacing: titleAccessorySpacing,
            contentBottomPadding: contentBottomPadding,
            accessory: { EmptyView() },
            trailing: trailing
        )
    }
}
