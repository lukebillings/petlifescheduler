import SwiftUI
import UIKit

struct FamilySharingSettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    @State private var shareInviteURL: IdentifiableURL?
    @State private var isPreparingInviteLink = false
    @State private var householdParticipants: [HouseholdShareParticipantRow] = []
    @State private var isLoadingParticipants = false

    private var usesSharedDatabase: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.prefersSharedDatabase)
    }

    private var canInviteAsOwner: Bool {
        !usesSharedDatabase
    }

    var body: some View {
        Form {
            if canInviteAsOwner {
                ownerInstructionsContent
            } else {
                participantContent
            }

            if sync.isSyncing {
                Section {
                    HStack {
                        ProgressView()
                        Text("Updating household…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let err = sync.lastErrorMessage {
                Section {
                    Text(err)
                        .font(AppTypography.supportingText)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await sync.syncNow(viewModel) }
                } label: {
                    Label("Update now", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            if usesSharedDatabase {
                Section {
                    Button(role: .destructive) {
                        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.prefersSharedDatabase)
                        sync.clearModificationCache()
                    } label: {
                        Label("Leave shared household on this phone", systemImage: "rectangle.portrait.and.arrow.forward")
                    }
                } footer: {
                    Text("Stops syncing shared pets and schedules on this device. Your local copy stays until you reset app data in Settings.")
                }
            }
        }
        .navigationTitle("Share with family")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $shareInviteURL, onDismiss: {
            Task { await reloadParticipants() }
        }) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
        .task {
            await reloadParticipants()
        }
    }

    // MARK: - Owner (organizer)

    @ViewBuilder
    private var ownerInstructionsContent: some View {
        Section {
            Text("Share Premium and your pets with the people you live with. Do **Step 1** first, then **Step 2**.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                householdInstructionStep(1, "Open **Settings** on your iPhone.")
                householdInstructionStep(2, "Tap your **name** at the top.")
                householdInstructionStep(3, "Tap **Family** → **Invite Others**.")
                householdInstructionStep(4, "Invite your partner or family member. When they join, they can use **Premium for free** in PetLifeScheduler.")
            }
            .padding(.vertical, 4)

            Button {
                openSystemSettings()
            } label: {
                Label("Open iPhone Settings", systemImage: "gear")
            }
        } header: {
            Label("Step 1 — Free Premium", systemImage: "1.circle.fill")
        } footer: {
            Text("Apple Family Sharing is set up in the Settings app. PetLifeScheduler can't show your Family list here — check Settings → your name → Family to see who's added.")
        }

        Section {
            Text("Send them a link so you both see the same pets, schedule, and logs. They must tap the link and accept on their phone (same Apple ID they use for iCloud).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task { await shareInviteLink() }
            } label: {
                Group {
                    if isPreparingInviteLink {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Share pets & schedule")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appPink)
            .disabled(isPreparingInviteLink)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Label("Step 2 — Same pets & schedule", systemImage: "2.circle.fill")
        } footer: {
            Text("Send the link in Messages, Mail, AirDrop, or any app you like. They tap it, accept the invite, then download or open PetLifeScheduler.")
        }

        householdMembersSection
    }

    // MARK: - Participant (joined someone else's household)

    @ViewBuilder
    private var participantContent: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're in a shared household")
                    .font(.headline)
                Text("Pets and schedules on this phone stay in sync with the person who invited you.")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                householdInstructionStep(1, "If the person who invited you has **Premium**, ask them to add you to their **Apple Family** (Settings → their name → Family).")
                householdInstructionStep(2, "Then you get **Premium for free** — no second subscription.")
            }
            .padding(.vertical, 4)

            Button {
                openSystemSettings()
            } label: {
                Label("Open iPhone Settings", systemImage: "gear")
            }
        } header: {
            Text("Free Premium")
        } footer: {
            Text("Only the person paying for Premium can add you to their Apple Family. Downloading the app alone doesn't share their subscription.")
        }

        householdMembersSection
    }

    @ViewBuilder
    private var householdMembersSection: some View {
        Section {
            if isLoadingParticipants {
                HStack {
                    ProgressView()
                    Text("Checking who's joined…")
                        .foregroundStyle(.secondary)
                }
            } else if householdParticipants.isEmpty {
                Text(canInviteAsOwner
                     ? "No one has joined your shared pets yet. After you send the Step 2 link and they accept, they'll appear here."
                     : "Ask the person who invited you to manage invites from their phone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(householdParticipants) { member in
                    HStack {
                        Label(member.displayName, systemImage: "person.fill")
                        Spacer()
                        Text(member.status)
                            .font(.caption)
                            .foregroundStyle(member.status == "Joined" ? .secondary : Color.orange)
                    }
                }
            }
        } header: {
            Text("Shared in PetLifeScheduler")
        } footer: {
            if canInviteAsOwner {
                Text("This list is people who accepted your pets & schedule link — not your Apple Family list.")
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func reloadParticipants() async {
        guard canInviteAsOwner || usesSharedDatabase else { return }
        isLoadingParticipants = true
        defer { isLoadingParticipants = false }
        if canInviteAsOwner {
            householdParticipants = await HouseholdCloudKitService.shared.fetchHouseholdShareParticipants()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: "App-Prefs:") else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func preparedInviteURL() async -> URL? {
        do {
            guard let url = try await HouseholdCloudKitService.shared.prepareInviteShareURL() else {
                sync.lastErrorMessage = "Couldn't create a link. Please try again in a moment."
                return nil
            }
            sync.lastErrorMessage = nil
            return url
        } catch {
            sync.lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    @MainActor
    private func shareInviteLink() async {
        guard !isPreparingInviteLink else { return }
        isPreparingInviteLink = true
        defer { isPreparingInviteLink = false }

        guard let url = await preparedInviteURL() else { return }
        shareInviteURL = IdentifiableURL(url: url)
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@ViewBuilder
private func householdInstructionStep(_ number: Int, _ text: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 10) {
        Text("\(number).")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 20, alignment: .trailing)
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
