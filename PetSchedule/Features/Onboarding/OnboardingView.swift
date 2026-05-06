import Observation
import PhotosUI
import StoreKit
import SwiftUI
import UserNotifications

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

    /// Rotating headline + icon on the paywall — tied to onboarding “main reason”.
    var paywallRotatingFields: (text: String, systemImage: String) {
        switch self {
        case .medicationCompliance:
            return (
                "Medication reminders and routines tailored to your pets—fewer misses, calmer routines.",
                "pills.circle.fill"
            )
        case .petDetailsAndProfiles:
            return (
                "Profiles for each pet—vet info, identifiers, allergies, notes, whenever you need them.",
                "text.book.closed.fill"
            )
        case .weightLogging:
            return (
                "Weights on a timeline so you spot changes early—with context per pet.",
                "scalemass.fill"
            )
        case .walksAndActivities:
            return (
                "Walks and play in one timeline—nothing slips between handoffs or busy days.",
                "figure.walk.circle.fill"
            )
        case .feedingAndDailyCare:
            return (
                "Meals, water, and daily care on a single schedule—simple to follow and share.",
                "fork.knife.circle.fill"
            )
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
    @AppStorage(UserProfileStorage.displayNameKey) private var userDisplayName = ""

    @State private var subscriptionProducts = SubscriptionProductLoader()
    @State private var step = 0
    @State private var petName = ""
    @State private var animalType: AnimalType = .dog
    @State private var customAnimalType = ""
    @State private var petPhotoData: Data? = nil
    @State private var triggerPhotoPicker = false
    @State private var activityName = "Walk"
    @State private var activityTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var paywallPlan: Step5Paywall.Plan = .yearly
    @State private var householdPetCount: HouseholdPetCount = .one
    @State private var selectedFeatureInterest: OnboardingFeatureInterest?
    @State private var showHouseholdInviteSheet = false
    /// Draft for step 1 — avoid `@AppStorage` on every keystroke with `@Bindable` (device crashes).
    @State private var displayNameDraft = ""
    /// Draft for step 6 — avoids writing `@AppStorage` on every chip tap (can re-enter with `@Bindable` and crash on device).
    @State private var timeFormatDraft = TimeFormat.twentyFourHour.rawValue
    /// Drafts for steps 7–8 — same pattern as time format.
    @State private var weightUnitDraft = WeightUnit.kg.rawValue
    @State private var heightUnitDraft = HeightUnit.cm.rawValue

    private let totalSteps = 12

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
                    StepHouseholdInvite(showInviteSheet: $showHouseholdInviteSheet)
                        .transition(slideTransition)
                case 11:
                    Step5Paywall(
                        pet: previewPet,
                        ownsMultiplePets: householdPetCount == .two || householdPetCount == .threePlus,
                        featureInterest: selectedFeatureInterest,
                        products: subscriptionProducts,
                        selectedPlan: $paywallPlan
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
                // Skip — optional photo, schedule, notifications, or household invite
                if step == 3 || step == 4 || step == 5 || step == 10 {
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
                            if step == 10 {
                                Label("Invite household members", systemImage: "person.badge.plus")
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
            if newStep == 11 {
                Task { await subscriptionProducts.refresh() }
            }
        }
    }

    private var buttonLabel: String {
        switch step {
        case 3: return petPhotoData == nil ? "Add Photo" : "Continue"
        case 5: return "Enable Notifications"
        case 11:
            return "Continue"
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
        default:
            return false
        }
    }

    private func advance() {
        if step == 10 {
            HapticManager.impact(.light)
            showHouseholdInviteSheet = true
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
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        case 6:
            timeFormatRaw = timeFormatDraft
        case 7:
            weightUnitRaw = weightUnitDraft
        case 8:
            heightUnitRaw = heightUnitDraft
        case 11:
            completeOnboarding()
            return
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
                            caption: option.caption,
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

// MARK: - Household invite (before paywall)

private struct StepHouseholdInvite: View {
    @Binding var showInviteSheet: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(minHeight: 44)

                ZStack {
                    Circle()
                        .fill(Color.appPink.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.3.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.appPink.gradient)
                        .padding(30)
                        .frame(width: 120, height: 120)
                }

                VStack(spacing: 10) {
                    Text("Invite your household")
                        .font(AppTypography.screenTitle)
                        .multilineTextAlignment(.center)
                    Text("Share your PetSchedule with partners, family, or roommates so everyone sees the same pets, schedules, and logs. They need iCloud on their device to join.")
                        .font(AppTypography.secondaryLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("You can skip for now or add people anytime in Settings → Household.")
                    .font(AppTypography.supportingText)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }
        .sheet(isPresented: $showInviteSheet) {
            CloudSharingSheet(isPresented: $showInviteSheet, container: HouseholdCloudKitService.shared.container)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Paywall

private struct Step5Paywall: View {
    let pet: Pet
    var ownsMultiplePets: Bool
    var featureInterest: OnboardingFeatureInterest?
    var products: SubscriptionProductLoader
    @Binding var selectedPlan: Plan

    enum Plan { case monthly, yearly }

    private static let defaultRotatingBenefits: [PaywallRotatingBenefitItem] = [
        PaywallRotatingBenefitItem(
            text: "Every walk, meal, and med—in one timeline per pet.",
            systemImage: "calendar.badge.clock"
        ),
        PaywallRotatingBenefitItem(
            text: "Reminders before what matters, so nothing slips.",
            systemImage: "bell.badge.fill"
        ),
        PaywallRotatingBenefitItem(
            text: "Premium experience—no ads, just easier pet care.",
            systemImage: "hand.thumbsup.fill"
        ),
    ]

    private var rotatingBenefits: [PaywallRotatingBenefitItem] {
        var items: [PaywallRotatingBenefitItem] = []
        if let featureInterest {
            let f = featureInterest.paywallRotatingFields
            items.append(PaywallRotatingBenefitItem(text: f.text, systemImage: f.systemImage))
        }
        for item in Self.defaultRotatingBenefits where !items.contains(item) {
            items.append(item)
        }
        return items
    }

    private var paywallHeadline: String {
        let name = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return "Get started today!"
        }
        if ownsMultiplePets {
            return "Keep \(name) and all your pets on schedule"
        }
        return "Keep \(name) on schedule"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 0) {
                Text(paywallHeadline)
                    .font(AppTypography.screenTitle)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
                    .lineLimit(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                PaywallRotatingBenefits(items: rotatingBenefits, interval: 3.5)

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

                PaywallSubscriptionFooter(
                    includeFreeTrialMention: products.isLoading
                        ? nil
                        : (products.yearlyProduct?.subscription?.introductoryOffer?.paymentMode == .freeTrial)
                )
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .padding(.bottom, 0)
                .background(Color(.systemBackground))
            }
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: 0)
        }
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
                    displayPrice: m.displayPrice,
                    isSelected: selectedPlan == .monthly
                ) { selectedPlan = .monthly }
            }
        }
        // Extra space so the selected plan’s stroke isn’t clipped against the footer region.
        .padding(.bottom, 4)
    }
}

/// One paywall carousel slide: headline + SF Symbol shown below it.
private struct PaywallRotatingBenefitItem: Equatable {
    var text: String
    var systemImage: String
}

/// Single large benefit at a time with an icon beneath; advances automatically.
private struct PaywallRotatingBenefits: View {
    let items: [PaywallRotatingBenefitItem]
    var interval: TimeInterval = 3.5

    var body: some View {
        Group {
            if items.isEmpty {
                Color.clear.frame(height: 180)
            } else {
                TimelineView(.periodic(from: .now, by: interval)) { timeline in
                    let count = items.count
                    let idx = Int(timeline.date.timeIntervalSince1970 / interval) % count
                    let item = items[idx]

                    VStack(spacing: 18) {
                        Text(item.text)
                            .font(AppTypography.panelTitle)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.88)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity)

                        Image(systemName: item.systemImage)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(Color.appPink.gradient)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 175, alignment: .center)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.45), value: idx)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.text)
                }
            }
        }
        .padding(.horizontal, 22)
    }
}

