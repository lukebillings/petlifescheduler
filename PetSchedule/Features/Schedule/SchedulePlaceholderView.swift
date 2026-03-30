import SwiftUI

struct SchedulePlaceholderView: View {
    var viewModel: SchedulePlaceholderViewModel

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Schedule",
                systemImage: "calendar",
                description: Text("Calendar and reminders will live here.")
            )
            .navigationTitle("Schedule")
        }
        .preferredColorScheme(.light)
    }
}

#Preview("Schedule placeholder") {
    SchedulePlaceholderView(viewModel: SchedulePlaceholderViewModel())
}
