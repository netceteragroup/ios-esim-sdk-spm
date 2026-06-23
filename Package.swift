// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ESimSDK",
    products: [
        .library(
            name: "ESimSDK",
            targets: ["ESimSDK"]
        ),
        .library(
            name: "ESimShared",
            targets: ["ESimShared"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "ESimSDK",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release-ios/com/netcetera/esim/ESimSDK/0.0.22/ESimSDK-0.0.22-xcframework.zip",
            checksum: "4a12afb0192f1d1b2f3586880edf4673de785748722dc2a5a04e71b721400071"
        ),
        .binaryTarget(
            name: "ESimShared",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release/com/netcetera/esim/esim-shared-sdk-ios/0.0.22/esim-shared-sdk-ios-0.0.22-xcframework.zip",
            checksum: "752171e74582af51e9a08d2ceff635b1227db8de9c85f41656a5ab52c534df59"
        )
    ],
    swiftLanguageModes: [.v6]
)
