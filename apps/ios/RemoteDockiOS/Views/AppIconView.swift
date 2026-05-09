import Foundation
import SwiftUI
import UIKit

struct AppIconView: View {
    var title: String
    var isActive: Bool
    var image: UIImage? = nil

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let wellSide = side * 0.86
            let iconPadding: CGFloat = 2
            let iconSide = max(1, wellSide - iconPadding * 2)
            let activeDotSize = max(10, wellSide * 0.11)
            let activeDotStroke = max(1.5, side * 0.018)

            ZStack {
                PhoneIconWellBackground(isActive: isActive)
                    .frame(width: wellSide, height: wellSide)

                iconContent
                    .frame(width: iconSide, height: iconSide)
                    .shadow(color: Color.black.opacity(0.22), radius: max(4, side * 0.045), x: 0, y: max(2, side * 0.026))

                if isActive {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.40, green: 1.00, blue: 0.66),
                                    Color(red: 0.05, green: 0.78, blue: 0.36)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: activeDotSize, height: activeDotSize)
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.86), lineWidth: activeDotStroke)
                        }
                        .shadow(color: Color.green.opacity(0.38), radius: 7, x: 0, y: 0)
                        .position(
                            x: side / 2 + wellSide / 2 - activeDotSize * 0.62,
                            y: side / 2 + wellSide / 2 - activeDotSize * 0.62
                        )
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
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
        TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { timeline in
            GeometryReader { proxy in
                let size = proxy.size
                let width = size.width
                let height = size.height
                let phase = timeline.date.timeIntervalSinceReferenceDate
                let slowWave = CGFloat(sin(phase * 0.16))
                let midWave = CGFloat(sin(phase * 0.27 + 1.2))
                let fastWave = CGFloat(sin(phase * 0.36 + 2.1))

                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.83, blue: 0.60),
                            Color(red: 1.00, green: 0.66, blue: 0.55),
                            Color(red: 0.94, green: 0.42, blue: 0.62),
                            Color(red: 0.46, green: 0.18, blue: 0.48)
                        ],
                        startPoint: UnitPoint(x: 0.12 + slowWave * 0.06, y: 0.02),
                        endPoint: UnitPoint(x: 0.88 - midWave * 0.05, y: 0.98)
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.42),
                            Color(red: 1.00, green: 0.90, blue: 0.68).opacity(0.16),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.14 + slowWave * 0.04, y: 0.03),
                        startRadius: 0,
                        endRadius: max(width, height) * 0.72
                    )

                    lightBand(
                        in: size,
                        widthMultiplier: 1.34,
                        heightMultiplier: 0.30,
                        colors: [
                            Color.white.opacity(0.36),
                            Color(red: 1.00, green: 0.86, blue: 0.48).opacity(0.42),
                            Color.clear
                        ],
                        rotation: -15 + Double(slowWave * 3),
                        offset: CGSize(width: -width * (0.13 + midWave * 0.03), height: -height * (0.30 + fastWave * 0.025)),
                        blur: 34,
                        opacity: 0.62
                    )

                    lightBand(
                        in: size,
                        widthMultiplier: 1.04,
                        heightMultiplier: 0.28,
                        colors: [
                            Color(red: 1.00, green: 0.44, blue: 0.58).opacity(0.36),
                            Color(red: 0.92, green: 0.62, blue: 1.00).opacity(0.22),
                            Color.clear
                        ],
                        rotation: 20 - Double(midWave * 3),
                        offset: CGSize(width: width * (0.24 + slowWave * 0.03), height: height * (0.04 + midWave * 0.04)),
                        blur: 42,
                        opacity: 0.42
                    )

                    lightBand(
                        in: size,
                        widthMultiplier: 1.18,
                        heightMultiplier: 0.24,
                        colors: [
                            Color(red: 0.56, green: 0.93, blue: 1.00).opacity(0.20),
                            Color.white.opacity(0.20),
                            Color.clear
                        ],
                        rotation: -8 + Double(fastWave * 3),
                        offset: CGSize(width: -width * (0.08 + fastWave * 0.025), height: height * (0.30 + slowWave * 0.03)),
                        blur: 44,
                        opacity: 0.34
                    )

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear,
                            Color(red: 0.21, green: 0.05, blue: 0.20).opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()
            }
        }
    }

    private func lightBand(
        in size: CGSize,
        widthMultiplier: CGFloat,
        heightMultiplier: CGFloat,
        colors: [Color],
        rotation: Double,
        offset: CGSize,
        blur: CGFloat,
        opacity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: max(size.width, size.height) * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width * widthMultiplier, height: size.height * heightMultiplier)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .blur(radius: blur)
            .opacity(opacity)
            .blendMode(.screen)
    }
}

