import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Bindable var viewModel: HomeViewModel
    let onComplete: () -> Void

    @State private var step = 0
    @State private var petName = ""
    @State private var animalType: AnimalType = .dog
    @State private var activityName = "Walk"
    @State private var activityTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Step content fills all available space
            ZStack {
                switch step {
                case 0:
                    Step1AddPet(petName: $petName, animalType: $animalType)
                        .transition(slideTransition)
                case 1:
                    Step2AddSchedule(
                        petName: petName,
                        animalType: animalType,
                        activityName: $activityName,
                        activityTime: $activityTime
                    )
                    .transition(slideTransition)
                case 2:
                    Step3Notifications()
                        .transition(slideTransition)
                case 3:
                    Step4Paywall(onSkip: completeOnboarding)
                        .transition(slideTransition)
                default:
                    EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(duration: 0.4), value: step)

            // Fixed bottom bar — same position on every screen
            VStack(spacing: 18) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.appPink : Color.gray.opacity(0.25))
                            .frame(width: i == step ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: step)
                    }
                }

                // CTA button
                Button(action: advance) {
                    Text(step == 3 ? "Subscribe" : "Continue")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(continueDisabled ? Color.gray.opacity(0.3) : Color.appPink)
                        )
                }
                .disabled(continueDisabled)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
            .padding(.top, 12)
        }
        .background(Color(.systemBackground))
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
        switch step {
        case 0:
            let pet = Pet(name: petName.trimmingCharacters(in: .whitespaces), animalType: animalType)
            viewModel.addPet(pet)
        case 1:
            if let pet = viewModel.pets.first {
                viewModel.scheduleItems.append(
                    ScheduleItem(time: activityTime, activityName: activityName, pet: pet)
                )
            }
        case 2:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        case 3:
            completeOnboarding()
            return
        default:
            break
        }
        withAnimation { step += 1 }
    }

    private func completeOnboarding() {
        onComplete()
    }
}

// MARK: - Step 1: Add First Pet

private struct Step1AddPet: View {
    @Binding var petName: String
    @Binding var animalType: AnimalType

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Illustration
                ZStack {
                    Circle()
                        .fill(animalType.color.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Image(systemName: animalType.systemImage)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(animalType.color.gradient)
                        .padding(34)
                        .frame(width: 140, height: 140)
                }
                .animation(.spring(duration: 0.3), value: animalType)
                .padding(.top, 48)

                // Heading
                VStack(spacing: 10) {
                    Text("Add your first pet")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Tell us a little about your companion\nto get things set up.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Animal type picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnimalType.allCases) { type in
                            let selected = animalType == type
                            Button {
                                withAnimation(.spring(duration: 0.25)) { animalType = type }
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
                                    Text(type.displayName)
                                        .font(.caption.bold())
                                        .foregroundStyle(selected ? Color.appPink : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 28)
                }

                // Name field
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
    }
}

// MARK: - Step 2: Add Schedule

private struct Step2AddSchedule: View {
    let petName: String
    let animalType: AnimalType
    @Binding var activityName: String
    @Binding var activityTime: Date

    private let activities = ["Walk", "Eat", "Sleep", "Play", "Vet", "Groom", "Medicine"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Illustration
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
                    Text("Add a first activity to kick things off.\nYou can add more on the Schedule tab.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Activity picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 28)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(activities, id: \.self) { activity in
                                let selected = activityName == activity
                                Button {
                                    activityName = activity
                                } label: {
                                    Text(activity)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule().fill(selected ? Color.appPink : Color(.secondarySystemBackground))
                                        )
                                        .foregroundStyle(selected ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(duration: 0.2), value: selected)
                            }
                        }
                        .padding(.horizontal, 28)
                    }
                }

                // Time picker
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

// MARK: - Step 3: Notifications

private struct Step3Notifications: View {
    @State private var tapped = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Illustration
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

            Button {
                tapped = true
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            } label: {
                Label(tapped ? "Notifications enabled ✓" : "Enable Notifications", systemImage: tapped ? "checkmark" : "bell.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(tapped ? Color.green : Color.appPink)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(tapped ? Color.green.opacity(0.1) : Color.appPink.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .animation(.spring(duration: 0.3), value: tapped)

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

// MARK: - Step 4: Paywall

private struct Step4Paywall: View {
    let onSkip: () -> Void
    @State private var selectedPlan: Plan = .annual

    enum Plan { case monthly, annual }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // X dismiss button
            Button(action: onSkip) {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .padding(.top, 16)
            .padding(.trailing, 24)

            // Main content
            VStack(spacing: 28) {
                Spacer().frame(height: 24)

                // Illustration
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: "crown.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.yellow.gradient)
                        .padding(28)
                        .frame(width: 120, height: 120)
                }

                VStack(spacing: 8) {
                    Text("PetSchedule Pro")
                        .font(.largeTitle.bold())
                    Text("Everything you need to keep your\npets healthy and happy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Plan cards
                VStack(spacing: 12) {
                    PlanCard(
                        title: "Annual",
                        price: "£29.99",
                        period: "per year",
                        badge: "Best Value",
                        isSelected: selectedPlan == .annual
                    ) { selectedPlan = .annual }

                    PlanCard(
                        title: "Monthly",
                        price: "£9.99",
                        period: "per month",
                        badge: nil,
                        isSelected: selectedPlan == .monthly
                    ) { selectedPlan = .monthly }
                }
                .padding(.horizontal, 28)

                Text("Cancel anytime. Renews automatically.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let period: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline.bold())
                        if let badge {
                            Text(badge)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appPink, in: Capsule())
                        }
                    }
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.title3.bold())
                    .foregroundStyle(isSelected ? Color.appPink : .primary)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.appPink : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

#Preview {
    OnboardingView(viewModel: HomeViewModel()) {}
}
