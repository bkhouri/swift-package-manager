// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Dep1-Apache2.0",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Dep1-Apache2.0",
            targets: ["Dep1-Apache2.0"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Dep1-Apache2.0"
        ),
        .testTarget(
            name: "Dep1Tests",
            dependencies: ["Dep1-Apache2.0"]
        ),
    ],
)
