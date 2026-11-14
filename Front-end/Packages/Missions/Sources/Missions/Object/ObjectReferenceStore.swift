import Foundation
import UIKit
import Vision

/// A registered item: its reference feature prints (one per angle), match threshold and thumbnail.
struct ObjectReference: @unchecked Sendable {
    let id: String
    let prints: [VNFeaturePrintObservation]
    let threshold: Float
    let thumbnail: UIImage?
}

/// Stores registered items on disk:
/// `Application Support/MissionAssets/<id>/prints.data` (archived feature prints),
/// `meta.json` (threshold), `thumb.png`. `MissionConfig.payload` holds the id.
public struct ObjectReferenceStore: Sendable {
    let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var shared: ObjectReferenceStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ObjectReferenceStore(root: base.appending(path: "MissionAssets"))
    }

    private struct Meta: Codable { let threshold: Float }

    func save(prints: [VNFeaturePrintObservation], threshold: Float, thumbnail: UIImage?) throws -> String {
        let id = UUID().uuidString
        let dir = root.appending(path: id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try NSKeyedArchiver.archivedData(withRootObject: prints as NSArray, requiringSecureCoding: true)
        try data.write(to: dir.appending(path: "prints.data"), options: .atomic)
        try JSONEncoder().encode(Meta(threshold: threshold)).write(to: dir.appending(path: "meta.json"), options: .atomic)
        if let png = thumbnail?.pngData() { try png.write(to: dir.appending(path: "thumb.png"), options: .atomic) }
        return id
    }

    func load(_ id: String) -> ObjectReference? {
        let dir = root.appending(path: id)
        guard let data = try? Data(contentsOf: dir.appending(path: "prints.data")),
              let array = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, VNFeaturePrintObservation.self], from: data) as? [VNFeaturePrintObservation],
              !array.isEmpty,
              let metaData = try? Data(contentsOf: dir.appending(path: "meta.json")),
              let meta = try? JSONDecoder().decode(Meta.self, from: metaData)
        else { return nil }
        let thumb = (try? Data(contentsOf: dir.appending(path: "thumb.png"))).flatMap(UIImage.init(data:))
        return ObjectReference(id: id, prints: array, threshold: meta.threshold, thumbnail: thumb)
    }

    public func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: root.appending(path: id).appending(path: "prints.data").path())
    }

    /// Thumbnail of a registered item (for editor rows).
    public func thumbnail(_ id: String) -> UIImage? {
        (try? Data(contentsOf: root.appending(path: id).appending(path: "thumb.png"))).flatMap(UIImage.init(data:))
    }

    /// Removes items no alarm uses anymore. Recent scans (an alarm still being edited) are kept.
    public func prune(keeping ids: Set<String>, olderThan age: TimeInterval = 3_600, now: Date = .now) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.creationDateKey]) else { return }
        for dir in entries where !ids.contains(dir.lastPathComponent) {
            let created = (try? dir.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if now.timeIntervalSince(created) > age { try? FileManager.default.removeItem(at: dir) }
        }
    }
}
