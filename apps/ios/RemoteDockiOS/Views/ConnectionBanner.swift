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
            "等待发现 Mac"
        case .discovering:
            "正在发现 Mac"
        case .connecting:
            "正在连接"
        case let .connected(peer):
            "已连接 \(peer.displayName)"
        case .reconnecting:
            "正在重连"
        case .disconnected:
            "已断开"
        case let .failed(message):
            message
        }
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
