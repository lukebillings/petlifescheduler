import SwiftUI
import PhotosUI
import UserNotifications

struct OnboardingView: View {
    @Bindable var viewModel: HomeViewModel
    let onComplete: () -> Void

    @State private var step = 0
    @State private var confettiTrigger = 0
    @State private var shimmerPhase: CGFloat = -1
    @State private var petName = ""
    @State private var animalType: AnimalType = .dog
    @State private var customAnimalType = ""
    @State private var petPhotoData: Data? = nil
    @State private var triggerPhotoPicker = false
    @State private var activityName = "Walk"
    @State private var activityTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch step {
                case 0:
                    Step1AddPet(petName: $petName, animalType: $animalType, customAnimalType: $customAnimalType)
                        .transition(slideTransition)
                case 1:
                    Step2AddPhoto(petName: petName, animalType: animalType, photoData: $petPhotoData, triggerPicker: $triggerPhotoPicker)
                        .transition(slideTransition)
                case 2:
                    Step3AddSchedule(
                        petName: petName,
                        animalType: animalType,
                        activityName: $activityName,
                        activityTime: $activityTime
                    )
                    .transition(slideTransition)
                case 3:
                    Step4Notifications()
                        .transition(slideTransition)
                case 4:
                    Step5Paywall(pet: previewPet, onSkip: { step = 5 })
                        .transition(slideTransition)
                case 5:
                    Step6OfferPaywall(
                        pet: previewPet,
                        onSkip: completeOnboarding,
                        onExpire: { withAnimation { step = 4 } }
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
                // Skip text link — only on photo step
                if step == 1 {
                    Button {
                        addPetIfNeeded()
                        withAnimation { step += 1 }
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 20)
                }

                // Hide progress dots on offer step
                if step < 5 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i == step ? Color.appPink : Color.gray.opacity(0.25))
                                .frame(width: i == step ? 20 : 8, height: 8)
                                .animation(.spring(duration: 0.3), value: step)
                        }
                    }
                } else {
                    Color.clear.frame(height: 8)
                }

                Button(action: advance) {
                    Text(buttonLabel)
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(continueDisabled ? Color.gray.opacity(0.3) : Color.appPink)
                        )
                        .overlay(
                            GeometryReader { geo in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.45), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 16, height: geo.size.height * 3)
                                .rotationEffect(.degrees(20))
                                .offset(x: shimmerPhase * (geo.size.width + 40) - 20,
                                        y: -(geo.size.height))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                            .allowsHitTesting(false)
                            .opacity(continueDisabled ? 0 : 1)
                        )
                }
                .disabled(continueDisabled)
                .onAppear {
                    withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1.6
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
            .padding(.top, 8)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            ConfettiView(trigger: confettiTrigger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var buttonLabel: String {
        switch step {
        case 1: return petPhotoData == nil ? "Add Photo" : "Continue"
        case 3: return "Enable Notifications"
        case 4: return "Continue"
        case 5: return "Claim 50% Off Your 1st Year"
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
        step == 0 && petName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func advance() {
        HapticManager.impact(.medium)
        confettiTrigger += 1

        switch step {
        case 0:
            break // name/type collected; pet created after photo step
        case 1 where petPhotoData == nil:
            // "Add Photo" tapped with no photo yet — open the picker instead of advancing
            triggerPhotoPicker = true
            return
        case 1:
            addPetIfNeeded()
        case 2:
            if let pet = viewModel.pets.first {
                viewModel.scheduleItems.append(
                    ScheduleItem(time: activityTime, activityName: activityName, pet: pet)
                )
            }
        case 3:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        case 4, 5:
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
        onComplete()
    }
}

// MARK: - Step 1: Add First Pet

private struct Step1AddPet: View {
    @Binding var petName: String
    @Binding var animalType: AnimalType
    @Binding var customAnimalType: String

    @State private var showOtherAlert = false
    @State private var otherDraft = ""

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
                    Text("Add your first pet")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Tell us a little about your companion\nto get things set up. You can add more pets later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                                        .font(.caption.bold())
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
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    TextField("e.g. Buddy, Luna, Max…", text: $petName)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
        }
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
                                .scaledToFill()
                                .frame(width: 180, height: 180)
                                .clipShape(Circle())
                        } else {
                            Image(animalType.placeholderImage)
                                .resizable()
                                .scaledToFill()
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
                                .font(.body.bold())
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
                .font(.caption)
                .foregroundStyle(.tertiary)
                .photosPicker(isPresented: $showPicker, selection: $photoItem, matching: .images)
                .onChange(of: triggerPicker) { _, val in if val { showPicker = true; triggerPicker = false } }

            VStack(spacing: 10) {
                Text("Add a photo of \(petName)")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Optional – you can always add one later.")
                    .font(.subheadline)
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

    private let activities = ["Walk", "Eat", "Sleep", "Play", "Medicine"]

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
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Add an event that is part of \(petName.isEmpty ? "their" : "\(petName)'s") daily schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 28)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(activities, id: \.self) { activity in
                                let selected = activityName == activity
                                Button { activityName = activity } label: {
                                    Label(activity, systemImage: ScheduleItem.icon(for: activity))
                                        .font(.subheadline.bold())
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
                        .font(.subheadline.bold())
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
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Get timely reminders for walks, meals,\nand every moment that matters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("You can change this in Settings at any time.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Step 5: Paywall

private struct Step5Paywall: View {
    let pet: Pet
    let onSkip: () -> Void
    @State private var selectedPlan: Plan = .yearly

    enum Plan { case monthly, yearly }

    private let benefits: [(icon: String, color: Color, label: String)] = [
        ("calendar.badge.clock", .appPink,    "All your pets"),
        ("bell.badge.fill",      .orange,      "Smart reminders"),
        ("hand.thumbsup.fill",   .cyan,        "No ads"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 24)

                    Text("Get started today!")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    // 3-icon benefits grid
                    HStack(spacing: 0) {
                        ForEach(benefits, id: \.label) { benefit in
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(benefit.color.opacity(0.12))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: benefit.icon)
                                        .font(.title2.bold())
                                        .foregroundStyle(benefit.color)
                                }
                                Text(benefit.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 28)

                    // Plan cards — price must clearly match the stated billing period (App Store subscription display)
                        VStack(spacing: 12) {
                            PlanCard(
                                planTitle: "Yearly",
                                price: "£49.99",
                                billingPeriodPhrase: "per year",
                                equivalentDetail: "≈ £4.17/mo",
                                isSelected: selectedPlan == .yearly
                            ) { selectedPlan = .yearly }
                            PlanCard(
                                planTitle: "Monthly",
                                price: "£9.99",
                                billingPeriodPhrase: "per month",
                                equivalentDetail: nil,
                                isSelected: selectedPlan == .monthly
                            ) { selectedPlan = .monthly }
                        }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
            }

            PaywallSubscriptionFooter()
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
        }
        .overlay(alignment: .topTrailing) {
            PaywallCloseButton(action: onSkip)
        }
    }
}

/// Dismiss control on top of paywall content (overlay beats ScrollView hit testing) with a proper 44pt target.
private struct PaywallCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.systemGray3))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
}

/// Restore, subscription disclosure, and legal links — pinned below scroll content so it stays visible above the onboarding bottom bar.
private struct PaywallSubscriptionFooter: View {
    var body: some View {
        VStack(spacing: 10) {
            Button("Restore Purchases") {}
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

            Text("Payment will be charged to your Apple Account at confirmation of purchase. Subscriptions auto-renew until cancelled. Manage or cancel in Account Settings · Subscriptions at least 24 hours before the current period ends. If you cancel, you keep access until the end of the billing period.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Button("Privacy Policy") {}
                Text("·").foregroundStyle(.secondary.opacity(0.8))
                Button("Terms and Conditions") {}
                Text("·").foregroundStyle(.secondary.opacity(0.8))
                Button("Terms of Use (EULA)") {}
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
    }
}

private struct BenefitRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.appPink)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

private struct PlanCard: View {
    let planTitle: String
    let price: String
    /// Completes the price line, e.g. "per year" — same font size as `price`
    let billingPeriodPhrase: String
    /// Optional average (yearly plans); shown on the same line as price when set
    let equivalentDetail: String?
    let isSelected: Bool
    let onTap: () -> Void

    private var priceLineAccessibility: String {
        "\(price) \(billingPeriodPhrase)"
        + (equivalentDetail.map { ", \($0)" } ?? "")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.appPink : Color(.systemGray4))
                    .accessibilityHidden(true)

                Text(planTitle)
                    .font(.headline.bold())
                    .lineLimit(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(price) \(billingPeriodPhrase)")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let equivalentDetail {
                        Text(equivalentDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.appPink : Color.clear, lineWidth: 2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(planTitle). \(priceLineAccessibility)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - Step 6: Offer Paywall

private struct Step6OfferPaywall: View {
    let pet: Pet
    let onSkip: () -> Void
    let onExpire: () -> Void

    @State private var secondsLeft = 60
    @State private var selectedPlan: Plan = .yearly
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Plan { case monthly, yearly }

    private let benefits: [(icon: String, color: Color, label: String)] = [
        ("calendar.badge.clock", .appPink,  "All your pets"),
        ("bell.badge.fill",      .orange,   "Smart reminders"),
        ("hand.thumbsup.fill",   .cyan,     "No ads"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer().frame(height: 24)

                    Text("Get started today!")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    // Countdown timer
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: CGFloat(secondsLeft) / 60.0)
                                .stroke(Color.appPink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 1), value: secondsLeft)
                            Text("\(secondsLeft)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.appPink)
                        }
                        .frame(width: 40, height: 40)

                        Text("Offer expires in \(secondsLeft)s")
                            .font(.subheadline.bold())
                            .foregroundStyle(secondsLeft <= 10 ? Color.red : Color.appPink)
                            .animation(.default, value: secondsLeft)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appPink.opacity(0.08), in: Capsule())
                    .onReceive(ticker) { _ in
                        if secondsLeft > 0 { secondsLeft -= 1 } else { onExpire() }
                    }

                    // 3-icon benefits grid
                    HStack(spacing: 0) {
                        ForEach(benefits, id: \.label) { benefit in
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(benefit.color.opacity(0.12))
                                        .frame(width: 60, height: 60)
                                    Image(systemName: benefit.icon)
                                        .font(.title2.bold())
                                        .foregroundStyle(benefit.color)
                                }
                                Text(benefit.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 28)

                    // Offer card: intro price + equivalent inside box; renewal line outside
                    VStack(alignment: .trailing, spacing: 10) {
                        PromoPlanCard(
                            planTitle: "Yearly",
                            firstTermPrice: "£24.99",
                            firstTermPhrase: "(1st year)",
                            equivalentDetail: "≈ £2.08/mo"
                        )

                        HStack(spacing: 6) {
                            Text("Then")
                                .foregroundStyle(.secondary)
                            Text("£49.99 / year")
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
                }
            }

            PaywallSubscriptionFooter()
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Color(.systemBackground))
        }
        .overlay(alignment: .topTrailing) {
            PaywallCloseButton(action: onSkip)
        }
    }
}

/// Offer card: intro price + equivalent monthly inside the bordered box.
/// Renewal pricing sits outside, below the card.
private struct PromoPlanCard: View {
    let planTitle: String
    let firstTermPrice: String
    let firstTermPhrase: String
    let equivalentDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(planTitle)
                    .font(.headline.bold())
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(firstTermPrice) \(firstTermPhrase)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Text(equivalentDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appPink, lineWidth: 2))
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(viewModel: HomeViewModel()) {}
}
