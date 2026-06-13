import Foundation
import ZIPFoundation

/// Abstracts unzipping an archive (e.g. an `.ipa`) into a destination directory.
///
/// This is the single platform seam in Preflight. The default implementation
/// (`ZipExtractor`) is cross-platform (macOS + Linux), backed by ZIPFoundation
/// (pure Swift). An alternate implementation can be swapped in without touching
/// the rest of the library.
public protocol ArchiveExtractor: Sendable {
    func extract(_ archive: URL, to destination: URL) throws
}

/// Errors thrown while extracting an archive.
public enum ArchiveExtractionError: Error {
    /// The archive could not be extracted.
    case extractionFailed
}

/// Cross-platform archive extractor (macOS + Linux) backed by ZIPFoundation.
public struct ZipExtractor: ArchiveExtractor {
    public init() {}

    public func extract(_ archive: URL, to destination: URL) throws {
        do {
            try FileManager.default.unzipItem(at: archive, to: destination)
        } catch {
            throw ArchiveExtractionError.extractionFailed
        }
    }
}
