import Foundation
import Observation
import StoreKit

/// Outcome of a single `purchase` attempt, surfaced to the UI to decide what to show.
enum SubscriptionPurchaseOutcome {
    case success
    case userCancelled
    /// e.g. Ask-to-Buy awaiting parental approval — entitlement will arrive later via `Transaction.updates`.
    case pending
}

enum SubscriptionPurchaseError: LocalizedError {
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Couldn't verify your purchase with Apple. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

/// App-wide source of truth for whether the user has an active premium subscription.
///
/// Owned by a process-wide singleton (`SubscriptionEntitlementStore.shared`) so that the
/// onboarding paywall, settings, and any feature gates read the same value. Listens to
/// `Transaction.updates` for the lifetime of the process so renewals, refunds, and Ask-to-Buy
/// approvals stay in sync without manual refresh from callers.
@Observable
@MainActor
final class SubscriptionEntitlementStore {
    static let shared = SubscriptionEntitlementStore()

    /// `true` while any premium product ID has a verified, non-expired, non-revoked entitlement.
    private(set) var isSubscribed: Bool = false

    /// Product ID of the currently-active subscription, if any. Useful for "Manage" UI.
    private(set) var activeProductID: String?

    /// `true` once `refreshFromCurrentEntitlements()` has run at least once. Used when UI needs to
    /// wait for a first StoreKit sync (app launch no longer gates on subscription).
    private(set) var initialCheckComplete: Bool = false

    private var updatesTask: Task<Void, Never>?

    private static let premiumProductIDs: Set<String> = [
        PetScheduleSubscriptionProductID.monthly,
        PetScheduleSubscriptionProductID.yearly,
    ]

    private init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refreshFromCurrentEntitlements() }
    }

    /// Re-scan `Transaction.currentEntitlements`. Call after purchase / restore / on launch.
    func refreshFromCurrentEntitlements() async {
        var subscribed = false
        var activeID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.premiumProductIDs.contains(transaction.productID) else { continue }
            if let revoked = transaction.revocationDate, revoked <= Date() { continue }
            if let expires = transaction.expirationDate, expires <= Date() { continue }
            subscribed = true
            activeID = transaction.productID
        }

        self.isSubscribed = subscribed
        self.activeProductID = activeID
        self.initialCheckComplete = true
    }

    /// Initiates a StoreKit purchase. Caller renders an in-flight UI while this runs.
    func purchase(_ product: Product) async throws -> SubscriptionPurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshFromCurrentEntitlements()
                return .success
            case .unverified:
                throw SubscriptionPurchaseError.verificationFailed
            }
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            throw SubscriptionPurchaseError.unknown
        }
    }

    /// Forces StoreKit to re-fetch entitlements from Apple, then refreshes local state.
    /// Returns whether the user has an active subscription after the sync.
    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshFromCurrentEntitlements()
        return isSubscribed
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            await transaction.finish()
        }
        await refreshFromCurrentEntitlements()
    }

#if DEBUG
    /// Instantly grants premium access without a StoreKit purchase. Simulator / testing only.
    func grantDebugAccess() {
        isSubscribed = true
        initialCheckComplete = true
    }
#endif
}
