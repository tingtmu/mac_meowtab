import CoreGraphics
import ImageIO
import XCTest

/// Pins `MeowTabStore`: the `meowtab.*` keys, what `load()` accepts and reports, and that the picture folder is
/// only ever touched through MeowTab's own `<mood>-<UUID>.png` names. Each test runs on a temporary preferences
/// suite and a temporary folder, and `tearDown` checks that `UserDefaults.standard` got no `meowtab.*` key. See
/// the `peek-settings` spec under openspec/.
///
/// Groups: A loading · B saving settings · C pictures · D cleanup · E safety.
final class MeowTabStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var root: URL!
    private var folder: URL!
    private var store: MeowTabStore!

    override func setUpWithError() throws {
        suiteName = "meowtab-tests-\(UUID().uuidString)"
        defaults = TestDefaults.make(suiteName)
        root = FileManager.default.temporaryDirectory.appendingPathComponent("meowtab-store-tests-\(UUID().uuidString)")
        folder = root.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = MeowTabStore(defaults: defaults, folder: folder)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: root)
        TestDefaults.tearDown(defaults, suiteName)
        // The `peek-settings` requirement "Tests leave real data alone".
        let leaked = meowtabKeys(in: UserDefaults.standard)
        XCTAssertTrue(leaked.isEmpty, "UserDefaults.standard got \(leaked)")
    }

    // MARK: - A. Loading

    func testEmptyStorageGivesTheDefaults() {
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, MoodSettings.defaults)
        XCTAssertEqual(loaded.warnings, [])
        for mood in Mood.allCases {
            XCTAssertNil(store.pictureURL(mood))
        }
        XCTAssertEqual(meowtabKeys(in: defaults), [], "load() must not write")
    }

    /// The `peek-settings` scenario "Hand-edited invalid values": thresholds 9 and 5 fall back to 3 and 8, and
    /// the valid shares are kept.
    func testReversedThresholdsFallBackAndTheSharesAreKept() {
        defaults.set(9, forKey: "meowtab.someFrom")
        defaults.set(5, forKey: "meowtab.manyFrom")
        defaults.set(0.5, forKey: "meowtab.minShare")
        defaults.set(0.9, forKey: "meowtab.maxShare")

        let loaded = store.load()

        XCTAssertEqual(loaded.settings, MoodSettings(someFrom: 3, manyFrom: 8, minShare: 0.5, maxShare: 0.9))
        XCTAssertEqual(loaded.warnings, [MeowTabStore.invalidSettingsWarning])
        XCTAssertEqual(defaults.object(forKey: "meowtab.someFrom") as? Int, 9, "load() must not write")
    }

    func testAValueOfTheWrongTypeFallsBackToTheDefaults() {
        defaults.set("abc", forKey: "meowtab.someFrom")

        let loaded = store.load()

        XCTAssertEqual(loaded.settings, MoodSettings.defaults)
        XCTAssertEqual(loaded.warnings, [MeowTabStore.invalidSettingsWarning])
    }

    /// The spec says invalid values "fall back to the defaults for that pair": a wrong type invalidates its
    /// whole pair, as an out-of-range value does, and leaves the other pair alone.
    func testAValueOfTheWrongTypeResetsItsWholePair() {
        defaults.set("abc", forKey: "meowtab.someFrom")
        defaults.set(20, forKey: "meowtab.manyFrom")
        defaults.set(0.5, forKey: "meowtab.minShare")
        defaults.set(0.9, forKey: "meowtab.maxShare")

        XCTAssertEqual(store.load().settings, MoodSettings(someFrom: 3, manyFrom: 8, minShare: 0.5, maxShare: 0.9))
    }

    func testAPictureNameOutsideTheFolderIsRefused() {
        defaults.set("../evil.png", forKey: "meowtab.picture.few")

        XCTAssertNil(store.pictureURL(Mood.few))
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, MoodSettings.defaults)
        XCTAssertEqual(loaded.warnings, [MeowTabStore.invalidSettingsWarning])
    }

    /// A well-formed name only counts under its own mood's key.
    func testAPictureNameOfAnotherMoodIsRefused() {
        defaults.set("many-\(UUID().uuidString).png", forKey: "meowtab.picture.few")

        XCTAssertNil(store.pictureURL(Mood.few))
        XCTAssertEqual(store.load().warnings, [MeowTabStore.invalidSettingsWarning])
    }

    // MARK: - B. Saving settings

    func testSavedSettingsLoadBack() {
        let settings = MoodSettings(someFrom: 4, manyFrom: 12, minShare: 0.6, maxShare: 0.9)

        store.save(settings)

        XCTAssertEqual(defaults.object(forKey: "meowtab.someFrom") as? Int, 4)
        XCTAssertEqual(defaults.object(forKey: "meowtab.manyFrom") as? Int, 12)
        XCTAssertEqual(defaults.object(forKey: "meowtab.minShare") as? Double, 0.6)
        XCTAssertEqual(defaults.object(forKey: "meowtab.maxShare") as? Double, 0.9)
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, settings)
        XCTAssertEqual(loaded.warnings, [])
    }

    // MARK: - C. Pictures

    /// The key names a file in the folder that holds the data, and a second picture deletes the first file.
    func testSettingAPictureStoresItInTheFolder() throws {
        XCTAssertFalse(exists(folder))
        let first = Data("first".utf8)
        try store.setPicture(first, for: Mood.some)

        let name = try XCTUnwrap(defaults.object(forKey: "meowtab.picture.some") as? String)
        XCTAssertTrue(name.hasPrefix("some-"))
        XCTAssertTrue(name.hasSuffix(".png"))
        let firstFile = folder.appendingPathComponent(name)
        XCTAssertEqual(try Data(contentsOf: firstFile), first)
        XCTAssertEqual(store.pictureURL(Mood.some)?.lastPathComponent, name)
        XCTAssertEqual(store.load().warnings, [])

        let second = Data("second".utf8)
        try store.setPicture(second, for: Mood.some)

        let newName = try XCTUnwrap(defaults.object(forKey: "meowtab.picture.some") as? String)
        XCTAssertNotEqual(newName, name)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(newName)), second)
        XCTAssertFalse(exists(firstFile))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [newName])
    }

    /// The `peek-settings` scenario "Saving fails": the folder can't be written, so the previous key and file stay.
    func testAFailedSaveKeepsThePreviousPicture() throws {
        let original = Data("original".utf8)
        try store.setPicture(original, for: Mood.few)
        let name = try XCTUnwrap(defaults.object(forKey: "meowtab.picture.few") as? String)

        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.path)
        XCTAssertThrowsError(try store.setPicture(Data("replacement".utf8), for: Mood.few))
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)

        XCTAssertEqual(defaults.object(forKey: "meowtab.picture.few") as? String, name)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(name)), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [name])
    }

    /// The `peek-settings` scenario "Original moved": the stored copy still loads once its source is gone.
    func testTheStoredCopyOutlivesTheImportedFile() throws {
        let source = root.appendingPathComponent("source.png")
        try writeSourcePNG(to: source)
        let picture = try PeekPicture.load(url: source)
        let png = try XCTUnwrap(picture.pngData())

        try store.setPicture(png, for: Mood.many)
        try FileManager.default.removeItem(at: source)

        let copy = try XCTUnwrap(store.pictureURL(Mood.many))
        let reloaded = try PeekPicture.load(url: copy)
        XCTAssertEqual(reloaded.pixelWidth, picture.pixelWidth)
        XCTAssertEqual(reloaded.pixelHeight, picture.pixelHeight)
    }

    // MARK: - D. Cleanup

    /// The `peek-settings` scenario "Back to the shipped cat", with another mood and the settings left alone.
    func testUseDefaultRemovesOnlyThatMoodsPicture() throws {
        let custom = MoodSettings(someFrom: 4, manyFrom: 9, minShare: 0.5, maxShare: 0.7)
        store.save(custom)
        try store.setPicture(Data("few".utf8), for: Mood.few)
        try store.setPicture(Data("many".utf8), for: Mood.many)
        let fewFile = try XCTUnwrap(store.pictureURL(Mood.few))
        let manyFile = try XCTUnwrap(store.pictureURL(Mood.many))

        store.clearPicture(Mood.many)

        XCTAssertNil(defaults.object(forKey: "meowtab.picture.many"))
        XCTAssertNil(store.pictureURL(Mood.many))
        XCTAssertFalse(exists(manyFile))
        XCTAssertEqual(store.pictureURL(Mood.few), fewFile)
        XCTAssertTrue(exists(fewFile))
        XCTAssertEqual(store.load().settings, custom)
    }

    /// The `peek-settings` scenario "Restore defaults": MeowTab's keys and picture files go, nothing else does.
    func testRestoreDefaultsRemovesOnlyMeowTabsData() throws {
        store.save(MoodSettings(someFrom: 4, manyFrom: 9, minShare: 0.5, maxShare: 0.7))
        try store.setPicture(Data("few".utf8), for: Mood.few)
        try store.setPicture(Data("some".utf8), for: Mood.some)
        try write("unreferenced", to: folder.appendingPathComponent("many-\(UUID().uuidString).png"))
        try write("notes", to: folder.appendingPathComponent("notes.txt"))
        try write("not ours", to: folder.appendingPathComponent("few-not-a-uuid.png"))
        defaults.set("kept", forKey: "other.setting")

        store.restoreDefaults()

        XCTAssertEqual(meowtabKeys(in: defaults), [])
        let loaded = store.load()
        XCTAssertEqual(loaded.settings, MoodSettings.defaults)
        XCTAssertEqual(loaded.warnings, [])
        for mood in Mood.allCases {
            XCTAssertNil(store.pictureURL(mood))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(),
                       ["few-not-a-uuid.png", "notes.txt"])
        XCTAssertEqual(defaults.object(forKey: "other.setting") as? String, "kept")
    }

    /// Only a name that matches `<mood>-<UUID>.png` exactly, with an uppercase UUID, is ever deleted.
    func testRemoveOrphansDeletesOnlyUnreferencedPictures() throws {
        try store.setPicture(Data("few".utf8), for: Mood.few)
        let referenced = try XCTUnwrap(store.pictureURL(Mood.few))
        let orphan = folder.appendingPathComponent("some-\(UUID().uuidString).png")
        let notes = folder.appendingPathComponent("notes.txt")
        let notAUUID = folder.appendingPathComponent("few-not-a-uuid.png")
        let lowercase = folder.appendingPathComponent("many-abcdef01-2345-6789-abcd-ef0123456789.png")
        for url in [orphan, notes, notAUUID, lowercase] {
            try write("x", to: url)
        }

        store.removeOrphans()

        XCTAssertFalse(exists(orphan))
        XCTAssertTrue(exists(referenced))
        XCTAssertTrue(exists(notes))
        XCTAssertTrue(exists(notAUUID))
        XCTAssertTrue(exists(lowercase))
    }

    func testRemoveOrphansWithoutAFolderDoesNothing() {
        store.removeOrphans()

        XCTAssertFalse(exists(folder))
    }

    // MARK: - E. Safety

    /// A hand-edited key such as `../outside.png` must never lead to a file outside the folder being deleted.
    func testAKeyPointingOutsideTheFolderIsNeverDeleted() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let outside = root.appendingPathComponent("outside.png")
        try write("keep me", to: outside)

        defaults.set("../outside.png", forKey: "meowtab.picture.few")
        store.clearPicture(Mood.few)
        XCTAssertTrue(exists(outside), "clearPicture")

        defaults.set("../outside.png", forKey: "meowtab.picture.few")
        try store.setPicture(Data("new".utf8), for: Mood.few)
        XCTAssertTrue(exists(outside), "setPicture")

        defaults.set("../outside.png", forKey: "meowtab.picture.few")
        store.removeOrphans()
        XCTAssertTrue(exists(outside), "removeOrphans")

        defaults.set("../outside.png", forKey: "meowtab.picture.few")
        store.restoreDefaults()
        XCTAssertTrue(exists(outside), "restoreDefaults")
    }

    // MARK: - Helpers

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    private func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url)
    }

    private func meowtabKeys(in userDefaults: UserDefaults) -> [String] {
        userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("meowtab.") }.sorted()
    }

    /// A 64x64 PNG, transparent except for an opaque square in the middle.
    private func writeSourcePNG(to url: URL) throws {
        let context = try XCTUnwrap(CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0.5, blue: 0, alpha: 1)
        context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
