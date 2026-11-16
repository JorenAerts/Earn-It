// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Features", targets: ["Features"])],
    dependencies: [.package(path: "../Localization"),
        .package(path: "../Core"),
        .package(path: "../AlarmEngine"),
        .package(path: "../Missions"),
        .package(path: "../Purchases"),
        .package(path: "../Account"),
        .package(path: "../Coach"),
        .package(path: "../WidgetShared"),
        .package(path: "../Permissions"),
        .package(path: "../Buddies"),
        .package(path: "../Telemetry"),
    ],
    targets: [.target(name: "Features", dependencies: ["Localization", "Core", "AlarmEngine", "Missions", "Purchases", "Account", "Coach", "WidgetShared", "Permissions", "Buddies", "Telemetry"])]
)
