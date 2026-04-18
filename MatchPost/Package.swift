// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MatchPost",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MatchPost",
            path: "Sources/MatchPost",
            resources: [
                .process("Resources"),
                .process("Models/MatchPost.xcdatamodeld"),
            ]
        ),
        .testTarget(
            name: "MatchPostTests",
            dependencies: ["MatchPost"],
            path: "Tests/MatchPostTests"
        ),
    ]
)
