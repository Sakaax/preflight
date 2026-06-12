import Foundation

/// Structured, deterministic facts extracted from an iOS build artifact.
///
/// Every field is derived purely by reading files inside the build — no network,
/// no App Store Connect, no execution of the binary.
public struct BuildFacts: Equatable, Codable, Sendable {
    /// The build format the facts were extracted from.
    public var format: BuildFormat

    /// `CFBundleIdentifier` from the app's `Info.plist`.
    public var bundleId: String?
    /// `CFBundleDisplayName` falling back to `CFBundleName`.
    public var appName: String?
    /// `CFBundleShortVersionString` (marketing version).
    public var shortVersion: String?
    /// `CFBundleVersion` (build number).
    public var buildNumber: String?
    /// `MinimumOSVersion`.
    public var minimumOSVersion: String?

    /// Every `*UsageDescription` key mapped to its string value (empty string if non-string).
    public var usageDescriptions: [String: String]

    /// Relative paths (to the app root) of every `PrivacyInfo.xcprivacy` found.
    public var privacyManifestPaths: [String]
    /// Whether a `PrivacyInfo.xcprivacy` exists at the app root.
    public var hasRootPrivacyManifest: Bool

    /// Whether any privacy manifest declares `NSPrivacyTracking == true`.
    public var declaresTracking: Bool
    /// Union of `NSPrivacyTrackingDomains` across all manifests, sorted.
    public var trackingDomains: [String]
    /// Union of declared `NSPrivacyCollectedDataType` values across all manifests, sorted.
    public var collectedDataTypes: [String]

    /// Bundled frameworks/dylibs (lastPathComponent), sorted.
    public var frameworks: [String]

    /// Whether `ITSAppUsesNonExemptEncryption` is present in the `Info.plist`.
    public var hasEncryptionComplianceKey: Bool
    /// The value of `ITSAppUsesNonExemptEncryption`, if present and a Bool.
    public var usesNonExemptEncryption: Bool?

    /// Standard-PNG-encoded app icon data, when icon extraction is requested and possible.
    public var iconData: Data?

    /// A human-readable note describing why parsing failed or was partial, if any.
    public var parseNote: String?

    public init(
        format: BuildFormat,
        bundleId: String? = nil,
        appName: String? = nil,
        shortVersion: String? = nil,
        buildNumber: String? = nil,
        minimumOSVersion: String? = nil,
        usageDescriptions: [String: String] = [:],
        privacyManifestPaths: [String] = [],
        hasRootPrivacyManifest: Bool = false,
        declaresTracking: Bool = false,
        trackingDomains: [String] = [],
        collectedDataTypes: [String] = [],
        frameworks: [String] = [],
        hasEncryptionComplianceKey: Bool = false,
        usesNonExemptEncryption: Bool? = nil,
        iconData: Data? = nil,
        parseNote: String? = nil
    ) {
        self.format = format
        self.bundleId = bundleId
        self.appName = appName
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
        self.minimumOSVersion = minimumOSVersion
        self.usageDescriptions = usageDescriptions
        self.privacyManifestPaths = privacyManifestPaths
        self.hasRootPrivacyManifest = hasRootPrivacyManifest
        self.declaresTracking = declaresTracking
        self.trackingDomains = trackingDomains
        self.collectedDataTypes = collectedDataTypes
        self.frameworks = frameworks
        self.hasEncryptionComplianceKey = hasEncryptionComplianceKey
        self.usesNonExemptEncryption = usesNonExemptEncryption
        self.iconData = iconData
        self.parseNote = parseNote
    }
}
