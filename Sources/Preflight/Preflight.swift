import Foundation

/// Top-level entry point for Preflight.
///
/// Preflight opens an iOS build artifact, extracts structured `BuildFacts`, and
/// runs deterministic build-only `Check`s. 100% local: no network, no App Store
/// Connect, no AI, no licensing.
public enum Preflight {
    /// The Preflight library version.
    public static let version = "1.0.0"

    /// Parses the build at `url` and runs the standard build-only checks.
    ///
    /// - Parameters:
    ///   - url: The `.ipa` or `.xcarchive` URL.
    ///   - format: Override the format. If `nil`, inferred from `url`.
    /// - Returns: The extracted facts and the sorted findings.
    public static func inspect(
        at url: URL,
        format: BuildFormat? = nil
    ) -> (facts: BuildFacts, findings: [Finding]) {
        let facts = BuildParser.parse(at: url, format: format)
        let findings = CheckEngine.buildOnly.run(facts)
        return (facts, findings)
    }
}
