import SwiftUI

struct PetsPlaceholderView: View {
    var viewModel: PetsPlaceholderViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Pets",
                systemImage: "hare.fill",
                description: Text("Pet profiles will live here.")
            )
            .navigationTitle("Pets")
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Pets placeholder") {
    PetsPlaceholderView(viewModel: PetsPlaceholderViewModel())
}
