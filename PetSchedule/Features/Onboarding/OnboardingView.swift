import Observation
import PhotosUI
import StoreKit
import SwiftUI
import UserNotifications

/// Subscription plan currently selected on a paywall (onboarding paywall step or post-onboarding hard paywall).
enum PaywallPlan: Equatable {
    case monthly
    case yearly
}

/// In-flight state for any paywall — drives spinners, button label, and disabled state.
enum PaywallPurchaseState: Equatable {
    case idle
    case purchasing
    case restoring
}

private enum HouseholdPetCount: Equatable {
    case unspecified
    case one
    case two
    case threePlus
}

private enum OnboardingFeatureInterest: String, CaseIterable, Identifiable {
    case medicationCompliance
    case petDetailsAndProfiles
    case weightLogging
    case walksAndActivities
    case feedingAndDailyCare

    /// `UserDefaults` key for persisting the user's selection so post-onboarding paywalls
    /// (after the user has finished onboarding) can keep showing the same personalization.
    static let persistenceKey = "selectedFeatureInterest"

    /// Convenience accessor that reads the persisted choice from `UserDefaults` (`nil` if unset).
    static var persisted: OnboardingFeatureInterest? {
        guard let raw = UserDefaults.standard.string(forKey: persistenceKey), !raw.isEmpty else {
            return nil
        }
        return OnboardingFeatureInterest(rawValue: raw)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medicationCompliance: return "I forget tasks & meds"
        case .petDetailsAndProfiles: return "I lose documents & records"
        case .weightLogging: return "I lose track of weight & health"
        case .walksAndActivities: return "I forget walks & activities"
        case .feedingAndDailyCare: return "I miss feeding & daily care"
        }
    }

    var caption: String {
        switch self {
        case .medicationCompliance:
            return "Meds, treatments, or tasks that should happen on a schedule"
        case .petDetailsAndProfiles:
            return "Vet letters, insurance, microchip details, and notes"
        case .weightLogging:
            return "Hard to notice gradual changes without a log"
        case .walksAndActivities:
            return "Walks, play, grooming, or vet appointments"
        case .feedingAndDailyCare:
            return "Meals, water, treats, or handoffs between carers"
        }
    }

    /// Paywall headline — solution framing for the problem the user picked, plus “+ more!”.
    var paywallHeadline: String {
        switch self {
        case .medicationCompliance: return "Never forget tasks & meds + more!"
        case .petDetailsAndProfiles: return "Never lose documents & records + more!"
        case .weightLogging: return "Never lose track of weight & health + more!"
        case .walksAndActivities: return "Never forget walks & activities + more!"
        case .feedingAndDailyCare: return "Never miss feeding & daily care + more!"
        }
    }

    /// One-line caption under the paywall feature carousel preview for this interest.
    func paywallCarouselCaption(petName: String, ownsMultiplePets: Bool) -> String {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let useName = !trimmed.isEmpty && !ownsMultiplePets
        let possessive = useName ? "\(trimmed)'s" : "your pets'"
        let nominative = useName ? trimmed : "your pets"

        switch self {
        case .medicationCompliance:
            return "Reminders when \(possessive) meds are due — log a dose in one tap."
        case .petDetailsAndProfiles:
            return "Vet contacts, microchip, allergies, and documents for \(nominative) in one profile."
        case .weightLogging:
            return useName
                ? "Log \(trimmed)'s weight in seconds and spot trends on charts over time."
                : "Log your pets' weights in seconds and spot trends on charts over time."
        case .walksAndActivities:
            return "Schedule walks and play for \(nominative) with reminders that won't slip."
        case .feedingAndDailyCare:
            return "Log meals, mood, and more for \(nominative) on one timeline your household shares."
        }
    }

    /// Carousel order: the user's chosen problem first, then every other feature.
    static func paywallCarouselOrder(primary: OnboardingFeatureInterest?) -> [OnboardingFeatureInterest] {
        let all = Array(allCases)
        guard let primary else { return all }
        return [primary] + all.filter { $0 != primary }
    }

    /// Product screenshot shown in the paywall feature carousel for this interest.
    var paywallPreviewAssetName: String {
        switch self {
        case .medicationCompliance: return "paywall_preview_logs"
        case .petDetailsAndProfiles: return "paywall_preview_documents"
        case .weightLogging: return "paywall_preview_weight"
        case .walksAndActivities: return "paywall_preview_schedule"
        case .feedingAndDailyCare: return "paywall_preview_schedule"
        }
    }

}

/// Diagonal shimmer across the onboarding bottom CTA; `TimelineView` keeps animation reliable on every step (including paywall).
private struct OnboardingPrimaryCTAShimmerOverlay: View {
    var disabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sweepDuration: TimeInterval = 3.5

    private var paused: Bool { disabled || reduceMotion }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate / sweepDuration
                let cycle = CGFloat(elapsed - floor(elapsed))

                LinearGradient(
                    colors: [.clear, .white.opacity(0.45), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 16, height: height * 3)
                .rotationEffect(.degrees(20))
                .offset(x: cycle * (width + 40) - 20, y: -height)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .opacity(paused ? 0 : 1)
        .allowsHitTesting(false)
    }
}

struct OnboardingView: View {
    @Bindable var viewModel: HomeViewModel
    let onComplete: () -> Void

    @AppStorage("timeFormat")  private var timeFormatRaw  = "24h"
    @AppStorage("weightUnit")  private var weightUnitRaw  = "kg"
    @AppStorage("heightUnit")  private var heightUnitRaw  = "cm"
    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @AppStorage(UserProfileStorage.displayNameKey) private var userDisplayName = ""

    @State private var step = 0
    @State private var petName = ""
    @State private var animalType: AnimalType = .dog
    @State private var customAnimalType = ""
    @State private var petPhotoData: Data? = nil
    @State private var triggerPhotoPicker = false
    @State private var activityName = "Walk"
    @State private var activityTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var householdPetCount: HouseholdPetCount = .one
    @State private var selectedFeatureInterest: OnboardingFeatureInterest?
    /// Draft for step 1 — avoid `@AppStorage` on every keystroke with `@Bindable` (device crashes).
    @State private var displayNameDraft = ""
    /// Draft for step 6 — avoids writing `@AppStorage` on every chip tap (can re-enter with `@Bindable` and crash on device).
    @State private var timeFormatDraft = TimeFormat.twentyFourHour.rawValue
    /// Drafts for steps 7–8 — same pattern as time format.
    @State private var weightUnitDraft = WeightUnit.kg.rawValue
    @State private var heightUnitDraft = HeightUnit.cm.rawValue

