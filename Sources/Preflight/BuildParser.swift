import Foundation

/// Parses an iOS build artifact (`.ipa` or `.xcarchive`) into `BuildFacts`.
///
/// 100% local: reads files only, never executes the binary, never touches the
/// network. The only platform-specific seam is `ArchiveExtractor` (for `.ipa`)
/// and optional icon extraction (`extractIcon`).
public enum BuildParser {
    /// Parses the build at `url`.
    ///
    /// - Parameters:
    ///   - url: The `.ipa` or `.xcarchive` URL.
    ///   - format: Override the format. If `nil`, inferred from `url`.
    ///   - extractor: Used to unzip `.ipa` archives. Defaults to `DittoExtractor`.
    ///   - extractIcon: Whether to extract the app icon (macOS/ImageIO only).
    /// - Returns: Extracted `BuildFacts`. On failure, a minimal facts value with `parseNote` set.
    public static func parse(
        at url: URL,
        format: BuildFormat? = nil,
        extractor: ArchiveExtractor = DittoExtractor(),
        extractIcon: Bool = false
    ) -> BuildFacts {
        let resolvedFormat = format ?? BuildFormat.infer(from: url)
        switch resolvedFormat {
        case .xcarchive:
            return parseXcarchive(at: url, extractIcon: extractIcon)
        case .ipa:
            return parseIPA(at: url, extractor: extractor, extractIcon: extractIcon)
        }
    }

    // MARK: - Format handlers

    private static func parseXcarchive(at url: URL, extractIcon: Bool) -> BuildFacts {
        let appsDir = url
            .appendingPathComponent("Products")
            .appendingPathComponent("Applications")
        guard let appURL = firstApp(in: appsDir) else {
            return BuildFacts(format: .xcarchive, parseNote: "No .app found inside Products/Applications.")
        }
        var facts = parseAppBundle(appURL, extractIcon: extractIcon)
        facts.format = .xcarchive
        return facts
    }

    private static func parseIPA(at url: URL, extractor: ArchiveExtractor, extractIcon: Bool) -> BuildFacts {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
            .appendingPathComponent("preflight-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tmp) }

        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            try extractor.extract(url, to: tmp)
        } catch {
            return BuildFacts(format: .ipa, parseNote: "Failed to extract the .ipa archive.")
        }

        let payloadDir = tmp.appendingPathComponent("Payload")
        guard let appURL = firstApp(in: payloadDir) else {
            return BuildFacts(format: .ipa, parseNote: "No .app found inside Payload.")
        }

        var facts = parseAppBundle(appURL, extractIcon: extractIcon)
        facts.format = .ipa
        return facts
    }

    private static func firstApp(in directory: URL) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return entries.first { $0.pathExtension.lowercased() == "app" }
    }

    // MARK: - App bundle parsing

    private static func parseAppBundle(_ appURL: URL, extractIcon: Bool) -> BuildFacts {
        var facts = BuildFacts(format: .ipa) // format overwritten by caller

        // Info.plist
        let infoPlistURL = appURL.appendingPathComponent("Info.plist")
        if let info = readPlist(infoPlistURL) {
            facts.bundleId = info["CFBundleIdentifier"] as? String
            facts.appName = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String)
            facts.shortVersion = info["CFBundleShortVersionString"] as? String
            facts.buildNumber = info["CFBundleVersion"] as? String
            facts.minimumOSVersion = info["MinimumOSVersion"] as? String

            var usage: [String: String] = [:]
            for (key, value) in info where key.hasSuffix("UsageDescription") {
                usage[key] = (value as? String) ?? ""
            }
            facts.usageDescriptions = usage

            if let enc = info["ITSAppUsesNonExemptEncryption"] {
                facts.hasEncryptionComplianceKey = true
                facts.usesNonExemptEncryption = enc as? Bool
            }
        }

        // Root privacy manifest
        let rootManifest = appURL.appendingPathComponent("PrivacyInfo.xcprivacy")
        facts.hasRootPrivacyManifest = FileManager.default.fileExists(atPath: rootManifest.path)

        // All privacy manifests
        let manifestURLs = findPrivacyManifestURLs(under: appURL)
        let appPrefix = appURL.path + "/"
        facts.privacyManifestPaths = manifestURLs
            .map { url -> String in
                if url.path.hasPrefix(appPrefix) {
                    return String(url.path.dropFirst(appPrefix.count))
                }
                return url.path
            }
            .sorted()

        // Aggregate privacy across all manifests
        aggregatePrivacy(from: manifestURLs, into: &facts)

        // Frameworks
        facts.frameworks = listFrameworks(in: appURL)

        // Icon
        if extractIcon {
            facts.iconData = AppIconExtractor.iconPNG(fromApp: appURL)
        }

        return facts
    }

    // MARK: - Helpers

    private static func readPlist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &fmt
        ) else {
            return nil
        }
        return plist as? [String: Any]
    }

    private static func findPrivacyManifestURLs(under appURL: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: appURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        var result: [URL] = []
        for case let url as URL in enumerator where url.lastPathComponent == "PrivacyInfo.xcprivacy" {
            result.append(url)
        }
        return result
    }

    private static func aggregatePrivacy(from manifestURLs: [URL], into facts: inout BuildFacts) {
        var domains = Set<String>()
        var dataTypes = Set<String>()
        for manifestURL in manifestURLs {
            guard let plist = readPlist(manifestURL) else { continue }
            if let tracking = plist["NSPrivacyTracking"] as? Bool, tracking {
                facts.declaresTracking = true
            }
            if let trackingDomains = plist["NSPrivacyTrackingDomains"] as? [String] {
                domains.formUnion(trackingDomains)
            }
            if let collected = plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]] {
                for entry in collected {
                    if let type = entry["NSPrivacyCollectedDataType"] as? String {
                        dataTypes.insert(type)
                    }
                }
            }
        }
        facts.trackingDomains = domains.sorted()
        facts.collectedDataTypes = dataTypes.sorted()
    }

    private static func listFrameworks(in appURL: URL) -> [String] {
        let fm = FileManager.default
        let frameworksDir = appURL.appendingPathComponent("Frameworks")
        guard let entries = try? fm.contentsOfDirectory(
            at: frameworksDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries
            .filter { ["framework", "dylib"].contains($0.pathExtension.lowercased()) }
            .map { $0.lastPathComponent }
            .sorted()
    }
}