/// Yearly option; pink border when selected (prices from StoreKit).
private struct PaywallYearlyCard: View {
    let yearly: Product
    /// Compared to \(monthly.price × 12) for savings copy; omit if unavailable.
    var monthly: Product?
    var isSelected: Bool
    var onSelect: () -> Void

    private var effectivePerMonthFormatted: String {
        let perMonth = yearly.price / Decimal(12)
        return perMonth.formatted(yearly.priceFormatStyle)
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
        return "SAVE \(p)%"
    }

    private var accessibilitySubtitle: String {
        let base = "\(yearly.displayPrice) per year. Approximately \(effectivePerMonthFormatted) per month."
        if let yearlySavingsPercent {
            return "\(base) Save \(yearlySavingsPercent) percent versus twelve months billed monthly."
        }
        return base
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
                        Text("~\(effectivePerMonthFormatted) per month")
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

private struct PaywallSubscriptionFooter: View {
    /// `nil` while loading — show non-trial wording until product metadata resolves (avoids flashing trial copy).
    var includeFreeTrialMention: Bool? = nil

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
                    footerLink(title: "Restore Purchases", font: .caption2, minScale: 1.0) {}
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

    /// Privacy / terms row only (Restore is on its own line above).
    private func paywallPolicyLinkStrip(
        spacingBetweenItems: CGFloat,
        captionFont: Font,
        minScale: CGFloat = 1.0
    ) -> some View {
        HStack(spacing: spacingBetweenItems) {
            footerLink(title: "Privacy Policy", font: captionFont, minScale: minScale) {}
            middotDivider(font: captionFont)
            footerLink(title: "Terms and Conditions", font: captionFont, minScale: minScale) {}
            middotDivider(font: captionFont)
            footerLink(title: "Terms of Use (EULA)", font: captionFont, minScale: minScale) {}
        }
    }

    private func middotDivider(font: Font) -> some View {
        Text("\u{00B7}") // interpunct ·
            .font(font)
            .foregroundStyle(.secondary.opacity(0.8))
            .baselineOffset(-0.5)
    }

    private func footerLink(
        title: String,
        font: Font,
        minScale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .allowsTightening(true)
                .minimumScaleFactor(minScale)
        }
        .buttonStyle(.plain)
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

// The Xcode Canvas preview often does not connect the software keyboard; run the app in Simulator (▶) to type in text fields, or use an Interactive Live preview.
#Preview {
    OnboardingView(viewModel: HomeViewModel()) {}
}
