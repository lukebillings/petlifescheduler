import SwiftUI

enum AnimalType: String, CaseIterable, Identifiable, Hashable, Codable {
    case dog, cat, fish, rabbit, bird, tortoise, other

    var id: String { rawValue }
    var displayName: String {
        self == .other ? "Other" : rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .dog:      return "dog.fill"
        case .cat:      return "cat.fill"
        case .fish:     return "fish.fill"
        case .rabbit:   return "hare.fill"
        case .bird:     return "bird.fill"
        case .tortoise: return "tortoise.fill"
        case .other:    return "pawprint.fill"
        }
    }

    var placeholderImage: String {
        "placeholder_\(rawValue)"
    }

    var color: Color {
        switch self {
        case .dog:      return .orange
        case .cat:      return .purple
        case .fish:     return .cyan
        case .rabbit:   return Color(red: 0.85, green: 0.55, blue: 0.45)
        case .bird:     return .blue
        case .tortoise: return Color(red: 0.25, green: 0.65, blue: 0.35)
        case .other:    return Color.appPink
        }
    }
}
