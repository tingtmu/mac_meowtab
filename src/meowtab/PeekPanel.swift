import Cocoa
import os

/// The click-through panel that shows the mood picture on the switcher pane's top edge.
final class PeekPanel: NSPanel {
    /// The picture. Its delegate turns implicit animations off, so no change to it can animate.
    let imageLayer = noAnimation { CALayer() }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: .nonactivatingPanel, backing: .buffered, defer: false)
        // As `SearchDiscoveryPanel`. The `.unknown` subrole keeps it out of the switcher's own window list.
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        animationBehavior = .none
        collectionBehavior = [.transient, .fullScreenAuxiliary, .ignoresCycle]
        setAccessibilitySubrole(.unknown)
        // A picture, not a window: no shadow, clicks go to whatever is under it, and VoiceOver never lands on it.
        ignoresMouseEvents = true
        hasShadow = false
        setAccessibilityElement(false)
        // A 512-px picture is drawn about 160 px wide on a 1x display. Linear sampling skips pixels at that ratio
        // and leaves the outline jagged; mipmaps average them.
        imageLayer.minificationFilter = .trilinear
        let view = NSView()
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .never
        // The picture runs on below the panel's bottom edge, which is the pane's top edge, and is cut off there.
        view.layer!.masksToBounds = true
        view.layer!.addSublayer(imageLayer)
        contentView = view
    }
}

/// Puts the peek panel on the pane's top edge. Main thread only, inside the app's own calls: `setUp` and one `hide`
/// from `App`, `attachedFrame` from `SearchDiscoveryHint`, `reload` and `whenSwitcherCloses` from the settings
/// section, and the rest from hooks in `TilesPanel`. There is no timer and no async work: what `whenSwitcherCloses`
/// queues runs in the `hide()` that ends the session, so a dismissed session leaves nothing behind. `panel` is nil
/// until `setUp` has run, and while it is, every hook leaves the switcher as upstream's.
class PeekController {
    /// MeowTab's settings, and its copies of the user's pictures.
    static let store = MeowTabStore(defaults: .standard, folder: FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MeowTab", isDirectory: true)
        .appendingPathComponent("images", isDirectory: true))
    /// The settings in use.
    private(set) static var settings = MoodSettings.defaults
    /// Each mood's picture in use: the user's, or the shipped one.
    private(set) static var pictures = [Mood: PeekPicture]()
    /// Why something saved couldn't be used, for the settings section.
    private(set) static var warnings = [String]()

    private static let logger = os.Logger(subsystem: "io.github.tingtmu.meowtab.macos", category: "peek")
    private static let pictureWarningFormat = NSLocalizedString(
        "Your picture for “%@” couldn't be loaded, so the default cat is shown.",
        comment: "MeowTab settings message; %@ is a mood: few, some or many")
    private static var panel: PeekPanel?
    private static var shipped = [Mood: PeekPicture]()
    private static var pictureMetrics = [Mood: PictureMetrics]()
    private static var pictureWarnings = [String]()
    /// Bumped by `reload`, so the next `update` applies its result.
    private static var generation = 0
    private static var applied: Inputs?
    /// Whose picture the image layer holds, framed by the last `update`; nil when that update had nothing to show.
    private static var shown: Shown?
    /// Between `show()` and `hide()`, which is while the pane is on screen and not masked.
    private static var paneShown = false
    /// What `whenSwitcherCloses` holds for the end of the session, in the order it came.
    private static var queuedWork = [() -> Void]()

    /// Once, at launch, right after `TilesPanel` is created.
    static func setUp() {
        store.removeOrphans()
        var loaded = [Mood: PeekPicture]()
        for mood in Mood.allCases {
            let name = "chill_\(mood.rawValue)"
            loaded[mood] = decode(Bundle.main.url(forResource: name, withExtension: "png"), "\(name).png")
        }
        // A shipped picture that can't be loaded means a broken build. It is logged, and the switcher stays upstream's.
        guard loaded.count == Mood.allCases.count else { return }
        shipped = loaded
        reload(picturesChanged: true)
        panel = PeekPanel()
    }

