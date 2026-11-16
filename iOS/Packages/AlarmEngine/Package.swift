// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AlarmEngine",
    platforms: [.iOS("26.1")],
    products: [.library(name: "AlarmEngine", targets: ["AlarmEngine"])],
    dependencies: [.package(path: "../Localization"), .package(path: "../Core")],
    targets: [.target(name: "AlarmEngine", dependencies: ["Localization", "Core"])]
)
