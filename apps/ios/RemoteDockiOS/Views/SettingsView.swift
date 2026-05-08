import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    var body: some View {
        NavigationStack {
            List {
                Section("Mac") {
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
                    }

                    Button {
                        appModel.reconnect()
                    } label: {
                        Label("重连", systemImage: "arrow.clockwise")
                    }
                }

                Section("同步") {
                    Toggle("剪贴板历史", isOn: $appModel.settings.clipboardSyncEnabled)
                    Toggle("粘贴前确认", isOn: $appModel.settings.pasteConfirmationEnabled)
                }

                Section("隐私") {
                    Label("文本历史仅在已配对设备间同步", systemImage: "lock")
                    Label("图片、文件、富文本不在 MVP 范围", systemImage: "doc.plaintext")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
