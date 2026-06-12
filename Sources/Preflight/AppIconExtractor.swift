import Foundation

#if canImport(ImageIO)
import ImageIO
import CoreGraphics
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif
#endif

/// Extracts the app icon from an `.app` bundle as standard PNG data.
///
/// This is the only macOS/ImageIO-specific part of the library. On platforms
/// without ImageIO it returns `nil`.
public enum AppIconExtractor {
    /// Returns standard-PNG-encoded data for the largest `AppIcon*.png` at the
    /// app bundle root, or `nil` if none is found or ImageIO is unavailable.
    public static func iconPNG(fromApp appURL: URL) -> Data? {
        #if canImport(ImageIO)
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: appURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        // Candidate icon files: AppIcon*.png at the app root.
        let candidates = entries.filter { url in
            let name = url.lastPathComponent
            return name.lowercased().hasPrefix("appicon") && url.pathExtension.lowercased() == "png"
        }
        guard !candidates.isEmpty else { return nil }

        // Pick the candidate with the largest pixel width.
        var best: (url: URL, width: Int)?
        for url in candidates {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = props[kCGImagePropertyPixelWidth] as? Int
            else { continue }
            if best == nil || width > best!.width {
                best = (url, width)
            }
        }

        guard let chosen = best,
              let source = CGImageSourceCreateWithURL(chosen.url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        // Re-encode to standard PNG.
        let pngType: CFString
        #if canImport(UniformTypeIdentifiers)
        pngType = UTType.png.identifier as CFString
        #else
        pngType = "public.png" as CFString
        #endif

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, pngType, 1, nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
        #else
        return nil
        #endif
    }
}
