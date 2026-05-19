import Foundation

/// Hosted legal pages on GitHub Pages (`/docs` → `https://lukebillings.github.io/petlifescheduler/…`).
enum LegalPageURLs {
    private static let base = "https://lukebillings.github.io/petlifescheduler"

    static let privacy = URL(string: "\(base)/privacypolicy/")!
    static let termsAndConditions = URL(string: "\(base)/termsandconditions/")!
    /// Apple Standard Licensed Application End User License Agreement.
    static let termsOfService = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
