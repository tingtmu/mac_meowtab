import XCTest

/// Pins the peek's rules that need no screen and no picture file: which mood a window count gets, how much of
/// the art rises above the pane, which saved settings are valid, how the settings controls clamp and push each
/// other, and where the picture, the pane and the peek go in a given usable area. See the `mood-peek` and
/// `peek-settings` specs under openspec/.
///
/// Groups: A mood · B share · C validation · D the settings controls · E picture size and height · F box scale
/// and reserve · G the pane · H the peek and the image.
final class MoodPeekTests: XCTestCase {
    private func make(someFrom: Int = 3, manyFrom: Int = 8, minShare: Double = 0.80,
                      maxShare: Double = 0.95) -> MoodSettings {
        MoodSettings(someFrom: someFrom, manyFrom: manyFrom, minShare: minShare, maxShare: maxShare)
    }

    // Picture metrics: a square with art in every row, a square with art only in rows 200-312, and a 2:1 one.
    private let fullArt = PictureMetrics(pixelWidth: 512, pixelHeight: 512, artTop: 0, artBottom: 512)
    private let padded = PictureMetrics(pixelWidth: 512, pixelHeight: 512, artTop: 200, artBottom: 312)
    private let wide = PictureMetrics(pixelWidth: 1024, pixelHeight: 512, artTop: 100, artBottom: 400)
    /// A laptop's usable area with the Dock below it, so its `minY` is not 0.
    private let laptop = CGRect(x: 0, y: 70, width: 1440, height: 805)

    private func everyMood(_ picture: PictureMetrics) -> [Mood: PictureMetrics] {
        [Mood.few: picture, Mood.some: picture, Mood.many: picture]
    }

    private func makeGeometry(_ pictures: [Mood: PictureMetrics], in visibleFrame: CGRect,
                              settings: MoodSettings = MoodSettings.defaults) -> PeekGeometry {
        PeekGeometry(settings: settings, pictures: pictures, visibleFrame: visibleFrame)
    }

    /// A pane as tall as the cap allows, where `paneOrigin` puts it.
    private func paneAtTheCap(_ geometry: PeekGeometry) -> CGRect {
        let padding = CGFloat(20)
        let size = CGSize(width: 1000, height: geometry.maxContentHeight(windowPadding: padding) + 2 * padding)
        return CGRect(origin: geometry.paneOrigin(paneSize: size), size: size)
    }

    func testThereAreThreeMoods() {
        XCTAssertEqual(Mood.allCases.count, 3)
    }

    // MARK: - A. Mood

    func testDefaultThresholdsPickTheMood() {
        let expected: [(Int, Mood?)] = [
            (0, nil), (1, Mood.few), (2, Mood.few), (3, Mood.some),
            (7, Mood.some), (8, Mood.many), (12, Mood.many), (20, Mood.many),
        ]
        for (count, mood) in expected {
            XCTAssertEqual(MoodSettings.defaults.mood(count), mood, "\(count) windows")
        }
    }

    func testCustomThresholdsPickTheMood() {
        let settings = make(someFrom: 2, manyFrom: 4)
        XCTAssertEqual(settings.mood(1), Mood.few)
        XCTAssertEqual(settings.mood(2), Mood.some)
        XCTAssertEqual(settings.mood(4), Mood.many)
    }

    // MARK: - B. Share

    /// The share reaches `maxShare` at `manyFrom + 4` windows (12 by default) and stays there.
    func testShareRisesFromMinShareToMaxShare() {
        let settings = MoodSettings.defaults
        let sixWindows: Double = 0.80 + 0.15 * 5 / 11
        XCTAssertEqual(settings.share(1), 0.80, accuracy: 1e-9)
        XCTAssertEqual(settings.share(6), sixWindows, accuracy: 1e-9)
        XCTAssertEqual(settings.share(12), 0.95, accuracy: 1e-9)
        XCTAssertEqual(settings.share(20), 0.95, accuracy: 1e-9)
    }

    // MARK: - C. Validation

