//
//  Theme.swift
//  FitnessApp
//
//  Central design system for the "Tiimo-style" redesign.
//  All colors are light/dark adaptive. Tokens here are the single source of
//  truth for the new look — change a value once and it propagates everywhere.
//

import SwiftUI

// MARK: - Brand

/// Editable brand strings shown on the splash screen.
/// Change these two lines to rename the app / tweak the tagline.
enum Brand {
    static let name = "RepDay"
    static let slogan = "Plan the work. Work the plan."
}

// MARK: - Theme tokens

enum Theme {

    // MARK: Colors (light / dark adaptive)
    enum Color {
        /// App background — soft lavender-white in light, deep ink in dark.
        static let background = SwiftUI.Color.dynamic(light: 0xF4F1FB, dark: 0x14121C)
        /// Card / sheet surface.
        static let surface = SwiftUI.Color.dynamic(light: 0xFFFFFF, dark: 0x1F1C29)
        /// Slightly recessed surface (inner rows, empty slots).
        static let surfaceMuted = SwiftUI.Color.dynamic(light: 0xF0ECF9, dark: 0x2A2636)

        /// Primary brand accent — the Tiimo lavender.
        static let accent = SwiftUI.Color.dynamic(light: 0x8B7BF0, dark: 0xA99BF6)
        /// Accent used as a soft fill behind icons / progress tracks.
        static let accentSoft = SwiftUI.Color.dynamic(light: 0xEAE5FB, dark: 0x342E4A)

        static let textPrimary = SwiftUI.Color.dynamic(light: 0x1B1726, dark: 0xF2EFFA)
        static let textSecondary = SwiftUI.Color.dynamic(light: 0x6E6880, dark: 0xA39CB5)

        /// High-contrast pill button (Tiimo's black CTA) — inverts in dark.
        static let cta = SwiftUI.Color.dynamic(light: 0x171320, dark: 0xF2EFFA)
        static let ctaLabel = SwiftUI.Color.dynamic(light: 0xFFFFFF, dark: 0x171320)

        // Pastel section tints (Tiimo's time-of-day pills, reused for grouping).
        static let tintPeach  = SwiftUI.Color.dynamic(light: 0xFBE7DA, dark: 0x3A2E28)
        static let tintBlue   = SwiftUI.Color.dynamic(light: 0xE2ECFB, dark: 0x232C3D)
        static let tintMint   = SwiftUI.Color.dynamic(light: 0xDFF3EA, dark: 0x213429)
        static let tintPurple = SwiftUI.Color.dynamic(light: 0xEDE5FB, dark: 0x2D2840)
        static let tintOrange = SwiftUI.Color.dynamic(light: 0xFBEADA, dark: 0x3A2C21)

        static let success = SwiftUI.Color.dynamic(light: 0x4CAF82, dark: 0x6FD3A6)
        static let hairline = SwiftUI.Color.dynamic(light: 0xE7E2F2, dark: 0x322D40)
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner radii
    enum Radius {
        static let small: CGFloat = 14
        static let card: CGFloat = 22
        static let pill: CGFloat = 999
    }

    // MARK: Shadow
    enum Shadow {
        static let color = SwiftUI.Color.black.opacity(0.06)
        static let radius: CGFloat = 14
        static let y: CGFloat = 6
    }
}

// MARK: - Typography

extension Font {
    /// Serif display face (New York) — captures Tiimo's elegant headers.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let displayLarge = Font.display(34, weight: .bold)
    static let displayMedium = Font.display(24, weight: .bold)
    static let sectionLabel = Font.system(size: 13, weight: .semibold).width(.expanded)
}

// MARK: - Color helpers

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Light/dark adaptive color from two hex literals.
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}
