// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Missions",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Missions", targets: ["Missions"])],
    dependencies: [.package(path: "../Core")],
    targets: [.target(name: "Missions", dependencies: ["Core"])]
)
