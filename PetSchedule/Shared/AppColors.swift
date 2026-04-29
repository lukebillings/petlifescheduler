import SwiftUI

extension Color {
    /// #F84EA6 — the app's signature pink used on event cards and accents
    static let appPink = Color(red: 248 / 255, green: 78 / 255, blue: 166 / 255)

    /// Teal-green tuned to sit beside app pink on schedule rows (yes / completed).
    static let complianceAccept = Color(red: 52 / 255, green: 158 / 255, blue: 138 / 255)

    /// Dusty rose — warmer than pure red; pairs with pink for declined compliance.
    static let complianceDecline = Color(red: 198 / 255, green: 98 / 255, blue: 122 / 255)
}
