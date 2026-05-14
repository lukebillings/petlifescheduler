import Charts
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
        case .medicationCompliance: return "Medication compliance"
        case .petDetailsAndProfiles: return "Pet details & profiles"
        case .weightLogging: return "Weight logging"
        case .walksAndActivities: return "Walks & activities"
        case .feedingAndDailyCare: return "Feeding & daily care"
        }
    }

    var caption: String {
        switch self {
        case .medicationCompliance:
            return "Reminders and routines so doses don't get missed"
        case .petDetailsAndProfiles:
            return "Store vet info, notes, and everything about each pet"
        case .weightLogging:
            return "Log weight over time and spot changes early"
        case .walksAndActivities:
            return "Schedule walks, playtime, and what's happening next"
        case .feedingAndDailyCare:
            return "Keep meals, water, and everyday tasks on track"
        }
    }

    /// Big headline at the top of the paywall — interest-specific, with the user's pet woven in
    /// when there's exactly one. Multi-pet households get plural copy that doesn't single out one
    /// name (avoids awkward "Luna and all your pets's meds" possessive constructions).
    func paywallHeadline(petName: String, ownsMultiplePets: Bool) -> String {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !trimmed.isEmpty && !ownsMultiplePets

        switch self {
        case .medicationCompliance:
            if ownsMultiplePets { return "Never miss a dose for any of your pets" }
            return hasName ? "Never miss \(trimmed)'s meds again" : "Never miss a dose again"
        case .petDetailsAndProfiles:
            if ownsMultiplePets { return "Every pet's details in one place" }
            return hasName ? "Everything about \(trimmed) in one place" : "Everything about your pet in one place"
        case .weightLogging:
            if ownsMultiplePets { return "Track every pet's weight, spot changes early" }
            return hasName ? "Track \(trimmed)'s weight, spot changes early" : "Track your pet's weight, spot changes early"
        case .walksAndActivities:
            if ownsMultiplePets { return "Keep every pet's walks and play on track" }
            return hasName ? "Keep \(trimmed)'s walks and play on track" : "Keep your pet's walks and play on track"
        case .feedingAndDailyCare:
            if ownsMultiplePets { return "Keep every pet fed and cared for, every day" }
            return hasName ? "Keep \(trimmed) fed and cared for, every day" : "Keep your pet fed and cared for, every day"
        }
    }

    /// Short caption shown under the "Yearly" label on the yearly plan card — anchors the value
    /// of the higher-AOV plan to the user's stated reason for downloading.
    var paywallYearlyCardCaption: String {
        switch self {
        case .medicationCompliance:  return "Best for medication routines"
        case .petDetailsAndProfiles: return "Best for vet visits & emergencies"
        case .weightLogging:         return "Best for long-term health tracking"
        case .walksAndActivities:    return "Best for active households"
        case .feedingAndDailyCare:   return "Best for daily routines"
        }
    }

    /// Three concise check-mark bullets reinforcing the user's chosen interest — sit between the
    /// rotating benefits and the plan cards so the value prop is visible without scrolling.
    func paywallBullets(petName: String, ownsMultiplePets: Bool) -> [String] {
        let trimmed = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let useName = !trimmed.isEmpty && !ownsMultiplePets
        let possessive = useName ? "\(trimmed)'s" : "your pets'"
        let nominative = useName ? trimmed : "your pets"

        switch self {
        case .medicationCompliance:
            return [
                "Reminders fire when \(possessive) meds are due",
                "One tap to log a dose — synced across your household",
                "Spot missed doses early with compliance trends",
            ]
        case .petDetailsAndProfiles:
            return [
                "Vet contacts, microchip, allergies, and notes for \(nominative)",
                "Export a polished pet profile to PDF in seconds",
                "Share full pet info with sitters or family instantly",
            ]
        case .weightLogging:
            return [
                useName ? "Log \(trimmed)'s weight in seconds — kg or lbs"
                        : "Log your pets' weights in seconds — kg or lbs",
                "Charts reveal trends over weeks and months",
                "Set target weights and see progress at a glance",
            ]
        case .walksAndActivities:
            return [
                "Schedule walks and play for \(nominative)",
                "Reminders so nothing slips between handoffs",
                "Share the plan with everyone in your household",
            ]
        case .feedingAndDailyCare:
            return [
                "Meals, water, and treats for \(nominative) on one timeline",
                "Reminders that won't double-feed when shared",
                "Daily logs everyone in your household can check",
            ]
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
    @State private var paywallSelectedPlan: PaywallPlan = .monthly
    @State private var paywallPurchaseState: PaywallPurchaseState = .idle
    @State private var paywallErrorMessage: String?
    @State private var notificationPermissionAlertMessage: String?
    @State private var showNotificationPermissionAlert = false

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
                        petCount: petCountForPaywall,
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
                            if step == 10 && paywallPurchaseState == .purchasing {
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
                        .padding(20)
                }
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
        case 10:
            return paywallPurchaseState != .idle
                || (products.monthlyProduct == nil && products.yearlyProduct == nil)
        default:
            return false
        }
    }

    private var petCountForPaywall: Int {
        switch householdPetCount {
        case .one, .unspecified: return 1
        case .two: return 2
        case .threePlus: return 3
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
            Task { @MainActor in
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
            }
        case 6:
            timeFormatRaw = timeFormatDraft
        case 7:
            weightUnitRaw = weightUnitDraft
        case 8:
            heightUnitRaw = heightUnitDraft
        case 9:
            // Persist the user's "main reason" so the post-onboarding paywall can keep the
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

                Text("We'll personalize your setup.")
                    .font(AppTypography.secondaryLabel)
                    .foregroundStyle(.secondary)
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
                ZStack {
                    Image(animalType.placeholderImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                }
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
                    ZStack {
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                        } else {
                            Image(animalType.placeholderImage)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFill()
                        }
                    }
                    .frame(width: 180, height: 180)
                    .scaleEffect(1.14)
                    .clipShape(Circle())
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

    private let activities = ["Walk", "Feed", "Give water", "Put to Bed", "Play", "Give Medication"]

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
                Text("Get timely reminders for walks, meals,\nand every moment that matters.")
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
                    if let caption, !caption.isEmpty {
                        Text(caption)
                            .font(AppTypography.supportingText)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.appPink : Color(.tertiaryLabel))
            }
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

// MARK: - Feature interest (before paywall)

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
                    Text("What's the main reason you're using Pet Schedule?")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.78)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                    Text("Pick the closest match, for example meds, pet records, weight, walks, or feeding.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 28)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(OnboardingFeatureInterest.allCases) { option in
                        OnboardingChoiceButton(
                            title: option.title,
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

            Text("You'll still have access to every feature. This just tells us what you care about most.")
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

private struct Step5Paywall: View {
    let pet: Pet
    var ownsMultiplePets: Bool
    /// Number of pets in the household (1, 2, or 3 — `3` is used for "3+" so per-pet/month
    /// framing stays honest for households with more than three pets).
    var petCount: Int
    var featureInterest: OnboardingFeatureInterest?
    var products: SubscriptionProductLoader
    @Binding var selectedPlan: PaywallPlan
    var purchaseState: PaywallPurchaseState
    var errorMessage: String?
    var onRestorePurchases: () -> Void

    /// Preview slides for the paged carousel — ordered so the user's "main reason" choice from
    /// step 9 surfaces first. Falls back to schedule → reminder → weight chart for users who
    /// haven't picked an interest.
    private var previewSlides: [PaywallPreviewSlide] {
        paywallPreviewSlides(petName: pet.name, animalType: pet.animalType, prioritized: featureInterest)
    }

    private var paywallHeadline: String {
        if let featureInterest {
            return featureInterest.paywallHeadline(petName: pet.name, ownsMultiplePets: ownsMultiplePets)
        }
        let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Get started today!"
        }
        if ownsMultiplePets {
            return "Keep \(name) and all your pets on schedule"
        }
        return "Keep \(name) on schedule"
    }

    /// Three short check-mark bullets — interest-specific when the user picked one in step 9.
    private var paywallBullets: [String] {
        featureInterest?.paywallBullets(petName: pet.name, ownsMultiplePets: ownsMultiplePets)
            ?? Self.defaultPaywallBullets
    }

    /// Generic 3-bullet fallback for users who somehow reach the paywall without selecting an
    /// interest (e.g. a future flow that skips step 9).
    private static let defaultPaywallBullets: [String] = [
        "Every walk, meal, and med — in one timeline per pet",
        "Reminders before what matters, so nothing slips",
        "Premium experience — no ads, just easier pet care",
    ]

    var body: some View {
        VStack(spacing: 0) {
            PaywallContentBody(
                headline: paywallHeadline,
                previewSlides: previewSlides,
                personalizedBullets: paywallBullets,
                petCount: petCount,
                products: products,
                selectedPlan: $selectedPlan,
                purchaseState: purchaseState,
                errorMessage: errorMessage,
                onRestorePurchases: onRestorePurchases
            )
            Spacer(minLength: 0)
        }
    }
}

/// Builds the canonical preview-carousel slide list, optionally promoting one slide to the first
/// position based on the user's onboarding "main reason" choice. Both paywalls (onboarding and
/// post-onboarding) call this so the ordering logic stays in one place.
private func paywallPreviewSlides(
    petName: String,
    animalType: AnimalType,
    prioritized featureInterest: OnboardingFeatureInterest?
) -> [PaywallPreviewSlide] {
    var slides: [PaywallPreviewSlide] = [
        .scheduleTimeline(petName: petName, animalType: animalType),
        .reminderPush(petName: petName, animalType: animalType),
        .weightChart,
    ]

    guard let featureInterest else { return slides }

    let priorityID: String
    switch featureInterest {
    case .weightLogging:
        priorityID = "weight"
    case .medicationCompliance, .feedingAndDailyCare, .walksAndActivities:
        priorityID = "reminder"
    case .petDetailsAndProfiles:
        priorityID = "schedule"
    }

    if let priorityIdx = slides.firstIndex(where: { $0.stableSlideKind == priorityID }), priorityIdx != 0 {
        let priority = slides.remove(at: priorityIdx)
        slides.insert(priority, at: 0)
    }
    return slides
}

/// Headline + paged preview carousel + plan cards + error + footer. Shared between the
/// in-onboarding paywall and the post-onboarding hard paywall so both look and behave identically.
private struct PaywallContentBody: View {
    let headline: String
    /// Real in-app UI (scaled) in the auto-advancing carousel above the plan cards. The first slide
    /// is what most users see, so callers should put the most relevant preview first.
    let previewSlides: [PaywallPreviewSlide]
    /// 0–3 short personalized bullets shown above the plan cards. Empty array hides the section.
    var personalizedBullets: [String] = []
    /// Small caption shown under the "Yearly" label on the yearly plan card. `nil` to hide.
    var yearlyCardCaption: String? = nil
    /// Number of pets in the household — drives per-day vs. per-pet/month framing on the yearly card.
    var petCount: Int = 1
    let products: SubscriptionProductLoader
    @Binding var selectedPlan: PaywallPlan
    let purchaseState: PaywallPurchaseState
    let errorMessage: String?
    let onRestorePurchases: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(headline)
                .font(AppTypography.screenTitle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            PaywallPreviewCarousel(slides: previewSlides, interval: 3.5)

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
            .padding(.top, 18)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .accessibilityLabel("Subscription error: \(errorMessage)")
            }

            // Risk-reversal microcopy — sits directly above the cold legal disclosures so the
            // last thing the user reads before tapping the CTA is a friendly reassurance, not
            // fine print. Single-line, small icon, primary text color so it doesn't blend with
            // the secondary legal copy below.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.appPink)
                    .accessibilityHidden(true)
                Text("Cancel anytime in Settings")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
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
            .padding(.top, 10)
            .padding(.bottom, 0)
            .background(Color(.systemBackground))
        }
        /// Extra top inset so the large title clears the status bar / Dynamic Island comfortably.
        .padding(.top, 40)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var planCards: some View {
        VStack(spacing: 8) {
            if let m = products.monthlyProduct {
                PaywallMonthlyCard(
                    displayPrice: m.displayPrice,
                    isSelected: selectedPlan == .monthly
                ) { selectedPlan = .monthly }
            }
            if let y = products.yearlyProduct {
                PaywallYearlyCard(
                    yearly: y,
                    monthly: products.monthlyProduct,
                    topCaption: yearlyCardCaption,
                    petCount: petCount,
                    isSelected: selectedPlan == .yearly
                ) { selectedPlan = .yearly }
            }
        }
        // Extra space so the selected plan’s stroke isn't clipped against the footer region.
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var personalizedBulletList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(personalizedBullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.appPink)
                        .accessibilityHidden(true)
                    Text(bullet)
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Paywall preview carousel

/// A single slide in the paywall preview carousel — each case shows real product UI (schedule list,
/// Settings reminders, or Analytics-style weight chart), scaled to fit the carousel.
private enum PaywallPreviewSlide: Equatable, Identifiable {
    case scheduleTimeline(petName: String, animalType: AnimalType)
    case reminderPush(petName: String, animalType: AnimalType)
    case weightChart

    /// Fixed kind for reordering the carousel (`paywallPreviewSlides`); not the same as `id`.
    var stableSlideKind: String {
        switch self {
        case .scheduleTimeline: return "schedule"
        case .reminderPush: return "reminder"
        case .weightChart: return "weight"
        }
    }

    /// Unique per slide *content* so SwiftUI does not reuse a `TabView` page host when the pet name
    /// or type changes while the paywall is visible (that reuse produced “invalid reuse after initialization failure”).
    var id: String {
        switch self {
        case .scheduleTimeline(let petName, let animalType):
            return "schedule-\(animalType.rawValue)-\(petName)"
        case .reminderPush(let petName, let animalType):
            return "reminder-\(animalType.rawValue)-\(petName)"
        case .weightChart:
            return "weight"
        }
    }

    var caption: String {
        switch self {
        case .scheduleTimeline: return "Every walk, meal, and med — at a glance"
        case .reminderPush:     return "Reminders before what matters"
        case .weightChart:      return "Track weight, spot changes early"
        }
    }
}

/// Swipeable, auto-advancing paged carousel of real in-app UI previews. Replaces the older text-only
/// `PaywallRotatingBenefits` because image-led paywalls reliably outperform text-only paywalls.
/// User swipes interrupt the auto-advance and continue cycling from the new position on the
/// next tick.
///
/// Uses a paging `ScrollView` + `scrollPosition` instead of `TabView(.page)` so we never hit
/// `UIPageViewController`’s aggressive child reuse (a frequent source of “invalid reuse after initialization failure”
/// with heterogeneous pages like `ScheduleListView` vs charts).
private struct PaywallPreviewCarousel: View {
    let slides: [PaywallPreviewSlide]
    var interval: TimeInterval = 3.5

    /// Vertical space for the scaled preview inside each page (caption + page dots sit below).
    /// Taller than before so schedule + compliance rows scale down with the full feature still visible.
    private let previewAreaHeight: CGFloat = 268
    /// Horizontal padding applied to each slide (`28` × 2 is subtracted from page width for fit math).
    private let slideHorizontalPadding: CGFloat = 28

    /// Scroll anchor id (matches each slide’s `id`, including pet name).
    @State private var scrollPosition: String?
    /// `Task`-based advance avoids Combine `Autoconnect` reuse issues; cancelled whenever the slide set changes.
    @State private var autoAdvanceTask: Task<Void, Never>?

    private var activeSlideID: String? {
        guard let scrollPosition, slides.contains(where: { $0.id == scrollPosition }) else {
            return slides.first?.id
        }
        return scrollPosition
    }

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let pageWidth = max(geo.size.width, 1)
                let contentWidth = max(pageWidth - slideHorizontalPadding * 2, 1)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(slides) { slide in
                            slideView(slide, availableWidth: contentWidth, availableHeight: previewAreaHeight)
                                .padding(.horizontal, slideHorizontalPadding)
                                .frame(width: pageWidth, height: previewAreaHeight, alignment: .top)
                                .id(slide.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
            }
            .frame(height: previewAreaHeight)

            Group {
                if let id = activeSlideID, let current = slides.first(where: { $0.id == id }) {
                    Text(current.caption)
                        .font(AppTypography.secondaryEmphasis)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24)
                }
            }
            .frame(minHeight: 36)
            .id("caption-\(activeSlideID ?? "")")
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: activeSlideID)

            HStack(spacing: 6) {
                ForEach(slides) { slide in
                    let isCurrent = slide.id == activeSlideID
                    Capsule()
                        .fill(isCurrent ? Color.appPink : Color.gray.opacity(0.3))
                        .frame(width: isCurrent ? 16 : 6, height: 6)
                        .animation(.spring(duration: 0.3), value: activeSlideID)
                }
            }
        }
        .onAppear {
            syncScrollPositionToSlides()
            startAutoAdvanceIfNeeded()
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
        }
        .onChange(of: slides.map(\.id)) { _, _ in
            syncScrollPositionToSlides()
            startAutoAdvanceIfNeeded()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(slides.first(where: { $0.id == activeSlideID })?.caption ?? "App preview")
    }

    private func syncScrollPositionToSlides() {
        guard !slides.isEmpty else { return }
        if scrollPosition == nil {
            scrollPosition = slides[0].id
            return
        }
        if slides.contains(where: { $0.id == scrollPosition }) { return }

        // Pet name / type changed: keep the same slide *kind* (schedule / reminder / weight) if it still exists.
        let prior = scrollPosition ?? ""
        let kind: String? = {
            if prior == "weight" { return "weight" }
            if prior.hasPrefix("schedule-") { return "schedule" }
            if prior.hasPrefix("reminder-") { return "reminder" }
            return nil
        }()
        if let kind, let match = slides.first(where: { $0.stableSlideKind == kind }) {
            scrollPosition = match.id
        } else {
            scrollPosition = slides[0].id
        }
    }

    private func startAutoAdvanceIfNeeded() {
        autoAdvanceTask?.cancel()
        guard slides.count > 1 else { return }
        let tickSeconds = interval
        autoAdvanceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickSeconds))
                guard !Task.isCancelled else { break }
                guard slides.count > 1 else { break }
                withAnimation(.easeInOut(duration: 0.45)) {
                    let current = scrollPosition ?? slides[0].id
                    guard let idx = slides.firstIndex(where: { $0.id == current }) else {
                        scrollPosition = slides[0].id
                        return
                    }
                    scrollPosition = slides[(idx + 1) % slides.count].id
                }
            }
        }
    }

    @ViewBuilder
    private func slideView(_ slide: PaywallPreviewSlide, availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        switch slide {
        case .scheduleTimeline(let name, let type):
            PaywallScheduleProductPreview(petName: name, animalType: type)
                .paywallCarouselFit(
                    designWidth: 410,
                    designHeight: 640,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight
                )
        case .reminderPush(_, _):
            PaywallSettingsNotificationsProductPreview()
                .paywallCarouselFit(
                    designWidth: 400,
                    designHeight: 340,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight
                )
        case .weightChart:
            PaywallWeightTrendProductPreview()
                .paywallCarouselFit(
                    designWidth: 400,
                    designHeight: 300,
                    availableWidth: availableWidth,
                    availableHeight: availableHeight
                )
        }
    }
}

