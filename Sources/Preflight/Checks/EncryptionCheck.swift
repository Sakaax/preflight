import Foundation

/// Flags a missing export-compliance key (`ITSAppUsesNonExemptEncryption`).
public struct EncryptionComplianceCheck: Check {
    public init() {}

    public func run(_ facts: BuildFacts) -> [Finding] {
        if facts.hasEncryptionComplianceKey {
            return []
        }
        return [Finding(
            id: "A.encryption.missing",
            code: "encryption.missing",
            severity: .info,
            category: .a,
            guideline: nil,
            title: "Export compliance not declared",
            message: "The ITSAppUsesNonExemptEncryption key is missing from the Info.plist. Without it, App Store Connect asks you the question again at every upload.",
            fix: "Add ITSAppUsesNonExemptEncryption (usually NO if you only use standard HTTPS)."
        )]
    }
}
