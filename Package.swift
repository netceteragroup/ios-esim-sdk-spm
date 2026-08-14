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
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release-ios/com/netcetera/esim/ESimSDK/0.0.44/ESimSDK-0.0.44-xcframework.zip",
            checksum: "0165c9044eeeb2d0eeb4da7689e3d30fe72247315185a3bdc69075a608303261"
        ),
        .binaryTarget(
            name: "ESimShared",
            url: "https://repo.netcetera.com/nexus/repository/internal-repository-release/com/netcetera/esim/esim-shared-sdk-ios/0.0.44/esim-shared-sdk-ios-0.0.44-xcframework.zip",
            checksum: "3e54ab44a9f6f408e957bfe5a7b33a2c544c8f0ecadc51fd05a36d7859fc4810"
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
