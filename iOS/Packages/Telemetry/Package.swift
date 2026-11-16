// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Telemetry",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Telemetry", targets: ["Telemetry"])],
    dependencies: [
        .package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.0.0"),
    ],
    targets: [
        .target(name: "Telemetry", dependencies: [
            .product(name: "TelemetryDeck", package: "SwiftSDK"),
        ]),
    ]
)
