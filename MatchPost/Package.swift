// swift-tools-version: 5.9
import PackageDescription

// NOTE: This package builds and runs the main MatchPost macOS app.
//
// The Photos extensions (Sources/MatchPostProject and Sources/MatchPostEditing)
// are intentionally NOT declared as targets here: SwiftPM cannot produce loadable
// macOS .appex bundles, and the extensions also require the paid Apple Developer
// Program (App Groups + extension signing). Those source files are kept on disk as
// a blueprint for migrating to a full Xcode project when that step is taken.
let package = Package(
    name: "MatchPost",
    platforms: [.macOS(.v14)],
    targets: [
        // Main macOS app — all models, services, utilities, view models and views
        .executableTarget(
            name: "MatchPost",
            path: "Sources/MatchPost",
            resources: [
                .process("Models/MatchPost.xcdatamodeld"),
            ]
        ),

        // Tests
        .testTarget(
            name: "MatchPostTests",
            dependencies: ["MatchPost"],
            path: "Tests/MatchPostTests"
        ),
    ]
)
