// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MagicClick",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MagicClick",
            path: "Sources/MagicClick",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
