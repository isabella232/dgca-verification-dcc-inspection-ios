// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DCCInspection",
    defaultLocalization: "en",
    platforms: [.iOS(.v12), .macOS(.v10_14)],
    
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "DCCInspection", targets: ["DCCInspection"]),
    ],
    
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "jsonlogic", url: "https://github.com/eu-digital-green-certificates/json-logic-swift.git", from: "1.1.9"),
        .package(name: "SWCompression", url: "https://github.com/tsolomko/SWCompression.git", from: "4.7.0"),
        .package(name: "Alamofire", url: "https://github.com/Alamofire/Alamofire", from: "5.5.0"),
        .package(name: "JSONSchema", url: "https://github.com/eu-digital-green-certificates/JSONSchema.swift", .branch("master")),
        .package(name: "CertLogic", url: "https://github.com/eu-digital-green-certificates/dgc-certlogic-ios", .branch("main")),
        .package(name: "DGCBloomFilter", url: "https://github.com/eu-digital-green-certificates/dgc-bloomfilter-ios.git", .branch("main")),
        .package(name: "DGCPartialVarHashFilter", url: "https://github.com/eu-digital-green-certificates/dgca-partialvarhashfilter-ios.git", .branch("main")),
        .package(name: "DGCCoreLibrary", url: "https://github.com/eu-digital-green-certificates/dgca-verification-core-library.git", .branch("main")),
    ],
    
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "DCCInspection",
            dependencies: [
                "Alamofire",
                "jsonlogic",
                "CertLogic",
                "JSONSchema",
                "SWCompression",
                "DGCBloomFilter",
                "DGCPartialVarHashFilter",
                "DGCCoreLibrary"
            ],
            resources: [
                .copy("Resources/Assets.xcassets"),
                .copy("Resources/DCCRevocation.xcdatamodeld")
            ]
        ),
        .testTarget(name: "DCCInspectionTests",
            dependencies: ["DCCInspection"]),
    ]
)
