// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Purchases",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Purchases", targets: ["Purchases"])],
    dependencies: [.package(path: "../Localization"), .package(path: "../Core")],
    targets: [.target(name: "Purchases", dependencies: ["Localization", "Core"])]
)
