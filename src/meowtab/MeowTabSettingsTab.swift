import Cocoa
import UniformTypeIdentifiers

/// The MeowTab section of Settings: a card per mood, where the moods begin, and how high the peek rises. Every
/// change is saved at once and handed to `PeekController`, as AltTab's own settings apply immediately, so there is
/// no Save or Cancel.
class MeowTabSettingsTab {
    private static let percentFormat = NSLocalizedString("%d%%", comment: "MeowTab settings: a peek height, such as 80%")
    private static var cards = [Mood: PictureCard]()
    /// Each stepper and slider, with the label that shows its value.
    private static var fieldViews = [Field: (control: NSControl, label: NSTextField)]()
    private static var messageLine: NSTextField?

    static func initTab() -> NSView {
        let pictures = TableGroupView(title: NSLocalizedString("Pictures", comment: "MeowTab settings group"),
                                      width: SettingsWindow.contentWidth)
        pictures.addRow(secondaryViews: [makeCardsRow()])
        let moods = makeGroup(NSLocalizedString("Moods", comment: "MeowTab settings group"), [.someFrom, .manyFrom])
        let heights = makeGroup(NSLocalizedString("Peek height", comment: "MeowTab settings group"), [.minShare, .maxShare])
        let view = TableGroupSetView(originalViews: [pictures, moods, heights, makeFooter()],
                                     titleTableGroupSpacing: 15, padding: 0, bottomPadding: 0)
        refresh()
        showWarnings()
        return view
    }

    static func cleanup() {
        cards.removeAll()
        fieldViews.removeAll()
        messageLine = nil
    }

    /// Saves an import's PNG as `mood`'s picture, or says why not. A failure changes nothing, so the card and the
    /// peek keep their picture.
    fileprivate static func finishImport(_ result: Result<Data, Error>, for mood: Mood) {
        do {
            try PeekController.store.setPicture(result.get(), for: mood)
        } catch {
            showMessage(importFailureMessage(error), isError: true)
            return
        }
        pictureChanged()
    }

    /// After a picture is saved or cleared: the switcher decodes its pictures again, the cards show them, and the
    /// message line is cleared.
    fileprivate static func pictureChanged() {
        PeekController.reload(picturesChanged: true)
        refresh()
        showMessage("", isError: false)
    }

    /// The three picture cards, in equal columns across the row.
    private static func makeCardsRow() -> NSView {
        let newCards = Mood.allCases.map { PictureCard($0) }
        cards = Dictionary(uniqueKeysWithValues: zip(Mood.allCases, newCards))
        let row = NSStackView(views: newCards)
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.widthAnchor.constraint(equalToConstant: SettingsWindow.contentWidth - 2 * TableGroupView.padding).isActive = true
        return row
    }

    private static func makeGroup(_ title: String, _ fields: [Field]) -> TableGroupView {
        let table = TableGroupView(title: title, width: SettingsWindow.contentWidth)
        for field in fields {
            table.addRow(TableGroupView.Row(leftTitle: field.title, rightViews: makeFieldViews(field)))
        }
        return table
    }

    /// The field's control and value label: "3" and a stepper, or a slider and "80%".
    private static func makeFieldViews(_ field: Field) -> [NSView] {
        let control = field.isShare ? makeSlider(field.range) : makeStepper(field.range)
        control.setAccessibilityLabel(field.title)
        control.onAction = { sender in change(field, to: Int(sender.doubleValue.rounded())) }
        let label = NSTextField(labelWithString: "")
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        // fixed, and wide enough for "100%", so a slider doesn't shift when its value's text changes length
        label.widthAnchor.constraint(equalToConstant: field.isShare ? 44 : 24).isActive = true
        fieldViews[field] = (control, label)
        return field.isShare ? [control, label] : [label, control]
    }

    private static func makeStepper(_ range: ClosedRange<Int>) -> NSControl {
        let stepper = NSStepper()
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.valueWraps = false
        return stepper
    }

    private static func makeSlider(_ range: ClosedRange<Int>) -> NSControl {
        let slider = NSSlider()
        slider.minValue = Double(range.lowerBound)
        slider.maxValue = Double(range.upperBound)
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        return slider
    }

    /// Restore defaults, and the message line under it.
    private static func makeFooter() -> NSView {
        let restore = NSButton(title: NSLocalizedString("Restore defaults", comment: "MeowTab settings button"),
                               target: nil, action: nil)
        restore.onAction = { _ in restoreDefaults() }
        let message = NSTextField(wrappingLabelWithString: "")
        message.preferredMaxLayoutWidth = SettingsWindow.contentWidth
        messageLine = message
        let footer = NSStackView(views: [restore, message])
        footer.orientation = .vertical
        footer.alignment = .leading
        footer.translatesAutoresizingMaskIntoConstraints = false
        return footer
    }

