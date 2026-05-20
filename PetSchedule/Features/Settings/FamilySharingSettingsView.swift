import SwiftUI
import UIKit

struct FamilySharingSettingsView: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject private var sync = HouseholdSyncCoordinator.shared

    @State private var showInviteSheet = false
    @State private var isPreparingInviteLink = false
    @State private var showLinkCopiedToast = false

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
                    Task { await copyInviteLink() }
                } label: {
                    HStack {
                        Label(
                            isPreparingInviteLink ? "Preparing link…" : "Copy invite link",
                            systemImage: "link"
                        )
                        Spacer()
                        if isPreparingInviteLink {
                            ProgressView()
                        }
                    }
                }
                .disabled(!canInviteAsOwner || isPreparingInviteLink)

                Button {
                    showInviteSheet = true
                } label: {
                    Label("More sharing options…", systemImage: "person.badge.plus")
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
        .overlay(alignment: .bottom) {
            if showLinkCopiedToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text("Invite link copied. Paste it anywhere.")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.appPink)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                )
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: showLinkCopiedToast)
    }

    private var canInviteAsOwner: Bool {
        !usesSharedDatabase
    }

    private var sharingFooter: String {
        if canInviteAsOwner {
            return "Tap Copy invite link, then paste into Messages, WhatsApp, email, or anywhere else. Or tap More sharing options for AirDrop / Mail / Messages. To share your PetLifeScheduler Premium subscription with them, add them to your Apple Family in iOS Settings (Family Sharing must be on for the subscription)."
        }
        return "Each person needs iCloud on. The person who invited you can add more people from their own phone. If they're in your Apple Family, their Premium subscription covers you too."
    }

    @MainActor
    private func copyInviteLink() async {
        guard !isPreparingInviteLink else { return }
        isPreparingInviteLink = true
        defer { isPreparingInviteLink = false }

        do {
            guard let url = try await HouseholdCloudKitService.shared.prepareInviteShareURL() else {
                sync.lastErrorMessage = "Couldn't create an invite link. Please try again in a moment."
                return
            }
            UIPasteboard.general.url = url
            HapticManager.notification(.success)
            sync.lastErrorMessage = nil

            showLinkCopiedToast = true
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            showLinkCopiedToast = false
        } catch {
            sync.lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
