// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Features", targets: ["Features"])],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../AlarmEngine"),
        .package(path: "../Missions"),
        .package(path: "../Purchases"),
        .package(path: "../Account"),
    ],
    targets: [.target(name: "Features", dependencies: ["Core", "AlarmEngine", "Missions", "Purchases", "Account"])]
)
