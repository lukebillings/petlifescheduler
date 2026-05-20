import SwiftUI

struct FamilySharingSettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    @State private var showInviteSheet = false

    private var usesSharedDatabase: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.prefersSharedDatabase)
    }

    var body: some View {
        Form {
            Section {
                if usesSharedDatabase {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sharing is on")
                            .font(.headline)
                        Text("This phone is part of a household. Pets and schedules update together over iCloud.")
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Sharing is off")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

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
            return "Each person needs iCloud turned on with their own Apple ID. After they accept, you all see the same pets and calendar. Tap Invite again anytime to see who is already in. To share your PetLifeScheduler Premium subscription with them, add them to your Apple Family in iOS Settings (Family Sharing must be on for the subscription)."
        }
        return "Each person needs iCloud on. The person who invited you can add more people from their own phone. If they're in your Apple Family, their Premium subscription covers you too."
    }
}