    func testAnInvalidThresholdPairFallsBackAndTheSharesAreKept() {
        for (someFrom, manyFrom) in [(9, 5), (1, 5), (5, 31), (5, 5)] {
            let saved = make(someFrom: someFrom, manyFrom: manyFrom, minShare: 0.50, maxShare: 0.70)
            XCTAssertEqual(saved.validated(), make(minShare: 0.50, maxShare: 0.70),
                           "thresholds \(someFrom), \(manyFrom)")
        }
    }

    func testAnInvalidSharePairFallsBackAndTheThresholdsAreKept() {
        let invalid: [(Double, Double)] = [(0.2, 0.9), (0.9, 0.9), (0.5, 1.1), (0.95, 0.80), (.nan, 0.9)]
        for (minShare, maxShare) in invalid {
            let saved = make(someFrom: 4, manyFrom: 10, minShare: minShare, maxShare: maxShare)
            XCTAssertEqual(saved.validated(), make(someFrom: 4, manyFrom: 10),
                           "shares \(minShare), \(maxShare)")
        }
    }

    /// The defaults, and the tightest and the widest pairs the rules allow.
    func testValidSettingsComeBackUnchanged() {
        let valid = [MoodSettings.defaults,
                     make(someFrom: 2, manyFrom: 3, minShare: 0.30, maxShare: 0.31),
                     make(someFrom: 29, manyFrom: 30, minShare: 0.99, maxShare: 1.00),
                     make(someFrom: 2, manyFrom: 30, minShare: 0.30, maxShare: 1.00)]
        for settings in valid {
            XCTAssertEqual(settings.validated(), settings)
        }
    }

    // MARK: - D. The settings controls

    /// The `peek-settings` scenario: "Many from" is 4 and the user raises "Some from" to 4.
    func testRaisingSomeFromToManyFromPushesManyFromUp() {
        XCTAssertEqual(make(someFrom: 2, manyFrom: 4).settingSomeFrom(4), make(someFrom: 4, manyFrom: 5))
    }

    func testEachControlStopsAtItsCap() {
        XCTAssertEqual(make().settingSomeFrom(35), make(someFrom: 29, manyFrom: 30))
        XCTAssertEqual(make().settingManyFrom(2), make(someFrom: 2, manyFrom: 3))
        XCTAssertEqual(make().settingMinShare(1.0), make(minShare: 0.99, maxShare: 1.00))
        XCTAssertEqual(make().settingMaxShare(0.30), make(minShare: 0.30, maxShare: 0.31))
    }

    func testEachControlStopsAtTheOtherEndToo() {
        XCTAssertEqual(make().settingSomeFrom(1), make(someFrom: 2, manyFrom: 8))
        XCTAssertEqual(make().settingManyFrom(40), make(someFrom: 3, manyFrom: 30))
        XCTAssertEqual(make().settingMinShare(0.20), make(minShare: 0.30, maxShare: 0.95))
        XCTAssertEqual(make().settingMaxShare(1.50), make(minShare: 0.80, maxShare: 1.00))
    }

    /// The second move of each pair stops one step clear of the other value, which still pushes nothing.
    func testAMoveThatDoesNotCrossLeavesTheOtherValueAlone() {
        XCTAssertEqual(make().settingSomeFrom(5), make(someFrom: 5, manyFrom: 8))
        XCTAssertEqual(make().settingSomeFrom(7), make(someFrom: 7, manyFrom: 8))
        XCTAssertEqual(make().settingManyFrom(10), make(someFrom: 3, manyFrom: 10))
        XCTAssertEqual(make().settingManyFrom(4), make(someFrom: 3, manyFrom: 4))
        XCTAssertEqual(make().settingMinShare(0.85), make(minShare: 0.85, maxShare: 0.95))
        XCTAssertEqual(make().settingMinShare(0.94), make(minShare: 0.94, maxShare: 0.95))
        XCTAssertEqual(make().settingMaxShare(0.90), make(minShare: 0.80, maxShare: 0.90))
        XCTAssertEqual(make().settingMaxShare(0.81), make(minShare: 0.80, maxShare: 0.81))
    }

