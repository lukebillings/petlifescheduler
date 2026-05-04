import SwiftUI

private extension PostTutorialHintID {
    var title: String {
        switch self {
        case .scheduleTryEvent: return "Plan something on the timeline"
        case .scheduleTryLog: return "Log a moment"
        case .petsOpenProfileExtras: return "Finish a pet profile"
        case .petsAddAnother: return "Add another pet"
        }
    }

    var message: String {
        switch self {
        case .scheduleTryEvent:
            return "Tap + Event to add walks, visits, medications, or anything that repeats."
        case .scheduleTryLog:
            return "Tap + Log to record walks, meals, bathroom trips, mood, and quick notes."
        case .petsOpenProfileExtras:
            return "Tap a pet for vet details, documents, and weight or height logs."
        case .petsAddAnother:
            return "Tap + (top right) to add more companions."
        }
    }
}

enum PostTutorialHints {
    private enum StoredState: String {
        case pending, done, ignored
    }

    /// Bumps so SwiftUI views that read `@AppStorage(revisionKey)` redraw hint stacks.
    private static func bumpRevision() {
        let key = PostTutorialHintPersistence.revisionKey
        let r = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(r + 1, forKey: key)
    }

    static var revisionStorageKey: String { PostTutorialHintPersistence.revisionKey }

    /// Run once when the tab-bar tutorial overlay is dismissed (finished or skipped).
    static func startHintBundleIfNeeded() {
        let bundleKey = PostTutorialHintPersistence.bundleKey
        guard !UserDefaults.standard.bool(forKey: bundleKey) else { return }
        UserDefaults.standard.set(true, forKey: bundleKey)
        bumpRevision()
    }

    static var isHintBundleActive: Bool {
        UserDefaults.standard.bool(forKey: PostTutorialHintPersistence.bundleKey)
    }

    private static func state(for id: PostTutorialHintID) -> StoredState {
        guard let raw = UserDefaults.standard.string(forKey: PostTutorialHintPersistence.stateKey(id)),
              let s = StoredState(rawValue: raw) else { return .pending }
        return s
    }

    static func shouldShow(_ id: PostTutorialHintID) -> Bool {
        guard isHintBundleActive else { return false }
        return state(for: id) == .pending
    }

    static func markDone(_ id: PostTutorialHintID) {
        UserDefaults.standard.set(StoredState.done.rawValue, forKey: PostTutorialHintPersistence.stateKey(id))
        bumpRevision()
    }

    static func markIgnored(_ id: PostTutorialHintID) {
        UserDefaults.standard.set(StoredState.ignored.rawValue, forKey: PostTutorialHintPersistence.stateKey(id))
        bumpRevision()
    }

    /// Clears the hint program — call when wiping app data / restarting onboarding.
    static func resetForFreshInstall() {
        PostTutorialHintPersistence.resetForFreshInstall()
    }

    /// Marks hints done when the app already reflects the behaviour (optional nudge).
    static func syncScheduleAndPets(with viewModel: HomeViewModel) {
        guard isHintBundleActive else { return }

        captureScheduleBaselineIfNeeded(from: viewModel)
        let baselineNonLog = UserDefaults.standard.integer(forKey: PostTutorialHintPersistence.baselineNonLogScheduleCountKey)
        let baselineLogs = UserDefaults.standard.integer(forKey: PostTutorialHintPersistence.baselineQuickLogScheduleCountKey)
        let nonLogNow = nonLogScheduleCount(viewModel)
        let logsNow = quickLogScheduleCount(viewModel)

        var changed = false
        if logsNow > baselineLogs {
            if state(for: .scheduleTryLog) == .pending {
                UserDefaults.standard.set(StoredState.done.rawValue, forKey: PostTutorialHintPersistence.stateKey(.scheduleTryLog))
                changed = true
            }
        }
        if nonLogNow > baselineNonLog {
            if state(for: .scheduleTryEvent) == .pending {
                UserDefaults.standard.set(StoredState.done.rawValue, forKey: PostTutorialHintPersistence.stateKey(.scheduleTryEvent))
                changed = true
            }
        }

        let anyPetEnriched = viewModel.pets.contains { pet in
            !pet.vetDetails.isEmpty || !pet.documents.isEmpty || !pet.weightHistory.isEmpty || !pet.heightHistory.isEmpty
        }
        if anyPetEnriched, state(for: .petsOpenProfileExtras) == .pending {
            UserDefaults.standard.set(StoredState.done.rawValue, forKey: PostTutorialHintPersistence.stateKey(.petsOpenProfileExtras))
            changed = true
        }
        if viewModel.pets.count >= 2, state(for: .petsAddAnother) == .pending {
            UserDefaults.standard.set(StoredState.done.rawValue, forKey: PostTutorialHintPersistence.stateKey(.petsAddAnother))
            changed = true
        }

        if changed { bumpRevision() }
    }

