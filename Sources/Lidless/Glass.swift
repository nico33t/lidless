import SwiftUI

/// Liquid Glass on macOS 26 and later, translucent material on earlier versions.
extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.08)))
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

/// Groups glass shapes so they blend into each other on macOS 26 and later.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// Soft coloured backdrop that gives the glass something to refract.
struct AmbientBackground: View {
    var active: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            RadialGradient(
                colors: [Color.indigo.opacity(active ? 0.45 : 0.18), .clear],
                center: .topLeading, startRadius: 0, endRadius: 520)
            RadialGradient(
                colors: [Color.cyan.opacity(active ? 0.30 : 0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 480)
        }
        .animation(.easeInOut(duration: 0.6), value: active)
        .ignoresSafeArea()
    }
}
