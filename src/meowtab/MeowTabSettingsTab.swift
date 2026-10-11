import Cocoa

/// The MeowTab section of Settings: a card per mood, where the moods begin, and how high the peek rises. Every
/// change is saved at once and handed to `PeekController`, as AltTab's own settings apply immediately, so there is
/// no Save or Cancel.
class MeowTabSettingsTab {
    private static let percentFormat = NSLocalizedString("%d%%", comment: "MeowTab settings: a peek height, such as 80%")
    private static var cardTitles = [Mood: NSTextField]()
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
        cardTitles.removeAll()
        fieldViews.removeAll()
        messageLine = nil
    }

    /// Each mood's title, centred in three equal columns across the row.
    private static func makeCardsRow() -> NSView {
        let titles = Mood.allCases.map { _ in NSTextField(labelWithString: "") }
        titles.forEach { $0.alignment = .center }
        cardTitles = Dictionary(uniqueKeysWithValues: zip(Mood.allCases, titles))
        let row = NSStackView(views: titles)
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

    /// Shows the settings in use in every control, value label and card title.
    private static func refresh() {
        let settings = PeekController.settings
        for (field, views) in fieldViews {
            let number = field.number(in: settings)
            views.control.integerValue = number
            views.label.stringValue = field.isShare ? String(format: percentFormat, number) : "\(number)"
        }
        for (mood, title) in cardTitles {
            title.stringValue = cardTitle(mood, settings)
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
