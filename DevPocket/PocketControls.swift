import SwiftUI

enum PocketStyle {
    static let mint = Color(red: 0.12, green: 0.51, blue: 0.40)
    static let ink = adaptive(light: (0.10, 0.43, 0.34), dark: (0.48, 0.82, 0.69))
    static let canvas = adaptive(light: (0.965, 0.974, 0.969), dark: (0.067, 0.086, 0.078))
    static let sidebar = adaptive(light: (0.943, 0.962, 0.951), dark: (0.079, 0.104, 0.092))
    static let surface = adaptive(light: (1, 1, 1), dark: (0.105, 0.132, 0.118))
    static let field = adaptive(light: (0.953, 0.965, 0.957), dark: (0.139, 0.172, 0.153))
    static let accentWash = adaptive(light: (0.884, 0.942, 0.912), dark: (0.119, 0.225, 0.179))
    static let line = Color.primary.opacity(0.075)
    static let radius: CGFloat = 12

    private static func adaptive(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

struct PocketToolIcon: View {
    let symbol: String
    var emphasized = false
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .resizable().scaledToFit().symbolRenderingMode(.monochrome)
            .fontWeight(.medium)
            .frame(width: size * 0.48, height: size * 0.48)
            .foregroundStyle(emphasized ? PocketStyle.ink : Color.secondary)
            .frame(width: size, height: size)
            .background(emphasized ? PocketStyle.accentWash : PocketStyle.field,
                        in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

private struct PocketCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PocketStyle.surface, in: RoundedRectangle(cornerRadius: PocketStyle.radius))
            .clipShape(RoundedRectangle(cornerRadius: PocketStyle.radius))
            .overlay(RoundedRectangle(cornerRadius: PocketStyle.radius).strokeBorder(PocketStyle.line))
            .shadow(color: .black.opacity(0.018), radius: 8, y: 3)
    }
}

extension View {
    func pocketCard() -> some View { modifier(PocketCard()) }
    func pocketField() -> some View {
        self.padding(.horizontal, 11).frame(height: 35)
            .background(PocketStyle.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(PocketStyle.line.opacity(0.7)))
    }
}

struct PocketSegmentedPicker<Value: Hashable>: View {
    let title: String
    let choices: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(choices, id: \.self) { choice in
                Button { selection = choice } label: {
                    Text(label(choice))
                        .font(.system(size: 11, weight: selection == choice ? .semibold : .medium))
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .foregroundStyle(selection == choice ? PocketStyle.ink : Color.secondary)
                        .background {
                            if selection == choice {
                                RoundedRectangle(cornerRadius: 7).fill(PocketStyle.surface)
                                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "selection", in: indicator)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == choice ? [.isSelected] : [])
            }
        }
        .padding(3).background(PocketStyle.field, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain).accessibilityLabel(title)
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.92), value: selection)
    }
}

struct PocketButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 13).frame(height: 36)
            .foregroundStyle(prominent ? Color.white : Color.primary.opacity(0.78))
            .background(prominent ? PocketStyle.mint : PocketStyle.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(prominent ? Color.clear : PocketStyle.line))
            .shadow(color: prominent ? PocketStyle.mint.opacity(0.13) : .clear, radius: 5, y: 2)
            .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PocketIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .regular))
            .frame(width: 27, height: 27)
            .foregroundStyle(.secondary)
            .background(configuration.isPressed ? Color.primary.opacity(0.075) : PocketStyle.field,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? 1 : 0.35)
    }
}
