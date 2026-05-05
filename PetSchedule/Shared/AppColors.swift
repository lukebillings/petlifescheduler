import SwiftUI

/// Preset color for the “assigned to” pill on event rows (stored as `rawValue` in sync payloads).
enum ScheduleAssigneeAccent: String, CaseIterable, Identifiable, Codable, Hashable {
    case pink
    case coral
    case orange
    case yellow
    case green
    case teal
    case blue
    case purple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pink: return "Pink"
        case .coral: return "Coral"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }

    var swatchColor: Color {
        switch self {
        case .pink: return .appPink
        case .coral: return Color(red: 1, green: 0.42, blue: 0.38)
        case .orange: return Color(red: 1, green: 0.58, blue: 0.2)
        case .yellow: return Color(red: 0.96, green: 0.78, blue: 0.22)
        case .green: return Color(red: 0.31, green: 0.72, blue: 0.4)
        case .teal: return Color(red: 0.2, green: 0.62, blue: 0.62)
        case .blue: return Color(red: 0.28, green: 0.52, blue: 0.96)
        case .purple: return Color(red: 0.58, green: 0.38, blue: 0.92)
        }
    }

    /// Text color on the assignee pill.
    var pillLabelColor: Color {
        switch self {
        case .yellow: return Color(red: 0.25, green: 0.2, blue: 0.05)
        default: return .white
        }
    }

    static func decode(stored: String) -> ScheduleAssigneeAccent {
        ScheduleAssigneeAccent(rawValue: stored) ?? .pink
    }
}

extension Color {
    /// #F84EA6 — the app's signature pink used on event cards and accents
    static let appPink = Color(red: 248 / 255, green: 78 / 255, blue: 166 / 255)

    /// Cool sea-glass teal — analogous to pink without traffic-light green.
    static let complianceAccept = Color(red: 42 / 255, green: 146 / 255, blue: 132 / 255)

    /// Plum-mauve — neighbor hue to app pink; avoids harsh red vs the homepage palette.
    static let complianceDecline = Color(red: 154 / 255, green: 82 / 255, blue: 118 / 255)
}
