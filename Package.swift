// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ESimSDK",
    products: [
        .library(name: "ESimSDK", targets: ["ESimSDKKit"]),
        .library(name: "ESimShared", targets: ["ESimShared"])
    ],
    dependencies: [
        .package(url: "https://github.com/zendesk/sdk_messaging_ios", from: "2.25.0"),
        .package(url: "https://github.com/zendesk/sdk_zendesk_ios", from: "3.3.0")
    ],
    targets: [
        .binaryTarget(
            name: "ESimSDKBinary",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release-ios/com/netcetera/esim/ESimSDK/0.0.43/ESimSDK-0.0.43-xcframework.zip",
            checksum: "ad63993b2c1c6765312efd561e6d11abd838e1995ec420390f7044b4a547ffd6"
        ),
        .binaryTarget(
            name: "ESimShared",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release/com/netcetera/esim/esim-shared-sdk-ios/0.0.43/esim-shared-sdk-ios-0.0.43-xcframework.zip",
            checksum: "11edc22c2374c44c37ee12b0e5e1c7e8848900c5e6e5e5145bdee55992bf7f56"
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