struct PhonePanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        PhoneTheme.panelBackgroundTop.opacity(0.96),
                        PhoneTheme.panelBackground.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 16, x: 0, y: 9)
    }
}

struct PhoneIconWellBackground: View {
    var isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cornerRadius = max(18, side * 0.25)

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.52 : 0.42),
                                (isActive ? PhoneTheme.activeIconWellBackground : PhoneTheme.iconWellBackground).opacity(0.58),
                                Color(red: 1.00, green: 0.74, blue: 0.52).opacity(0.32)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isActive ? 0.48 : 0.36),
                                PhoneTheme.iconWarmGlow.opacity(isActive ? 0.24 : 0.16),
                                Color.white.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isActive ? 1.4 : 1
                    )
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PhoneTheme.iconWarmGlow.opacity(isActive ? 0.24 : 0.14))
                    .blur(radius: max(6, side * 0.08))
            }
            .shadow(color: Color.black.opacity(isActive ? 0.18 : 0.12), radius: max(7, side * 0.08), x: 0, y: max(4, side * 0.05))
            .shadow(color: PhoneTheme.iconWarmGlow.opacity(isActive ? 0.24 : 0.14), radius: max(7, side * 0.08), x: 0, y: 0)
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

    private let largeIconSpacing: CGFloat = 24
    private let mediumIconSpacing: CGFloat = 10
    private let smallIconSpacing: CGFloat = 6
    private let compactLandscapeSpacing: CGFloat = 10
    private let largeEdgePadding: CGFloat = 26
    private let mediumEdgePadding: CGFloat = 14
    private let smallEdgePadding: CGFloat = 10
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
        let edgePadding: CGFloat
        if isLandscape {
            edgePadding = landscapeEdgePadding
        } else {
            switch gridCount {
            case .four:
                edgePadding = smallEdgePadding
            case .three:
                edgePadding = mediumEdgePadding
            case .two:
                edgePadding = largeEdgePadding
            }
        }
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
        if shouldFitFourColumns {
            let baseSpacing: CGFloat
            switch gridCount {
            case .four:
                baseSpacing = smallIconSpacing
            case .three:
                baseSpacing = mediumIconSpacing
            case .two:
                baseSpacing = largeIconSpacing
            }
            let heightConstrainedSize = (availableHeight - baseSpacing * CGFloat(count - 1)) / CGFloat(count)
            let requiredWidth = heightConstrainedSize * CGFloat(landscapeTwoRowVisibleColumns)
                + baseSpacing * CGFloat(landscapeTwoRowVisibleColumns - 1)

            return requiredWidth > availableWidth ? compactLandscapeSpacing : baseSpacing
        }

        switch gridCount {
        case .four:
            return smallIconSpacing
        case .three:
            return mediumIconSpacing
        case .two:
            return largeIconSpacing
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
    static let canvas = Color(red: 0.46, green: 0.18, blue: 0.48)
    static let accent = Color(red: 1.00, green: 0.88, blue: 0.66)
    static let panelBackgroundTop = Color(red: 0.38, green: 0.14, blue: 0.20)
    static let panelBackground = Color(red: 0.25, green: 0.075, blue: 0.13)
    static let iconWellBackground = Color(red: 0.98, green: 0.76, blue: 0.56)
    static let activeIconWellBackground = Color(red: 1.00, green: 0.82, blue: 0.61)
    static let iconWarmGlow = Color(red: 1.00, green: 0.68, blue: 0.36)
    static let rowBackground = Color(red: 0.22, green: 0.065, blue: 0.11)
    static let rowSeparator = Color.white.opacity(0.14)
    static let bannerBackground = Color(red: 0.28, green: 0.08, blue: 0.14)
    static let tabBarBackground = Color(red: 0.20, green: 0.045, blue: 0.095)
    static let tabBarSelectedBackground = Color(red: 0.56, green: 0.25, blue: 0.18)
    static let tabBarStroke = Color(red: 1.00, green: 0.66, blue: 0.36)
}
