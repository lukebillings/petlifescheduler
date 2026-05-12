import SwiftUI

#if targetEnvironment(simulator)
/// Launch argument `-PetScheduleScreenshotHarness` plus env `PET_SS` = `never` | `share` | `track` | `send` | `store`
/// shows real product UI with **Max / Luna / Nemo** sample data. For **raw** PNGs (no bezel/background/text), run
/// `Marketing/capture_raw_screenshots.sh` or use **Simulator → File → Save Screen** while this mode is active.
enum AppStoreScreenshotHarnessScene: String, CaseIterable {
    case never
    case share
    case track
    case send
    case store

    static func currentFromEnvironment() -> AppStoreScreenshotHarnessScene {
        let raw = ProcessInfo.processInfo.environment["PET_SS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return AppStoreScreenshotHarnessScene(rawValue: raw) ?? .never
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-PetScheduleScreenshotHarness")
    }
}

@MainActor
enum AppStoreScreenshotHarness {
    static func viewModel(for scene: AppStoreScreenshotHarnessScene) -> HomeViewModel {
        var vm = HomeViewModel.analyticsPreview
        guard scene == .store, let maxIndex = vm.pets.firstIndex(where: { $0.name == "Max" }) else {
            return vm
        }
        var maxPet = vm.pets[maxIndex]
        let stub = Data("PetSchedule demo document".utf8)
        maxPet.documents = [
            PetDocument(name: "Lab results", data: stub, fileExtension: "pdf"),
            PetDocument(name: "X-ray", data: stub, fileExtension: "png"),
        ]
        vm.pets[maxIndex] = maxPet
        for i in vm.scheduleItems.indices where vm.scheduleItems[i].pet.id == maxPet.id {
            vm.scheduleItems[i].pet = maxPet
        }
        return vm
    }
}

struct AppStoreScreenshotHarnessRoot: View {
    let scene: AppStoreScreenshotHarnessScene
    @State private var viewModel: HomeViewModel

    init(scene: AppStoreScreenshotHarnessScene) {
        self.scene = scene
        _viewModel = State(initialValue: AppStoreScreenshotHarness.viewModel(for: scene))
    }

    var body: some View {
        Group {
            switch scene {
            case .never:
                ScheduleView(viewModel: viewModel)
            case .share:
                NavigationStack {
                    FamilySharingSettingsView(viewModel: viewModel)
                }
            case .track:
                AnalyticsView(viewModel: viewModel, screenshotHarnessScrollToJumpRaw: "mood")
            case .send:
                if let max = viewModel.pets.first(where: { $0.name == "Max" }) {
                    PetDetailSheet(pet: max, initialScrollAnchor: .export, onSave: { viewModel.updatePet($0) }, onRemovePet: nil)
                } else {
                    Text("Missing demo pet")
                }
            case .store:
                if let max = viewModel.pets.first(where: { $0.name == "Max" }) {
                    PetDetailSheet(pet: max, initialScrollAnchor: .documents, onSave: { viewModel.updatePet($0) }, onRemovePet: nil)
                } else {
                    Text("Missing demo pet")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
