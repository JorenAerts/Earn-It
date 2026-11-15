// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Buddies",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Buddies", targets: ["Buddies"])],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Coach"),
        .package(path: "../Account"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
    ],
    targets: [
        .target(name: "Buddies", dependencies: [
            "Core", "Coach", "Account",
            .product(name: "Supabase", package: "supabase-swift"),
        ]),
    ]
)
