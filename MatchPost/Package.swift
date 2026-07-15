// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MatchPost",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MatchPostCore", targets: ["MatchPostCore"]),
    ],
    targets: [
        // Shared library: CoreData models, services, utilities
        .target(
            name: "MatchPostCore",
            path: "Sources/MatchPostCore",
            resources: [
                .process("Models/MatchPost.xcdatamodeld"),
            ]
        ),

        // Main macOS app
        .executableTarget(
            name: "MatchPost",
            dependencies: ["MatchPostCore"],
            path: "Sources/MatchPost",
            resources: [
                .process("Resources"),
            ]
        ),

        // Photos Project Extension (File → Create → MatchPost in Photos.app)
        .target(
            name: "MatchPostProject",
            dependencies: ["MatchPostCore"],
            path: "Sources/MatchPostProject"
        ),

        // Photos Editing Extension (Edit mode → ··· → MatchPost in Photos.app)
        .target(
            name: "MatchPostEditing",
            dependencies: ["MatchPostCore"],
            path: "Sources/MatchPostEditing"
        ),

        // Tests
        .testTarget(
            name: "MatchPostTests",
            dependencies: ["MatchPostCore"],
            path: "Tests/MatchPostTests"
        ),
    ]
)
