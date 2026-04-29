import SwiftUI

// MARK: - Environment

private struct InterfaceMotionEnabledKey: EnvironmentKey {
    /// Default when no ancestor sets it (e.g. previews).
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Micro slide-in animations for lists and panels; respects Settings and Reduce Motion via `HomeView`.
    var interfaceMotionEnabled: Bool {
        get { self[InterfaceMotionEnabledKey.self] }
        set { self[InterfaceMotionEnabledKey.self] = newValue }
    }
}

// MARK: - Row stagger (lists)

private struct SlideInRowModifier: ViewModifier {
    let index: Int

    @Environment(\.interfaceMotionEnabled) private var motionEnabled
    @State private var shown = false
    @State private var didSchedule = false

    func body(content: Content) -> some View {
        content
            .opacity(motionEnabled ? (shown ? 1 : 0) : 1)
            .offset(y: motionEnabled ? (shown ? 0 : 14) : 0)
            .onAppear {
                guard motionEnabled else {
                    shown = true
                    return
                }
                guard !shown else { return }
                guard !didSchedule else { return }
                didSchedule = true
                let delay = Double(min(index, 18)) * 0.045
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        shown = true
                    }
                }
            }
    }
}

// MARK: - Panel entrance

private struct InterfaceContentEntranceModifier: ViewModifier {
    let delay: CGFloat

    @Environment(\.interfaceMotionEnabled) private var motionEnabled
    @State private var shown = false
    @State private var didStart = false

    func body(content: Content) -> some View {
        content
            .opacity(motionEnabled ? (shown ? 1 : 0) : 1)
            .offset(y: motionEnabled ? (shown ? 0 : 14) : 0)
            .onAppear {
                guard motionEnabled else {
                    shown = true
                    return
                }
                guard !didStart else { return }
                didStart = true
                let d = max(0, delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// Staggered slide-up + fade for list rows (`index` caps stagger depth).
    func interfaceSlideInRow(index: Int) -> some View {
        modifier(SlideInRowModifier(index: index))
    }

    /// Single panel fade + slide after optional delay (seconds).
    func interfaceContentEntrance(delay: CGFloat = 0) -> some View {
        modifier(InterfaceContentEntranceModifier(delay: delay))
    }
}
