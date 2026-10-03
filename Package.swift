// swift-tools-version: 6.0
import PackageDescription

// SPEC.md §4.8: verified manifest. Builds clean and dumps a live AX tree
// off the main thread on macOS 27 / Swift 6.4 / arm64.
let package = Package(
    name: "jevscope",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AXKit", targets: ["AXKit"]),
        .executable(name: "jevscope", targets: ["jevscope"]),
    ],
    targets: [
        .target(
            name: "AXKit",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "jevscope",
            dependencies: ["AXKit"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        ),
        .testTarget(
            name: "AXKitTests",
            dependencies: ["AXKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)