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

/// A picture's size in pixels, and the rows its art spans (alpha above `MoodPeek.artAlpha`), counted from the
/// top.
struct PictureMetrics: Equatable {
    let pixelWidth: Int
    let pixelHeight: Int
    let artTop: Int
    let artBottom: Int // exclusive
}

/// Where the peek and the pane go in a display's usable area, as arithmetic on plain rectangles, so that no
/// screen is needed to test it. All values are in points. `visibleFrame` is the usable area, which excludes the
/// menu bar and the Dock.
struct PeekGeometry {
    /// What the box is scaled by, at most 1, so that `reserve` stays within `MoodPeek.maxReserve` of the usable
    /// height.
    let scale: CGFloat
    /// The room above the pane that the tallest of the three moods' peeks needs, at `maxShare`. It does not
    /// depend on the count.
    let reserve: CGFloat
    private let settings: MoodSettings
    private let pictures: [Mood: PictureMetrics]
    private let visibleFrame: CGRect

    init(settings: MoodSettings, pictures: [Mood: PictureMetrics], visibleFrame: CGRect) {
        let fullScaleReaches = pictures.values.map { PeekGeometry.reach($0, share: settings.maxShare, scale: 1) }
        let fullScaleReserve = fullScaleReaches.max() ?? 0
        let boxScale: CGFloat
        if fullScaleReserve > 0 {
            boxScale = min(1, MoodPeek.maxReserve * visibleFrame.height / fullScaleReserve)
        } else {
            boxScale = 1
        }
        self.settings = settings
        self.pictures = pictures
        self.visibleFrame = visibleFrame
        self.scale = boxScale
        self.reserve = fullScaleReserve * boxScale
    }

    /// The picture's size in the box, with its aspect ratio kept. `.zero` when the mood has no picture.
    func pictureSize(_ mood: Mood) -> CGSize {
        guard let picture = pictures[mood] else { return .zero }
        let k = PeekGeometry.pointsPerPixel(picture, scale: scale)
        return CGSize(width: CGFloat(picture.pixelWidth) * k, height: CGFloat(picture.pixelHeight) * k)
    }

    /// How many points of the picture show above the pane for a count of `n`. 0 when `n` has no mood or its
    /// mood has no picture.
    func up(_ n: Int) -> CGFloat {
        guard let mood = settings.mood(n), let picture = pictures[mood] else { return 0 }
        return PeekGeometry.reach(picture, share: settings.share(n), scale: scale)
    }

    /// The tallest content the pane may have: what the usable height leaves after the reserve, a margin at each
    /// end and the window padding on both sides. The caller takes the smaller of this and upstream's own cap.
    func maxContentHeight(windowPadding: CGFloat) -> CGFloat {
        (visibleFrame.height - reserve - 2 * MoodPeek.margin - 2 * windowPadding).rounded()
    }

    /// Centred in the usable area, as upstream does, but no higher than leaves room above the pane for the
    /// reserve and the top margin.
    func paneOrigin(paneSize: CGSize) -> CGPoint {
        let x = visibleFrame.minX + max(visibleFrame.width - paneSize.width, 0) * 0.5
        let centredY = visibleFrame.minY + max(visibleFrame.height - paneSize.height, 0) * 0.5
        let highestY = visibleFrame.maxY - MoodPeek.margin - reserve - paneSize.height
        return CGPoint(x: x, y: min(centredY, highestY))
    }

    /// The peek panel's frame: its bottom on the pane's top edge, `inset` in from the pane's left edge. nil when
    /// less than a point of it would show.
    func peekFrame(n: Int, paneFrame: CGRect) -> CGRect? {
        let height = up(n)
        guard height >= 1 else { return nil }
        return CGRect(x: paneFrame.minX + MoodPeek.inset, y: paneFrame.maxY,
                      width: pictureSize(count: n).width, height: height)
    }

    /// The picture's frame inside the peek panel. Its top `up(n)` points show, and the rest, below the panel's
    /// bottom edge, is clipped.
    func imageFrame(n: Int) -> CGRect {
        let size = pictureSize(count: n)
        return CGRect(x: 0, y: up(n) - size.height, width: size.width, height: size.height)
    }

    private func pictureSize(count n: Int) -> CGSize {
        guard let mood = settings.mood(n) else { return .zero }
        return pictureSize(mood)
    }

    /// Points per picture pixel when the picture fills the box at box scale `scale`.
    private static func pointsPerPixel(_ picture: PictureMetrics, scale: CGFloat) -> CGFloat {
        MoodPeek.box * scale / CGFloat(max(picture.pixelWidth, picture.pixelHeight))
    }

    /// How far below a picture's top the point `share` of the way through its art lies, at box scale `scale`.
    private static func reach(_ picture: PictureMetrics, share: Double, scale: CGFloat) -> CGFloat {
        let artHeight = CGFloat(picture.artBottom - picture.artTop)
        let rows = CGFloat(picture.artTop) + artHeight * CGFloat(share)
        return rows * pointsPerPixel(picture, scale: scale)
    }
}
