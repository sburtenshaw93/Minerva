import SwiftUI
import UIKit

// Shared palette options for budget visualizations.
// These are used by the budget screen's theme picker in `ContentView`
// and by chart views such as the ring, bar, and line charts --> Future release for line chart.
enum BudgetPalette: String, CaseIterable, Identifiable {
    case earth
    case ocean
    case dusk
    case natural

    var id: String { rawValue }

    var title: String {
        switch self {
        case .earth: "Earth"
        case .ocean: "Ocean"
        case .dusk: "Mono"
        case .natural: "Natural"
        }
    }

    // Ordered chart colors used when mapping categories to a palette.
    // The helper `color(for:palette:)` cycles through this array based on category ID.
    var colors: [Color] {
        switch self {
        case .earth:
            return [
                .minervaChart1,
                Color(red: 0.78, green: 0.46, blue: 0.34),
                .minervaChart3,
                Color(red: 0.69, green: 0.58, blue: 0.31),
                .minervaChart5,
                Color(red: 0.58, green: 0.43, blue: 0.34),
                Color(red: 0.36, green: 0.56, blue: 0.48),
                Color(red: 0.82, green: 0.62, blue: 0.40),
                Color(red: 0.50, green: 0.36, blue: 0.29),
                Color(red: 0.30, green: 0.44, blue: 0.47),
                Color(red: 0.67, green: 0.48, blue: 0.22),
                Color(red: 0.47, green: 0.41, blue: 0.55),
                Color(red: 0.43, green: 0.50, blue: 0.35),
                Color(red: 0.74, green: 0.55, blue: 0.47),
                Color(red: 0.38, green: 0.31, blue: 0.24),
                Color(red: 0.57, green: 0.51, blue: 0.40)
            ]
        case .ocean:
            return [
                Color(red: 0.14, green: 0.44, blue: 0.54),
                Color(red: 0.22, green: 0.57, blue: 0.63),
                Color(red: 0.33, green: 0.66, blue: 0.55),
                Color(red: 0.46, green: 0.73, blue: 0.65),
                Color(red: 0.34, green: 0.42, blue: 0.63),
                Color(red: 0.52, green: 0.56, blue: 0.74),
                Color(red: 0.16, green: 0.36, blue: 0.44),
                Color(red: 0.18, green: 0.66, blue: 0.76),
                Color(red: 0.42, green: 0.78, blue: 0.79),
                Color(red: 0.27, green: 0.51, blue: 0.72),
                Color(red: 0.40, green: 0.63, blue: 0.80),
                Color(red: 0.23, green: 0.30, blue: 0.55),
                Color(red: 0.19, green: 0.48, blue: 0.58),
                Color(red: 0.33, green: 0.70, blue: 0.69),
                Color(red: 0.28, green: 0.39, blue: 0.47),
                Color(red: 0.56, green: 0.71, blue: 0.83)
            ]
        case .dusk:
            return [
                Color(red: 0.52, green: 0.52, blue: 0.52),
                Color(red: 0.31, green: 0.31, blue: 0.33),
                Color(red: 0.45, green: 0.45, blue: 0.47),
                Color(red: 0.60, green: 0.60, blue: 0.62),
                Color(red: 0.76, green: 0.76, blue: 0.78),
                Color(red: 0.91, green: 0.91, blue: 0.92),
                Color(red: 0.39, green: 0.39, blue: 0.42),
                Color(red: 0.67, green: 0.67, blue: 0.70),
                Color(red: 0.24, green: 0.24, blue: 0.27),
                Color(red: 0.84, green: 0.84, blue: 0.86),
                Color(red: 0.56, green: 0.56, blue: 0.60),
                Color(red: 0.72, green: 0.72, blue: 0.75),
                Color(red: 0.15, green: 0.15, blue: 0.17),
                Color(red: 0.48, green: 0.48, blue: 0.50),
                Color(red: 0.79, green: 0.79, blue: 0.81),
                Color(red: 0.36, green: 0.36, blue: 0.38)
            ]
        case .natural:
            return [
                Color(red: 0.54, green: 0.43, blue: 0.36),
                Color(red: 0.76, green: 0.66, blue: 0.57),
                Color(red: 0.67, green: 0.58, blue: 0.51),
                Color(red: 0.84, green: 0.78, blue: 0.71),
                Color(red: 0.58, green: 0.49, blue: 0.44),
                Color(red: 0.71, green: 0.63, blue: 0.58),
                Color(red: 0.74, green: 0.68, blue: 0.63),
                Color(red: 0.73, green: 0.58, blue: 0.40),
                Color(red: 0.66, green: 0.57, blue: 0.49),
                Color(red: 0.49, green: 0.41, blue: 0.30),
                Color(red: 0.80, green: 0.72, blue: 0.60),
                Color(red: 0.39, green: 0.47, blue: 0.33),
                Color(red: 0.65, green: 0.60, blue: 0.48),
                Color(red: 0.87, green: 0.82, blue: 0.74),
                Color(red: 0.55, green: 0.52, blue: 0.43),
                Color(red: 0.44, green: 0.37, blue: 0.28)
            ]
        }
    }
}

