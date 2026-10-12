// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spike",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.5"),
    ],
    targets: [
        .executableTarget(name: "Spike", dependencies: ["FluidAudio"]),
    ]
)
