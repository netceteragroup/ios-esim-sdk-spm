// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ESimSDK",
    products: [
        .library(name: "ESimSDK", targets: ["ESimSDKKit"]),
        .library(name: "ESimShared", targets: ["ESimShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/zendesk/sdk_messaging_ios", exact: "2.40.0"),
        .package(url: "https://github.com/zendesk/sdk_zendesk_ios", exact: "3.18.0")
    ],
    targets: [
        .binaryTarget(
            name: "ESimSDKBinary",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release-ios/com/netcetera/esim/ESimSDK/0.0.45/ESimSDK-0.0.45-xcframework.zip",
            checksum: "7046db037403fcd6b78965f3dcb9af8976d00c7eacc3c215479c73ff4325225d"
        ),
        .binaryTarget(
            name: "ESimShared",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release/com/netcetera/esim/esim-shared-sdk-ios/0.0.45/esim-shared-sdk-ios-0.0.45-xcframework.zip",
            checksum: "e7c17a051f1062da325da8cd0c970f4eb6b5608b2de92e16300d12e9507f3bb5"
        ),
        .target(
            name: "ESimSDKKit",
            dependencies: [
                "ESimSDKBinary",
                "ESimShared",
                .product(name: "ZendeskSDKMessaging", package: "sdk_messaging_ios"),
                .product(name: "ZendeskSDK", package: "sdk_zendesk_ios")
            ],
            path: "Sources/ESimSDKKit"
        )
    ],
    swiftLanguageModes: [.v6]
)
