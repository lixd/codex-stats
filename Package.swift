// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexStats",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexStatsCore", targets: ["CodexStatsCore"]),
        .executable(name: "codex-stats-report", targets: ["CodexStatsReport"])
    ],
    targets: [
        .target(name: "CodexStatsCore", path: "Sources/Core"),
        .executableTarget(name: "CodexStatsReport", dependencies: ["CodexStatsCore"], path: "Sources/Report"),
        .testTarget(name: "CodexStatsCoreTests", dependencies: ["CodexStatsCore"], path: "Tests/CodexStatsCoreTests", resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)

#if os(macOS)
package.products.append(.executable(name: "codex-stats-app", targets: ["CodexStatsApp"]))
package.targets.append(.executableTarget(name: "CodexStatsApp", dependencies: ["CodexStatsCore"], path: "Sources/App"))
#endif
