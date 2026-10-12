import CoreGraphics
import ImageIO
import XCTest

/// Every picture is drawn and encoded at run time into a temporary folder; no binary fixtures are committed.
final class PeekPictureTests: XCTestCase {
    private enum FixtureError: Error { case cannotWrite(String) }

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("PeekPictureTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testPaddedPictureIsAcceptedWithItsArtSpan() throws {
        let picture = try PeekPicture.load(url: savePaddedPNG())
        XCTAssertEqual(picture.pixelWidth, 512)
        XCTAssertEqual(picture.pixelHeight, 512)
        XCTAssertLessThanOrEqual(abs(picture.artTop - 100), 1)
        XCTAssertLessThanOrEqual(abs(picture.artBottom - 400), 1)
    }

    func testLargePictureIsScaledDownKeepingItsTransparency() throws {
        let image = try makeImage(width: 2000, height: 1000) { context in
            context.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
            // the top-left corner: y points up
            context.clear(CGRect(x: 0, y: 800, width: 200, height: 200))
        }
        let url = try save([image], type: "public.png", name: "large.png")
        let picture = try PeekPicture.load(url: url)
        XCTAssertEqual(picture.pixelWidth, 1024)
        XCTAssertEqual(picture.pixelHeight, 512)
        XCTAssertEqual(picture.image.width, 1024)
        XCTAssertEqual(picture.image.height, 512)
        XCTAssertEqual(picture.image.alphaInfo, .premultipliedLast)
        XCTAssertEqual(picture.image.bitsPerPixel, 32)
        let corner = try alpha(of: picture.image, x: 0, y: 0)
        let centre = try alpha(of: picture.image, x: 512, y: 256)
        XCTAssertEqual(corner, 0)
        XCTAssertEqual(centre, 255)
    }

    func testJPEGNamedPNGIsNotAcceptedAsPNG() throws {
        let image = try solidImage(alphaInfo: .noneSkipLast)
        let url = try save([image], type: "public.jpeg", name: "cat.png")
        assertLoad(url, fails: .notPNG)
    }

    func testGIFIsNotAcceptedAsPNG() throws {
        let url = try save([solidImage()], type: "com.compuserve.gif", name: "cat.gif")
        assertLoad(url, fails: .notPNG)
    }

    func testTwoFrameAPNGIsAnimated() throws {
        let frames = try [solidImage(green: 0), solidImage(green: 1)]
        let loop: [CFString: Any] = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: 0]]
        let delay: [CFString: Any] = [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: 0.1]]
        let url = try save(frames, type: "public.png", name: "cat.png",
                           fileProperties: loop as CFDictionary, frameProperties: delay as CFDictionary)
        assertLoad(url, fails: .animated)
    }

    func testTruncatedPNGIsUnreadable() throws {
        let data = try Data(contentsOf: savePaddedPNG())
        let url = folder.appendingPathComponent("truncated.png")
        try data.prefix(100).write(to: url)
        assertLoad(url, fails: .unreadable)
    }

    /// A PNG cut just before its end has lost its IEND chunk, but ImageIO may still decode most of it.
    func testPNGCutShortOfItsEndIsUnreadable() throws {
        let data = try Data(contentsOf: savePaddedPNG())
        let url = folder.appendingPathComponent("cut.png")
        try data.dropLast(16).write(to: url)
        assertLoad(url, fails: .unreadable)
    }

    func testFileOverTenMegabytesIsTooBig() throws {
        let url = folder.appendingPathComponent("big.png")
        try Data(count: 10_000_000 + 1).write(to: url)
        assertLoad(url, fails: .tooBig)
    }

    func testPictureOver8192PixelsWideIsTooLarge() throws {
        let image = try makeImage(width: 8200, height: 4)
        let url = try save([image], type: "public.png", name: "wide.png")
        assertLoad(url, fails: .tooLarge)
    }

    func testFullyTransparentPictureIsEmpty() throws {
        let image = try makeImage(width: 64, height: 64)
        let url = try save([image], type: "public.png", name: "clear.png")
        assertLoad(url, fails: .empty)
    }

    func testPNGDataRoundTripKeepsSizeAndArtSpan() throws {
        let original = try PeekPicture.load(url: savePaddedPNG())
        let data = try XCTUnwrap(original.pngData())
        let url = folder.appendingPathComponent("round-trip.png")
        try data.write(to: url)
        let again = try PeekPicture.load(url: url)
        XCTAssertEqual(again.pixelWidth, original.pixelWidth)
        XCTAssertEqual(again.pixelHeight, original.pixelHeight)
        XCTAssertEqual(again.artTop, original.artTop)
        XCTAssertEqual(again.artBottom, original.artBottom)
    }

    // MARK: - Fixtures

    private func assertLoad(_ url: URL, fails expected: PeekPicture.LoadError,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try PeekPicture.load(url: url), file: file, line: line) {
            XCTAssertEqual($0 as? PeekPicture.LoadError, expected, file: file, line: line)
        }
    }

    /// An image that starts out all zeros, with `draw` applied. CoreGraphics' y axis points up, so the edge `row`
    /// rows down from the top of an image `height` tall is at y = height - row.
    private func makeImage(width: Int, height: Int, alphaInfo: CGImageAlphaInfo = .premultipliedLast,
                           draw: (CGContext) -> Void = { _ in }) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space, bitmapInfo: alphaInfo.rawValue))
        draw(context)
        return try XCTUnwrap(context.makeImage())
    }

    private func solidImage(green: CGFloat = 0.5, alphaInfo: CGImageAlphaInfo = .premultipliedLast) throws -> CGImage {
        try makeImage(width: 32, height: 32, alphaInfo: alphaInfo) { context in
            context.setFillColor(red: 1, green: green, blue: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }

    /// 512 x 512 and transparent, with opaque art in rows 100..<400 from the top, which is y 112..<412.
    private func savePaddedPNG() throws -> URL {
        let image = try makeImage(width: 512, height: 512) { context in
            context.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1)
            context.fill(CGRect(x: 100, y: 112, width: 312, height: 300))
        }
        return try save([image], type: "public.png", name: "padded.png")
    }

    /// Encodes with ImageIO as `type`, a UTI, whatever the file's name says.
    private func save(_ images: [CGImage], type: String, name: String,
                      fileProperties: CFDictionary? = nil, frameProperties: CFDictionary? = nil) throws -> URL {
        let url = folder.appendingPathComponent(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, images.count, nil))
        if let fileProperties { CGImageDestinationSetProperties(destination, fileProperties) }
        for image in images { CGImageDestinationAddImage(destination, image, frameProperties) }
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.cannotWrite(name) }
        return url
    }

    /// The alpha of one pixel, for an image with 4 bytes a pixel and alpha last. Row 0 is the top row.
    private func alpha(of image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let data = try XCTUnwrap(image.dataProvider?.data)
        return (data as Data)[y * image.bytesPerRow + x * 4 + 3]
    }
}
