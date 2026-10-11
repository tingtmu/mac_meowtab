import XCTest

/// Pins the peek's rules that need no screen and no picture: which mood a window count gets, how much of the
/// art rises above the pane, which saved settings are valid, and how the settings controls clamp and push
/// each other. See the `mood-peek` and `peek-settings` specs under openspec/.
///
/// Groups: A mood · B share · C validation · D the settings controls.
final class MoodPeekTests: XCTestCase {
    private func make(someFrom: Int = 3, manyFrom: Int = 8, minShare: Double = 0.80,
                      maxShare: Double = 0.95) -> MoodSettings {
        MoodSettings(someFrom: someFrom, manyFrom: manyFrom, minShare: minShare, maxShare: maxShare)
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
}
