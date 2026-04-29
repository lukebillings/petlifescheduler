import SwiftUI

extension Color {
    /// #F84EA6 — the app's signature pink used on event cards and accents
    static let appPink = Color(red: 248 / 255, green: 78 / 255, blue: 166 / 255)

    /// Cool sea-glass teal — analogous to pink without traffic-light green.
    static let complianceAccept = Color(red: 42 / 255, green: 146 / 255, blue: 132 / 255)

    /// Plum-mauve — neighbor hue to app pink; avoids harsh red vs the homepage palette.
    static let complianceDecline = Color(red: 154 / 255, green: 82 / 255, blue: 118 / 255)
}
