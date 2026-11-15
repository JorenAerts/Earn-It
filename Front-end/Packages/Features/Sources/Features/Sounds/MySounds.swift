import Core
import Foundation
import Localization
import Observation

/// One of the user's own alarm sounds (imported or recorded), stored as
/// `Library/Sounds/custom-<id>.caf` so iOS can ring it, with metadata in `custom-sounds.json`.
struct CustomSound: Codable, Identifiable, Hashable, Sendable {
    enum Source: String, Codable, Sendable { case imported, recorded }

    let id: UUID
    var name: String
    var duration: Double
    var source: Source
    var created: Date

    var choice: SoundChoice { .custom(id: id, name: name) }
}

/// The user's own sounds. Observable so screens (and alarms using a deleted sound) update.
@MainActor
@Observable
final class MySounds {
    static let shared = MySounds()

    private(set) var sounds: [CustomSound] = []
    @ObservationIgnored let directory: URL

    init(directory: URL = CustomSoundLibrary.directory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sounds = (try? JSONDecoder().decode([CustomSound].self, from: Data(contentsOf: indexURL))) ?? []
    }

    private var indexURL: URL { directory.appending(path: "custom-sounds.json") }

    var isFull: Bool { sounds.count >= CustomSoundLibrary.maxSounds }

    func url(for id: UUID) -> URL { CustomSoundLibrary.url(for: id, in: directory) }

    /// Moves an exported CAF into the library.
    @discardableResult
    func add(file: URL, name: String, duration: Double, source: CustomSound.Source) throws -> CustomSound {
        let sound = CustomSound(id: UUID(), name: name.isEmpty ? L10n.tr("My sound") : name, duration: duration,
                                source: source, created: .now)
        try FileManager.default.moveItem(at: file, to: url(for: sound.id))
        sounds.insert(sound, at: 0)
        save()
        return sound
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = sounds.firstIndex(where: { $0.id == id }), !name.isEmpty else { return }
        sounds[i].name = name
        save()
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
        sounds.removeAll { $0.id == id }
        save()
    }

    func contains(_ id: UUID) -> Bool { sounds.contains { $0.id == id } }

    private func save() {
        try? JSONEncoder().encode(sounds).write(to: indexURL, options: .atomic)
    }
}
