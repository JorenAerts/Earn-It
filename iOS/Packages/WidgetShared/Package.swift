// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WidgetShared",
    platforms: [.iOS("26.1")],
    products: [.library(name: "WidgetShared", targets: ["WidgetShared"])],
    dependencies: [.package(path: "../Localization"), .package(path: "../Coach"), .package(path: "../Core")],
    targets: [.target(name: "WidgetShared", dependencies: ["Localization", "Coach", "Core"])]
)
