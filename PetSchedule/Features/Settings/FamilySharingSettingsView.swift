import SwiftUI

struct FamilySharingSettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    @AppStorage(UserProfileStorage.displayNameKey) private var userDisplayName = ""
    @State private var showInviteSheet = false
    @State private var rosterDraft = ""

    private var usesSharedDatabase: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.prefersSharedDatabase)
    }

    var body: some View {
        Form {
            Section {
                Label(syncStatusTitle, systemImage: syncGlyph)
                if sync.isSyncing {
                    ProgressView()
                }
                if let err = sync.lastErrorMessage {
                    Text(err)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Status")
            }

            Section {
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite household members", systemImage: "person.badge.plus")
                }
                .disabled(!canInviteAsOwner)

                Button {
                    Task { await sync.syncNow(viewModel) }
                } label: {
                    Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                }
            } header: {
                Text("Sharing")
            } footer: {
                Text("Uses iCloud so pets and schedules stay up to date for everyone who accepts the invitation. They must sign in to iCloud on their device.")
            }

            Section {
                TextField("Your display name", text: $userDisplayName)
                    .textContentType(.name)

                TextField("Add another person’s name", text: $rosterDraft)
                    .textContentType(.name)

                Button("Add to picker list") {
                    let n = rosterDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    var extras = UserProfileStorage.rosterExtraNames()
                    extras.append(n)
                    UserProfileStorage.setRosterExtraNames(extras)
                    rosterDraft = ""
                }

                if UserProfileStorage.rosterExtraNames().isEmpty {
                    Text("Extra names appear in Logged by when adding events or logs.")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(UserProfileStorage.rosterExtraNames(), id: \.self) { name in
                        Text(name)
                    }
                }
            } header: {
                Text("Household names")
            }

            Section {
                Text(participantsFooter)
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Participants")
            }

            Section {
                Button(role: .destructive) {
                    UserDefaults.standard.set(false, forKey: UserDefaultsKeys.prefersSharedDatabase)
                    sync.clearModificationCache()
                } label: {
                    Label("Leave household on this device", systemImage: "rectangle.portrait.and.arrow.forward")
                }
            } footer: {
                Text("Stops using the shared iCloud library on this device (your local draft stays until you reset data).")
            }
        }
        .navigationTitle("Household")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showInviteSheet) {
            CloudSharingSheet(isPresented: $showInviteSheet, container: HouseholdCloudKitService.shared.container)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var syncStatusTitle: String {
        usesSharedDatabase ? "Joined shared household" : "Organizer — private iCloud library"
    }

    private var syncGlyph: String {
        usesSharedDatabase ? "person.3.fill" : "house.fill"
    }

    private var canInviteAsOwner: Bool {
        !usesSharedDatabase
    }

    private var participantsFooter: String {
        "After someone accepts, they appear in Apple’s share participants UI when you tap Invite again. Everyone sees Logged by names on events."
    }
}
