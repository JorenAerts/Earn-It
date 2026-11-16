// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Localization",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Localization", targets: ["Localization"])],
    targets: [.target(name: "Localization")]
)
