import Foundation

/// Hosted legal pages on GitHub Pages (`/docs` → `https://lukebillings.github.io/petlifescheduler/…`).
enum LegalPageURLs {
    private static let base = "https://lukebillings.github.io/petlifescheduler"

    static let privacy = URL(string: "\(base)/privacypolicy/")!
    static let termsAndConditions = URL(string: "\(base)/termsandconditions/")!
    /// App Store EULA link; same document as terms today.
    static let termsOfService = termsAndConditions
}
