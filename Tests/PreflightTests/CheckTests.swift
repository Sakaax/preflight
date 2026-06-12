import Foundation
import Testing
@testable import Preflight

@Suite("Checks")
struct CheckTests {

    // MARK: UsageStringCheck

    @Test("Empty usage string -> one error usage.empty")
    func emptyUsageString() {
        let facts = BuildFacts(format: .ipa, usageDescriptions: ["NSCameraUsageDescription": ""])
        let findings = UsageStringCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "usage.empty")
        #expect(findings[0].severity == .error)
        #expect(findings[0].id == "A.usage.empty.NSCameraUsageDescription")
    }

    @Test("Placeholder / short value -> usage.placeholder warning")
    func placeholderUsageString() {
        let facts = BuildFacts(format: .ipa, usageDescriptions: ["NSCameraUsageDescription": "TODO"])
        let findings = UsageStringCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "usage.placeholder")
        #expect(findings[0].severity == .warning)
    }

    @Test("Short value -> usage.placeholder warning")
    func shortUsageString() {
        let facts = BuildFacts(format: .ipa, usageDescriptions: ["NSCameraUsageDescription": "scan"])
        let findings = UsageStringCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "usage.placeholder")
    }

    @Test("Good long description -> no finding")
    func goodUsageString() {
        let facts = BuildFacts(
            format: .ipa,
            usageDescriptions: ["NSCameraUsageDescription": "To scan your receipts and attach them to expenses."]
        )
        let findings = UsageStringCheck().run(facts)
        #expect(findings.isEmpty)
    }

    // MARK: PrivacyManifestCheck

    @Test("Missing root manifest -> privacy.missing warning")
    func missingPrivacyManifest() {
        let facts = BuildFacts(format: .ipa, hasRootPrivacyManifest: false)
        let findings = PrivacyManifestCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "privacy.missing")
        #expect(findings[0].severity == .warning)
    }

    @Test("Present root manifest -> no finding")
    func presentPrivacyManifest() {
        let facts = BuildFacts(format: .ipa, hasRootPrivacyManifest: true)
        let findings = PrivacyManifestCheck().run(facts)
        #expect(findings.isEmpty)
    }

    // MARK: EncryptionComplianceCheck

    @Test("Missing encryption key -> encryption.missing info")
    func missingEncryptionKey() {
        let facts = BuildFacts(format: .ipa, hasEncryptionComplianceKey: false)
        let findings = EncryptionComplianceCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "encryption.missing")
        #expect(findings[0].severity == .info)
    }

    @Test("Present encryption key -> no finding")
    func presentEncryptionKey() {
        let facts = BuildFacts(format: .ipa, hasEncryptionComplianceKey: true)
        let findings = EncryptionComplianceCheck().run(facts)
        #expect(findings.isEmpty)
    }

    // MARK: TrackingUsageCheck

    @Test("Empty NSUserTrackingUsageDescription -> tracking.empty error")
    func emptyTrackingUsage() {
        let facts = BuildFacts(format: .ipa, usageDescriptions: ["NSUserTrackingUsageDescription": "  "])
        let findings = TrackingUsageCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "tracking.empty")
        #expect(findings[0].severity == .error)
    }

    // MARK: TrackingATTCheck

    @Test("declaresTracking + no ATT string -> tracking.noATT error in category C")
    func trackingWithoutATT() {
        let facts = BuildFacts(format: .ipa, declaresTracking: true)
        let findings = TrackingATTCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "tracking.noATT")
        #expect(findings[0].severity == .error)
        #expect(findings[0].category == .c)
    }

    @Test("declaresTracking + ATT string present -> no finding")
    func trackingWithATT() {
        let facts = BuildFacts(
            format: .ipa,
            usageDescriptions: ["NSUserTrackingUsageDescription": "To measure ad effectiveness."],
            declaresTracking: true
        )
        let findings = TrackingATTCheck().run(facts)
        #expect(findings.isEmpty)
    }

    // MARK: CollectedDataCheck

    @Test("collectedDataTypes non-empty -> collectedData.declare, informative wording")
    func collectedDataInformative() {
        let facts = BuildFacts(
            format: .ipa,
            collectedDataTypes: ["NSPrivacyCollectedDataTypePurchaseHistory"]
        )
        let findings = CollectedDataCheck().run(facts)
        #expect(findings.count == 1)
        #expect(findings[0].code == "collectedData.declare")
        // Informative, never affirmative about ASC labels.
        #expect(findings[0].message.contains("embeds"))
        #expect(!findings[0].message.contains("missing from"))
    }

    // MARK: Engine sort order

    @Test("Engine sorts errors before warnings before info")
    func engineSortOrder() {
        let facts = BuildFacts(
            format: .ipa,
            usageDescriptions: ["NSCameraUsageDescription": ""], // error
            hasRootPrivacyManifest: false,                       // warning
            hasEncryptionComplianceKey: false                    // info
        )
        let findings = CheckEngine.buildOnly.run(facts)
        // Ensure non-decreasing severity raw values.
        let severities = findings.map { $0.severity.rawValue }
        #expect(severities == severities.sorted())
        // Must contain at least one of each kind.
        #expect(findings.contains { $0.severity == .error })
        #expect(findings.contains { $0.severity == .warning })
        #expect(findings.contains { $0.severity == .info })
        // First finding is an error.
        #expect(findings.first?.severity == .error)
    }
}
