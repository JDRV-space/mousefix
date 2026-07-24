// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MouseFix",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "MouseFixCore",
            dependencies: ["Yams"],
            path: "Sources/MouseFixCore"
        ),
        .executableTarget(
            name: "MouseFix",
            dependencies: ["MouseFixCore"],
            path: "Sources/MouseFix"
        ),
        .executableTarget(
            name: "MouseFixCoreChecks",
            dependencies: ["MouseFixCore"],
            path: "Tests/MouseFixCoreChecks"
        ),
    ]
)
