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

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(title.uppercased())
                .font(.sectionLabel)
            if let count {
                Text("(\(count))")
                    .font(.system(size: 13, weight: .semibold))
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
                .font(.system(size: 15, weight: .semibold))
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
            .font(.system(size: 17, weight: .bold))
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Color.textSecondary)

            HStack(spacing: Theme.Spacing.m) {
                stepButton(symbol: "minus", enabled: value > range.lowerBound) {
                    value = max(range.lowerBound, value - 1)
                }
                Text("\(value)")
                    .font(.system(size: 19, weight: .bold))
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
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Theme.Color.accent : Theme.Color.textSecondary.opacity(0.4))
                .frame(width: 34, height: 34)
                .background(enabled ? Theme.Color.accentSoft : Theme.Color.surfaceMuted, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Themed text field background

extension View {
    /// Wraps a control (e.g. a plain TextField) in a soft, rounded inset field
    /// — replaces the harsh system `.roundedBorder` style.
    func themedField() -> some View {
        self
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, 14)
            .background(Theme.Color.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .stroke(Theme.Color.hairline, lineWidth: 1)
            )
    }
}

/// Maps an exercise name to a stable, sensible emoji.
enum ExerciseEmoji {
    static func forName(_ name: String) -> String {
        let lower = name.lowercased()
        let table: [(keys: [String], emoji: String)] = [
            (["卧推", "bench", "胸", "chest", "push", "夹胸", "飞鸟"], "🏋️"),
            (["深蹲", "squat", "腿", "leg", "蹲", "弓步", "lunge"], "🦵"),
            (["硬拉", "deadlift", "背", "back", "划船", "row", "引体", "pull"], "🪝"),
            (["肩", "shoulder", "推举", "press", "侧平举", "raise"], "🤸"),
            (["二头", "biceps", "弯举", "curl", "臂", "arm", "三头", "triceps"], "💪"),
            (["核心", "腹", "core", "abs", "plank", "平板"], "🔥"),
            (["跑", "run", "有氧", "cardio", "单车", "bike", "划船机"], "🏃"),
        ]
        for entry in table where entry.keys.contains(where: { lower.contains($0) }) {
            return entry.emoji
        }
        return "💪"
    }
}
