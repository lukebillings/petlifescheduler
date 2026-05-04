import SwiftUI

/// Shared text styles so tab screens, sheets, and cards use one coherent type scale.
/// All styles use Dynamic Type text styles (not fixed point sizes) except where layout requires it.
enum AppTypography {

    // MARK: - Screens & major structure

    /// Custom large title (Schedule header) — matches `.navigationBarTitleDisplayMode(.large)`.
    static let screenTitle = Font.largeTitle.weight(.bold)

    /// In-content section label (`Today`, calendar context).
    static let sectionHeading = Font.title3.weight(.semibold)

    /// Group headers (`Weight Trends`, selected day on calendar).
    static let groupTitle = Font.headline

    /// Sheet and overlay titles (tutorial card, satisfaction check-in).
    static let panelTitle = Font.title2.weight(.semibold)

    // MARK: - Cards & dense UI

    /// Titles on tinted cards, hints, empty-state headlines.
    static let cardTitle = Font.subheadline.weight(.semibold)

    /// Primary line in list rows, pet names in charts, prominent names.
    static let primaryLabel = Font.body.weight(.semibold)

    /// Default secondary line (activity title, descriptions).
    static let secondaryLabel = Font.subheadline

    /// Stronger subhead (mood, metadata beside values).
    static let secondaryEmphasis = Font.subheadline.weight(.semibold)

    /// Fine print, footers, long helper copy.
    static let supportingText = Font.caption

    // MARK: - Controls & data

    /// Chips, avatar labels, + Event / + Log capsules, filter “All”.
    static let compactControl = Font.caption.weight(.semibold)

    /// Table column headers, chart tick labels, “now” divider time.
    static let micro = Font.caption2.weight(.semibold)

    /// Pink capsule CTAs (`Tap to add`).
    static let capsuleButton = Font.subheadline.weight(.semibold)

    /// Leading icon glyph in schedule rows.
    static let rowIcon = Font.body.weight(.semibold)

    /// Calendar chevrons, similar toolbar glyphs.
    static let navControl = Font.body.weight(.semibold)

    /// Day number inside the month grid.
    static let calendarDayNumber = Font.callout.weight(.semibold)

    /// Completion checkbox / circle control.
    static let completionControl = Font.title2

    /// Decorative symbol in empty states (with opacity applied in views).
    static let emptyStateSymbol = Font.largeTitle
}
