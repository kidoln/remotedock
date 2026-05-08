import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        NavigationStack {
            PhonePageSurface {
                List {
                    Section("Mac") {
                        if appModel.discovery.availableMacs.isEmpty {
                            Label("正在搜索同一网络附近的 Mac", systemImage: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.white.opacity(0.62))
                                .listRowBackground(PhoneTheme.rowBackground)
                        }

                        ForEach(appModel.discovery.availableMacs) { peer in
                            Button {
                                appModel.connect(to: peer)
                            } label: {
                                HStack {
                                    Label(peer.displayName, systemImage: "desktopcomputer")
                                    Spacer()
                                    if appModel.settings.selectedMacId == peer.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .listRowBackground(PhoneTheme.rowBackground)
                        }

                        Button {
                            appModel.reconnect()
                        } label: {
                            Label("重连", systemImage: "arrow.clockwise")
                        }
                        .listRowBackground(PhoneTheme.rowBackground)

                        if appModel.isConnected {
                            Button(role: .destructive) {
                                appModel.disconnectFromMac()
                            } label: {
                                Label("断开连接", systemImage: "xmark.circle")
                            }
                            .listRowBackground(PhoneTheme.rowBackground)
                        }
                    }

                    if let pairingCode = appModel.pairingCode {
                        Section("配对") {
                            Label("已连接，Mac 配对码 \(pairingCode)", systemImage: "key")
                                .listRowBackground(PhoneTheme.rowBackground)
                        }
                    }

                    Section("同步") {
                        Toggle("剪贴板历史", isOn: $appModel.settings.clipboardSyncEnabled)
                            .listRowBackground(PhoneTheme.rowBackground)
                        Toggle("粘贴前确认", isOn: $appModel.settings.pasteConfirmationEnabled)
                            .listRowBackground(PhoneTheme.rowBackground)
                    }

                    Section("隐私") {
                        Label("文本历史仅在已配对设备间同步", systemImage: "lock")
                            .listRowBackground(PhoneTheme.rowBackground)
                        Label("图片、文件、富文本不在 MVP 范围", systemImage: "doc.plaintext")
                            .listRowBackground(PhoneTheme.rowBackground)
                    }
                }
                .foregroundStyle(.white.opacity(0.88))
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
        }
    }
}
