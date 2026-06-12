import Foundation

/// Runs a set of `Check`s over `BuildFacts` and returns sorted findings.
public struct CheckEngine: Sendable {
    public let checks: [Check]

    public init(checks: [Check]) {
        self.checks = checks
    }

    /// Runs every check and returns the findings sorted by
    /// `(severity, category.rawValue)` ascending.
    public func run(_ facts: BuildFacts) -> [Finding] {
        checks
            .flatMap { $0.run(facts) }
            .sorted { lhs, rhs in
                if lhs.severity != rhs.severity {
                    return lhs.severity < rhs.severity
                }
                return lhs.category.rawValue < rhs.category.rawValue
            }
    }

    /// The standard build-only check set, in canonical order.
    public static let buildOnly = CheckEngine(checks: [
        UsageStringCheck(),
        PrivacyManifestCheck(),
        EncryptionComplianceCheck(),
        TrackingUsageCheck(),
        TrackingATTCheck(),
        CollectedDataCheck(),
    ])
}
