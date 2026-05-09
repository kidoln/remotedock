import RemoteDockCore
import RemoteDockTransport
import SwiftUI

struct ConnectionBanner: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)

            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)

            Spacer()

            if case .disconnected = appModel.discovery.connectionState {
                Button {
                    appModel.reconnect()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(PhoneTheme.bannerBackground)
    }

    private var title: String {
        switch appModel.discovery.connectionState {
        case .idle:
            language.localizedString("ios.connection.waitingForMac")
        case .discovering:
            language.localizedString("ios.connection.discoveringMac")
        case .connecting:
            language.localizedString("connection.connecting")
        case let .connected(peer):
            language.formattedLocalizedString("connection.connected", peer.displayName)
        case .reconnecting:
            language.localizedString("connection.reconnecting")
        case .disconnected:
            language.localizedString("connection.disconnected")
        case let .failed(message):
            message
        }
    }

    private var language: RemoteDockLanguage {
        appModel.settings.remoteLanguage
    }

    private var symbol: String {
        switch appModel.discovery.connectionState {
        case .connected:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        default:
            "antenna.radiowaves.left.and.right"
        }
    }

    private var color: Color {
        switch appModel.discovery.connectionState {
        case .connected:
            .green
        case .failed:
            .orange
        default:
            .secondary
        }
    }
}
