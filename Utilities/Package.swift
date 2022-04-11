// swift-tools-version:5.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Utilities",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "metal-data-type-tools", targets: ["MetalDataTypeTools"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MetalDataTypeTools",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ])
    ]
)
