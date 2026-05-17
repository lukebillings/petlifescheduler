import SwiftUI
import UIKit

extension View {
    /// Pet / event / log editor sheets: standard large detent on iPhone; near full-screen on iPad.
    func detailEditorSheetStyle() -> some View {
        modifier(DetailEditorSheetStyleModifier())
    }
}

private struct DetailEditorSheetStyleModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesExpandedPresentation: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || horizontalSizeClass == .regular
    }

    func body(content: Content) -> some View {
        if usesExpandedPresentation {
            content
                .presentationDetents([.fraction(0.94)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(16)
                .presentationCompactAdaptation(.sheet)
                .modifier(DetailEditorPageSizingModifier())
        } else {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// iOS 18+ page-style sheets are much wider on iPad than the default form card.
private struct DetailEditorPageSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
