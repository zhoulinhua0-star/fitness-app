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
        /// App background — crisp neutral near-white in light, true black in dark.
        /// Deliberately colorless so cards + the lavender accent read as sharp,
        /// gym-grade contrast rather than a soft pastel wash.
        static let background = SwiftUI.Color.dynamic(light: 0xF4F3F1, dark: 0x000000)
        /// Card / sheet surface — pure white on the neutral canvas so cards lift.
        static let surface = SwiftUI.Color.dynamic(light: 0xFFFFFF, dark: 0x1C1A19)
        /// Slightly recessed surface (inner rows, empty slots).
        static let surfaceMuted = SwiftUI.Color.dynamic(light: 0xEEEDEB, dark: 0x2A2725)

        /// Primary brand accent — deep blood-red (Crimson) for a hard, gym-grade look.
        static let accent = SwiftUI.Color.dynamic(light: 0xDC2626, dark: 0xF04444)
        /// Accent used as a soft fill behind icons / progress tracks.
        static let accentSoft = SwiftUI.Color.dynamic(light: 0xFBE0E0, dark: 0x3A2020)

        // Warm-neutral ink/paper — a whisper of red under the "black" & "white"
        // so text shares the crimson accent's temperature (no leftover violet).
        static let textPrimary = SwiftUI.Color.dynamic(light: 0x1C1917, dark: 0xF7F4F2)
        static let textSecondary = SwiftUI.Color.dynamic(light: 0x77706B, dark: 0xA8A29C)

        /// High-contrast pill button (warm near-black CTA) — inverts in dark.
        static let cta = SwiftUI.Color.dynamic(light: 0x1C1917, dark: 0xF7F4F2)
        static let ctaLabel = SwiftUI.Color.dynamic(light: 0xFFFFFF, dark: 0x1C1917)

        // Pastel section tints (Tiimo's time-of-day pills, reused for grouping).
        static let tintPeach  = SwiftUI.Color.dynamic(light: 0xFBE7DA, dark: 0x3A2E28)
        static let tintBlue   = SwiftUI.Color.dynamic(light: 0xE2ECFB, dark: 0x232C3D)
        static let tintMint   = SwiftUI.Color.dynamic(light: 0xDFF3EA, dark: 0x213429)
        static let tintPurple = SwiftUI.Color.dynamic(light: 0xFBE0E3, dark: 0x3A2126)
        static let tintOrange = SwiftUI.Color.dynamic(light: 0xFBEADA, dark: 0x3A2C21)

        static let success = SwiftUI.Color.dynamic(light: 0x4CAF82, dark: 0x6FD3A6)
        static let hairline = SwiftUI.Color.dynamic(light: 0xE5E3E0, dark: 0x33302D)
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
    /// Semantic New York display roles. Using text styles keeps the hierarchy
    /// responsive to both the system Dynamic Type setting and RepDay's text-size preference.
    static let displayLarge = Font.system(.title, design: .serif, weight: .bold)
    static let displayMedium = Font.system(.title2, design: .serif, weight: .bold)
    static let displayMetricLarge = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let displayMetric = Font.system(.title, design: .serif, weight: .bold)
    static let displayMetricSmall = Font.system(.title2, design: .serif, weight: .bold)
    static let sectionLabel = Font.caption.weight(.semibold).width(.expanded)
}

/// Keeps the App Store typography sizes as the `.large` Dynamic Type baseline,
/// while still scaling with both the system setting and RepDay's text-size preference.
private struct AppScaledSystemFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat

    let weight: Font.Weight
    let design: Font.Design
    let width: Font.Width

    init(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight,
        design: Font.Design,
        width: Font.Width
    ) {
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
        self.width = width
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight, design: design).width(width))
    }
}

extension View {
    func appScaledFont(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        width: Font.Width = .standard
    ) -> some View {
        modifier(
            AppScaledSystemFontModifier(
                size: size,
                relativeTo: textStyle,
                weight: weight,
                design: design,
                width: width
            )
        )
    }
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
