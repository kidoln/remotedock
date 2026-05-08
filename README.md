# E Remote Dock

Apple-only remote companion for controlling a Mac from an iPhone.

Current implementation follows `docs/1_development-spec.md` Phase 0:

- `RemoteDock.xcworkspace` with macOS and iOS app schemes.
- Shared Swift packages under `packages/shared`.
- Platform-neutral models, protocol envelopes, command payloads, storage interfaces, and clipboard history rules.
- `TransportSession` abstraction with `MockTransportSession` and a scaffolded `MultipeerTransportSession`.
- macOS menu bar app skeleton with pinned apps, running apps, clipboard monitoring, permission status, and command execution boundaries.
- iOS SwiftUI app skeleton with Dock, Running, Clipboard, and Settings tabs driven by mock data.

## Build

```sh
rtk swift test --package-path packages/shared
rtk xcodebuild -workspace RemoteDock.xcworkspace -scheme RemoteDockMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -workspace RemoteDock.xcworkspace -scheme RemoteDockiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Next Iteration

Phase 1 should replace the mock session at the app boundary with real MultipeerConnectivity discovery and pairing, while keeping UI and feature stores behind the existing transport protocol.