// Full-screen decorative background used at the root `ContentView` level.
// This establishes the overall visual identity before any cards or controls are drawn.
// Implementation pieces:
// - top-to-bottom gradient for the base atmosphere
// - layered mountain silhouettes for depth
// - a lower shadow wash to improve foreground contrast
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.black, Color.minervaNight, Color.minervaLake]
                        : [Color.minervaPrimary, Color.minervaMist, Color.minervaLake.opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                MountainLayer(color: Color.black.opacity(colorScheme == .dark ? 0.46 : 0.18), heightRatio: 0.44)
                    .offset(y: proxy.size.height * 0.12)

                MountainLayer(color: Color.minervaForest.opacity(colorScheme == .dark ? 0.62 : 0.28), heightRatio: 0.34)
                    .offset(y: proxy.size.height * 0.22)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(colorScheme == .dark ? 0.58 : 0.18)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
    }
}

// Shared category-to-color mapping used anywhere a category needs a stable accent color.
// This is referenced by budget rows and chart views in `ContentView` so the same category
// keeps the same visual identity across the app.
func color(for categoryId: Int, palette: BudgetPalette = .earth) -> Color {
    let colors = palette.colors
    return colors[abs(categoryId - 1) % colors.count]
}

// Centralized Minerva design tokens.
// This extension is the main source of truth for the app's color system so styling updates
// can be made here instead of searching through `ContentView`.
//
// Token groups:
// - Base surfaces: page and background colors
// - Brand accents: greens, clay, orange
// - Semantic states: success, warning, danger, info
// - Chart colors: palette anchors for budget visualizations
// - Adaptive UI colors: text and glass materials that shift for light/dark mode
//
// Where these are implemented:
// - `ContentView` uses them for text, buttons, cards, chips, headers, and tab bar styling
// - `AppBackground` uses the landscape/background tokens
// - chart views use the chart and track colors
extension Color {
    // Base neutrals and surfaces used for backgrounds, cards, and soft fills.
    static let minervaBg = Color(red: 0.965, green: 0.976, blue: 0.969)
    static let minervaPrimary = Color(red: 0.910, green: 0.933, blue: 0.918)
    static let minervaMint200 = Color(red: 0.827, green: 0.871, blue: 0.847)
    static let minervaMint300 = Color(red: 0.718, green: 0.788, blue: 0.753)
    static let minervaMint400 = Color(red: 0.561, green: 0.659, blue: 0.612)

