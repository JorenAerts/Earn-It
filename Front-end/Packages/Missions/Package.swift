// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Missions",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Missions", targets: ["Missions"])],
    dependencies: [.package(path: "../Localization"), .package(path: "../Core"), .package(path: "../Permissions")],
    targets: [.target(name: "Missions", dependencies: ["Localization", "Core", "Permissions"])]
)
