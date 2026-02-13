// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "XSpaceBar",
    platforms: [.macOS(.v10_15)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "XSpaceBar",
            dependencies: [],
            path: "Sources",
            sources: ["main.swift"]
        )
    ]
)
