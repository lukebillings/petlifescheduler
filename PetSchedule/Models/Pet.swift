import SwiftUI

struct Pet: Identifiable, Hashable {
    let id: UUID
    var name: String
    var color: Color
    /// SF Symbol name for the animal icon shown in the avatar
    var systemImage: String

    init(id: UUID = UUID(), name: String, color: Color, systemImage: String) {
        self.id = id
        self.name = name
        self.color = color
        self.systemImage = systemImage
    }
}
