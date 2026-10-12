// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DimmelaCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "DimmelaCore", targets: ["DimmelaCore"]),
    ],
    targets: [
        .target(name: "DimmelaCore"),
        .testTarget(name: "DimmelaCoreTests", dependencies: ["DimmelaCore"]),
    ]
)
