import SwiftUI

/// Names suggested for household pickers; combines profile, extras from Settings, and names seen on existing rows.
enum HouseholdPersonOptions {
    static func sortedNames(viewModel: HomeViewModel) -> [String] {
        var set = Set<String>()
        let mine = UserProfileStorage.trimmedDisplayName()
        if !mine.isEmpty { set.insert(mine) }
        for n in UserProfileStorage.rosterExtraNames() {
            let t = n.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { set.insert(t) }
        }
        for item in viewModel.scheduleItems {
            for n in [
                item.createdByDisplayName,
                item.assignedToDisplayName,
                item.completedByDisplayName,
            ] {
                let t = n.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { set.insert(t) }
            }
        }
        return Array(set).sorted()
    }
}

/// Rows only (no outer `Section`) — for embedding multiple people fields in one section.
struct HouseholdPersonInlineField: View {
    var title: String
    @Binding var name: String
    var viewModel: HomeViewModel

    private var options: [String] {
        HouseholdPersonOptions.sortedNames(viewModel: viewModel)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                TextField("", text: $name)
                    .textContentType(.name)
                    .multilineTextAlignment(.trailing)
                    .labelsHidden()
                    .accessibilityLabel(title)
                if !options.isEmpty {
                    Menu {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                name = option
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appPink)
                    }
                    .accessibilityLabel("Choose \(title.lowercased())")
                }
            }
        }
    }
}

/// One Form section for add/edit **events** and **logs**: people + assignee pill color.
struct HouseholdEventPeopleSingleSection: View {
    @Binding var createdBy: String
    @Binding var assignedTo: String
    @Binding var completedBy: String
    @Binding var assigneeAccent: ScheduleAssigneeAccent
    var viewModel: HomeViewModel
    /// When `false`, hides the "Assigned to" row (used by logs).
    var showAssignedTo: Bool = true
    /// When `false`, the row is hidden until the task is completed; completion flow sets the name automatically.
    var showCompletedBy: Bool = true

    var body: some View {
        Section {
            HouseholdPersonInlineField(title: "Created by", name: $createdBy, viewModel: viewModel)
            if showAssignedTo {
                HouseholdPersonInlineField(title: "Assigned to", name: $assignedTo, viewModel: viewModel)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Assignee pill color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ScheduleAssigneeAccent.allCases) { accent in
                            Button {
                                assigneeAccent = accent
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accent.swatchColor)
                                        .frame(width: 32, height: 32)
                                    if assigneeAccent == accent {
                                        Circle()
                                            .strokeBorder(Color.primary, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(accent.displayName)
                            .accessibilityAddTraits(assigneeAccent == accent ? [.isSelected] : [])
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            if showCompletedBy {
                HouseholdPersonInlineField(title: "Completed by", name: $completedBy, viewModel: viewModel)
            }
        } header: {
            Text("People")
        }
    }
}
