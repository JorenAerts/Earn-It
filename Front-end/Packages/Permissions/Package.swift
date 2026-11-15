// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Permissions",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Permissions", targets: ["Permissions"])],
    dependencies: [.package(path: "../Localization")],
    targets: [.target(name: "Permissions", dependencies: ["Localization"])]
)
