import Foundation

/// Human-readable name for a usage-description key (English).
func prettyPermissionName(_ key: String) -> String {
    let map: [String: String] = [
        "NSCameraUsageDescription": "Camera",
        "NSMicrophoneUsageDescription": "Microphone",
        "NSPhotoLibraryUsageDescription": "Photos",
        "NSPhotoLibraryAddUsageDescription": "Add to Photos",
        "NSLocationWhenInUseUsageDescription": "Location",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Location (always)",
        "NSContactsUsageDescription": "Contacts",
        "NSCalendarsUsageDescription": "Calendar",
        "NSFaceIDUsageDescription": "Face ID",
        "NSUserTrackingUsageDescription": "Tracking",
        "NSBluetoothAlwaysUsageDescription": "Bluetooth",
        "NSMotionUsageDescription": "Motion",
    ]
    return map[key] ?? key
}

/// Flags empty or placeholder usage-description strings (App Store §5.1.1).
public struct UsageStringCheck: Check {
    public init() {}

    private static let placeholders: Set<String> = [
        "todo", "test", "description", "asdf", "...", "x", "xxx", "usage",
        "reason", "permission", "lorem ipsum", "tbd", "na", "n/a",
    ]

    public func run(_ facts: BuildFacts) -> [Finding] {
        var findings: [Finding] = []
        for key in facts.usageDescriptions.keys.sorted() {
            let value = facts.usageDescriptions[key] ?? ""
            let permission = prettyPermissionName(key)
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                findings.append(Finding(
                    id: "A.usage.empty.\(key)",
                    code: "usage.empty",
                    severity: .error,
                    category: .a,
                    guideline: "5.1.1",
                    title: "\(permission): empty description",
                    message: "The \(key) key is present but its value is empty. Apple rejects empty usage strings.",
                    fix: "Provide a clear sentence explaining WHY the app needs this access.",
                    args: ["key": key, "permission": permission]
                ))
            } else if Self.placeholders.contains(value.lowercased()) || value.count < 10 {
                findings.append(Finding(
                    id: "A.usage.placeholder.\(key)",
                    code: "usage.placeholder",
                    severity: .warning,
                    category: .a,
                    guideline: "5.1.1",
                    title: "\(permission): suspicious description",
                    message: "The value \"\(value)\" of \(key) looks like a placeholder or is too short.",
                    fix: "Describe the real usage, focused on user benefit (e.g. \"To scan your receipts\").",
                    args: ["key": key, "permission": permission, "value": value]
                ))
            }
        }
        return findings
    }
}

/// Flags an empty `NSUserTrackingUsageDescription` (App Store §5.1.2).
public struct TrackingUsageCheck: Check {
    public init() {}

    public func run(_ facts: BuildFacts) -> [Finding] {
        guard let value = facts.usageDescriptions["NSUserTrackingUsageDescription"] else {
            return []
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return []
        }
        return [Finding(
            id: "A.tracking.empty",
            code: "tracking.empty",
            severity: .error,
            category: .a,
            guideline: "5.1.2",
            title: "Tracking: empty description",
            message: "NSUserTrackingUsageDescription is present but empty. The ATT prompt requires text.",
            fix: "Explain why you request tracking permission (e.g. \"To measure the effectiveness of our ads\")."
        )]
    }
}

/// Flags tracking declared in a privacy manifest without an ATT prompt string (App Store §5.1.2).
public struct TrackingATTCheck: Check {
    public init() {}

    public func run(_ facts: BuildFacts) -> [Finding] {
        guard facts.declaresTracking else { return [] }
        let att = (facts.usageDescriptions["NSUserTrackingUsageDescription"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !att.isEmpty {
            return []
        }
        return [Finding(
            id: "C.tracking.noATT",
            code: "tracking.noATT",
            severity: .error,
            category: .c,
            guideline: "5.1.2",
            title: "Tracking declared without ATT prompt",
            message: "A privacy manifest declares tracking (NSPrivacyTracking) but the app has no NSUserTrackingUsageDescription. Tracking the user without asking permission (ATT) = rejection.",
            fix: "Add NSUserTrackingUsageDescription and call ATTrackingManager, or disable tracking in the SDK concerned."
        )]
    }
}
