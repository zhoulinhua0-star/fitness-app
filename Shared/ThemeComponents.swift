//
//  ThemeComponents.swift
//  FitnessApp
//
//  Reusable Tiimo-style building blocks: card surface, section pill,
//  primary CTA button, and a tappable circle checkmark. Compose these so
//  every screen shares one visual identity.
//

import SwiftUI

// MARK: - Card surface

/// Wraps content in the standard rounded surface with soft shadow.
struct TiimoCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.l
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(highlighted ? Theme.Color.accent : Theme.Color.hairline,
                            lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, x: 0, y: Theme.Shadow.y)
    }
}

extension View {
    func tiimoCard(padding: CGFloat = Theme.Spacing.l, highlighted: Bool = false) -> some View {
        modifier(TiimoCardModifier(padding: padding, highlighted: highlighted))
    }
}

// MARK: - Section pill (time-of-day / grouping label)

struct SectionPill: View {
    let title: String
    var count: Int? = nil
    var systemImage: String = "circle"
    var tint: Color = Theme.Color.tintPeach
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
            Text(
                AppLocalization.string(
                    title,
                    languageIdentifier: locale.identifier
                ).uppercased()
            )
                .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold, width: .expanded)
            if let count {
                Text("(\(count))")
                    .appScaledFont(size: 13, relativeTo: .caption, weight: .semibold)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .foregroundStyle(Theme.Color.textPrimary)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(tint, in: Capsule())
    }
}

// MARK: - Counter pill (Tiimo's "🎉 0/8")

struct CounterPill: View {
    let emoji: String
    let value: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(emoji)
            Text("\(value) / \(total)")
                .appScaledFont(size: 15, relativeTo: .subheadline, weight: .semibold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Theme.Color.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.Color.hairline, lineWidth: 1))
    }
}

// MARK: - Primary CTA button (Tiimo's black pill)

struct PrimaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .appScaledFont(size: 17, relativeTo: .headline, weight: .bold)
            .foregroundStyle(Theme.Color.ctaLabel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.Color.cta, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryCTAButtonStyle {
    static var primaryCTA: PrimaryCTAButtonStyle { PrimaryCTAButtonStyle() }
}

// MARK: - Circle check (Tiimo's right-edge checkbox)

struct CircleCheck: View {
    let isComplete: Bool
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle()
                .stroke(isComplete ? Theme.Color.accent : Theme.Color.textSecondary.opacity(0.5),
                        lineWidth: 2)
            if isComplete {
                Circle().fill(Theme.Color.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isComplete)
    }
}

// MARK: - Emoji tile (leading icon on list rows)

/// A soft rounded tile holding an emoji, deterministically chosen from a name.
struct EmojiTile: View {
    let emoji: String
    var tint: Color = Theme.Color.accentSoft
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Themed stepper (circular −/+ around a value)

/// A compact, fully themed replacement for the system `Stepper` — no boxes,
/// no clashing colors. Reads as: TITLE  ( − ) value ( + ).
struct ThemedStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(
                AppLocalization.string(
                    title,
                    languageIdentifier: locale.identifier
                )
            )
                .appScaledFont(size: 12, relativeTo: .caption, weight: .semibold)
                .foregroundStyle(Theme.Color.textSecondary)

            HStack(spacing: Theme.Spacing.m) {
                stepButton(symbol: "minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - 1)
                }
                Text("\(value)")
                    .appScaledFont(size: 19, relativeTo: .title3, weight: .bold)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(minWidth: 30)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                stepButton(symbol: "plus", enabled: value < range.upperBound) {
                    value = min(range.upperBound, value + 1)
                }
            }
        }
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: symbol)
                .appScaledFont(size: 13, relativeTo: .caption, weight: .bold)
                .foregroundStyle(enabled ? Theme.Color.accent : Theme.Color.textSecondary.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(enabled ? Theme.Color.accentSoft : Theme.Color.surfaceMuted, in: Circle())
                .contentShape(Rectangle().inset(by: -5))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Themed text field background

extension View {
    /// Wraps a control (e.g. a plain TextField) in a soft, rounded inset field
    /// — replaces the harsh system `.roundedBorder` style.
    func themedField(isFocused: Bool = false) -> some View {
        self
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 14)
            .background(Theme.Color.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .stroke(
                        isFocused ? Theme.Color.accent : Theme.Color.hairline,
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
    }

}
