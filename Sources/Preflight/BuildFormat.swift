import Foundation

/// The format of an iOS build artifact.
public enum BuildFormat: String, Codable, Sendable {
    case ipa
    case xcarchive

    /// Infers the build format from a file URL.
    ///
    /// Returns `.xcarchive` if and only if the path extension (lowercased) is
    /// `"xcarchive"`; otherwise `.ipa`.
    public static func infer(from url: URL) -> BuildFormat {
        url.pathExtension.lowercased() == "xcarchive" ? .xcarchive : .ipa
    }
}