    // Paywall (final onboarding step) state
    @State private var entitlementStore = SubscriptionEntitlementStore.shared
    @State private var products = SubscriptionProductLoader()
    @State private var paywallSelectedPlan: PaywallPlan = .yearly
    @State private var paywallPurchaseState: PaywallPurchaseState = .idle
    @State private var paywallErrorMessage: String?
    @State private var notificationPermissionAlertMessage: String?
    @State private var showNotificationPermissionAlert = false
    @State private var isRequestingNotificationPermission = false

    private let totalSteps = 11

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0:
                    Step0HouseholdPetCount(householdPetCount: $householdPetCount)
                        .transition(slideTransition)
                case 1:
                    StepYourName(displayName: $displayNameDraft)
                        .transition(slideTransition)
                case 2:
                    Step1AddPet(
                        householdPetCount: householdPetCount,
                        petName: $petName,
                        animalType: $animalType,
                        customAnimalType: $customAnimalType
                    )
                        .transition(slideTransition)
                case 3:
                    Step2AddPhoto(petName: petName, animalType: animalType, photoData: $petPhotoData, triggerPicker: $triggerPhotoPicker)
                        .transition(slideTransition)
                case 4:
                    Step3AddSchedule(
                        petName: petName,
                        animalType: animalType,
                        activityName: $activityName,
                        activityTime: $activityTime
                    )
                    .transition(slideTransition)
                case 5:
                    Step4Notifications()
                        .transition(slideTransition)
                case 6:
                    StepTimeFormat(timeFormatRaw: $timeFormatDraft)
                        .transition(slideTransition)
                case 7:
                    StepWeightUnits(weightUnitRaw: $weightUnitDraft)
                        .transition(slideTransition)
                case 8:
                    StepHeightUnits(heightUnitRaw: $heightUnitDraft)
                        .transition(slideTransition)
                case 9:
                    StepFeatureInterest(selection: $selectedFeatureInterest)
                        .transition(slideTransition)
                case 10:
                    Step5Paywall(
                        pet: previewPet,
                        ownsMultiplePets: householdPetCount != .one,
                        featureInterest: selectedFeatureInterest,
                        products: products,
                        selectedPlan: $paywallSelectedPlan,
                        purchaseState: paywallPurchaseState,
                        errorMessage: paywallErrorMessage,
                        onRestorePurchases: { Task { await beginRestorePurchases() } }
                    )
                    .transition(slideTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(duration: 0.4), value: step)