// MARK: - Paywall carousel (real product UI)

private extension View {
    /// Lays out the preview at a fixed “design” size, then scales **uniformly** so the entire rect
    /// fits inside the carousel cell. Design height/width are generous so real product UI (schedule
    /// rows with compliance, charts, etc.) is not clipped **before** scaling — only the final cell
    /// clips to `availableWidth` × `availableHeight`.
    func paywallCarouselFit(
        designWidth: CGFloat,
        designHeight: CGFloat,
        availableWidth: CGFloat,
        availableHeight: CGFloat
    ) -> some View {
        let aw = max(availableWidth, 1)
        let ah = max(availableHeight, 1)
        let scale = min(aw / designWidth, ah / designHeight)
        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            self
                .frame(width: designWidth, height: designHeight, alignment: .topLeading)
                .scaleEffect(scale, anchor: .top)
                .frame(width: designWidth * scale, height: designHeight * scale)
            Spacer(minLength: 0)
        }
        .frame(width: aw, height: ah, alignment: .top)
        .clipped()
    }
}

/// Same `ScheduleListView` as the Schedule tab, with sample today’s events for the user’s pet.
private struct PaywallScheduleProductPreview: View {
    @State private var viewModel: HomeViewModel

    init(petName: String, animalType: AnimalType) {
        _viewModel = State(initialValue: HomeViewModel.paywallCarouselSchedule(petName: petName, animalType: animalType))
    }

