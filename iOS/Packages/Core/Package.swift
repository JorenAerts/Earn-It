// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Core", targets: ["Core"])],
    dependencies: [.package(path: "../Localization")],
    targets: [.target(name: "Core", dependencies: ["Localization"])]
)