    func testAPushNeverChangesTheOtherPair() {
        let settings = make(someFrom: 5, manyFrom: 8, minShare: 0.50, maxShare: 0.60)
        XCTAssertEqual(settings.settingSomeFrom(9),
                       make(someFrom: 9, manyFrom: 10, minShare: 0.50, maxShare: 0.60))
        XCTAssertEqual(settings.settingManyFrom(4),
                       make(someFrom: 3, manyFrom: 4, minShare: 0.50, maxShare: 0.60))
        XCTAssertEqual(settings.settingMinShare(0.60),
                       make(someFrom: 5, manyFrom: 8, minShare: 0.60, maxShare: 0.61))
        XCTAssertEqual(settings.settingMaxShare(0.50),
                       make(someFrom: 5, manyFrom: 8, minShare: 0.49, maxShare: 0.50))
    }

    /// As Doubles, 0.81 + 0.01 is 0.8200000000000001 and 0.82 - 0.01 is 0.8099999999999999, so a push that
    /// added or took off 0.01 would not land on the whole percent the slider shows.
    func testAPushLandsOnAWholePercent() {
        XCTAssertEqual(make(minShare: 0.30, maxShare: 0.31).settingMinShare(0.81),
                       make(minShare: 0.81, maxShare: 0.82))
        XCTAssertEqual(make(minShare: 0.95, maxShare: 0.96).settingMaxShare(0.82),
                       make(minShare: 0.81, maxShare: 0.82))
    }

    // MARK: - E. Picture size and height

    /// The `mood-peek` scenario "Padded picture": art in rows 200-312 of 512, at share 0.80, rises 289.6 rows
    /// above the pane, which is 90.5 points at 160 / 512 points a row.
    func testUpIsTheArtRowsAboveThePaneInPoints() {
        let geometry = makeGeometry(everyMood(padded), in: laptop)
        XCTAssertEqual(geometry.up(1), 90.5, accuracy: 1e-9)
        XCTAssertEqual(geometry.up(12), 95.75, accuracy: 1e-9)
        XCTAssertEqual(geometry.up(20), 95.75, accuracy: 1e-9)
        XCTAssertEqual(geometry.up(0), 0)
    }

    func testPictureSizeKeepsTheAspectRatioInsideTheBox() {
        let tall = PictureMetrics(pixelWidth: 512, pixelHeight: 1024, artTop: 0, artBottom: 1024)
        let geometry = makeGeometry([Mood.few: wide, Mood.some: tall], in: laptop)
        XCTAssertEqual(geometry.pictureSize(Mood.few), CGSize(width: 160, height: 80))
        XCTAssertEqual(geometry.pictureSize(Mood.some), CGSize(width: 80, height: 160))
        XCTAssertEqual(geometry.pictureSize(Mood.many), CGSize.zero)
    }

    // MARK: - F. Box scale and reserve

    /// `some` is the tallest here, at 0.95 × 160. `many` has padding above and below its art, and `few` is
    /// only half as high as it is wide.
    func testReserveIsTheTallestPeekOfTheMoodsThatHaveAPicture() {
        let all = [Mood.few: wide, Mood.some: fullArt, Mood.many: padded]
        XCTAssertEqual(makeGeometry(all, in: laptop).reserve, 152, accuracy: 1e-9)
        let withoutSome = [Mood.few: wide, Mood.many: padded]
        XCTAssertEqual(makeGeometry(withoutSome, in: laptop).reserve, 95.75, accuracy: 1e-9)
        let onlyFew = [Mood.few: wide]
        XCTAssertEqual(makeGeometry(onlyFew, in: laptop).reserve, 60.15625, accuracy: 1e-9)
    }

    /// The reserve is worked out at `maxShare`, whatever the count, while `up` follows the count.
    func testTheReserveFollowsMaxShareAndUpFollowsTheCount() {
        let settings = make(minShare: 0.30, maxShare: 0.50)
        let geometry = makeGeometry(everyMood(fullArt), in: laptop, settings: settings)
        XCTAssertEqual(geometry.reserve, 80, accuracy: 1e-9)
        XCTAssertEqual(geometry.up(1), 48, accuracy: 1e-9)
        XCTAssertEqual(geometry.up(20), 80, accuracy: 1e-9)
    }

