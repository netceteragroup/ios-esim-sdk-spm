# eSIM SDK for iOS — Partner Integration Guide

`ESimSDK` is the iOS distribution of the Netcetera eSIM SDK. It ships as a **Swift Package**
that wraps a precompiled `ESimShared.xcframework` (Kotlin Multiplatform) and renders the
**complete** eSIM journey — browsing, checkout, installation, diagnostics and support.

Your app is responsible for exactly three things:

1. **Authentication** — supply a *subject token* identifying the current user.
2. **Payment** — present your own checkout when the SDK hands payment back to you.
3. **Result handling** — react to the terminal flow result.

---

## Table of contents

1. [Requirements](#1-requirements)
2. [Installation](#2-installation)
3. [Architecture at a glance](#3-architecture-at-a-glance)
4. [Quick start](#4-quick-start)
5. [Integration steps in detail](#5-integration-steps-in-detail)
6. [Configuration reference](#6-configuration-reference)
7. [Theming](#7-theming)
8. [Content overrides (texts, images, FAQ)](#8-content-overrides-texts-images-faq)
9. [Localization](#9-localization)
10. [Permissions & privacy](#10-permissions--privacy)
11. [Security](#11-security)
12. [Troubleshooting](#12-troubleshooting)
13. [API reference summary](#13-api-reference-summary)
14. [FAQ](#14-faq)
- [Document changelog](#document-changelog)

---

## 1. Requirements

| Requirement           | Value                                                        |
|-----------------------|--------------------------------------------------------------|
| iOS deployment target | **iOS 17+**                                                  |
| Xcode                 | **16+**                                                      |
| Swift tools / mode    | `swift-tools-version: 6.1`, Swift language mode **6**        |
| UI                    | SwiftUI + UIKit; a **`UINavigationController`** in your app  |
| Backend               | A reachable eSIM backend URL (test and/or production)        |
| Subject token         | Your app/backend must be able to issue one                   |
| Zendesk               | A Zendesk Messaging **channel key** (for the Support screen) |

> The SDK is **`@MainActor`-bound**. Create and call `ESimCoordinator` from the main actor only.

---

## 2. Installation

Add **ESimSDK** as a Swift Package dependency:

- **Xcode:** *File ▸ Add Package Dependencies…* → point to the `ESimSDK` package
  (distribution URL, or the local `ios-sdk/ESimSDK` folder when working inside this repository).
- **Package.swift:**

  ```swift
  dependencies: [
      .package(url: "<esim-sdk-package-url>", from: "0.0.39"),
  ],
  targets: [
      .target(name: "YourApp", dependencies: [
          .product(name: "ESimSDK", package: "ESimSDK"),
      ]),
  ]
  ```

The package vends a single product, **`ESimSDK`** (a **static** library). It re-exports the
underlying `ESimShared` framework, so a single import is enough:

```swift
import ESimSDK
```

### Transitive dependencies

| Dependency | Version | Why |
|---|---|---|
| `ESimShared.xcframework` | bundled binary target | Shared KMP business logic, networking, view models. |
| [`zendesk/sdk_messaging_ios`](https://github.com/zendesk/sdk_messaging_ios) (`ZendeskSDKMessaging`) | `>= 2.25.0` | In-app support chat on the Support screen. |

> ℹ️ **Building from source in this repository:** the Xcode schemes run a pre-build script that
> compiles the XCFramework and generates `ios-sdk/ESimSDK/Sources/Resources` (git-ignored). If you
> build the package outside those schemes, run `./gradlew :shared:generateIosResources` first.
> See [`../iosApp/README.md`](../iosApp/README.md).

---

## 3. Architecture at a glance

```text
┌──────────────┐   subject token    ┌──────────────┐   session token   ┌──────────────┐
│   Your app   │ ─────────────────▶ │   eSIM SDK   │ ────────────────▶ │ eSIM backend │
│   (host)     │                    │ (UI + logic) │                   │              │
│              │ ◀───────────────── │              │ ◀──────────────── │              │
└──────────────┘  payment handoff   └──────────────┘   eSIM data       └──────────────┘
        │          + flow result              ▲
        └────────── your payment screen ──────┘
```

`ESimCoordinator` is the single public entry point. It pushes and presents SDK screens on the
`UINavigationController` you hand it, and communicates back to you through three **Combine
subjects** you own:

| Subject | Type | Emitted when |
|---|---|---|
| `onPaymentCallBackSubject` | `PassthroughSubject<String, Never>` | The user confirmed checkout. Payload is the **payment request token**. |
| `onTriggerSessionReAuthenticationSubject` | `PassthroughSubject<Void, Never>` | The session expired and a fresh subject token is required. |
| `onFlowFinishedSubject` | `PassthroughSubject<ESimFlowResult, Never>` | The flow terminated (completed / cancelled / failed). |

---

## 4. Quick start

```swift
import UIKit
import SwiftUI
import Combine
import ESimSDK

@MainActor
final class EsimIntegration {

    private let navigationController: UINavigationController
    private var coordinator: ESimCoordinator?
    private var subscribers = Set<AnyCancellable>()

    private let onPayment = PassthroughSubject<String, Never>()
    private let onReauth  = PassthroughSubject<Void, Never>()
    private let onFinish  = PassthroughSubject<ESimFlowResult, Never>()

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        subscribe()
    }

    private func subscribe() {
        onPayment
            .sink { [weak self] requestToken in self?.presentPayment(requestToken: requestToken) }
            .store(in: &subscribers)

        onReauth
            .sink { [weak self] in self?.provideFreshSubjectToken() }
            .store(in: &subscribers)

        onFinish
            .sink { result in print("eSIM flow finished: \(result)") }
            .store(in: &subscribers)
    }

    func startESimFlow(subjectToken: String) {
        let backendConfig = SdkBackendConfig(
            prodBaseUrl: "https://esim.example.com",
            testBaseUrl: "https://esim-test.example.com",
            activeEnvironment: .test          // use .prod for release builds
        )

        let platformOptions = PlatformOptions(
            httpLoggingEnabled: false,        // never enable in production
            connectTimeoutMillis: PlatformOptions.companion.DEFAULT_CONNECT_TIMEOUT_MS,
            requestTimeoutMillis: PlatformOptions.companion.DEFAULT_REQUEST_TIMEOUT_MS,
            socketTimeoutMillis: PlatformOptions.companion.DEFAULT_REQUEST_TIMEOUT_MS,
            retryPolicy: RetryPolicy.companion.NONE,
            userAgentSuffix: "PartnerApp/2.1",
            certificatePinning: nil
        )

        let coordinator = ESimCoordinator(
            theme: DefaultESimTheme(),        // or your own ESimTheme
            screenOverrides: .init(texts: [:], images: [:], faq: .none),
            liquidGlassEnabled: true,
            backendConfig: backendConfig,
            platformOptions: platformOptions,
            zendeskConfig: ZendeskConfig(channelKey: "<zendesk-channel-key>"),
            onPaymentCallBackSubject: onPayment,
            onTriggerSessionReAuthenticationSubject: onReauth,
            onFlowFinishedSubject: onFinish
        )
        self.coordinator = coordinator

        coordinator.start(subjectToken: subjectToken,
                          navigationController: navigationController)
    }
}
```

> ⚠️ **Keep a strong reference to the coordinator** for the lifetime of the flow. If it is
> deallocated, navigation callbacks stop firing.

---

## 5. Integration steps in detail

### 5.1 Start the flow

```swift
coordinator.start(subjectToken: subjectToken, navigationController: navigationController)
```

- `subjectToken` — an opaque token from your backend/auth layer identifying the user. The SDK
  exchanges it for an internal session token. It must be **non-empty**.
- `navigationController` — the SDK records the current `topViewController` as the entry point and
  pushes its screens on top of this stack.

### 5.2 Handle the payment handoff

When the user confirms checkout, the SDK emits a **payment request token** on
`onPaymentCallBackSubject` and expects you to run your own payment UI:

```swift
private func presentPayment(requestToken: String) {
    let checkout = MyCheckoutView(
        requestToken: requestToken,
        onStartProcessing: { [weak self] in
            // Optional: tell the backend the partner started processing the payment.
            self?.coordinator?.acknowledgePaymentProcessing()
        },
        onFinish: { [weak self] status in
            self?.coordinator?.resume(paymentStatus: status)
        }
    )
    let vc = UIHostingController(rootView: checkout)
    navigationController.pushViewController(vc, animated: true)  // same navigation stack!
}
```

> ⚠️ **Use the same `UINavigationController`** you passed to `start(...)`. Pushing the payment
> screen onto a different stack (e.g. a SwiftUI `NavigationStack`) breaks the SDK's ability to
> resume and dismiss screens.

### 5.3 Resume the flow

```swift
coordinator.resume(paymentStatus: .success(confirmationToken: token))
coordinator.resume(paymentStatus: .cancelled)
coordinator.resume(paymentStatus: .failure)
```

| Status | Payload | SDK behaviour |
|---|---|---|
| `.success(confirmationToken:)` | Confirmation token from your payment backend. | Persists the payment data and shows the **purchase complete** screen. |
| `.cancelled` | — | Pops back to the **checkout** screen. |
| `.failure` | — | Shows the **purchase failed** screen. |

`acknowledgePaymentProcessing()` is optional and idempotent-safe: it reports "partner is processing
this payment" to the backend for the current payment id. Failures are logged, never surfaced.

### 5.4 Handle session re-authentication

```swift
private func provideFreshSubjectToken() {
    Task { @MainActor [weak self] in
        let token = try? await myAuthService.fetchSubjectToken()
        self?.coordinator?.reAuthenticate(subjectToken: token ?? "")
    }
}
```

The SDK emits on `onTriggerSessionReAuthenticationSubject` whenever the session expires mid-flow.
Re-auth is lightweight — it is just another subject-token exchange.

### 5.5 Handle the flow result

`ESimFlowResult` is a SKIE-exposed sealed type of the shared `FlowResult`, so it can be exhaustively
switched in Swift:

```swift
onFinish
    .sink { result in
        switch result {
        case .completed(let completed):  // completed.step
            print("Completed at step: \(completed.step)")
        case .cancelled(let cancelled):  // cancelled.screen
            print("Cancelled at: \(cancelled.screen)")
        case .failed(let failed):        // failed.error
            print("Failed: \(failed.error.reason) — \(failed.error.message)")
        }
    }
    .store(in: &subscribers)
```

| Case | Meaning | Payload |
|---|---|---|
| `.completed` | The user finished a stage of the flow. | `step: CompletedStep` — `PAYMENT`, `ACTIVATION_THIS_DEVICE`, `ACTIVATION_OTHER_DEVICE` |
| `.cancelled` | The user dismissed the flow. | `screen: CancelledAt` — `WELCOME`, `UNSUPPORTED_DEVICE`, `BROWSE_SELECTION`, `PACKAGE_SELECTION`, `CHECKOUT`, `PAYMENT_FAILED`, `INSTALL`, `PACKAGES_OVERVIEW`, `UNKNOWN` |
| `.failed` | Unrecoverable error. | `error: FlowError(reason:message:)` — `AUTHENTICATION_FAILED`, `SESSION_EXPIRED`, `NETWORK_ERROR`, `INTERNAL_ERROR` |

> `CompletedStep` is an **ephemeral UI hint** for the current session (banner, analytics). The
> **eSIM backend is the source of truth** for order and provisioning state.
> `FlowError.message` is for **logs**, never for end users.

---

## 6. Configuration reference

### 6.1 `SdkBackendConfig`

| Property | Type | Required | Description |
|---|---|---|---|
| `prodBaseUrl` | `String` | ✅ | Production backend root URL. |
| `testBaseUrl` | `String?` | ⚠️ | Test backend root URL. **Required when** `activeEnvironment == .test`. |
| `activeEnvironment` | `SdkEnvironment` | — | `.prod` (default) or `.test`. |

The SDK derives `…/secured/api`, `…/public/api` and the resource root from the active URL.
A blank active base URL, or `.test` without a `testBaseUrl`, **throws at initialization**.

### 6.2 `PlatformOptions`

| Property | Default | Description |
|---|---|---|
| `httpLoggingEnabled` | `false` | Logs HTTP request/response metadata. **Never enable in production.** |
| `connectTimeoutMillis` | `15_000` | TCP connect timeout (ms). |
| `requestTimeoutMillis` | `30_000` | Overall call timeout (ms). |
| `socketTimeoutMillis` | = request timeout | Read/write socket timeout (ms). |
| `retryPolicy` | `RetryPolicy.companion.NONE` | Retry policy for transient failures. |
| `userAgentSuffix` | `nil` | Appended to the SDK `User-Agent` (e.g. `"PartnerApp/2.1"`). |
| `certificatePinning` | `nil` | Optional public-key pinning. |

Convenience: `PlatformOptions.companion.default()` and
`PlatformOptions.companion.withHttpLoggingEnabled(enabled:)`.

**`RetryPolicy`** — `maxRetries` (`0`), `initialDelayMillis` (`1_000`), `maxDelayMillis`
(`10_000`), `backoffMultiplier` (`2.0`; `1.0` = fixed interval).

**`CertificatePinningConfig`** — `enabled` (`true`) and `pins` in `sha256/<base64>` format:

```swift
certificatePinning: CertificatePinningConfig(
    enabled: true,
    pins: [
        "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // primary
        "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", // backup (rotation)
    ]
)
```

- Pins apply only to the SDK's **own backend hosts** derived from your base URLs.
- On mismatch the Darwin engine **rejects the TLS challenge** — the request fails by design.
- Always supply a **primary + backup** pin; a single pin logs a warning.

### 6.3 `ZendeskConfig`

```swift
ZendeskConfig(channelKey: "<zendesk-messaging-channel-key>")
```

The channel key comes from the Zendesk Admin Center and **must not be blank**. It powers the
in-app Support chat. Zendesk theming is limited — see
[`../docs/zendesk-customization.md`](../docs/zendesk-customization.md).

### 6.4 `liquidGlassEnabled`

`Bool` — enables the liquid-glass visual effect on supported screens/OS versions. Set to `false`
for a flat appearance.

---

## 7. Theming

Conform to the `ESimTheme` protocol and pass your instance to the coordinator. `DefaultESimTheme()`
is provided as a ready-made baseline, and `DefaultTokens` exposes every default token so you can
override selectively.

```swift
struct PartnerTheme: ESimTheme {
    var colorScheme: ESimColorScheme {
        ESimColorScheme(
            brand:               ColorToken(light: .init(red: 0, green: 0.53, blue: 1), dark: .blue),
            onBrand:             ColorToken(light: .white, dark: .black),
            foregroundPrimary:   DefaultTokens.Colors.foregroundPrimary,
            foregroundSecondary: DefaultTokens.Colors.foregroundSecondary,
            foregroundTertiary:  DefaultTokens.Colors.foregroundTertiary,
            tint:                DefaultTokens.Colors.tint,
            surfacePrimary:      DefaultTokens.Colors.surfacePrimary,
            surfaceSecondary:    DefaultTokens.Colors.surfaceSecondary,
            divider:             DefaultTokens.Colors.divider,
            surfaceEmphasized:   DefaultTokens.Colors.surfaceEmphasized,
            onSurfaceEmphasized: DefaultTokens.Colors.onSurfaceEmphasized,
            success:             DefaultTokens.Colors.success,
            warning:             DefaultTokens.Colors.warning,
            error:               DefaultTokens.Colors.error
        )
    }

    var typography: ESimTypography  { DefaultTokens.typography }
    var cornerRadius: ESimCornerRadius { ESimCornerRadius(buttons: 12, cards: 20) }
    var icons: ESimIcons            { DefaultTokens.icons }
    var spacings: ESimSpacings      { ESimSpacings(cardHorizontalPadding: 16) }
}
```

### Token groups

| Group | Type | Slots |
|---|---|---|
| Colors | `ESimColorScheme` of `ColorToken(light:dark:)` | `brand`, `onBrand`, `foregroundPrimary/Secondary/Tertiary`, `tint`, `surfacePrimary/Secondary`, `divider`, `surfaceEmphasized`, `onSurfaceEmphasized`, `success`, `warning`, `error` |
| Typography | `ESimTypography` of `TypographyToken(fontFamilyName:weight:size:lineHeight:letterSpacing:)` | `titleLarge/Medium/Small`, `bodyLarge`, `bodyLargeEmphasized`, `bodySmall`, `bodySmallEmphasized`, `buttonLarge`, `buttonSmall` |
| Corner radius | `ESimCornerRadius` | `buttons`, `cards` |
| Icons | `ESimIcons` | `navigationIconsWeight`, `bodyIconsWeight`, `bodyLargeIconsSize`, `bodySmallIconsSize` |
| Spacing | `ESimSpacings` | `cardHorizontalPadding` |

> **Dark mode** is handled by `ColorToken`'s `light`/`dark` pair — no separate theme needed.
> **Custom fonts:** pass the PostScript name in `fontFamilyName` and make sure the font is
> registered in *your* app bundle (`UIAppFonts`). Pass `nil` to use the system font.

---

## 8. Content overrides (texts, images, FAQ)

```swift
screenOverrides: ESimScreenOverrides(
    texts: [
        TextId.WelcomeTitle(): "Travel data, instantly",
        TextId.GlobalPleaseTryAgainLater(): "Please try again shortly",
        TextId.WelcomeFeatureTitle(index: 0): "No roaming fees",
    ],
    images: [
        ImageId.WelcomeMain(): DynamicImage(
            lightMode: PlatformImage(uiImage: UIImage(named: "welcome-light")!),
            darkMode:  PlatformImage(uiImage: UIImage(named: "welcome-dark")!)
        )
    ],
    faq: .patch(
        upserts: [0: FaqItem(/* … */)],
        removedIndices: [3],
        removedRanges: [5...6]
    )
)
```

| Override | Type | Notes |
|---|---|---|
| `texts` | `[TextId: String]` | `TextId` is a sealed hierarchy covering every overridable string slot (welcome, unsupported device, select area/package, checkout, install, purchase complete/failed, global). Indexed variants (e.g. `WelcomeFeatureTitle(index:)`) target list items. |
| `images` | `[ImageId: DynamicImage]` | `ImageId`: `WelcomeMain`, `UnsupportedMain`, `PurchaseCompleteMain`, `PurchaseFailedMain`, `InstallMain`, `ErrorMain`. Each `DynamicImage` carries a light and a dark variant. |
| `faq` | `FaqOverrides` | `.none` keeps SDK defaults. `.patch(upserts:removedIndices:removedRanges:)` replaces entries by index, appends when the index is beyond the defaults, and removes single indices or inclusive ranges. |

> Overrides are **opt-in per slot** — anything you omit keeps the SDK's localized default.

---

## 9. Localization

The SDK ships localized strings for **English (default), German, French and Italian**, and follows
the device language automatically. Any language outside that set falls back to English.
Use `screenOverrides.texts` to replace individual strings; note that a text override is a **single
literal**, so if you support multiple languages resolve the string in your app before passing it.

---

## 10. Permissions & privacy

**TL;DR: the standard flow requires no iOS permissions and no `NSUsageDescription` keys.**

| Area | What the SDK does | Permission | Prompt? |
|---|---|---|---|
| eSIM installation | Opens Apple's Universal Link `https://esimsetup.apple.com/esim_qrcode_provisioning?carddata=…` (or shows a QR code); provisioning happens in iOS Settings. | None | No |
| QR code | Generated **locally** with CoreImage (`CIQRCodeGenerator`); displayed, never scanned. | None (no camera) | No |
| "Location" | The SDK's `LocationService` is a **backend REST API** for coverage countries/regions — **not** `CoreLocation`. | None | No |
| Networking | Standard HTTPS to your eSIM backend. | None (no `NetworkExtension`) | No |
| Support chat | Zendesk Messaging (network only). | None | No |

Because iOS frameworks cannot contribute `Info.plist` keys to the host app, the SDK follows a
strict rule: **check authorization status before any protected API and degrade gracefully** rather
than risk a termination. If a future release adds an optional permission-gated capability, the
required key will be documented here — add it **only** when you enable that capability.

---

## 11. Security

- **DPoP (RFC 9449).** Secured backend calls are sender-constrained: the access token is bound to an
  in-memory ES256 key generated per session, and every request carries a fresh, single-use proof.
  This is fully automatic — you do not implement DPoP.
- **Keys are never persisted.** App eviction ⇒ the bound key is gone ⇒ the SDK asks for
  re-authentication via `onTriggerSessionReAuthenticationSubject`.
- **`AuthError` contract** (observable failure modes):

| Variant | When | What to do |
|---|---|---|
| `TokenExchangeFailed` | Token exchange rejected (invalid subject token / non-2xx). | Verify the subject token, retry the flow. |
| `BoundKeyUnavailable` | Bound key lost mid-session. | Re-authenticate with a fresh subject token. |
| `SessionInvalidated` | Backend rejected the session (`invalid_token`) or re-auth exhausted. | Re-authenticate. |
| `DpopProofRejected` | Proof stale/replayed/mismatched. Not retried. | Treat as session failure; persistent occurrences indicate a clock/binding problem. |
| `KeyGenerationFailed` / `SigningFailed` | Platform crypto failure. | Surface as generic failure; not expected. |

- **Never ship `httpLoggingEnabled: true`.**
- **Don't display raw SDK error messages** to end users.

---

## 12. API reference summary

### Entry point — `ESimCoordinator` (`@MainActor`)

| Symbol | Purpose |
|---|---|
| `init(theme:screenOverrides:liquidGlassEnabled:backendConfig:platformOptions:zendeskConfig:onPaymentCallBackSubject:onTriggerSessionReAuthenticationSubject:onFlowFinishedSubject:)` | Create and configure the coordinator (initializes SDK dependencies and Zendesk). |
| `start(subjectToken:navigationController:)` | Start the flow on the host navigation stack. |
| `resume(paymentStatus:)` | Continue after your payment screen finishes. |
| `acknowledgePaymentProcessing()` | Report to the backend that the partner started processing the current payment. |
| `reAuthenticate(subjectToken:)` | Supply a fresh subject token after session expiry. |

### Types

| Type | Purpose |
|---|---|
| `SdkBackendConfig`, `SdkEnvironment` | Backend URLs + active environment. |
| `PlatformOptions`, `RetryPolicy`, `CertificatePinningConfig` | Networking & security options. |
| `ZendeskConfig` | Support-chat channel key. |
| `ESimTheme`, `DefaultESimTheme`, `DefaultTokens` | Theming protocol, baseline theme, default tokens. |
| `ESimColorScheme`, `ESimTypography`, `ESimCornerRadius`, `ESimIcons`, `ESimSpacings`, `ColorToken`, `TypographyToken` | Design tokens. |
| `ESimScreenOverrides`, `TextId`, `ImageId`, `DynamicImage`, `PlatformImage`, `FaqOverrides`, `FaqItem` | Content overrides. |
| `PaymentStatus` (`.success(confirmationToken:)` / `.cancelled` / `.failure`) | Payment outcome you report. |
| `ESimFlowResult` (`.completed` / `.cancelled` / `.failed`) | Terminal flow outcome. |
| `CompletedStep`, `CancelledAt`, `FailureReason`, `FlowError`, `AuthError` | Result/error detail types. |
| `ESimVersionLabel` | Optional SwiftUI label rendering the running SDK version (bug reporting). |

---

## 13. FAQ

**Do I need to build any eSIM UI?**
No. The SDK renders every eSIM screen. You build only your **payment** screen.

**Where do subject tokens come from?**
From your backend / auth layer. The SDK never mints them.

**Can I run the SDK inside a SwiftUI `NavigationStack`?**
The SDK requires a `UINavigationController`. Host it (e.g. via `UIViewControllerRepresentable`) and
pass that controller to both `start(...)` and your payment screen presentation.

**Is it safe to create multiple coordinators?**
Create one per flow and keep it alive for the flow's duration. Re-initialization is guarded, but a
single coordinator instance per session is the supported pattern.

**Can the SDK be themed to match my brand?**
Yes — see [Theming](#7-theming).

