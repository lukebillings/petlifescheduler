import SwiftUI

/// iOS 26 Liquid Glass control — uses system `GlassButtonStyle`.
struct LiquidGlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 56, height: 48)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Primary CTA using prominent glass (for future schedule actions).
struct LiquidGlassProminentButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.glassProminent)
    }
}

#Preview("Icon buttons") {
    GlassEffectContainer(spacing: 16) {
        HStack(spacing: 16) {
            LiquidGlassIconButton(systemImage: "leaf.fill", accessibilityLabel: "Feeding") {}
            LiquidGlassIconButton(systemImage: "figure.walk", accessibilityLabel: "Walk") {}
        }
    }
    .padding(40)
    .background(
      LinearGradient(
        colors: [Color(white: 0.95), Color(white: 0.88)],
        startPoint: .top,
        endPoint: .bottom
      )
    )
    .preferredColorScheme(.light)
}

#Preview("Prominent") {
    LiquidGlassProminentButton("Add event", systemImage: "plus.circle.fill") {}
        .padding()
        .preferredColorScheme(.light)
}