    /// A 160-point box never needs more than 160 points, so 600 points of usable height never shrink it. 400
    /// points do, to a reserve of 0.30 × 400.
    func testTheBoxShrinksOnlyAsFarAsNeeded() {
        let roomy = makeGeometry(everyMood(fullArt), in: CGRect(x: 0, y: 70, width: 1440, height: 600))
        XCTAssertEqual(roomy.scale, 1)
        XCTAssertLessThanOrEqual(roomy.reserve, 180)
        XCTAssertEqual(roomy.pictureSize(Mood.few).width, 160)
        let short = makeGeometry(everyMood(fullArt), in: CGRect(x: 0, y: 70, width: 1440, height: 400))
        XCTAssertLessThan(short.scale, 1)
        XCTAssertEqual(short.reserve, 120, accuracy: 1e-9)
        XCTAssertEqual(short.pictureSize(Mood.few).width, 160 * short.scale, accuracy: 1e-9)
    }

    func testWithoutPicturesThereIsNoReserveAndNoPeek() {
        let geometry = makeGeometry([:], in: laptop)
        XCTAssertEqual(geometry.scale, 1)
        XCTAssertEqual(geometry.reserve, 0)
        XCTAssertEqual(geometry.up(5), 0)
        XCTAssertNil(geometry.peekFrame(n: 5, paneFrame: CGRect(x: 320, y: 111, width: 800, height: 600)))
        XCTAssertEqual(geometry.maxContentHeight(windowPadding: 20), 741) // 805 - 2 * 12 - 2 * 20
    }

    // MARK: - G. The pane

    func testThePaneCapLeavesRoomForThePeekAndTheMargins() {
        let geometry = makeGeometry(everyMood(fullArt), in: laptop)
        XCTAssertEqual(geometry.maxContentHeight(windowPadding: 20), 589) // 805 - 152 - 2 * 12 - 2 * 20
        XCTAssertEqual(geometry.maxContentHeight(windowPadding: 25), 579)
    }

    func testAShortPaneStaysCentred() {
        let geometry = makeGeometry(everyMood(fullArt), in: laptop)
        let origin = geometry.paneOrigin(paneSize: CGSize(width: 800, height: 300))
        XCTAssertEqual(origin, CGPoint(x: 320, y: 322.5))
    }

    /// Centred, a 600-point pane would sit at y = 172.5, and its 152-point peek would pass the top margin.
    func testATallPaneMovesDownToMakeRoomForThePeek() {
        let geometry = makeGeometry(everyMood(fullArt), in: laptop)
        let origin = geometry.paneOrigin(paneSize: CGSize(width: 800, height: 600))
        XCTAssertEqual(origin.x, 320)
        XCTAssertEqual(origin.y, 111, accuracy: 1e-9) // 875 - 12 - 152 - 600
    }

    func testThePaneIsCentredAcrossTheUsableAreaButNeverLeftOfIt() {
        let leftDisplay = CGRect(x: -1440, y: 70, width: 1440, height: 805)
        let geometry = makeGeometry(everyMood(fullArt), in: leftDisplay)
        XCTAssertEqual(geometry.paneOrigin(paneSize: CGSize(width: 800, height: 300)).x, -1120)
        XCTAssertEqual(geometry.paneOrigin(paneSize: CGSize(width: 2000, height: 300)).x, -1440)
    }

    /// The cap is rounded, so the margin can be missed by up to half a point.
    func testAPaneAtTheCapStaysAMarginAboveTheDock() {
        let geometry = makeGeometry(everyMood(fullArt), in: laptop)
        let pane = paneAtTheCap(geometry)
        XCTAssertGreaterThanOrEqual(pane.minY - laptop.minY, MoodPeek.margin - 0.5)
    }

