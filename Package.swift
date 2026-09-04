// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "QuickJaso",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "QuickJasoCore", targets: ["QuickJasoCore"]),
        .executable(name: "QuickJaso", targets: ["QuickJaso"])
    ],
    targets: [
        .target(
            name: "QuickJasoCore",
            path: "Sources/QuickJasoCore"
        ),
        .executableTarget(
            name: "QuickJaso",
            dependencies: ["QuickJasoCore"],
            path: "Sources/QuickJaso"
        ),
        .testTarget(
            name: "QuickJasoCoreTests",
            dependencies: ["QuickJasoCore"],
            path: "Tests/QuickJasoCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