    var body: some View {
        ScheduleListView(viewModel: viewModel, hideCompleted: .constant(false))
            .background(Color(.systemGroupedBackground))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Notifications section matching **Settings › Notifications** (reminder timing UI).
/// Implemented with static layout (no `List`) so UIKit table reuse never nests inside the paywall `TabView`.
private struct PaywallSettingsNotificationsProductPreview: View {
    @State private var remindersEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notifications")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                Toggle("Enable event reminders", isOn: $remindersEnabled)
                    .tint(Color.appPink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)

                Divider().padding(.leading, 16)

                HStack {
                    Text("10 minutes before")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.appPink)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(maxWidth: 360)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Weight trends card using the same chart styling as **Analytics › Weight Trends** (sample data).
private struct PaywallWeightTrendProductPreview: View {
    @AppStorage("weightUnit") private var weightUnitRaw = "kg"
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    private var sortedEntries: [WeightEntry] {
        let cal = Calendar.current
        let now = Date.now
        let daysAgo: (Int) -> Date = { cal.date(byAdding: .day, value: -$0, to: now) ?? now }
        return [
            WeightEntry(date: daysAgo(28), kg: 11.8),
            WeightEntry(date: daysAgo(21), kg: 12.0),
            WeightEntry(date: daysAgo(14), kg: 12.2),
            WeightEntry(date: daysAgo(7), kg: 12.4),
            WeightEntry(date: daysAgo(0), kg: 12.6),
        ].sorted { $0.date < $1.date }
    }

    var body: some View {
        let sorted = sortedEntries
        let diffKg = sorted.last!.kg - sorted[sorted.count - 2].kg
        let displayValues = sorted.map { weightUnit.displayValue(fromKg: $0.kg) }
        let minY = (displayValues.min() ?? 0) * 0.92
        let maxY = (displayValues.max() ?? 1) * 1.08
        let color = Color.appPink
        let dateDomain = sorted.first!.date ... sorted.last!.date

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weight Trends")
                    .font(AppTypography.groupTitle)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: diffKg >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diffKg >= 0 ? .orange : .green)
                    Text(weightUnit.formatChange(diffKg))
                        .foregroundStyle(diffKg >= 0 ? .orange : .green)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(weightUnit.formatValue(sorted.last!.kg)) now")
                        .foregroundStyle(.secondary)
                }
                .font(AppTypography.compactControl)
            }

            Chart(sorted) { e in
                let y = weightUnit.displayValue(fromKg: e.kg)
                LineMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .interpolationMethod(.linear)
                AreaMark(
                    x: .value("Date", e.date),
                    yStart: .value("Min", minY),
                    yEnd: .value(weightUnit.label, y)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.linear)
                PointMark(x: .value("Date", e.date), y: .value(weightUnit.label, y))
                    .foregroundStyle(color)
                    .symbolSize(24)
            }
            .chartYScale(domain: minY...maxY)
            .chartXScale(domain: dateDomain)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Color(.separator).opacity(0.5))
                    AxisValueLabel(centered: false) {
                        if let v = v.as(Double.self) {
                            Text(String(format: "%.1f", v))
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .frame(height: 96)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Yearly option; pink border when selected (prices from StoreKit).
private struct PaywallYearlyCard: View {
    let yearly: Product
    /// Compared to \(monthly.price × 12) for savings copy; omit if unavailable.
    var monthly: Product?
    /// Optional tagline shown under "Yearly" — used to anchor the yearly plan to the user's
    /// stated reason for downloading (e.g. "Best for medication routines").
    var topCaption: String? = nil
    /// Number of pets in the household. `1` shows per-day framing; `>1` shows per-pet/month
    /// framing. Per-day pricing converts higher because the number feels trivially small.
    var petCount: Int = 1
    var isSelected: Bool
    var onSelect: () -> Void

    private var effectivePerMonthFormatted: String {
        let perMonth = yearly.price / Decimal(12)
        return perMonth.formatted(yearly.priceFormatStyle)
    }

    /// Currency formatter that rounds **up** to the storefront currency's natural precision so
    /// "Less than $X/day" wording is always honest (we never claim a price lower than reality).
    private var ceilingCurrencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = yearly.priceFormatStyle.locale
        f.roundingMode = .up
        return f
    }

    private func formatCeiling(_ value: Decimal) -> String {
        ceilingCurrencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? value.formatted(yearly.priceFormatStyle)
    }

    /// Per-day price, ceiled. e.g. $99/year → "$0.27".
    private var perDayCeilingFormatted: String {
        formatCeiling(yearly.price / Decimal(365))
    }

    /// Per-pet, per-month price, ceiled. e.g. $99/year ÷ 12 ÷ 3 pets → "$2.75".
    private var perPetPerMonthCeilingFormatted: String {
        let perPetMonth = yearly.price / Decimal(12) / Decimal(max(petCount, 1))
        return formatCeiling(perPetMonth)
    }

    /// Subtitle under the per-year price — always shows the effective per-month cost.
    private var pricingSubtitleText: String {
        return "~\(effectivePerMonthFormatted) per month"
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
        var parts: [String] = []
        if let topCaption { parts.append(topCaption) }
        parts.append("\(yearly.displayPrice) per year.")
        parts.append("\(pricingSubtitleText).")
        if let yearlySavingsPercent {
            parts.append("Save \(yearlySavingsPercent) percent versus twelve months billed monthly.")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .top) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yearly")
                            .font(AppTypography.secondaryEmphasis)
                            .multilineTextAlignment(.leading)
                        if let topCaption {
                            Text(topCaption)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, savingsBadgeCaption != nil ? 22 : 14)
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
    let displayPrice: String
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .firstTextBaseline) {
                Text("Monthly")
                    .font(AppTypography.secondaryEmphasis)
                Spacer(minLength: 8)
                Text("\(displayPrice) per month")
                    .font(.footnote)
                    .fontWeight(.regular)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
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
        .accessibilityLabel("Monthly, \(displayPrice) per month")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Centralized legal URLs used by the paywall footer. Must stay in sync with the links in `SettingsView`.
private enum PaywallLegalURLs {
    static let privacy = URL(string: "https://lukebillings.github.io/PetSchedule/privacypolicy/")!
    static let terms = URL(string: "https://lukebillings.github.io/PetSchedule/termsandconditions/")!
    static let tos = URL(string: "https://lukebillings.github.io/PetSchedule/termsandconditions/")!
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
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                ForEach(Array(disclosureLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 8) {
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
            footerLinkURL(title: "Terms of Use (EULA)", url: PaywallLegalURLs.tos, font: captionFont, minScale: minScale)
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
    static let monthly = "com.petschedule.premium.monthly"
    static let yearly = "com.petschedule.premium.yearly"
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
    @State private var selectedPlan: PaywallPlan = .monthly
    @State private var purchaseState: PaywallPurchaseState = .idle
    @State private var errorMessage: String?
    /// The user's "main reason" choice from onboarding step 9 (persisted to `UserDefaults`).
    /// Drives the personalized headline, plan-card caption, and bullets after onboarding.
    @AppStorage(OnboardingFeatureInterest.persistenceKey) private var persistedFeatureInterestRaw: String = ""

    private var featureInterest: OnboardingFeatureInterest? {
        OnboardingFeatureInterest(rawValue: persistedFeatureInterestRaw)
    }

    private var firstPet: Pet? { viewModel.pets.first }
    private var ownsMultiplePets: Bool { viewModel.pets.count > 1 }
    private var petName: String { firstPet?.name ?? "" }
    /// Real household size (clamped to >= 1 so the per-pet/month divisor never hits zero on a
    /// fresh install with no pets yet).
    private var petCountForPricing: Int { max(viewModel.pets.count, 1) }

    private var headline: String {
        if let featureInterest {
            return featureInterest.paywallHeadline(petName: petName, ownsMultiplePets: ownsMultiplePets)
        }
        let name = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Unlock PetSchedule Premium"
        }
        if ownsMultiplePets {
            return "Keep \(name) and all your pets on schedule"
        }
        return "Keep \(name) on schedule"
    }

    private var previewSlides: [PaywallPreviewSlide] {
        paywallPreviewSlides(
            petName: petName,
            animalType: firstPet?.animalType ?? .dog,
            prioritized: featureInterest
        )
    }

    private var bullets: [String] {
        featureInterest?.paywallBullets(petName: petName, ownsMultiplePets: ownsMultiplePets)
            ?? Self.defaultPaywallBullets
    }

    private static let defaultPaywallBullets: [String] = [
        "Every walk, meal, and med — in one timeline per pet",
        "Reminders before what matters, so nothing slips",
        "Premium experience — no ads, just easier pet care",
    ]

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
                ScrollView(showsIndicators: false) {
                    PaywallContentBody(
                        headline: headline,
                        previewSlides: previewSlides,
                        personalizedBullets: bullets,
                        petCount: petCountForPricing,
                        products: products,
                        selectedPlan: $selectedPlan,
                        purchaseState: purchaseState,
                        errorMessage: errorMessage,
                        onRestorePurchases: { Task { await beginRestorePurchases() } }
                    )
                    .padding(.top, 12)
                }

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

// The Xcode Canvas preview often does not connect the software keyboard; run the app in Simulator (▶) to type in text fields, or use an Interactive Live preview.
#Preview {
    OnboardingView(viewModel: HomeViewModel()) {}
}

#Preview("Post-Onboarding Paywall") {
    PostOnboardingPaywallView(viewModel: HomeViewModel())
}