    /// The `mood-peek` scenario "Thirty windows on a laptop display". At 30 windows the peek rises by the whole
    /// reserve, which is the tightest fit, and it still ends a margin short of the top of the usable area.
    func testThirtyWindowsOnALaptopDisplayKeepThePeekBelowTheTopMargin() throws {
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 875)
        let geometry = makeGeometry(everyMood(fullArt), in: visible)
        let pane = paneAtTheCap(geometry)
        let peek = try XCTUnwrap(geometry.peekFrame(n: 30, paneFrame: pane))
        XCTAssertEqual(peek.height, geometry.reserve, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(pane.minY, visible.minY + MoodPeek.margin - 0.5)
        XCTAssertLessThanOrEqual(peek.maxY, visible.maxY - MoodPeek.margin + 1e-9)
    }

    /// The `mood-peek` scenario "Very short usable area": the scaled picture still fits the same way.
    func testAVeryShortUsableAreaStillFitsTheScaledPicture() throws {
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 400)
        let geometry = makeGeometry(everyMood(fullArt), in: visible)
        let pane = paneAtTheCap(geometry)
        let peek = try XCTUnwrap(geometry.peekFrame(n: 30, paneFrame: pane))
        XCTAssertEqual(peek.height, geometry.reserve, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(pane.minY, visible.minY + MoodPeek.margin - 0.5)
        XCTAssertLessThanOrEqual(peek.maxY, visible.maxY - MoodPeek.margin + 1e-9)
    }

    // MARK: - H. The peek and the image

    func testThePeekSitsOnThePanesTopEdge() throws {
        let geometry = makeGeometry([Mood.few: wide, Mood.some: fullArt, Mood.many: padded], in: laptop)
        let pane = CGRect(x: 320, y: 111, width: 800, height: 600)
        for (n, mood) in [(1, Mood.few), (3, Mood.some), (20, Mood.many)] {
            let peek = try XCTUnwrap(geometry.peekFrame(n: n, paneFrame: pane), "\(n) windows")
            XCTAssertEqual(peek.minX, pane.minX + 24, "\(n) windows")
            XCTAssertEqual(peek.minY, pane.maxY, "\(n) windows")
            XCTAssertEqual(peek.width, geometry.pictureSize(mood).width, "\(n) windows")
            XCTAssertEqual(peek.height, geometry.up(n), "\(n) windows")
        }
        let few = try XCTUnwrap(geometry.peekFrame(n: 1, paneFrame: pane))
        XCTAssertEqual(few.height, 53.125, accuracy: 1e-9)
        XCTAssertNil(geometry.peekFrame(n: 0, paneFrame: pane))
    }

    func testAPeekShorterThanOnePointIsHidden() {
        let sliver = PictureMetrics(pixelWidth: 512, pixelHeight: 512, artTop: 0, artBottom: 1)
        let geometry = makeGeometry(everyMood(sliver), in: laptop)
        XCTAssertGreaterThan(geometry.up(1), 0)
        XCTAssertLessThan(geometry.up(1), 1)
        XCTAssertNil(geometry.peekFrame(n: 1, paneFrame: CGRect(x: 320, y: 111, width: 800, height: 600)))
    }

    /// The peek panel's bottom edge is the pane's top edge. The image's top `up(n)` points lie above it, and the
    /// rest, below that edge, is clipped.
    func testTheImageShowsItsTopRowsAboveThePanelsBottomEdge() {
        let geometry = makeGeometry([Mood.few: wide, Mood.some: fullArt, Mood.many: padded], in: laptop)
        let few = geometry.imageFrame(n: 1)
        XCTAssertEqual(few.minX, 0)
        XCTAssertEqual(few.size, CGSize(width: 160, height: 80))
        XCTAssertEqual(few.maxY, geometry.up(1), accuracy: 1e-9)
        XCTAssertEqual(few.minY, -26.875, accuracy: 1e-9)
        let many = geometry.imageFrame(n: 20)
        XCTAssertEqual(many.maxY, geometry.up(20), accuracy: 1e-9)
        XCTAssertEqual(many.minY, -64.25, accuracy: 1e-9)
        XCTAssertEqual(geometry.imageFrame(n: 0), CGRect.zero)
    }
}