    // Brand and atmosphere colors used in the app background and primary accents.
    static let minervaNight = Color(red: 0.050, green: 0.060, blue: 0.055)
    static let minervaLake = Color(red: 0.140, green: 0.200, blue: 0.190)
    static let minervaForest = Color(red: 0.120, green: 0.160, blue: 0.130)
    static let minervaMist = Color(red: 0.827, green: 0.871, blue: 0.847)
    static let minervaGreen = Color(red: 0.294, green: 0.498, blue: 0.322)
    static let minervaMint = Color(red: 0.910, green: 0.933, blue: 0.918)
    static let minervaPeach = Color(red: 1.000, green: 0.957, blue: 0.910)
    static let minervaClay = Color(red: 0.694, green: 0.333, blue: 0.110)
    static let minervaOrange = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.88, green: 0.54, blue: 0.22, alpha: 1)
            : UIColor(red: 0.62, green: 0.36, blue: 0.18, alpha: 1)
    })
    static let minervaOrangePressed = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.46, blue: 0.18, alpha: 1)
            : UIColor(red: 0.50, green: 0.29, blue: 0.14, alpha: 1)
    })
    static let minervaSuccess = Color(red: 0.294, green: 0.498, blue: 0.322)
    static let minervaWarning = Color(red: 0.890, green: 0.698, blue: 0.235)
    static let minervaDanger = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.84, green: 0.13, blue: 0.13, alpha: 1)
            : UIColor(red: 0.78, green: 0.17, blue: 0.17, alpha: 1)
    }) // Transaction
    static let minervaInfo = Color(red: 0.122, green: 0.435, blue: 0.545)

    // Core chart anchors reused by budget palettes.
    // Some palettes use these directly, while others define custom inline colors.
    static let minervaChart1 = Color(red: 0.122, green: 0.435, blue: 0.545)
    static let minervaChart2 = Color(red: 0.957, green: 0.420, blue: 0.271)
    static let minervaChart3 = Color(red: 0.459, green: 0.533, blue: 0.463)
    static let minervaChart4 = Color(red: 0.890, green: 0.698, blue: 0.235)
    static let minervaChart5 = Color(red: 0.427, green: 0.349, blue: 0.478)

    // Primary readable text color.
    // This flips between near-white in dark mode and black in light mode.
    static let minervaText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.95, blue: 0.94, alpha: 1)
            : UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)
    })

    // Secondary text used for subtitles, metadata, captions, and helper labels.
    static let minervaSubtext = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.66, blue: 0.61, alpha: 1)
            : UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    })

    // Brand-forward foreground used where the app wants a stronger logo/title treatment.
    static let minervaBrand = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.965, green: 0.976, blue: 0.969, alpha: 1)
            : UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1)
    })

    // Shared translucent material for cards and overlays.
    // Used by components like GlassCard-style surfaces in `ContentView`.
    static let minervaGlass = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.10, blue: 0.09, alpha: 0.74)
            : UIColor(red: 0.91, green: 0.93, blue: 0.92, alpha: 0.66)
    })

    // Slightly heavier glass treatment for headers so top content stays legible.
    static let minervaHeaderGlass = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.06, blue: 0.06, alpha: 0.82)
            : UIColor(red: 0.91, green: 0.93, blue: 0.92, alpha: 0.72)
    })

    // Glass styling dedicated to the bottom tab bar capsule.
    static let minervaTabGlass = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.06, blue: 0.06, alpha: 0.84)
            : UIColor(red: 0.91, green: 0.93, blue: 0.92, alpha: 0.78)
    })

    // Softer panel fill for rows, chips, and inline grouped surfaces.
    static let minervaPanel = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.79, blue: 0.75, alpha: 0.10)
            : UIColor(red: 0.827, green: 0.871, blue: 0.847, alpha: 0.60)
    })

    // Neutral track color behind chart progress and graph baselines.
    static let minervaChartTrack = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.72, green: 0.79, blue: 0.75, alpha: 0.14)
            : UIColor(red: 0.718, green: 0.788, blue: 0.753, alpha: 0.42)
    })
}

// Private background shape layer used only by `AppBackground`.
// This is not a reusable component elsewhere; it exists strictly to construct
// the mountain silhouette effect behind the main app screens.
private struct MountainLayer: View {
    let color: Color
    let heightRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                let baseY = height * heightRatio

                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: baseY + 70))
                path.addLine(to: CGPoint(x: width * 0.18, y: baseY + 20))
                path.addLine(to: CGPoint(x: width * 0.38, y: baseY - 58))
                path.addLine(to: CGPoint(x: width * 0.55, y: baseY + 12))
                path.addLine(to: CGPoint(x: width * 0.75, y: baseY - 76))
                path.addLine(to: CGPoint(x: width, y: baseY + 28))
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(color)
            .blur(radius: 0.6)
        }
        .ignoresSafeArea()
    }
}
