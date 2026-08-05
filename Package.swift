// swift-tools-version: 6.2

import Foundation
import PackageDescription

private func selectedDeveloperDirectory() -> String {
    if let explicitDirectory = ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
       !explicitDirectory.isEmpty {
        return explicitDirectory
    }

    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    process.arguments = ["-p"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fatalError("Unable to query the active developer directory: \(error)")
    }

    let data = output.fileHandleForReading.readDataToEndOfFile()
    let directory = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0, !directory.isEmpty else {
        fatalError("xcode-select did not return an active developer directory")
    }
    return directory
}

private let testingLibraryPath = URL(
    fileURLWithPath: selectedDeveloperDirectory()
).appendingPathComponent("Library/Developer/usr/lib").path

let package = Package(
    name: "MouseFix",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            exact: "6.3.2"
        ),
    ],
    targets: [
        .target(
            name: "MouseFixCore",
            dependencies: ["Yams"],
            path: "Sources/MouseFixCore"
        ),
        .target(
            name: "MouseFixHIDBridge",
            path: "Sources/MouseFixHIDBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "MouseFix",
            dependencies: ["MouseFixCore", "MouseFixHIDBridge"],
            path: "Sources/MouseFix"
        ),
        .executableTarget(
            name: "MouseFixCoreChecks",
            dependencies: ["MouseFixCore"],
            path: "Tests/MouseFixCoreChecks"
        ),
        .testTarget(
            name: "MouseFixTests",
            dependencies: [
                "MouseFix",
                "MouseFixCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/MouseFixTests",
            linkerSettings: [
                .unsafeFlags([
                    "-L", testingLibraryPath,
                    "-Xlinker", "-rpath",
                    "-Xlinker", testingLibraryPath,
                ]),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
