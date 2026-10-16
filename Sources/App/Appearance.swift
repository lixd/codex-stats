import SwiftUI

enum AppPalette: String, CaseIterable, Identifiable {
    case cyan, blue
    var id: Self { self }
    var label: String { self == .cyan ? "浅青" : "晴蓝" }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette.cyan
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

/// Fixed app-owned colors, resolved from the current view's palette and appearance.
/// Native text and control accent colors remain managed by the system.
enum CPTheme: ShapeStyle {
    case accent, cyan, purple, orange, chart
    case cardBackground, viewBackground, sectionBackground, headerBackground, metricBackground
    case selection, actionFill, stroke, overviewBackground

    func resolve(in environment: EnvironmentValues) -> Color {
        if self == .chart && environment.colorSchemeContrast == .increased {
            return CPTheme.accent.resolve(in: environment)
        }
        let colors: (cyanLight: UInt32, blueLight: UInt32, cyanDark: UInt32, blueDark: UInt32)
        switch self {
        case .accent: colors = (0x23747F, 0x3D62AD, 0x6BC5D0, 0x9EBEF3)
        case .cyan: colors = (0x286F96, 0x286F96, 0x79B8E5, 0x79B8E5)
        case .purple: colors = (0x735DAA, 0x735DAA, 0xB4A3E4, 0xB4A3E4)
        case .orange: colors = (0x975813, 0x975813, 0xEEB370, 0xEEB370)
        case .chart: colors = (0x8BC7CE, 0x83A5DF, 0x579CA6, 0x7399CF)
        case .cardBackground: colors = (0xFFFFFF, 0xFFFFFF, 0x1C2C31, 0x202F44)
        case .overviewBackground: colors = (0xF8FBFC, 0xF9FAFD, 0x111E22, 0x141E2D)
        case .viewBackground: colors = (0xF3FAFA, 0xF5F7FB, 0x111E22, 0x141E2D)
        case .sectionBackground: colors = (0xEAF5F5, 0xEFF2F8, 0x17282D, 0x1B293D)
        case .headerBackground: colors = (0xFCFEFE, 0xFFFFFF, 0x17282D, 0x1B293D)
        case .metricBackground: colors = (0xEDF7F8, 0xFFFFFF, 0x20343B, 0x202F44)
        case .selection: colors = (0xDFF0F2, 0xE6EDF9, 0x203F46, 0x293E5E)
        case .actionFill: colors = (0x23747F, 0x3D62AD, 0x23747F, 0x3D62AD)
        case .stroke:
            colors = environment.colorSchemeContrast == .increased
                ? (0x71888D, 0x75839D, 0x829CA3, 0x91A3BD)
                : (0xDFEBED, 0xE5E9F1, 0x38535A, 0x40536F)
        }
        let rgb: UInt32
        switch (environment.appPalette, environment.colorScheme) {
        case (.cyan, .dark): rgb = colors.cyanDark
        case (.blue, .dark): rgb = colors.blueDark
        case (.cyan, _): rgb = colors.cyanLight
        case (.blue, _): rgb = colors.blueLight
        }
        return Color(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                     green: Double((rgb >> 8) & 255) / 255,
                     blue: Double(rgb & 255) / 255, opacity: 1)
    }
}
