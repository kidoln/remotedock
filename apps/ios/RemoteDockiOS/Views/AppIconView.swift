import SwiftUI
import UIKit

struct AppIconView: View {
    var title: String
    var isActive: Bool
    var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            iconContent
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isActive ? Color.green.opacity(0.75) : Color.white.opacity(0.12), lineWidth: isActive ? 2 : 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)

            if isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle().stroke(Color(red: 0.055, green: 0.058, blue: 0.067), lineWidth: 2)
                    }
                    .offset(x: 2, y: 2)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconContent: some View {
        if let image {
            Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.15, blue: 0.17),
                                Color(red: 0.075, green: 0.085, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.36))
            }
        }
    }
}

struct PhonePageSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            PhonePageBackground()
            content
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(PhoneTheme.accent)
    }
}

struct PhonePageBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                PhoneTheme.canvas

                RoundedRectangle(cornerRadius: 52, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.14, blue: 0.18).opacity(0.72))
                    .frame(width: width * 1.18, height: height * 0.32)
                    .rotationEffect(.degrees(-17))
                    .offset(x: -width * 0.18, y: -height * 0.38)

                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(Color(red: 0.15, green: 0.12, blue: 0.17).opacity(0.58))
                    .frame(width: width * 0.92, height: height * 0.30)
                    .rotationEffect(.degrees(19))
                    .offset(x: width * 0.28, y: height * 0.02)

                RoundedRectangle(cornerRadius: 58, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.15, blue: 0.12).opacity(0.58))
                    .frame(width: width * 1.08, height: height * 0.28)
                    .rotationEffect(.degrees(-9))
                    .offset(x: -width * 0.16, y: height * 0.35)

                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.14, blue: 0.10).opacity(0.36))
                    .frame(width: width * 0.76, height: height * 0.20)
                    .rotationEffect(.degrees(27))
                    .offset(x: width * 0.34, y: -height * 0.20)

                Color.black.opacity(0.32)
            }
            .ignoresSafeArea()
        }
    }
}

struct PhonePanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(PhoneTheme.panelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

struct PhoneIconWellBackground: View {
    var isActive: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isActive ? PhoneTheme.activeIconWellBackground : PhoneTheme.iconWellBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isActive ? Color.green.opacity(0.24) : Color.white.opacity(0.055), lineWidth: 1)
            }
    }
}

struct PhoneEmptyState: View {
    var title: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.56))

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.64))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .background(PhonePanelBackground())
        .padding(16)
    }
}

enum PhoneTheme {
    static let canvas = Color(red: 0.028, green: 0.030, blue: 0.036)
    static let accent = Color(red: 0.58, green: 0.70, blue: 0.72)
    static let panelBackground = Color(red: 0.085, green: 0.092, blue: 0.106)
    static let iconWellBackground = Color(red: 0.078, green: 0.084, blue: 0.096)
    static let activeIconWellBackground = Color(red: 0.095, green: 0.112, blue: 0.112)
    static let rowBackground = Color(red: 0.088, green: 0.096, blue: 0.110)
    static let rowSeparator = Color.white.opacity(0.055)
    static let bannerBackground = Color(red: 0.065, green: 0.070, blue: 0.082)
}
