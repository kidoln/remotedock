import SwiftUI

struct DockView: View {
    @EnvironmentObject private var appModel: RemoteDockClientStore

    private let columns = [
        GridItem(.adaptive(minimum: 96, maximum: 132), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(appModel.dock.apps) { app in
                        Button {
                            appModel.activate(app)
                        } label: {
                            VStack(spacing: 10) {
                                AppIconView(title: app.displayName, isActive: appModel.dock.lastActivatedAppId == app.id)

                                Text(app.displayName)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 36)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Dock")
            .safeAreaInset(edge: .top) {
                ConnectionBanner()
            }
        }
    }
}
