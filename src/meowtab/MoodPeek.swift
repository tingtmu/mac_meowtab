import CoreGraphics

/// The peek's mood, picked by how many windows the switcher lists.
enum Mood: String, CaseIterable {
    case few, some, many
}

/// The peek's fixed sizes. Lengths are in points, except `maxSide`, which is in pixels.
enum MoodPeek {
    /// The picture's longest side.
    static let box: CGFloat = 160
    /// From the pane's left edge to the picture's.
    static let inset: CGFloat = 24
    /// The peek's top stays at least this far below the top of the usable area.
    static let margin: CGFloat = 12
    /// The most of the usable height the peek may take, as a fraction.
    static let maxReserve: CGFloat = 0.30
    /// A pixel is art when its alpha is above this.
    static let artAlpha: UInt8 = 24
    /// Imported pictures are scaled down to this many pixels on their longest side.
    static let maxSide = 1024
}

/// What the peek follows: where the moods begin, and how much of the art rises above the pane.
struct MoodSettings: Equatable {
    let someFrom: Int
    let manyFrom: Int
    let minShare: Double
    let maxShare: Double

    static let defaults = MoodSettings(someFrom: 3, manyFrom: 8, minShare: 0.80, maxShare: 0.95)

    /// Each invalid pair is replaced by its defaults, and a valid one is kept. The comparisons are written so
    /// that NaN fails them.
    func validated() -> MoodSettings {
        let thresholdsAreValid = 2 <= someFrom && someFrom < manyFrom && manyFrom <= 30
        let sharesAreValid = 0.30 <= minShare && minShare < maxShare && maxShare <= 1.00
        let fallback = MoodSettings.defaults
        return MoodSettings(
            someFrom: thresholdsAreValid ? someFrom : fallback.someFrom,
            manyFrom: thresholdsAreValid ? manyFrom : fallback.manyFrom,
            minShare: sharesAreValid ? minShare : fallback.minShare,
            maxShare: sharesAreValid ? maxShare : fallback.maxShare)
    }

    /// nil when no window is listed.
    func mood(_ n: Int) -> Mood? {
        if n <= 0 { return nil }
        if n < someFrom { return Mood.few }
        if n < manyFrom { return Mood.some }
        return Mood.many
    }

    /// The part of the picture's art shown above the pane: `minShare` with one window, rising to `maxShare`
    /// at `manyFrom + 4` windows.
    func share(_ n: Int) -> Double {
        let ramp = Double(n - 1) / Double(manyFrom + 3)
        let progress = min(max(ramp, 0), 1)
        return minShare + (maxShare - minShare) * progress
    }

    // The settings controls' rules. Each returns new settings, and the other pair stays as it was.

    /// `someFrom` is `value` within 2...29. `manyFrom` is pushed up to stay above it, as far as 30.
    func settingSomeFrom(_ value: Int) -> MoodSettings {
        let newSomeFrom = min(max(value, 2), 29)
        let newManyFrom = min(max(manyFrom, newSomeFrom + 1), 30)
        return MoodSettings(someFrom: newSomeFrom, manyFrom: newManyFrom, minShare: minShare, maxShare: maxShare)
    }

    /// `manyFrom` is `value` within 3...30. `someFrom` is pushed down to stay below it, as far as 2.
    func settingManyFrom(_ value: Int) -> MoodSettings {
        let newManyFrom = min(max(value, 3), 30)
        let newSomeFrom = max(min(someFrom, newManyFrom - 1), 2)
        return MoodSettings(someFrom: newSomeFrom, manyFrom: newManyFrom, minShare: minShare, maxShare: maxShare)
    }

    // The sliders move in whole percent, so the share rules work in whole percent and store percent / 100:
    // adding or taking off 0.01 would drift (as Doubles, 0.81 + 0.01 is 0.8200000000000001). Shares must be
    // finite, which a slider and `validated()` guarantee.

    /// `minShare` is `value` within 30...99 %. `maxShare` is pushed up to stay above it, as far as 100 %.
    func settingMinShare(_ value: Double) -> MoodSettings {
        let newMinPercent = min(max(MoodSettings.wholePercent(value), 30), 99)
        let newMaxPercent = min(max(MoodSettings.wholePercent(maxShare), newMinPercent + 1), 100)
        return MoodSettings(someFrom: someFrom, manyFrom: manyFrom,
                            minShare: Double(newMinPercent) / 100, maxShare: Double(newMaxPercent) / 100)
    }

    /// `maxShare` is `value` within 31...100 %. `minShare` is pushed down to stay below it, as far as 30 %.
    func settingMaxShare(_ value: Double) -> MoodSettings {
        let newMaxPercent = min(max(MoodSettings.wholePercent(value), 31), 100)
        let newMinPercent = max(min(MoodSettings.wholePercent(minShare), newMaxPercent - 1), 30)
        return MoodSettings(someFrom: someFrom, manyFrom: manyFrom,
                            minShare: Double(newMinPercent) / 100, maxShare: Double(newMaxPercent) / 100)
    }

    private static func wholePercent(_ share: Double) -> Int {
        Int((share * 100).rounded())
    }
}
