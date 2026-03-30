import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                HomeBackgroundView()

                VStack(spacing: 28) {
                    Spacer(minLength: 12)

                    VStack(spacing: 8) {
                        Text("Pet Schedule")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Your timeline will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    GlassQuickActionsBar()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}

private struct HomeBackgroundView: View {
    var body: some View {
        LinearGradient(
          colors: [
            Color(red: 0.97, green: 0.98, blue: 1.0),
            Color(red: 0.93, green: 0.96, blue: 0.99)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct GlassQuickActionsBar: View {
    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                LiquidGlassIconButton(systemImage: "leaf.fill", accessibilityLabel: "Feeding") {}
                LiquidGlassIconButton(systemImage: "figure.walk", accessibilityLabel: "Walk") {}
                LiquidGlassIconButton(systemImage: "cross.case.fill", accessibilityLabel: "Vet") {}
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 4)
    }
}

#Preview("Home") {
    HomeView(viewModel: HomeViewModel())
}
