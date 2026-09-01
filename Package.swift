// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiquidCalc",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LiquidCalcCore",
            targets: ["LiquidCalcCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LiquidCalcCore",
            dependencies: [],
            path: "LiquidCalc",
            sources: [
                "Core",
                "Models",
                "ViewModels"
            ]
        ),
        .testTarget(
            name: "LiquidCalcTests",
            dependencies: ["LiquidCalcCore"],
            path: "LiquidCalcTests"
        ),
    ]
)
