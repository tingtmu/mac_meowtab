import CoreGraphics
import Foundation
import ImageIO

/// A mood picture, decoded into one pixel layout and measured.
struct PeekPicture {
    enum LoadError: Error, Equatable { case tooBig, unreadable, notPNG, animated, tooLarge, empty }

    /// 10 MB, as the import message says and Finder counts.
    private static let maxImportBytes = 10_000_000
    private static let maxImportSide = 8192
    private static let maxImportPixels = 32_000_000
    /// The last chunk of every PNG: a length of 0, "IEND", and the CRC of "IEND".
    private static let pngEnd = Data([0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])

    /// sRGB, 8 bits per component, premultiplied alpha last.
    let image: CGImage
    let pixelWidth: Int
    let pixelHeight: Int
    /// The first row, from the top, with any alpha above `MoodPeek.artAlpha`.
    let artTop: Int
    /// One past the last such row.
    let artBottom: Int

    /// Checks the file against the import limits in order, and stops at the first failure. No pixel is decoded
    /// until the limits have passed.
    static func load(url: URL) throws -> PeekPicture {
        // a symlink's own size is its path's length, so measure what it points to
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path),
              let bytes = (attributes[.size] as? NSNumber)?.intValue else { throw LoadError.unreadable }
        if bytes > maxImportBytes { throw LoadError.tooBig }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw LoadError.unreadable
        }
        guard let uti = CGImageSourceGetType(source), (uti as String) == "public.png" else { throw LoadError.notPNG }
        let frames = CGImageSourceGetCount(source)
        if frames > 1 { throw LoadError.animated }
        // a truncated file can report no images
        if frames == 0 { throw LoadError.unreadable }
        guard let size = pixelSize(of: source) else { throw LoadError.unreadable }
        if size.width > maxImportSide || size.height > maxImportSide || size.width * size.height > maxImportPixels {
            throw LoadError.tooLarge
        }
        guard hasPNGEnd(url), let decoded = decode(source, longestSide: max(size.width, size.height)) else {
            throw LoadError.unreadable
        }
        return try normalized(decoded)
    }

    /// The picture as PNG, or nil if encoding fails.
    func pngData() -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as NSDictionary?,
              let width = (properties.object(forKey: kCGImagePropertyPixelWidth) as? NSNumber)?.intValue,
              let height = (properties.object(forKey: kCGImagePropertyPixelHeight) as? NSNumber)?.intValue else { return nil }
        return (width, height)
    }

    /// A cut-short PNG can decode into a partly blank picture, and a whole one holds its IEND chunk. ImageIO's
    /// status can't tell: WebKit's ImageDecoderCG notes that `CGImageSourceGetStatusAtIndex` is inaccurate for
    /// a still image's only frame.
    private static func hasPNGEnd(_ url: URL) -> Bool {
        guard let file = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
        return file.range(of: pngEnd, options: .backwards) != nil
    }

    private static func decode(_ source: CGImageSource, longestSide: Int) -> CGImage? {
        guard longestSide > MoodPeek.maxSide else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: MoodPeek.maxSide,
            kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Redraws into one pixel layout, which is what the art scan and `pngData()` rely on.
    private static func normalized(_ decoded: CGImage) throws -> PeekPicture {
        let width = decoded.width
        let height = decoded.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw LoadError.unreadable
        }
        context.draw(decoded, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw LoadError.unreadable }
        let span = try artSpan(of: context)
        return PeekPicture(image: image, pixelWidth: width, pixelHeight: height, artTop: span.top, artBottom: span.bottom)
    }

    /// The first row with any alpha above `MoodPeek.artAlpha`, and one past the last. Row 0 of the context's buffer
    /// is the top row.
    private static func artSpan(of context: CGContext) throws -> (top: Int, bottom: Int) {
        guard let data = context.data else { throw LoadError.unreadable }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = context.bytesPerRow
        let width = context.width
        let threshold = MoodPeek.artAlpha
        // alpha is byte 3 of each 4-byte pixel
        func hasArt(_ row: Int) -> Bool {
            let start = row * rowBytes
            return stride(from: start + 3, to: start + 4 * width, by: 4).contains { pixels[$0] > threshold }
        }
        let rows = 0..<context.height
        guard let top = rows.first(where: hasArt), let last = rows.last(where: hasArt) else { throw LoadError.empty }
        return (top, last + 1)
    }
}
