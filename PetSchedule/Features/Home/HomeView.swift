import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