            // Fixed bottom bar — identical position on every screen
            VStack(spacing: 14) {
                // Skip — optional photo, schedule, or notifications.
                if step == 3 || step == 4 || step == 5 {
                    Button {
                        if step == 3 {
                            addPetIfNeeded()
                        }
                        withAnimation { step += 1 }
                    } label: {
                        Text("Skip")
                            .font(AppTypography.secondaryLabel)
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 20)
                }

                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.appPink : Color.gray.opacity(0.25))
                            .frame(width: i == step ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: step)
                    }
                }

                Button(action: advance) {
                        Group {
                            if (step == 10 && paywallPurchaseState == .purchasing)
                                || (step == 5 && isRequestingNotificationPermission) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(buttonLabel)
                            }
                        }
                            .font(AppTypography.primaryLabel)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(continueDisabled ? Color.gray.opacity(0.3) : Color.appPink)
                            )
                            .overlay(OnboardingPrimaryCTAShimmerOverlay(disabled: continueDisabled))
                    }
                    .disabled(continueDisabled)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
            .padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            if step == 10 {
                Button {
                    completeOnboarding()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                }
                .padding(.trailing, 20)
                .safeAreaPadding(.top, 8)
                .padding(.top, 12)
                .accessibilityLabel("Skip paywall")
            }
        }
        .background(Color(.systemBackground))
        .onChange(of: step) { _, newStep in
            if newStep == 1 {
                displayNameDraft = userDisplayName
            }
            if newStep == 6 {
                timeFormatDraft = timeFormatRaw
            }
            if newStep == 7 {
                weightUnitDraft = weightUnitRaw
            }
            if newStep == 8 {
                heightUnitDraft = heightUnitRaw
            }
            if newStep == 10 {
                Task { await products.refresh() }
                Task { await entitlementStore.refreshFromCurrentEntitlements() }
            }
        }
        .onChange(of: entitlementStore.isSubscribed) { _, isSubscribed in
            if isSubscribed && step == 10 {
                completeOnboarding()
            }
        }
        .alert("Notifications", isPresented: $showNotificationPermissionAlert) {
            Button("OK", role: .cancel) {}
            if notificationPermissionAlertMessage?.contains("Settings") == true {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(notificationPermissionAlertMessage ?? "")
        }
    }

    private var buttonLabel: String {
        switch step {
        case 3: return petPhotoData == nil ? "Add Photo" : "Continue"
        case 5: return "Enable Notifications"
        case 10:
            if products.isLoading { return "Loading…" }
            switch paywallSelectedPlan {
            case .monthly: return "Continue with Monthly"
            case .yearly:  return "Continue with Yearly"
            }
        default: return "Continue"
        }
    }

    private var previewPet: Pet {
        Pet(name: petName, animalType: animalType, photoData: petPhotoData)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var continueDisabled: Bool {
        switch step {
        case 0:
            return householdPetCount == .unspecified
        case 1:
            return displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 9:
            return selectedFeatureInterest == nil
        case 5:
            return isRequestingNotificationPermission
        case 10:
            return paywallPurchaseState != .idle
                || (products.monthlyProduct == nil && products.yearlyProduct == nil)
        default:
            return false
        }
    }

    private var selectedProductForPaywall: Product? {
        switch paywallSelectedPlan {
        case .monthly: return products.monthlyProduct
        case .yearly:  return products.yearlyProduct
        }
    }

    private func advance() {
        if step == 10 {
            Task { await beginPurchase() }
            return
        }

        HapticManager.impact(.medium)

        switch step {
        case 0:
            break // pet count chosen
        case 1:
            userDisplayName = displayNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        case 3 where petPhotoData == nil:
            // "Add Photo" tapped with no photo yet — open the picker instead of advancing
            triggerPhotoPicker = true
            return
        case 3:
            addPetIfNeeded()
        case 4:
            if let pet = viewModel.pets.first {
                viewModel.scheduleItems.append(
                    ScheduleItem(
                        time: activityTime,
                        activityName: activityName,
                        pet: pet,
                        createdByDisplayName: UserProfileStorage.trimmedDisplayName(),
                        assignedToDisplayName: UserProfileStorage.trimmedDisplayName()
                    )
                )
                viewModel.syncWidgetSchedule()
            }
        case 5:
            requestNotificationPermissionThenAdvance()
            return
        case 6:
            timeFormatRaw = timeFormatDraft
        case 7:
            weightUnitRaw = weightUnitDraft
        case 8:
            heightUnitRaw = heightUnitDraft
        case 9:
            // Persist the user's problem choice so the post-onboarding paywall can keep the
            // same personalization after onboarding is done.
            UserDefaults.standard.set(
                selectedFeatureInterest?.rawValue ?? "",
                forKey: OnboardingFeatureInterest.persistenceKey
            )
        default:
            break
        }
        withAnimation { step += 1 }
    }

    /// Requests notification permission on the dedicated notifications step, then advances.
    /// Must not advance until the system dialog is dismissed — otherwise the popup appears on a
    /// later onboarding screen (e.g. the paywall carousel showing notification settings).
    private func requestNotificationPermissionThenAdvance() {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        Task { @MainActor in
            defer { isRequestingNotificationPermission = false }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let granted: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                granted = true
            case .notDetermined:
                granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            case .denied:
                granted = false
                notificationPermissionAlertMessage = "iOS notification permission was already denied, so Apple won't show the popup again. You can enable notifications in Settings."
                showNotificationPermissionAlert = true
            @unknown default:
                granted = false
            }
            if settings.authorizationStatus == .notDetermined && !granted {
                notificationPermissionAlertMessage = "Notifications are off right now. You can enable them in Settings at any time."
                showNotificationPermissionAlert = true
            }
            remindersEnabled = granted
            viewModel.syncWidgetSchedule()
            withAnimation { step += 1 }
        }
    }

    private func addPetIfNeeded() {
        guard viewModel.pets.isEmpty else { return }
        viewModel.addPet(Pet(
            name: petName.trimmingCharacters(in: .whitespaces),
            animalType: animalType,
            customAnimalType: animalType == .other ? customAnimalType.trimmingCharacters(in: .whitespaces) : nil,
            photoData: petPhotoData
        ))
    }

    private func completeOnboarding() {
        HouseholdLocalStore.save(viewModel: viewModel)
        viewModel.syncWidgetSchedule()
        onComplete()
    }

    private func beginPurchase() async {
        guard let product = selectedProductForPaywall else {
            paywallErrorMessage = "Couldn't load subscription. Please try again."
            return
        }
        paywallErrorMessage = nil
        paywallPurchaseState = .purchasing
        defer { paywallPurchaseState = .idle }

        do {
            switch try await entitlementStore.purchase(product) {
            case .success:
                HapticManager.impact(.medium)
                if entitlementStore.isSubscribed {
                    completeOnboarding()
                }
            case .userCancelled:
                break
            case .pending:
                paywallErrorMessage = "Your purchase is pending approval. You'll get access as soon as it's approved."
            }
        } catch {
            paywallErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func beginRestorePurchases() async {
        paywallErrorMessage = nil
        paywallPurchaseState = .restoring
        defer { paywallPurchaseState = .idle }

        do {
            if try await entitlementStore.restore() {
                HapticManager.impact(.light)
            } else {
                paywallErrorMessage = "No active subscription found on this Apple Account."
            }
        } catch {
            paywallErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Step 1: Your name

private struct StepYourName: View {
    @Binding var displayName: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(minHeight: 56)

                Text("What's your name?")
                    .font(AppTypography.screenTitle)
                    .multilineTextAlignment(.center)

                Text("This name appears on shared tasks so household members know who logged each item.")
                    .font(AppTypography.secondaryLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .font(AppTypography.primaryLabel)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Step 0: How many pets

private struct Step0HouseholdPetCount: View {
    @Binding var householdPetCount: HouseholdPetCount

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(minHeight: 56)

                Text("How many pets do you have?")
                    .font(AppTypography.screenTitle)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    householdPetCountChip(
                        title: "1",
                        selected: householdPetCount == .one
                    ) { householdPetCount = .one }

                    householdPetCountChip(
                        title: "2",
                        selected: householdPetCount == .two
                    ) { householdPetCount = .two }

                    householdPetCountChip(
                        title: "3+",
                        selected: householdPetCount == .threePlus
                    ) { householdPetCount = .threePlus }
                }
                .padding(.top, 8)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }
    }

    private func householdPetCountChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.secondaryEmphasis)
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Color.appPink : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? Color.appPink : Color.clear, lineWidth: 2)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 1: Add First Pet

private struct Step1AddPet: View {
    var householdPetCount: HouseholdPetCount
    @Binding var petName: String
    @Binding var animalType: AnimalType
    @Binding var customAnimalType: String

    @State private var showOtherAlert = false
    @State private var otherDraft = ""
    @FocusState private var isNameFieldFocused: Bool

    private var addPetHeadline: String {
        householdPetCount == .one ? "Add your pet" : "Add your first pet"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                AnimalTypeDefaultAvatar(animalType: animalType)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                    .id(animalType)
                    .animation(.spring(duration: 0.3), value: animalType)
                    .padding(.top, 48)

                VStack(spacing: 10) {
                    Text(addPetHeadline)
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnimalType.allCases) { type in
                            let selected = animalType == type
                            Button {
                                withAnimation(.spring(duration: 0.25)) { animalType = type }
                                if type == .other {
                                    otherDraft = customAnimalType
                                    showOtherAlert = true
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(selected ? type.color : type.color.opacity(0.1))
                                            .frame(width: 54, height: 54)
                                        Image(systemName: type.systemImage)
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(selected ? .white : type.color)
                                            .padding(13)
                                            .frame(width: 54, height: 54)
                                    }
                                    Text(type == .other && !customAnimalType.isEmpty ? customAnimalType.capitalized : type.displayName)
                                        .font(AppTypography.compactControl)
                                        .foregroundStyle(selected ? Color.appPink : .secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pet's name")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Buddy, Luna, Max…", text: $petName)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isNameFieldFocused)
                        .submitLabel(.continue)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
        }
        // Avoid dismissing the keyboard on small scroll movements while typing (`.immediately` is very aggressive).
        .scrollDismissesKeyboard(.interactively)
        .alert("What type of pet?", isPresented: $showOtherAlert) {
            TextField("e.g. Guinea pig, Gecko…", text: $otherDraft)
            Button("Done") {
                customAnimalType = otherDraft.trimmingCharacters(in: .whitespaces)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the type of animal for your pet.")
        }
    }
}

// MARK: - Step 2: Add Photo

private struct Step2AddPhoto: View {
    let petName: String
    let animalType: AnimalType
    @Binding var photoData: Data?
    @Binding var triggerPicker: Bool

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Photo circle
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    // Photo or default avatar
                    Group {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                                .frame(width: 180, height: 180)
                                .scaleEffect(1.14)
                                .clipShape(Circle())
                        } else {
                            AnimalTypeDefaultAvatar(animalType: animalType)
                                .frame(width: 180, height: 180)
                                .clipShape(Circle())
                        }
                    }
                    .shadow(color: animalType.color.opacity(0.4), radius: 12, y: 6)

                    // Camera badge
                    Circle()
                        .fill(Color.appPink)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: photoData == nil ? "camera.fill" : "arrow.triangle.2.circlepath")
                                .font(AppTypography.primaryLabel)
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.appPink.opacity(0.4), radius: 6, y: 3)
                        .offset(x: 4, y: 4)
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    photoData = try? await item?.loadTransferable(type: Data.self)
                }
            }

            Text(photoData == nil ? "Tap to choose a photo" : "Tap to change photo")
                .font(AppTypography.supportingText)
                .foregroundStyle(.tertiary)
                .photosPicker(isPresented: $showPicker, selection: $photoItem, matching: .images)
                .onChange(of: triggerPicker) { _, val in if val { showPicker = true; triggerPicker = false } }

            VStack(spacing: 10) {
                Text("Add a photo of \(petName)")
                    .font(AppTypography.screenTitle)
                    .multilineTextAlignment(.center)
                Text("Optional – you can always add one later.")
                    .font(AppTypography.secondaryLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Step 3: Add Schedule

private struct Step3AddSchedule: View {
    let petName: String
    let animalType: AnimalType
    @Binding var activityName: String
    @Binding var activityTime: Date

    private let activities = ["Walk", "Feed", "Give water", "Put to Bed", "Play", "Medication"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.appPink.opacity(0.12))
                        .frame(width: 140, height: 140)
                    Image(systemName: "calendar.badge.plus")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.appPink.gradient)
                        .padding(32)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("Set up \(petName.isEmpty ? "their" : "\(petName)'s") day")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text("Add an event that is part of \(petName.isEmpty ? "their" : "\(petName)'s") daily schedule.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 28)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(activities, id: \.self) { activity in
                                let selected = activityName == activity
                                Button { activityName = activity } label: {
                                    Label(activity, systemImage: ScheduleItem.icon(for: activity))
                                        .font(AppTypography.secondaryEmphasis)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(selected ? Color.appPink : Color(.secondarySystemBackground)))
                                        .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(duration: 0.2), value: selected)
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Time")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.secondary)
                    DatePicker("", selection: $activityTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Step 4: Notifications

private struct Step4Notifications: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "bell.badge.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.orange.gradient)
                    .padding(32)
                    .frame(width: 140, height: 140)
            }

            VStack(spacing: 10) {
                Text("Never miss a moment")
                    .font(AppTypography.screenTitle)
                    .multilineTextAlignment(.center)
                Text("Get timely reminders for walks, meals,\nand more.")
                    .font(AppTypography.secondaryLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("You can change this in Settings at any time.")
                .font(AppTypography.supportingText)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Clock & units (onboarding)

private struct OnboardingChoiceButton: View {
    let title: String
    var caption: String? = nil
    var singleLineTitle: Bool = false
    var showsSelectionIndicator: Bool = true
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.groupTitle)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(singleLineTitle ? 1 : nil)
                        .minimumScaleFactor(singleLineTitle ? 0.8 : 1)
                    if let caption, !caption.isEmpty {
                        Text(caption)
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.secondary)
                    }
                }
                if showsSelectionIndicator {
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Color.appPink : Color(.tertiaryLabel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.appPink : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StepTimeFormat: View {
    @Binding var timeFormatRaw: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.appPink.opacity(0.12))
                        .frame(width: 140, height: 140)
                    Image(systemName: "clock")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.appPink)
                        .padding(36)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("How should we show the time?")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text("Choose 24-hour or 12-hour for reminders and your schedule.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    OnboardingChoiceButton(
                        title: "24-hour",
                        caption: "e.g. 14:30",
                        isSelected: timeFormatRaw == TimeFormat.twentyFourHour.rawValue
                    ) {
                        timeFormatRaw = TimeFormat.twentyFourHour.rawValue
                    }
                    OnboardingChoiceButton(
                        title: "12-hour",
                        caption: "e.g. 2:30 pm",
                        isSelected: timeFormatRaw == TimeFormat.twelveHour.rawValue
                    ) {
                        timeFormatRaw = TimeFormat.twelveHour.rawValue
                    }
                }

                Text("You can change this later in Settings.")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct StepWeightUnits: View {
    @Binding var weightUnitRaw: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 140, height: 140)
                    Image(systemName: "scalemass")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.orange)
                        .padding(36)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("Weight units")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text("We’ll use this when you log weight and in charts.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    OnboardingChoiceButton(
                        title: WeightUnit.kg.pickerLabel,
                        caption: nil,
                        isSelected: weightUnitRaw == WeightUnit.kg.rawValue
                    ) {
                        weightUnitRaw = WeightUnit.kg.rawValue
                    }
                    OnboardingChoiceButton(
                        title: WeightUnit.stone.pickerLabel,
                        caption: nil,
                        isSelected: weightUnitRaw == WeightUnit.stone.rawValue
                    ) {
                        weightUnitRaw = WeightUnit.stone.rawValue
                    }
                }

                Text("You can change this later in Settings.")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct StepHeightUnits: View {
    @Binding var heightUnitRaw: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.12))
                        .frame(width: 140, height: 140)
                    Image(systemName: "ruler")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.cyan)
                        .padding(36)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("Height units")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text("Centimetres for metric, or feet and inches for imperial.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    OnboardingChoiceButton(
                        title: HeightUnit.cm.pickerLabel,
                        caption: "Metric — metres & centimetres",
                        isSelected: heightUnitRaw == HeightUnit.cm.rawValue
                    ) {
                        heightUnitRaw = HeightUnit.cm.rawValue
                    }
                    OnboardingChoiceButton(
                        title: HeightUnit.imperial.pickerLabel,
                        caption: "Feet and inches",
                        isSelected: heightUnitRaw == HeightUnit.imperial.rawValue
                    ) {
                        heightUnitRaw = HeightUnit.imperial.rawValue
                    }
                }

                Text("You can change this later in Settings.")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Problem selection (before paywall)

