// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardMini",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "ClipboardMini",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
