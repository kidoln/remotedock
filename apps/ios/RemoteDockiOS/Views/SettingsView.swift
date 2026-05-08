import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var didClearClipboardHistory = false
    @State private var clearClipboardFeedbackTask: Task<Void, Never>?

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

                    Section("应用控制") {
                        Toggle("点击后移到第一位", isOn: moveActivatedRunningAppToTopBinding)
                            .tint(Color(uiColor: .systemGreen))
                            .listRowBackground(PhoneTheme.rowBackground)
                    }

                    Section("剪贴板") {
                        HStack(spacing: 12) {
                            Text("清除剪贴板历史")

                            Spacer(minLength: 16)

                            Button {
                                clearClipboardHistory()
                            } label: {
                                Image(systemName: didClearClipboardHistory ? "checkmark" : "trash")
                                    .font(.system(size: didClearClipboardHistory ? 13 : 12, weight: .semibold))
                                    .frame(width: 51, height: 31)
                                    .foregroundStyle(PhoneTheme.canvas)
                                    .background {
                                        Capsule()
                                            .fill(Color.white.opacity(didClearClipboardHistory ? 0.96 : 0.88))
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(didClearClipboardHistory ? "已清除剪贴板历史" : "清除剪贴板历史")
                        }
                        .listRowBackground(PhoneTheme.rowBackground)

                        Toggle("点击后移到第一位", isOn: movePastedClipboardItemToTopBinding)
                            .tint(Color(uiColor: .systemGreen))
                            .listRowBackground(PhoneTheme.rowBackground)

                        Picker("剪贴板字号", selection: clipboardFontSizeBinding) {
                            ForEach(PhoneClipboardFontSize.allCases) { size in
                                Text(size.title)
                                    .tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(PhoneTheme.rowBackground)
                    }

                    Section("图标大小") {
                        Picker("大小", selection: iconGridCountBinding) {
                            ForEach(PhoneIconGridCount.allCases) { count in
                                Text(count.title)
                                    .tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(PhoneTheme.rowBackground)
                    }
                }
                .foregroundStyle(.white.opacity(0.88))
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .onDisappear {
                clearClipboardFeedbackTask?.cancel()
            }
        }
    }

    private var iconGridCountBinding: Binding<PhoneIconGridCount> {
        Binding {
            appModel.settings.iconGridCount
        } set: { value in
            appModel.updateIconGridCount(value)
        }
    }

    private var movePastedClipboardItemToTopBinding: Binding<Bool> {
        Binding {
            appModel.settings.movePastedClipboardItemToTop
        } set: { value in
            appModel.updateMovePastedClipboardItemToTop(value)
        }
    }

    private var moveActivatedRunningAppToTopBinding: Binding<Bool> {
        Binding {
            appModel.settings.moveActivatedRunningAppToTop
        } set: { value in
            appModel.updateMoveActivatedRunningAppToTop(value)
        }
    }

    private var clipboardFontSizeBinding: Binding<PhoneClipboardFontSize> {
        Binding {
            appModel.settings.clipboardFontSize
        } set: { value in
            appModel.updateClipboardFontSize(value)
        }
    }

    private func clearClipboardHistory() {
        clearClipboardFeedbackTask?.cancel()
        appModel.clearLocalClipboardHistory()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.15)) {
            didClearClipboardHistory = true
        }

        clearClipboardFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.15)) {
                    didClearClipboardHistory = false
                }
                clearClipboardFeedbackTask = nil
            }
        }
    }
}
