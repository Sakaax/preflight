import Foundation
import Testing
@testable import Preflight

@Suite("Parser")
struct ParserTests {

    /// Builds a synthetic `.xcarchive` on disk and returns its URL plus the
    /// `Payload` directory (for optional `.ipa` zipping) and the temp root to clean.
    private func makeSyntheticArchive() throws -> (archive: URL, payload: URL, tempRoot: URL) {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory
            .appendingPathComponent("preflight-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        // .xcarchive/Products/Applications/Test.app
        let archive = tempRoot.appendingPathComponent("Test.xcarchive", isDirectory: true)
        let appsDir = archive
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
        let appURL = appsDir.appendingPathComponent("Test.app", isDirectory: true)
        try fm.createDirectory(at: appURL, withIntermediateDirectories: true)

        // Info.plist (camera usage empty, no encryption key).
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.example.test",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42",
            "CFBundleDisplayName": "Test App",
            "NSCameraUsageDescription": "",
        ]
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0
        )
        try infoData.write(to: appURL.appendingPathComponent("Info.plist"))

        // Root PrivacyInfo.xcprivacy with tracking + collected data type.
        let manifest: [String: Any] = [
            "NSPrivacyTracking": true,
            "NSPrivacyTrackingDomains": ["tracker.example.com"],
            "NSPrivacyCollectedDataTypes": [
                ["NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypePurchaseHistory"]
            ],
        ]
        let manifestData = try PropertyListSerialization.data(
            fromPropertyList: manifest, format: .xml, options: 0
        )
        try manifestData.write(to: appURL.appendingPathComponent("PrivacyInfo.xcprivacy"))

        // Frameworks/Foo.framework (empty dir).
        let fooFramework = appURL
            .appendingPathComponent("Frameworks", isDirectory: true)
            .appendingPathComponent("Foo.framework", isDirectory: true)
        try fm.createDirectory(at: fooFramework, withIntermediateDirectories: true)

        // Payload/Test.app mirror for .ipa zipping.
        let payload = tempRoot.appendingPathComponent("Payload", isDirectory: true)
        let payloadApp = payload.appendingPathComponent("Test.app", isDirectory: true)
        try fm.createDirectory(at: payloadApp.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: appURL, to: payloadApp)

        return (archive, payload, tempRoot)
    }

    @Test("Parses a synthetic .xcarchive")
    func parseXcarchive() throws {
        let (archive, _, tempRoot) = try makeSyntheticArchive()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let facts = BuildParser.parse(at: archive, format: .xcarchive)

        #expect(facts.format == .xcarchive)
        #expect(facts.bundleId == "com.example.test")
        #expect(facts.shortVersion == "1.2.3")
        #expect(facts.buildNumber == "42")
        #expect(facts.appName == "Test App")
        #expect(facts.hasRootPrivacyManifest == true)
        #expect(facts.declaresTracking == true)
        #expect(!facts.collectedDataTypes.isEmpty)
        #expect(facts.usageDescriptions["NSCameraUsageDescription"] != nil)
        #expect(facts.hasEncryptionComplianceKey == false)
        #expect(facts.trackingDomains == ["tracker.example.com"])
    }

    @Test("Parses a synthetic .ipa via DittoExtractor")
    func parseIPA() throws {
        let (_, payload, tempRoot) = try makeSyntheticArchive()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        #if os(macOS)
        let fm = FileManager.default
        // Guard: skip gracefully if ditto is unavailable.
        guard fm.fileExists(atPath: "/usr/bin/ditto") else { return }

        // Zip Payload/ into Test.ipa using ditto (mirrors how Xcode packages .ipa).
        // A real .ipa has `Payload/` at the zip root, so we zip the directory that
        // CONTAINS Payload, taking its contents as the archive root.
        let stage = tempRoot.appendingPathComponent("stage", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        try fm.copyItem(at: payload, to: stage.appendingPathComponent("Payload", isDirectory: true))

        let ipaURL = tempRoot.appendingPathComponent("Test.ipa")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-c", "-k", "--sequesterRsrc", stage.path, ipaURL.path]
        do {
            try zip.run()
        } catch {
            return // ditto failed to launch; skip gracefully
        }
        zip.waitUntilExit()
        guard zip.terminationStatus == 0 else { return }

        let facts = BuildParser.parse(at: ipaURL, format: .ipa)
        #expect(facts.format == .ipa)
        #expect(facts.parseNote == nil)
        #expect(facts.bundleId == "com.example.test")
        #expect(facts.declaresTracking == true)
        #expect(facts.usageDescriptions["NSCameraUsageDescription"] != nil)
        #endif
    }
}
