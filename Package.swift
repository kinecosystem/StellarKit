// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StellarKit",
    products: [
        .library(
            name: "StellarKit",
            targets: ["StellarKit"]),
    ],
    dependencies: [
	.package(url: "kin-util-ios", from: "0.0.3")
    ],
    targets: [
	.target(
	    name: "StellarKit",
	    dependencies: ["KinUtil"]),
    ]
)

