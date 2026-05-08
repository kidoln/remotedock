# E Remote Dock

Apple-only remote companion for controlling a Mac from an iPhone.

Current implementation follows `docs/1_development-spec.md` Phase 0 and has started Phase 1:

- `RemoteDock.xcworkspace` with macOS and iOS app schemes.
- Shared Swift packages under `packages/shared`.
- Platform-neutral models, protocol envelopes, command payloads, storage interfaces, and clipboard history rules.
- `TransportSession` abstraction with `MockTransportSession` and a MultipeerConnectivity-backed `MultipeerTransportSession`.
- macOS menu bar app skeleton with pinned apps, running apps, clipboard monitoring, permission status, and command execution boundaries.
- iOS SwiftUI app skeleton with Dock, Running, Clipboard, and Settings tabs driven by mock data.
- macOS advertises itself over MultipeerConnectivity.
- iOS browses nearby Macs, connects, sends `hello` and `pairRequest`, then receives `pairApprove` and initial snapshots.

## Build

```sh
rtk swift test --package-path packages/shared
rtk xcodebuild -workspace RemoteDock.xcworkspace -scheme RemoteDockMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
rtk xcodebuild -workspace RemoteDock.xcworkspace -scheme RemoteDockiOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Phase 1 Notes

The macOS app uses `MultipeerTransportSession(role: .advertiser)`.

The iOS app uses `MultipeerTransportSession(role: .browser)`.

For real device testing, open `RemoteDock.xcworkspace`, set a development team for the app targets, run `RemoteDockMac` on the Mac, then run `RemoteDockiOS` on an iPhone on the same local network. The iOS Settings tab should show nearby Macs and a pairing code after connecting.

## Next Iteration

The next slice should make pairing explicit on the Mac side instead of auto-approving every invitation, then persist trusted devices through `PairedDeviceStore`.