private struct StepFeatureInterest: View {
    @Binding var selection: OnboardingFeatureInterest?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.appPink.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "heart.text.square.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.appPink.gradient)
                        .padding(34)
                        .frame(width: 120, height: 120)
                }
                .padding(.top, 28)

                VStack(spacing: 10) {
                    Text("What's the biggest problem you face right now?")
                        .font(AppTypography.panelTitle)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.9)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(OnboardingFeatureInterest.allCases) { option in
                        OnboardingChoiceButton(
                            title: option.title,
                            singleLineTitle: true,
                            showsSelectionIndicator: false,
                            isSelected: selection == option
                        ) {
                            selection = option
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)

            Text("You'll still have access to every feature. This just helps us focus on what matters most to you.")
                .font(AppTypography.supportingText)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Paywall

/// Rounds subscription prices **up** for honest "~ per day" copy on plan cards.
private enum PaywallPerDayPrice {
    private static func ceilingCurrencyFormatter(for product: Product) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.roundingMode = .up
        return formatter
    }

    static func formattedCeiling(product: Product, daysInPeriod: Decimal) -> String {
        let perDay = product.price / daysInPeriod
        let formatter = ceilingCurrencyFormatter(for: product)
        return formatter.string(from: NSDecimalNumber(decimal: perDay))
            ?? perDay.formatted(product.priceFormatStyle)
    }

    static func subtitle(for product: Product, daysInPeriod: Decimal) -> String {
        "~\(formattedCeiling(product: product, daysInPeriod: daysInPeriod)) per day"
    }
}

