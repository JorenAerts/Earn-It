// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Account",
    platforms: [.iOS("26.1")],
    products: [.library(name: "Account", targets: ["Account"])],
    dependencies: [.package(path: "../Localization"),
        .package(path: "../Core"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
    ],
    targets: [
        .target(name: "Account", dependencies: ["Localization",
            "Core",
            .product(name: "Supabase", package: "supabase-swift"),
        ]),
    ]
)
