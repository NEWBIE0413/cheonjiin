// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CheonjiinCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CheonjiinCore", targets: ["CheonjiinCore"])],
    targets: [
        .target(name: "CheonjiinCore"),
        .testTarget(name: "CheonjiinCoreTests", dependencies: ["CheonjiinCore"]),
    ]
)
