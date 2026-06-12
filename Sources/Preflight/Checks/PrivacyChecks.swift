import Foundation

/// Flags a missing root privacy manifest (App Store §5.1.2).
public struct PrivacyManifestCheck: Check {
    public init() {}

    public func run(_ facts: BuildFacts) -> [Finding] {
        if facts.hasRootPrivacyManifest {
            return []
        }
        return [Finding(
            id: "A.privacy.missing",
            code: "privacy.missing",
            severity: .warning,
            category: .a,
            guideline: "5.1.2",
            title: "Missing privacy manifest",
            message: "No PrivacyInfo.xcprivacy at the app root. Required since May 2024 if you use \"required reason APIs\" or third-party SDKs — a frequent rejection reason.",
            fix: "Add a PrivacyInfo.xcprivacy (New File → App Privacy) declaring the API reasons and the collected data types."
        )]
    }
}

/// Informs about data types this build's manifests declare collecting (App Store §5.1.1).
///
/// CRITICAL: this finding is purely INFORMATIVE. Preflight does NOT read App Store
/// Connect privacy labels, so it never claims anything is "missing" from them —
/// only states what the build EMBEDS. A false "missing" would be the worst bug.
public struct CollectedDataCheck: Check {
    public init() {}

    /// Turns a raw `NSPrivacyCollectedDataType...` id into a readable label.
    static func prettify(_ id: String) -> String {
        let prefix = "NSPrivacyCollectedDataType"
        var core = id
        if core.hasPrefix(prefix) {
            core = String(core.dropFirst(prefix.count))
        }
        // Insert a space before each interior uppercase letter.
        var result = ""
        for (index, char) in core.enumerated() {
            if index > 0, char.isUppercase {
                result.append(" ")
            }
            result.append(char)
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? id : trimmed
    }

    public func run(_ facts: BuildFacts) -> [Finding] {
        guard !facts.collectedDataTypes.isEmpty else { return [] }
        let pretty = facts.collectedDataTypes.map(Self.prettify).joined(separator: ", ")
        return [Finding(
            id: "C.collectedData.declare",
            code: "collectedData.declare",
            severity: .warning,
            category: .c,
            guideline: "5.1.1",
            title: "Collected data to verify in your App Privacy labels",
            message: "This build embeds SDKs/manifests that declare collecting: \(pretty). Make sure each is declared in your App Privacy labels on App Store Connect (a classic miss: an SDK like RevenueCat).",
            fix: "App Store Connect → App Privacy: ensure EVERY type above is declared, with the right purpose.",
            args: ["types": pretty]
        )]
    }
}
