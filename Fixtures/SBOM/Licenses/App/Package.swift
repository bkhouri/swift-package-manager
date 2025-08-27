// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "App",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "App",
            targets: ["App"]
        ),
    ],
    dependencies: [
        .package(path: "../Dep1-Apache2.0"),
        .package(path: "../Dep2-GPLv2"),
        .package(path: "../DepWithNoProducts-ISC"),
        .package(path: "../Dep3-BSD3"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["App"]
        ),
    ]
)
