import Foundation

/// MeowTab's settings, in its own `meowtab.*` keys, and its picture folder (design.md 7).
final class MeowTabStore {
    static let invalidSettingsWarning = NSLocalizedString("Some saved MeowTab settings were invalid and were reset.", comment: "")
    private static let idCharacters: Set<Character> = Set("0123456789ABCDEF-")

    private enum Key {
        static let prefix = "meowtab."
        static let someFrom = "meowtab.someFrom"
        static let manyFrom = "meowtab.manyFrom"
        static let minShare = "meowtab.minShare"
        static let maxShare = "meowtab.maxShare"
    }

    let defaults: UserDefaults
    let folder: URL

    init(defaults: UserDefaults, folder: URL) {
        self.defaults = defaults
        self.folder = folder
    }

    /// Reads only; it never writes. A missing key gives its default silently. A value of the wrong type
    /// invalidates its pair, as an out-of-range one does, and a picture key that isn't one of our names is
    /// invalid too. Any of these adds the warning, once.
    func load() -> (settings: MoodSettings, warnings: [String]) {
        let fallback = MoodSettings.defaults
        var badThresholds = false
        var badShares = false
        let someFrom = stored(Key.someFrom, fallback.someFrom, &badThresholds)
        let manyFrom = stored(Key.manyFrom, fallback.manyFrom, &badThresholds)
        let minShare = stored(Key.minShare, fallback.minShare, &badShares)
        let maxShare = stored(Key.maxShare, fallback.maxShare, &badShares)
        let read = MoodSettings(
            someFrom: badThresholds ? fallback.someFrom : someFrom,
            manyFrom: badThresholds ? fallback.manyFrom : manyFrom,
            minShare: badShares ? fallback.minShare : minShare,
            maxShare: badShares ? fallback.maxShare : maxShare)
        let settings = read.validated()
        let changed = settings != read
        let badPicture = Mood.allCases.contains { hasInvalidPicture($0) }
        var warnings: [String] = []
        if badThresholds || badShares || changed || badPicture {
            warnings.append(MeowTabStore.invalidSettingsWarning)
        }
        return (settings, warnings)
    }

    func save(_ settings: MoodSettings) {
        defaults.set(settings.someFrom, forKey: Key.someFrom)
        defaults.set(settings.manyFrom, forKey: Key.manyFrom)
        defaults.set(settings.minShare, forKey: Key.minShare)
        defaults.set(settings.maxShare, forKey: Key.maxShare)
    }

    /// MeowTab's own copy of the mood's picture, or nil for the shipped cat.
    func pictureURL(_ mood: Mood) -> URL? {
        guard let name = pictureName(mood) else { return nil }
        return fileURL(name)
    }

    /// Saves `png` as a new file, then points the mood's key at it, then deletes the file it replaces. If saving
    /// throws, the old key and file are left as they were.
    func setPicture(_ png: Data, for mood: Mood) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let previous = pictureName(mood)
        let name = "\(mood.rawValue)-\(UUID().uuidString).png"
        try png.write(to: fileURL(name), options: .atomic)
        defaults.set(name, forKey: pictureKey(mood))
        if let previous {
            removeFile(named: previous)
        }
    }

    /// "Use default": the shipped cat is back, and the copy is deleted.
    func clearPicture(_ mood: Mood) {
        let name = pictureName(mood)
        defaults.removeObject(forKey: pictureKey(mood))
        if let name {
            removeFile(named: name)
        }
    }

    /// Removes every `meowtab.*` key and every picture file of ours, and nothing else.
    func restoreDefaults() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Key.prefix) {
            defaults.removeObject(forKey: key)
        }
        for name in pictureFileNames() {
            removeFile(named: name)
        }
    }

    /// Deletes the picture files of ours that no key refers to, such as one a save left behind.
    func removeOrphans() {
        let referenced = Mood.allCases.compactMap { pictureName($0) }
        for name in pictureFileNames() where !referenced.contains(name) {
            removeFile(named: name)
        }
    }

    private func pictureKey(_ mood: Mood) -> String {
        return "meowtab.picture.\(mood.rawValue)"
    }

    /// The file name saved for the mood, if the key holds one of our names for that mood. Anything else, a path
    /// such as `../x.png` included, is nil, so it is never read or deleted.
    private func pictureName(_ mood: Mood) -> String? {
        guard let name = defaults.object(forKey: pictureKey(mood)) as? String,
              MeowTabStore.pictureMood(of: name) == mood else { return nil }
        return name
    }

    private func hasInvalidPicture(_ mood: Mood) -> Bool {
        return defaults.object(forKey: pictureKey(mood)) != nil && pictureName(mood) == nil
    }

    /// The value stored for `key`, or `fallback` when the key is absent. A value of another type also gives
    /// `fallback` and sets `invalid`.
    private func stored<T>(_ key: String, _ fallback: T, _ invalid: inout Bool) -> T {
        guard let object = defaults.object(forKey: key) else { return fallback }
        guard let value = object as? T else {
            invalid = true
            return fallback
        }
        return value
    }

    /// Our picture files that sit directly in the folder.
    private func pictureFileNames() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.filter { MeowTabStore.pictureMood(of: $0) != nil }
    }

    private func fileURL(_ name: String) -> URL {
        return folder.appendingPathComponent(name)
    }

    private func removeFile(named name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
    }

    /// The mood of a name we wrote, `<mood>-<UUID>.png` with an uppercase UUID: the pattern
    /// `^(few|some|many)-[0-9A-F-]{36}\.png$`, read strictly. Any other name gives nil.
    private static func pictureMood(of name: String) -> Mood? {
        for candidate in Mood.allCases {
            let prefix = candidate.rawValue + "-"
            guard name.hasPrefix(prefix), name.hasSuffix(".png") else { continue }
            let id = name.dropFirst(prefix.count).dropLast(4)
            if id.count == 36 && id.allSatisfy({ MeowTabStore.idCharacters.contains($0) }) {
                return candidate
            }
        }
        return nil
    }
}
