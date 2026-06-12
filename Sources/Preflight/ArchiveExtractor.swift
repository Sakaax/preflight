import Foundation

/// Abstracts unzipping an archive (e.g. an `.ipa`) into a destination directory.
///
/// This is the single platform seam in Preflight. The macOS implementation
/// (`DittoExtractor`) shells out to `/usr/bin/ditto`. A Linux implementation can
/// be swapped in without touching the rest of the library.
public protocol ArchiveExtractor: Sendable {
    func extract(_ archive: URL, to destination: URL) throws
}

/// Errors thrown while extracting an archive.
public enum ArchiveExtractionError: Error {
    /// The extractor process could not be launched.
    case launchFailed
    /// The archive could not be read (non-zero extractor exit status).
    case badArchive
}

/// macOS archive extractor backed by `/usr/bin/ditto -x -k`.
public struct DittoExtractor: ArchiveExtractor {
    public init() {}

    public func extract(_ archive: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, destination.path]

        do {
            try process.run()
        } catch {
            throw ArchiveExtractionError.launchFailed
        }
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ArchiveExtractionError.badArchive
        }
    }
}
