// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "dgx-display-mac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DGXDisplay", targets: ["DGXDisplay"])
    ],
    targets: [
        .target(name: "DGXDisplayCore"),
        .executableTarget(
            name: "DGXDisplay",
            dependencies: ["DGXDisplayCore"]
        ),
        .testTarget(
            name: "DGXDisplayCoreTests",
            dependencies: ["DGXDisplayCore"]
        ),
    ]
)
