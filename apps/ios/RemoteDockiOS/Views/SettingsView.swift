import RemoteDockCore
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore
    @State private var didClearClipboardHistory = false
    @State private var clearClipboardFeedbackTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                PhonePageBackground()

                PhonePageSurface {
                    List {
                        Section("Mac") {
                            if appModel.discovery.availableMacs.isEmpty {
                                Label(language.localizedString("ios.settings.mac.searching"), systemImage: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.white.opacity(0.72))
                                    .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
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
                                .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                            }

                            Button {
                                appModel.reconnect()
                            } label: {
                                Label(language.localizedString("action.reconnect"), systemImage: "arrow.clockwise")
                            }
                            .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))

                            if appModel.isConnected {
                                Button(role: .destructive) {
                                    appModel.disconnectFromMac()
                                } label: {
                                    Label(language.localizedString("action.disconnect"), systemImage: "xmark.circle")
                                }
                                .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                            }
                        }

                        if let pairingCode = appModel.pairingCode {
                            Section(language.localizedString("ios.settings.pairing.section")) {
                                Label(language.formattedLocalizedString("ios.settings.pairing.connectedCode", pairingCode), systemImage: "key")
                                    .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))

                                Label(language.formattedLocalizedString("ios.settings.mac.version", macVersionText), systemImage: "desktopcomputer")
                                    .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                            }
                        }

                        Section(language.localizedString("ios.settings.appControl.section")) {
                            Toggle(language.localizedString("ios.settings.moveToTopAfterTap"), isOn: moveActivatedRunningAppToTopBinding)
                                .tint(Color(uiColor: .systemGreen))
                                .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                        }

                        Section(language.localizedString("settings.pane.clipboard")) {
                            HStack(spacing: 12) {
                                Text(language.localizedString("ios.settings.clipboard.clearHistory"))

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
                                .accessibilityLabel(
                                    didClearClipboardHistory
                                        ? language.localizedString("ios.settings.clipboard.cleared")
                                        : language.localizedString("ios.settings.clipboard.clearHistory")
                                )
                            }
                            .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))

                            Toggle(language.localizedString("ios.settings.moveToTopAfterTap"), isOn: movePastedClipboardItemToTopBinding)
                                .tint(Color(uiColor: .systemGreen))
                                .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))

                            Picker(language.localizedString("ios.settings.clipboard.fontSize"), selection: clipboardFontSizeBinding) {
                                ForEach(PhoneClipboardFontSize.allCases) { size in
                                    Text(size.title(for: language))
                                        .tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                        }

                        Section(language.localizedString("ios.settings.iconSize.section")) {
                            Picker(language.localizedString("ios.settings.iconSize.picker"), selection: iconGridCountBinding) {
                                ForEach(PhoneIconGridCount.allCases) { count in
                                    Text(count.title(for: language))
                                        .tag(count)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(PhoneTheme.panelBackground.opacity(0.80))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .background(Color.clear)
                }
            }
            .navigationBarHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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

    private var macVersionText: String {
        appModel.pairedMacAppVersion ?? language.localizedString("value.unknown")
    }

    private var language: RemoteDockLanguage {
        appModel.settings.remoteLanguage
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