    private static func nonLogScheduleCount(_ vm: HomeViewModel) -> Int {
        vm.scheduleItems.filter { $0.quickLogKind == nil }.count
    }

    private static func quickLogScheduleCount(_ vm: HomeViewModel) -> Int {
        vm.scheduleItems.filter { $0.quickLogKind != nil }.count
    }

    /// First sync after the bundle arms: freeze counts so onboarding’s sample event doesn’t hide the Event hint.
    private static func captureScheduleBaselineIfNeeded(from viewModel: HomeViewModel) {
        let k1 = PostTutorialHintPersistence.baselineNonLogScheduleCountKey
        let k2 = PostTutorialHintPersistence.baselineQuickLogScheduleCountKey
        guard UserDefaults.standard.object(forKey: k1) == nil else { return }
        UserDefaults.standard.set(nonLogScheduleCount(viewModel), forKey: k1)
        UserDefaults.standard.set(quickLogScheduleCount(viewModel), forKey: k2)
    }
}

// MARK: - Hint cards

private struct PostTutorialHintCard: View {
    let id: PostTutorialHintID
    let onDone: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(id.title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(.white)
                Text(id.message)
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Button {
                    HapticManager.impact(.light)
                    onDone()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .accessibilityLabel("Mark as done")
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.impact(.light)
                    onIgnore()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.82))
                        .accessibilityLabel("Dismiss hint")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.appPink, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}

struct PostTutorialScheduleHintStack: View {
    @Bindable var viewModel: HomeViewModel
    @AppStorage(PostTutorialHints.revisionStorageKey) private var hintRevision = 0

    private var visible: [PostTutorialHintID] {
        _ = hintRevision
        return [PostTutorialHintID.scheduleTryEvent, .scheduleTryLog].filter { PostTutorialHints.shouldShow($0) }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 10) {
                    ForEach(visible, id: \.self) { hid in
                        PostTutorialHintCard(
                            id: hid,
                            onDone: { PostTutorialHints.markDone(hid) },
                            onIgnore: { PostTutorialHints.markIgnored(hid) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
        .onAppear { PostTutorialHints.syncScheduleAndPets(with: viewModel) }
        .onChange(of: viewModel.scheduleItems.count) { _, _ in
            PostTutorialHints.syncScheduleAndPets(with: viewModel)
        }
        .onChange(of: viewModel.pets) { _, _ in
            PostTutorialHints.syncScheduleAndPets(with: viewModel)
        }
    }
}

struct PostTutorialPetsHintStack: View {
    @Bindable var viewModel: HomeViewModel
    @AppStorage(PostTutorialHints.revisionStorageKey) private var hintRevision = 0

    private var visible: [PostTutorialHintID] {
        _ = hintRevision
        let base: [PostTutorialHintID] = [.petsOpenProfileExtras, .petsAddAnother].filter { PostTutorialHints.shouldShow($0) }
        return base.filter { hint in
            switch hint {
            case .petsOpenProfileExtras: return !viewModel.pets.isEmpty
            case .petsAddAnother: return viewModel.pets.count >= 1
            default: return true
            }
        }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 10) {
                    ForEach(visible, id: \.self) { hid in
                        PostTutorialHintCard(
                            id: hid,
                            onDone: { PostTutorialHints.markDone(hid) },
                            onIgnore: { PostTutorialHints.markIgnored(hid) }
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .onAppear { PostTutorialHints.syncScheduleAndPets(with: viewModel) }
        .onChange(of: viewModel.pets.count) { _, _ in
            PostTutorialHints.syncScheduleAndPets(with: viewModel)
        }
        .onChange(of: viewModel.pets) { _, _ in
            PostTutorialHints.syncScheduleAndPets(with: viewModel)
        }
    }
}