private struct Step5Paywall: View {
    let pet: Pet
    var ownsMultiplePets: Bool
    var featureInterest: OnboardingFeatureInterest?
    var products: SubscriptionProductLoader
    @Binding var selectedPlan: PaywallPlan
    var purchaseState: PaywallPurchaseState
    var errorMessage: String?
    var onRestorePurchases: () -> Void

    private var paywallHeadline: String {
        if let featureInterest {
            return featureInterest.paywallHeadline
        }
        let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Get started today! + more!"
        }
        if ownsMultiplePets {
            return "Keep \(name) and all your pets on schedule + more!"
        }
        return "Keep \(name) on schedule + more!"
    }

    var body: some View {
        PaywallContentBody(
            headline: paywallHeadline,
            featureInterest: featureInterest,
            petName: pet.name,
            ownsMultiplePets: ownsMultiplePets,
            products: products,
            selectedPlan: $selectedPlan,
            purchaseState: purchaseState,
            errorMessage: errorMessage,
            onRestorePurchases: onRestorePurchases,
            reservesCloseButtonInset: true
        )
    }
}

/// Headline + feature carousel + plan cards + error + footer. Shared between the
/// in-onboarding paywall and the post-onboarding hard paywall so both look and behave identically.
private struct PaywallContentBody: View {
    let headline: String
    var featureInterest: OnboardingFeatureInterest?
    var petName: String = ""
    var ownsMultiplePets: Bool = false
    let products: SubscriptionProductLoader
    @Binding var selectedPlan: PaywallPlan
    let purchaseState: PaywallPurchaseState
    let errorMessage: String?
    let onRestorePurchases: () -> Void
    /// Extra trailing inset so the title clears the skip control on the onboarding paywall.
    var reservesCloseButtonInset: Bool = false

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.82)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
                .padding(.trailing, reservesCloseButtonInset ? 52 : 28)
                .frame(maxWidth: .infinity)

            PaywallFeatureCarousel(
                interests: OnboardingFeatureInterest.paywallCarouselOrder(primary: featureInterest),
                petName: petName,
                ownsMultiplePets: ownsMultiplePets
            )
            .padding(.horizontal, 24)

            Group {
                if products.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading plans…")
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else if products.loadError != nil {
                    VStack(spacing: 8) {
                        Text("Couldn’t load prices")
                            .font(AppTypography.secondaryLabel)
                            .foregroundStyle(.secondary)
                        Button("Try again") {
                            Task { await products.refresh() }
                        }
                        .font(AppTypography.secondaryEmphasis)
                    }
                    .padding(.vertical, 12)
                } else {
                    planCards
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 28)
                    .padding(.top, 4)
                    .accessibilityLabel("Subscription error: \(errorMessage)")
            }

            // Risk-reversal microcopy — sits directly above the cold legal disclosures so the
            // last thing the user reads before tapping the CTA is a friendly reassurance, not
            // fine print. Single-line, small icon, primary text color so it doesn't blend with
            // the secondary legal copy below.
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.appPink)
                    .accessibilityHidden(true)
                Text("Cancel anytime in Settings")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You can cancel anytime in Settings.")

            PaywallSubscriptionFooter(
                includeFreeTrialMention: products.isLoading
                    ? nil
                    : (products.yearlyProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial),
                isRestoring: purchaseState == .restoring,
                onRestorePurchases: onRestorePurchases
            )
            .padding(.horizontal, 28)
            .padding(.top, 6)
            .padding(.bottom, 0)
            .background(Color(.systemBackground))

            Spacer(minLength: 0)
        }
        .safeAreaPadding(.top, 4)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var planCards: some View {
        VStack(spacing: 8) {
            if let y = products.yearlyProduct {
                PaywallYearlyCard(
                    yearly: y,
                    monthly: products.monthlyProduct,
                    isSelected: selectedPlan == .yearly
                ) { selectedPlan = .yearly }
            }
            if let m = products.monthlyProduct {
                PaywallMonthlyCard(
                    monthly: m,
                    isSelected: selectedPlan == .monthly
                ) { selectedPlan = .monthly }
            }
        }
        // Extra space so the selected plan’s stroke isn't clipped against the footer region.
        .padding(.bottom, 4)
    }

}

// MARK: - Paywall feature carousel