    /// A control moved to `number`. The clamping rules give the new settings, which are saved, handed to the
    /// switcher, and shown.
    private static func change(_ field: Field, to number: Int) {
        PeekController.store.save(field.setting(number, in: PeekController.settings))
        PeekController.reload(picturesChanged: false)
        refresh()
    }

    /// The shipped cats and the default settings again. The store removes only MeowTab's own keys and picture files.
    private static func restoreDefaults() {
        PeekController.store.restoreDefaults()
        PeekController.reload(picturesChanged: true)
        refresh()
        showWarnings()
    }

    /// Shows the settings and pictures in use in every control, value label and card.
    private static func refresh() {
        let settings = PeekController.settings
        for (field, views) in fieldViews {
            let number = field.number(in: settings)
            views.control.integerValue = number
            views.label.stringValue = field.isShare ? String(format: percentFormat, number) : "\(number)"
        }
        for (mood, card) in cards {
            card.refresh(title: cardTitle(mood, settings))
        }
    }

    /// What `PeekController`'s last reload couldn't use, or nothing.
    private static func showWarnings() {
        showMessage(PeekController.warnings.joined(separator: "\n"), isError: false)
    }

    /// Puts `text` on the message line, in red for an error. An empty text clears the line.
    private static func showMessage(_ text: String, isError: Bool) {
        messageLine?.stringValue = text
        messageLine?.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    /// Why an import failed: what `PeekPicture.load` refused the file for, or that saving it failed.
    private static func importFailureMessage(_ error: Error) -> String {
        guard let refusal = error as? PeekPicture.LoadError else {
            return NSLocalizedString("The picture couldn't be saved.", comment: "MeowTab import message")
        }
        switch refusal {
        case .tooBig:
            return NSLocalizedString("That file is over 10 MB.", comment: "MeowTab import message")
        case .notPNG:
            return NSLocalizedString("Choose a PNG picture. GIFs and other formats aren't supported yet.",
                                     comment: "MeowTab import message")
        case .animated:
            return NSLocalizedString("Animated PNGs aren't supported yet. Choose a still PNG.",
                                     comment: "MeowTab import message")
        case .tooLarge:
            return NSLocalizedString("That picture is too large (at most 8192 px a side and 32 megapixels).",
                                     comment: "MeowTab import message")
        case .unreadable:
            return NSLocalizedString("That file can't be read as a picture.", comment: "MeowTab import message")
        case .empty:
            return NSLocalizedString("That picture is fully transparent.", comment: "MeowTab import message")
        }
    }

    /// The mood, then the window counts it covers: "Few · 1–2 windows".
    private static func cardTitle(_ mood: Mood, _ settings: MoodSettings) -> String {
        switch mood {
        case Mood.few:
            let range = windowRange(1, settings.someFrom - 1)
            return String(format: NSLocalizedString("Few · %@", comment: "MeowTab; %@ is a window range"), range)
        case Mood.some:
            let range = windowRange(settings.someFrom, settings.manyFrom - 1)
            return String(format: NSLocalizedString("Some · %@", comment: "MeowTab; %@ is a window range"), range)
        case Mood.many:
            let range = String(format: NSLocalizedString("%d+ windows", comment: "MeowTab; %d is a window count"),
                               settings.manyFrom)
            return String(format: NSLocalizedString("Many · %@", comment: "MeowTab; %@ is a window range"), range)
        }
    }

    /// "1 window", "4 windows" or "3–7 windows".
    private static func windowRange(_ first: Int, _ last: Int) -> String {
        if first < last {
            return String(format: NSLocalizedString("%1$d–%2$d windows", comment: "MeowTab; a window range"), first, last)
        }
        if first == 1 {
            return NSLocalizedString("1 window", comment: "MeowTab; a window range")
        }
        return String(format: NSLocalizedString("%d windows", comment: "MeowTab; %d is a window count above 1"), first)
    }

    /// The four numbers the steppers and sliders set.
    private enum Field {
        case someFrom, manyFrom, minShare, maxShare

        var title: String {
            switch self {
            case .someFrom: return NSLocalizedString("Some from", comment: "MeowTab: the window count some starts at")
            case .manyFrom: return NSLocalizedString("Many from", comment: "MeowTab: the window count many starts at")
            case .minShare: return NSLocalizedString("With 1 window", comment: "MeowTab: peek height with one window")
            case .maxShare: return NSLocalizedString("With many windows", comment: "MeowTab: peek height with many windows")
            }
        }

        /// A peek height, set with a slider in whole percent; otherwise a window count, set with a stepper.
        var isShare: Bool {
            self == .minShare || self == .maxShare
        }

        var range: ClosedRange<Int> {
            switch self {
            case .someFrom: return 2...29
            case .manyFrom: return 3...30
            case .minShare, .maxShare: return 30...100
            }
        }

        /// The value in `settings`: a window count, or a share in whole percent.
        func number(in settings: MoodSettings) -> Int {
            switch self {
            case .someFrom: return settings.someFrom
            case .manyFrom: return settings.manyFrom
            case .minShare: return Int((settings.minShare * 100).rounded())
            case .maxShare: return Int((settings.maxShare * 100).rounded())
            }
        }

        /// `settings` with this value set to `number`, and the other of its pair pushed along.
        func setting(_ number: Int, in settings: MoodSettings) -> MoodSettings {
            switch self {
            case .someFrom: return settings.settingSomeFrom(number)
            case .manyFrom: return settings.settingManyFrom(number)
            case .minShare: return settings.settingMinShare(Double(number) / 100)
            case .maxShare: return settings.settingMaxShare(Double(number) / 100)
            }
        }
    }
}

/// One mood's card: its picture, its title, Choose… and Use default. A file dropped on the card is imported, and
/// the import's checks decide whether the peek can use it.
private final class PictureCard: NSStackView {
    let mood: Mood
    private let pictureView = PictureView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(title: NSLocalizedString("Choose…", comment: "MeowTab settings button"),
                                        target: nil, action: nil)
    private let defaultButton = NSButton(title: NSLocalizedString("Use default", comment: "MeowTab settings button"),
                                         target: nil, action: nil)
    /// While a picture is checked and converted, the card's buttons are off and it takes no drop.
    private var isImporting = false {
        didSet {
            chooseButton.isEnabled = !isImporting
            defaultButton.isEnabled = !isImporting
        }
    }

