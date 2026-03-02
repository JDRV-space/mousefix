// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MouseFix",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "MouseFix",
            dependencies: ["Yams"],
            path: "Sources/MouseFix"
        ),
    ]
)