private struct PaywallCarouselPageIndicator: View {
    let count: Int
    let page: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.appPink : Color.gray.opacity(0.25))
                    .frame(width: i == page ? 20 : 8, height: 8)
            }
        }
        .animation(.spring(duration: 0.3), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Feature \(min(page + 1, count)) of \(count)")
    }
}

private struct PaywallFeatureCarousel: View {
    let interests: [OnboardingFeatureInterest]
    let petName: String
    let ownsMultiplePets: Bool

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let autoAdvanceInterval: TimeInterval = 4.5

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $page) {
                ForEach(Array(interests.enumerated()), id: \.offset) { index, interest in
                    VStack(spacing: 6) {
                        PaywallFeatureScreenshotPreview(interest: interest)
                            .frame(maxWidth: .infinity)
                            .frame(height: 128)

                        Text(interest.paywallCarouselCaption(petName: petName, ownsMultiplePets: ownsMultiplePets))
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.88)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 178)

            if interests.count > 1 {
                PaywallCarouselPageIndicator(count: interests.count, page: page)
            }
        }
        .onReceive(Timer.publish(every: autoAdvanceInterval, on: .main, in: .common).autoconnect()) { _ in
            guard !reduceMotion, interests.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.35)) {
                page = (page + 1) % interests.count
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Real in-app product screenshot for each paywall carousel page.
private struct PaywallFeatureScreenshotPreview: View {
    let interest: OnboardingFeatureInterest

    var body: some View {
        Image(interest.paywallPreviewAssetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// Yearly option; pink border when selected (prices from StoreKit).
private struct PaywallYearlyCard: View {
    let yearly: Product
    /// Compared to \(monthly.price × 12) for savings copy; omit if unavailable.
    var monthly: Product?
    var isSelected: Bool
    var onSelect: () -> Void

    private var pricingSubtitleText: String {
        PaywallPerDayPrice.subtitle(for: yearly, daysInPeriod: 365)
    }

    /// Rounded percent off 12× monthly (`nil` if not cheaper / no monthly product).
    private var yearlySavingsPercent: Int? {
        guard let monthly else { return nil }
        let annualizedMonthly = monthly.price * Decimal(12)
        guard annualizedMonthly > yearly.price else { return nil }
        let savings = annualizedMonthly - yearly.price
        guard savings > 0 else { return nil }
        let percentDecimal = (savings / annualizedMonthly) * Decimal(100)
        let percent = Int(NSDecimalNumber(decimal: percentDecimal).doubleValue.rounded())
        guard percent >= 1 else { return nil }
        return percent
    }

    private var savingsBadgeCaption: String? {
        guard let p = yearlySavingsPercent else { return nil }
        return "SAVE ~\(p)% vs Monthly"
    }

    private var accessibilitySubtitle: String {
        var parts: [String] = ["\(yearly.displayPrice) per year.", "\(pricingSubtitleText)."]
        if let yearlySavingsPercent {
            parts.append("Save \(yearlySavingsPercent) percent versus twelve months billed monthly.")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .top) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Yearly")
                        .font(AppTypography.secondaryEmphasis)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(yearly.displayPrice) per year")
                            .font(.footnote)
                            .fontWeight(.regular)
                            .foregroundStyle(.primary)
                        Text(pricingSubtitleText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, savingsBadgeCaption != nil ? 20 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.appPink : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .top) {
                    if let savingsBadgeCaption {
                        Text(savingsBadgeCaption)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(Capsule(style: .continuous).fill(Color.appPink))
                            .shadow(color: .black.opacity(0.07), radius: 3, y: 2)
                            .offset(y: -13)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, savingsBadgeCaption != nil ? 8 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Yearly. \(accessibilitySubtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Simple monthly row: label left, price right; subtle highlight when selected.
private struct PaywallMonthlyCard: View {
    let monthly: Product
    var isSelected: Bool
    var onSelect: () -> Void

    private var pricingSubtitleText: String {
        PaywallPerDayPrice.subtitle(for: monthly, daysInPeriod: 30)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 8) {
                Text("Monthly")
                    .font(AppTypography.secondaryEmphasis)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(monthly.displayPrice) per month")
                        .font(.footnote)
                        .fontWeight(.regular)
                        .foregroundStyle(.primary)
                    Text(pricingSubtitleText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.appPink : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Monthly. \(monthly.displayPrice) per month. \(pricingSubtitleText).")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Paywall footer legal links — uses `LegalPageURLs` (same as Settings).
private enum PaywallLegalURLs {
    static let privacy = LegalPageURLs.privacy
    static let terms = LegalPageURLs.termsAndConditions
    static let tos = LegalPageURLs.termsOfService
}

private struct PaywallSubscriptionFooter: View {
    /// `nil` while loading — show non-trial wording until product metadata resolves (avoids flashing trial copy).
    var includeFreeTrialMention: Bool? = nil
    /// True while a Restore is in progress; the Restore button shows a spinner and is disabled.
    var isRestoring: Bool = false
    var onRestorePurchases: () -> Void = {}

    private static let disclosureNoTrialLines: [String] = [
        "Charges your Apple Account when you subscribe.",
        "Auto-renews until you cancel at least 24 hours before renewal in Account Settings · Subscriptions.",
        "If you cancel, access continues until the billing period ends.",
    ]

    /// One line per sentence; trial path uses two sentences.
    private static let disclosureTrialLines: [String] = [
        "When a trial or introductory offer applies, your Apple Account is charged when it converts unless you cancel at least 24 hours before renewal in Account Settings · Subscriptions.",
        "Auto-renews until cancelled; access continues until the billing period ends if you cancel.",
    ]

    private var disclosureLines: [String] {
        switch includeFreeTrialMention {
        case .some(true): return Self.disclosureTrialLines
        case .none, .some(false): return Self.disclosureNoTrialLines
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 3) {
                ForEach(Array(disclosureLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 6) {
                HStack {
                    Spacer(minLength: 0)
                    restorePurchasesLink
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)
                    ViewThatFits(in: .horizontal) {
                        paywallPolicyLinkStrip(spacingBetweenItems: 4, captionFont: .caption2)
                        paywallPolicyLinkStrip(spacingBetweenItems: 2, captionFont: .caption2)
                        paywallPolicyLinkStrip(spacingBetweenItems: 2, captionFont: .caption2, minScale: 0.88)
                        paywallPolicyLinkStrip(spacingBetweenItems: 2, captionFont: .caption2, minScale: 0.78)
                        paywallPolicyLinkStrip(spacingBetweenItems: 2, captionFont: .system(size: 10), minScale: 0.95)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var restorePurchasesLink: some View {
        Button(action: onRestorePurchases) {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.mini)
                }
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .allowsTightening(true)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .accessibilityLabel("Restore Purchases")
    }

    /// Privacy / terms row only (Restore is on its own line above).
    private func paywallPolicyLinkStrip(
        spacingBetweenItems: CGFloat,
        captionFont: Font,
        minScale: CGFloat = 1.0
    ) -> some View {
        HStack(spacing: spacingBetweenItems) {
            footerLinkURL(title: "Privacy Policy", url: PaywallLegalURLs.privacy, font: captionFont, minScale: minScale)
            middotDivider(font: captionFont)
            footerLinkURL(title: "Terms and Conditions", url: PaywallLegalURLs.terms, font: captionFont, minScale: minScale)
            middotDivider(font: captionFont)
            footerLinkURL(title: "Terms of Use", url: PaywallLegalURLs.tos, font: captionFont, minScale: minScale)
        }
    }

    private func middotDivider(font: Font) -> some View {
        Text("\u{00B7}") // interpunct ·
            .font(font)
            .foregroundStyle(.secondary.opacity(0.8))
            .baselineOffset(-0.5)
    }

    private func footerLinkURL(
        title: String,
        url: URL,
        font: Font,
        minScale: CGFloat
    ) -> some View {
        Link(destination: url) {
            Text(title)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(minScale)
        }
    }
}

// MARK: - App Store subscription products (StoreKit 2)

enum PetScheduleSubscriptionProductID {
    static let monthly = "com.petlifescheduler.premium.monthly"
    static let yearly = "com.petlifescheduler.premium.yearly"
}

@Observable
@MainActor
final class SubscriptionProductLoader {
    private(set) var yearlyProduct: Product?
    private(set) var monthlyProduct: Product?
    private(set) var isLoading = false
    private(set) var loadError: Error?

    /// No work on init — `refresh()` when user reaches the paywall so early steps don’t re-render from StoreKit.
    init() {}

    func refresh() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let ids = [PetScheduleSubscriptionProductID.yearly, PetScheduleSubscriptionProductID.monthly]
            let products = try await Product.products(for: ids)
            yearlyProduct = products.first { $0.id == PetScheduleSubscriptionProductID.yearly }
            monthlyProduct = products.first { $0.id == PetScheduleSubscriptionProductID.monthly }
        } catch {
            loadError = error
            yearlyProduct = nil
            monthlyProduct = nil
        }
    }
}

// MARK: - Post-onboarding hard paywall

/// Full-screen subscription gate — same UI as the onboarding paywall, but without the onboarding
/// chrome. **Not** presented at app launch; kept for previews or future entry points (e.g. Settings).
///
/// Observes `SubscriptionEntitlementStore.shared`; when `isSubscribed` becomes `true`, callers can
/// dismiss or navigate away.
struct PostOnboardingPaywallView: View {
    @Bindable var viewModel: HomeViewModel

    @State private var products = SubscriptionProductLoader()
    @State private var entitlementStore = SubscriptionEntitlementStore.shared
    @State private var selectedPlan: PaywallPlan = .yearly
    @State private var purchaseState: PaywallPurchaseState = .idle
    @State private var errorMessage: String?
    /// The user's problem choice from onboarding step 9 (persisted to `UserDefaults`).
    /// Drives the personalized headline and feature carousel after onboarding.
    @AppStorage(OnboardingFeatureInterest.persistenceKey) private var persistedFeatureInterestRaw: String = ""

    private var featureInterest: OnboardingFeatureInterest? {
        OnboardingFeatureInterest(rawValue: persistedFeatureInterestRaw)
    }

    private var firstPet: Pet? { viewModel.pets.first }
    private var ownsMultiplePets: Bool { viewModel.pets.count > 1 }
    private var petName: String { firstPet?.name ?? "" }
    /// Real household size (clamped to >= 1 so the per-pet/month divisor never hits zero on a
    /// fresh install with no pets yet).
    private var headline: String {
        if let featureInterest {
            return featureInterest.paywallHeadline
        }
        let name = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Unlock PetLifeScheduler Premium + more!"
        }
        if ownsMultiplePets {
            return "Keep \(name) and all your pets on schedule + more!"
        }
        return "Keep \(name) on schedule + more!"
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly: return products.monthlyProduct
        case .yearly:  return products.yearlyProduct
        }
    }

    private var ctaLabel: String {
        switch selectedPlan {
        case .monthly: return "Continue with Monthly"
        case .yearly:  return "Continue with Yearly"
        }
    }

    private var ctaDisabled: Bool {
        if purchaseState != .idle { return true }
        return selectedProduct == nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                PaywallContentBody(
                    headline: headline,
                    featureInterest: featureInterest,
                    petName: petName,
                    ownsMultiplePets: ownsMultiplePets,
                    products: products,
                    selectedPlan: $selectedPlan,
                    purchaseState: purchaseState,
                    errorMessage: errorMessage,
                    onRestorePurchases: { Task { await beginRestorePurchases() } }
                )

                VStack(spacing: 14) {
                    Button(action: { Task { await beginPurchase() } }) {
                        Group {
                            if purchaseState == .purchasing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(ctaLabel)
                            }
                        }
                        .font(AppTypography.primaryLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(ctaDisabled ? Color.gray.opacity(0.3) : Color.appPink)
                        )
                        .overlay(OnboardingPrimaryCTAShimmerOverlay(disabled: ctaDisabled))
                    }
                    .disabled(ctaDisabled)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
                .padding(.top, 8)
            }

#if DEBUG
            Button {
                entitlementStore.grantDebugAccess()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
            .accessibilityLabel("Close paywall (debug only)")
#endif
        }
        .background(Color(.systemBackground))
        .task {
            await products.refresh()
            // If the user already has an active subscription on this Apple Account but the local
            // entitlement hasn't refreshed yet, sync now so they're not stuck behind the paywall.
            await entitlementStore.refreshFromCurrentEntitlements()
        }
    }

    private func beginPurchase() async {
        guard let product = selectedProduct else {
            errorMessage = "Couldn't load subscription. Please try again."
            return
        }
        errorMessage = nil
        purchaseState = .purchasing
        defer { purchaseState = .idle }

        do {
            switch try await entitlementStore.purchase(product) {
            case .success:
                HapticManager.impact(.medium)
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Your purchase is pending approval. You'll get access as soon as it's approved."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func beginRestorePurchases() async {
        errorMessage = nil
        purchaseState = .restoring
        defer { purchaseState = .idle }

        do {
            if try await entitlementStore.restore() {
                HapticManager.impact(.light)
            } else {
                errorMessage = "No active subscription found on this Apple Account."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Household joined (invite acceptance) mini-onboarding

/// Shown the first time the app opens after a user accepts a CloudKit share invite, instead of the
/// full onboarding paywall flow. The invitee is joining someone else's household, so we skip pet
/// setup, units, the feature interest question, and the paywall. The two steps we still need are:
///   1. Their display name (used on Created by / Assigned to in shared task attribution).
///   2. Notification permission (so they get reminders for the household's events).
/// Premium entitlement comes from Apple's Family Sharing on the in-app subscription, not from
/// anything we do here — `SubscriptionEntitlementStore` picks family-shared transactions up via
/// `Transaction.currentEntitlements` automatically.
struct HouseholdJoinedWelcomeView: View {
    @Bindable var viewModel: HomeViewModel
    let onComplete: () -> Void

    @AppStorage(UserProfileStorage.displayNameKey) private var userDisplayName = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("remindersEnabled") private var remindersEnabled = false

    @State private var step = 0
    @State private var nameDraft = ""
    @State private var isRequestingNotificationPermission = false
    @State private var isFinishing = false
    @State private var notificationPermissionAlertMessage: String?
    @State private var showNotificationPermissionAlert = false
    @FocusState private var nameFieldFocused: Bool

    private let totalSteps = 2

    private var trimmedDraft: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var continueDisabled: Bool {
        switch step {
        case 0: return trimmedDraft.isEmpty || isFinishing
        case 1: return isRequestingNotificationPermission || isFinishing
        default: return false
        }
    }

    private var buttonLabel: String {
        switch step {
        case 0: return "Continue"
        case 1: return "Enable Notifications"
        default: return "Continue"
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0:
                    HouseholdJoinedNameStep(
                        nameDraft: $nameDraft,
                        nameFieldFocused: $nameFieldFocused
                    )
                    .transition(slideTransition)
                case 1:
                    Step4Notifications()
                        .transition(slideTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(duration: 0.4), value: step)

            VStack(spacing: 14) {
                Color.clear.frame(height: 20)

                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.appPink : Color.gray.opacity(0.25))
                            .frame(width: i == step ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: step)
                    }
                }

                Button(action: advance) {
                    Group {
                        if isFinishing || (step == 1 && isRequestingNotificationPermission) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Text(buttonLabel)
                        }
                    }
                    .font(AppTypography.primaryLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(continueDisabled ? Color.gray.opacity(0.3) : Color.appPink)
                    )
                    .overlay(OnboardingPrimaryCTAShimmerOverlay(disabled: continueDisabled))
                }
                .disabled(continueDisabled)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .onAppear {
            nameDraft = userDisplayName
            if step == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    nameFieldFocused = true
                }
            }
        }
        .onChange(of: step) { _, newStep in
            if newStep == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    nameFieldFocused = true
                }
            } else {
                nameFieldFocused = false
            }
        }
        .alert("Notifications", isPresented: $showNotificationPermissionAlert) {
            Button("OK", role: .cancel) {}
            if notificationPermissionAlertMessage?.contains("Settings") == true {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(notificationPermissionAlertMessage ?? "")
        }
    }

    private func advance() {
        HapticManager.impact(.medium)
        switch step {
        case 0:
            userDisplayName = trimmedDraft
            withAnimation { step += 1 }
        case 1:
            requestNotificationPermissionThenFinish()
        default:
            break
        }
    }

    /// Mirrors the main onboarding flow: ask for notification permission and only advance once the
    /// system dialog has been dismissed, so the popup doesn't appear over the home screen.
    private func requestNotificationPermissionThenFinish() {
        guard !isRequestingNotificationPermission else { return }
        isRequestingNotificationPermission = true
        Task { @MainActor in
            defer { isRequestingNotificationPermission = false }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let granted: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                granted = true
            case .notDetermined:
                granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            case .denied:
                granted = false
                notificationPermissionAlertMessage = "iOS notification permission was already denied, so Apple won't show the popup again. You can enable notifications in Settings."
                showNotificationPermissionAlert = true
            @unknown default:
                granted = false
            }
            if settings.authorizationStatus == .notDetermined && !granted {
                notificationPermissionAlertMessage = "Notifications are off right now. You can enable them in Settings at any time."
                showNotificationPermissionAlert = true
            }
            remindersEnabled = granted
            await finishAndComplete()
        }
    }

    private func finishAndComplete() async {
        isFinishing = true
        defer { isFinishing = false }
        // Pull the household pets/schedule first so Home lands populated.
        await HouseholdSyncCoordinator.shared.syncNow(viewModel)
        viewModel.syncWidgetSchedule()
        hasCompletedOnboarding = true
        onComplete()
    }
}

/// Step 0 of the invitee mini-onboarding — name capture, designed to match the look of
/// `StepYourName` while making clear they're joining an existing household.
private struct HouseholdJoinedNameStep: View {
    @Binding var nameDraft: String
    var nameFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(minHeight: 56)

                ZStack {
                    Circle()
                        .fill(Color.appPink.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.2.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.appPink.gradient)
                        .padding(34)
                        .frame(width: 120, height: 120)
                }

                VStack(spacing: 10) {
                    Text("You've joined the household!")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Pets and schedules will sync over iCloud. Your name appears next to tasks you log so the household knows who did what.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(.primary)

                    TextField("Your name", text: $nameDraft)
                        .textContentType(.name)
                        .focused(nameFieldFocused)
                        .submitLabel(.done)
                        .font(AppTypography.primaryLabel)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .padding(.top, 8)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }
    }
}

// The Xcode Canvas preview often does not connect the software keyboard; run the app in Simulator (▶) to type in text fields, or use an Interactive Live preview.
#Preview {
    OnboardingView(viewModel: HomeViewModel()) {}
}

#Preview("Joined household welcome") {
    HouseholdJoinedWelcomeView(viewModel: HomeViewModel()) {}
}

#Preview("Post-Onboarding Paywall") {
    PostOnboardingPaywallView(viewModel: HomeViewModel())
}
