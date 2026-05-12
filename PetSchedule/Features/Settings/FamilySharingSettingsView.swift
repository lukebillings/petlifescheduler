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
                VStack(alignment: .leading, spacing: 6) {
                    Text(usesSharedDatabase ? "Sharing is on" : "Sharing is off")
                        .font(.headline)
                    Text(usesSharedDatabase
                         ? "This phone is part of a household. Pets and schedules update together over iCloud."
                         : "Right now only you see this pet data on iCloud. Send an invite when you want someone else on the same plan.")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)

                if sync.isSyncing {
                    ProgressView()
                }
                if let err = sync.lastErrorMessage {
                    Text(err)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Invite someone", systemImage: "person.badge.plus")
                }
                .disabled(!canInviteAsOwner)

                Button {
                    Task { await sync.syncNow(viewModel) }
                } label: {
                    Label("Update now", systemImage: "arrow.triangle.2.circlepath")
                }
            } header: {
                Text("Household")
            } footer: {
                Text(sharingFooter)
            }

            Section {
                TextField("Your name", text: $userDisplayName)
                    .textContentType(.name)

                TextField("Another household name (optional)", text: $rosterDraft)
                    .textContentType(.name)

                Button("Add name") {
                    let n = rosterDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    var extras = UserProfileStorage.rosterExtraNames()
                    extras.append(n)
                    UserProfileStorage.setRosterExtraNames(extras)
                    rosterDraft = ""
                }

                if UserProfileStorage.rosterExtraNames().isEmpty {
                    Text("No extra names yet.")
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(UserProfileStorage.rosterExtraNames(), id: \.self) { name in
                        Text(name)
                    }
                }
            } header: {
                Text("Who did it?")
            } footer: {
                Text("When you log a feeding or walk, you can pick a name. Add people here so their names are easy to choose—even before they join on their phone.")
                    .font(AppTypography.supportingText)
            }

            Section {
                Button(role: .destructive) {
                    UserDefaults.standard.set(false, forKey: UserDefaultsKeys.prefersSharedDatabase)
                    sync.clearModificationCache()
                } label: {
                    Label("Stop sharing on this phone", systemImage: "rectangle.portrait.and.arrow.forward")
                }
            } footer: {
                Text("This phone stops using the shared household data. Your local copy stays until you reset app data elsewhere in Settings.")
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

    private var canInviteAsOwner: Bool {
        !usesSharedDatabase
    }

    private var sharingFooter: String {
        if canInviteAsOwner {
            return "Each person needs iCloud turned on with their own Apple ID. After they accept, you all see the same pets and calendar. Tap Invite again anytime to see who is already in."
        }
        return "Each person needs iCloud on. The person who invited you can add more people from their own phone."
    }
}
