import Foundation

/// Repo locations for tests that read source files: `ios` = the iOS project folder,
/// `shared` = `Shared/Config`, the content both the iOS and the Android app ship.
enum TestPaths {
    static let ios = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static let shared = ios.deletingLastPathComponent().appending(path: "Shared/Config")
}