    /// Reads the settings again, and decodes the user's pictures again when `picturesChanged`: a settings-only
    /// change reuses the decoded ones. The next `update` applies the result.
    static func reload(picturesChanged: Bool) {
        let loaded = store.load()
        if picturesChanged {
            let custom = loadCustomPictures()
            pictures = shipped.merging(custom.pictures) { _, users in users }
            pictureMetrics = pictures.mapValues {
                PictureMetrics(pixelWidth: $0.pixelWidth, pixelHeight: $0.pixelHeight, artTop: $0.artTop, artBottom: $0.artBottom)
            }
            pictureWarnings = custom.warnings
        }
        settings = loaded.settings
        warnings = loaded.warnings + pictureWarnings
        generation &+= 1
        // Thumbnail captures are sized for the tiles, which the reserve caps, and upstream sizes them again only
        // on its own reset. `setUp` reloads before it makes the panel, so launch keeps upstream's sizing.
        if panel != nil { TilesPanel.updateMaxPossibleThumbnailSize() }
    }

    /// Runs `work` at once while the switcher is closed, else in the `hide()` that closes it, in the order it came.
    /// The settings section waits this way to reload an import that ends while the switcher is open, since a
    /// session never decodes a picture or changes its room.
    static func whenSwitcherCloses(_ work: @escaping () -> Void) {
        guard SwitcherSession.isActive else {
            work()
            return
        }
        queuedWork.append(work)
    }

    /// From `TilesPanel.updateContents`, inside its transaction, once the pane has its size and place. AppKit moves
    /// a child window along with its parent; the absolute frame set here comes after the pane's move, so it wins.
    static func update(paneFrame: NSRect, screen: NSScreen) {
        guard let panel else { return }
        let count = Windows.list.lazy.filter { $0.shouldShowTheUser && !$0.isWindowlessApp }.count
        let inputs = Inputs(count: count, paneFrame: paneFrame, cornerRadius: Appearance.windowCornerRadius,
                            visibleFrame: screen.visibleFrame, backingScale: screen.backingScaleFactor,
                            generation: generation)
        guard inputs != applied else { return }
        let start = DispatchTime.now().uptimeNanoseconds
        applied = inputs
        let geometry = peekGeometry(inputs.visibleFrame)
        let radius = inputs.cornerRadius
        if let mood = settings.mood(count), let picture = pictures[mood],
           let peekFrame = geometry.peekFrame(n: count, paneFrame: paneFrame, cornerRadius: radius) {
            let imageFrame = geometry.imageFrame(n: count, paneFrame: paneFrame, cornerRadius: radius)
            place(panel, peekFrame, imageFrame, inputs.backingScale)
            let contents = Shown(mood: mood, generation: generation)
            if contents != shown {
                panel.imageLayer.contents = picture.image
                shown = contents
            }
            // Not over a pane that `show()` hasn't revealed yet, nor over one masked at alpha 0 for a rebuild.
            if paneShown && TilesPanel.shared.alphaValue > 0 { attach(panel) }
        } else {
            shown = nil
            detach(panel)
        }
        let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        logger.debug("update \(milliseconds, format: .fixed(precision: 3), privacy: .public) ms n=\(count, privacy: .public)")
    }

    /// From `TilesPanel.show()`, once the pane is revealed.
    static func show() {
        paneShown = true
        guard let panel, shown != nil else { return }
        attach(panel)
    }

    /// First thing in `TilesPanel.orderOut`, before upstream's fade, so the picture never outlasts the pane; and when a
    /// summon with another shortcut masks the pane for its rebuild, until `show()`. The next `update` applies
    /// everything again. Once the session has ended, as `App.beginHideUi` ends it before it orders the pane out, it
    /// then runs what `whenSwitcherCloses` queued; the mask, mid-session, leaves the queue alone.
    static func hide() {
        paneShown = false
        applied = nil
        if let panel { detach(panel) }
        guard !SwitcherSession.isActive else { return }
        let work = queuedWork
        queuedWork = []
        for item in work { item() }
    }

