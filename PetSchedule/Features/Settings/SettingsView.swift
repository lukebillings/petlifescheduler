import SwiftUI

struct SettingsView: View {
    @State private var remindersEnabled = true
    @State private var completionAlerts = false
    @State private var dailySummary = true

    var body: some View {
        NavigationStack {
            List {
                Section("Notifications") {
                    Toggle("Enable reminders", isOn: $remindersEnabled)
                    Toggle("Completion alerts", isOn: $completionAlerts)
                    Toggle("Daily summary", isOn: $dailySummary)
                }

                Section("Pets") {
                    Label("Manage pets", systemImage: "pawprint.fill")
                    Label("Add new pet", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.appPink)
                }

                Section("App") {
                    Label("Version 1.0", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
