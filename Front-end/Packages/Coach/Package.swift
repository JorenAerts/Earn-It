// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Coach",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Coach", targets: ["Coach"])],
    dependencies: [.package(path: "../Core")],
    targets: [.target(name: "Coach", dependencies: ["Core"])]
)