    init(_ mood: Mood) {
        self.mood = mood
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .centerX
        pictureView.imageScaling = .scaleProportionallyUpOrDown
        pictureView.translatesAutoresizingMaskIntoConstraints = false
        pictureView.widthAnchor.constraint(equalToConstant: 96).isActive = true
        pictureView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        titleLabel.alignment = .center
        chooseButton.onAction = { [weak self] _ in self?.choosePicture() }
        defaultButton.onAction = { [weak self] _ in self?.useDefault() }
        setViews([pictureView, titleLabel, NSStackView(views: [chooseButton, defaultButton])], in: .top)
        // each label names the mood, or VoiceOver would hear the same three controls on every card
        let pictureFormat = NSLocalizedString("Picture for “%@”", comment: "MeowTab; %@ is a mood: few, some or many")
        let chooseFormat = NSLocalizedString("Choose a picture for “%@”", comment: "MeowTab; %@ is a mood")
        let defaultFormat = NSLocalizedString("Use the default picture for “%@”", comment: "MeowTab; %@ is a mood")
        pictureView.setAccessibilityLabel(String(format: pictureFormat, mood.rawValue))
        chooseButton.setAccessibilityLabel(String(format: chooseFormat, mood.rawValue))
        defaultButton.setAccessibilityLabel(String(format: defaultFormat, mood.rawValue))
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("Class only supports programmatic initialization")
    }

    /// Shows `title`, the picture in use for the mood, and Use default only while that picture is the user's.
    func refresh(title: String) {
        titleLabel.stringValue = title
        pictureView.image = PeekController.pictures[mood].map { NSImage(cgImage: $0.image, size: .zero) }
        defaultButton.isHidden = PeekController.store.pictureURL(mood) == nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isImporting, droppedFile(sender) != nil else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isImporting, let url = droppedFile(sender) else { return false }
        importPicture(url)
        return true
    }

    /// The one file dragged in; nil for several files, or for something that isn't a file.
    private func droppedFile(_ sender: NSDraggingInfo) -> URL? {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                         options: [.urlReadingFileURLsOnly: true]) as? [URL]
        guard let urls, urls.count == 1 else { return nil }
        return urls[0]
    }

    private func choosePicture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importPicture(url)
    }

    private func useDefault() {
        PeekController.store.clearPicture(mood)
        MeowTabSettingsTab.pictureChanged()
    }

    /// Checks and converts the file off the main thread, then saves it, or says why not, on the main thread.
    private func importPicture(_ url: URL) {
        isImporting = true
        let mood = self.mood // not read from the card, which is gone if Settings closes first; the import still saves
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { () throws -> Data in
                guard let png = try PeekPicture.load(url: url).pngData() else { throw CocoaError(.fileWriteUnknown) }
                return png
            }
            DispatchQueue.main.async {
                self?.isImporting = false
                MeowTabSettingsTab.finishImport(result, for: mood)
            }
        }
    }
}

/// The card's picture. AppKit's image view can register drag types of its own even when it isn't editable, and then
/// refuse a drop meant for the card; this one never registers, so a file dragged over the picture reaches the card.
private final class PictureView: NSImageView {
    override func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {}
}
