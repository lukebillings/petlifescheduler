import SwiftUI
import UIKit

struct FamilySharingSettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    @State private var shareInviteURL: IdentifiableURL?
    @State private var isPreparingInviteLink = false
    @State private var householdParticipants: [HouseholdShareParticipantRow] = []
    @State private var isLoadingParticipants = false
    @State private var pastedInviteURL = ""
    @State private var isAcceptingInvite = false

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

            if !usesSharedDatabase {
                householdInvitePasteSection
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
            Text("Share Premium and your pets with the people you live with. Do **Step 1**, then **Step 2**, then **Step 3**.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                householdInstructionStep(1, "On **your** iPhone: open **Settings** → your **name** → **Family** → **Invite Others**.")
                householdInstructionStep(2, "Invite your partner or family member.")
                householdInstructionStep(3, "On **their** iPhone: open **Settings** → their **name** → **Family** and tap **Accept** on your invitation.")
                householdInstructionStep(4, "After they've accepted, they can use **Premium for free** in PetLifeScheduler.")
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
            Text("Apple Family Sharing is set up in the Settings app — you invite from your phone; they must accept on theirs. PetLifeScheduler can't show your Family list here; check Settings → your name → Family to see who's joined.")
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                householdInstructionStep(1, "Ask them to install **PetLifeScheduler** from the App Store on their iPhone **before** they tap your link.")
                householdInstructionStep(2, "They should be signed in to **iCloud** on that phone (Settings → their name).")
            }
            .padding(.vertical, 4)
        } header: {
            Label("Step 2 — Download the app", systemImage: "2.circle.fill")
        } footer: {
            Text("If they open the invite link before installing, they'll need to install the app and tap the link again to accept.")
        }

        Section {
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
            Label("Step 3 — Same pets & schedule", systemImage: "3.circle.fill")
        } footer: {
            Text("Send the link in Messages, Mail, AirDrop, or any app you like. After they install the app, they tap the link and accept the invite to sync pets, schedule, and logs.")
        }

        householdMembersSection
    }

    // MARK: - Accept invite link (TestFlight / paste fallback)

    @ViewBuilder
    private var householdInvitePasteSection: some View {
        Section {
            TextField("Paste invite link", text: $pastedInviteURL, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .lineLimit(3 ... 6)

            Button {
                Task { await acceptPastedInvite() }
            } label: {
                Group {
                    if isAcceptingInvite {
                        ProgressView()
                    } else {
                        Text("Accept household invite")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appPink)
            .disabled(
                pastedInviteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isAcceptingInvite
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("Received an invite?")
        } footer: {
            Text("If **Open in PetLifeScheduler** shows an App Store error, copy the link from Messages, paste it above, then tap Accept.")
        }
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
                     ? "No one has joined your shared pets yet. After you send the Step 3 link and they accept, they'll appear here."
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

    @MainActor
    private func acceptPastedInvite() async {
        let trimmed = pastedInviteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            sync.lastErrorMessage = "That doesn’t look like a valid invite link."
            return
        }

        isAcceptingInvite = true
        defer { isAcceptingInvite = false }

        do {
            try await HouseholdCloudKitService.shared.acceptIncomingShare(url: url)
            sync.lastErrorMessage = nil
            pastedInviteURL = ""
            await sync.syncNow(viewModel)
        } catch {
            sync.lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
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