    /// Upstream's centring, lowered when the pane needs the peek's room. The top edge, which the peek sits on, is
    /// rounded down to a whole point. Before `setUp`, upstream's `repositionPanel` itself.
    static func positionPane(_ pane: NSWindow, on screen: NSScreen) {
        guard panel != nil else {
            screen.repositionPanel(pane)
            return
        }
        let size = pane.frame.size
        let origin = peekGeometry(screen.visibleFrame).paneOrigin(paneSize: size)
        let top = (origin.y + size.height).rounded(.down)
        pane.setFrameOrigin(NSPoint(x: origin.x.rounded(), y: top - size.height))
    }

    /// The pane's content height that leaves room for the peek. Unlimited before `setUp`, so upstream's cap wins.
    static func maxContentHeight(_ screen: NSScreen) -> CGFloat {
        guard panel != nil else { return .greatestFiniteMagnitude }
        return peekGeometry(screen.visibleFrame).maxContentHeight(windowPadding: Appearance.windowPadding)
    }

    /// The peek panel's frame while it is attached to the pane, else nil. The search hint keeps clear of it.
    static var attachedFrame: NSRect? {
        guard let panel, panel.parent != nil else { return nil }
        return panel.frame
    }

    private static func peekGeometry(_ visibleFrame: NSRect) -> PeekGeometry {
        PeekGeometry(settings: settings, pictures: pictureMetrics, visibleFrame: visibleFrame)
    }

    /// The bottom edge is the pane's top edge exactly, which `positionPane` put on a whole point; the other edges
    /// are rounded to whole points. Whole points are whole pixels on 1x and 2x displays, so the two windows meet on
    /// one pixel row, with no gap and no overlap. The image layer moves by what the rounding took off the height,
    /// so the picture's top stays at the panel's top.
    private static func place(_ panel: PeekPanel, _ peekFrame: NSRect, _ imageFrame: CGRect, _ backingScale: CGFloat) {
        let frame = NSRect(x: peekFrame.minX.rounded(), y: peekFrame.minY,
                           width: peekFrame.width.rounded(.up), height: peekFrame.height.rounded(.down))
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        panel.imageLayer.frame = imageFrame.offsetBy(dx: 0, dy: frame.height - peekFrame.height)
        // AppKit rescales the layers it owns when a window changes display; this one is ours.
        panel.imageLayer.contentsScale = backingScale
    }

    /// Same level as the pane, just above it, as `SearchDiscoveryHint` attaches its panel.
    private static func attach(_ panel: PeekPanel) {
        guard panel.parent == nil else { return }
        panel.level = TilesPanel.shared.level
        TilesPanel.shared.addChildWindow(panel, ordered: .above)
    }

    private static func detach(_ panel: PeekPanel) {
        panel.parent?.removeChildWindow(panel)
        if panel.isVisible { panel.orderOut(nil) }
    }

    /// The user's pictures that load. One that doesn't is left out, so its mood shows the shipped cat, and it adds
    /// a warning.
    private static func loadCustomPictures() -> (pictures: [Mood: PeekPicture], warnings: [String]) {
        var loaded = [Mood: PeekPicture]()
        var failures = [String]()
        for mood in Mood.allCases {
            guard let url = store.pictureURL(mood) else { continue }
            if let picture = decode(url, "the custom picture for \(mood.rawValue)") {
                loaded[mood] = picture
            } else {
                failures.append(String(format: pictureWarningFormat, mood.rawValue))
            }
        }
        return (loaded, failures)
    }

    /// The picture at `url`, or nil, logged, when there is none or it can't be loaded.
    private static func decode(_ url: URL?, _ name: String) -> PeekPicture? {
        do {
            return try PeekPicture.load(url: url.unwrapOrThrow())
        } catch {
            logger.error("\(name, privacy: .public) couldn't be loaded: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// What an `update` depends on. The next one with the same values, such as a selection step's, does nothing.
    private struct Inputs: Equatable {
        let count: Int
        let paneFrame: NSRect
        let cornerRadius: CGFloat
        let visibleFrame: NSRect
        let backingScale: CGFloat
        let generation: Int
    }

    private struct Shown: Equatable {
        let mood: Mood
        let generation: Int
    }
}
