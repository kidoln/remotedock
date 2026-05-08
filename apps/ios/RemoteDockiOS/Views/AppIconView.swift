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
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
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
            .fill(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.clear, lineWidth: 1)
            }
    }
}

enum PhoneIconGridLayout {
    case automatic
    case portrait
    case landscape
}

struct PhoneIconGrid<Content: View>: View {
    var gridCount: PhoneIconGridCount
    var layout: PhoneIconGridLayout
    var metricsSize: CGSize?
    private let content: (_ iconSize: CGFloat) -> Content

    private let defaultSpacing: CGFloat = 18
    private let compactLandscapeSpacing: CGFloat = 10
    private let portraitEdgePadding: CGFloat = 18
    private let landscapeEdgePadding: CGFloat = 12
    private let minimumIconSize: CGFloat = 40
    private let landscapeTwoRowVisibleColumns = 4

    init(
        gridCount: PhoneIconGridCount,
        layout: PhoneIconGridLayout = .automatic,
        metricsSize: CGSize? = nil,
        @ViewBuilder content: @escaping (_ iconSize: CGFloat) -> Content
    ) {
        self.gridCount = gridCount
        self.layout = layout
        self.metricsSize = metricsSize
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = resolvedIsLandscape(for: proxy.size)
            let metricSize = metricsSize ?? proxy.size
            let count = max(1, gridCount.rawValue)
            let metrics = resolvedMetrics(
                count: count,
                isLandscape: isLandscape,
                containerSize: metricSize
            )

            ScrollView(isLandscape ? .horizontal : .vertical) {
                if isLandscape {
                    LazyHGrid(
                        rows: gridItems(count: count, size: metrics.iconSize, spacing: metrics.spacing),
                        spacing: metrics.spacing
                    ) {
                        content(metrics.iconSize)
                    }
                    .padding(metrics.edgePadding)
                } else {
                    LazyVGrid(
                        columns: gridItems(count: count, size: metrics.iconSize, spacing: metrics.spacing),
                        spacing: metrics.spacing
                    ) {
                        content(metrics.iconSize)
                    }
                    .padding(metrics.edgePadding)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func gridItems(count: Int, size: CGFloat, spacing: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.fixed(size), spacing: spacing), count: count)
    }

    private func resolvedIsLandscape(for size: CGSize) -> Bool {
        switch layout {
        case .automatic:
            size.width > size.height
        case .portrait:
            false
        case .landscape:
            true
        }
    }

    private func resolvedMetrics(
        count: Int,
        isLandscape: Bool,
        containerSize: CGSize
    ) -> (iconSize: CGFloat, spacing: CGFloat, edgePadding: CGFloat) {
        let edgePadding = isLandscape ? landscapeEdgePadding : portraitEdgePadding
        let availableWidth = max(1, containerSize.width - edgePadding * 2)
        let availableHeight = max(1, containerSize.height - edgePadding * 2)
        let shouldFitFourColumns = isLandscape && count == 2
        let spacing = resolvedSpacing(
            count: count,
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            shouldFitFourColumns: shouldFitFourColumns
        )

        let constrainedLength = isLandscape ? availableHeight : availableWidth
        let gridConstrainedSize = (constrainedLength - spacing * CGFloat(count - 1)) / CGFloat(count)
        let columnConstrainedSize: CGFloat

        if shouldFitFourColumns {
            columnConstrainedSize = (availableWidth - spacing * CGFloat(landscapeTwoRowVisibleColumns - 1)) / CGFloat(landscapeTwoRowVisibleColumns)
        } else {
            columnConstrainedSize = .greatestFiniteMagnitude
        }

        let resolvedSize = floor(min(gridConstrainedSize, columnConstrainedSize))
        return (max(minimumIconSize, resolvedSize), spacing, edgePadding)
    }

    private func resolvedSpacing(
        count: Int,
        availableWidth: CGFloat,
        availableHeight: CGFloat,
        shouldFitFourColumns: Bool
    ) -> CGFloat {
        guard shouldFitFourColumns else {
            return defaultSpacing
        }

        let heightConstrainedSize = (availableHeight - defaultSpacing * CGFloat(count - 1)) / CGFloat(count)
        let requiredWidth = heightConstrainedSize * CGFloat(landscapeTwoRowVisibleColumns)
            + defaultSpacing * CGFloat(landscapeTwoRowVisibleColumns - 1)

        return requiredWidth > availableWidth ? compactLandscapeSpacing : defaultSpacing
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
