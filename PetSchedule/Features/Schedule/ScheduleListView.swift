import SwiftUI

struct ScheduleListView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Text("Today")
                    .font(.title3.bold())

                Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue, in: Capsule())

                Spacer()

                Button {
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 12) {
                    ForEach(viewModel.todayItems) { item in
                        ScheduleRowView(item: item) {
                            viewModel.toggleCompletion(for: item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    ScheduleListView(viewModel: HomeViewModel())
        .padding(.top)
}
