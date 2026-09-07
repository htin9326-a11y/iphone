import SwiftUI

enum AppTheme {
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.45, green: 0.39, blue: 1.00, alpha: 1.00)
                : UIColor(red: 0.32, green: 0.24, blue: 0.82, alpha: 1.00)
        }
    )
    static let secondaryAccent = Color(red: 0.12, green: 0.84, blue: 0.72)
    static let hotPink = Color(red: 1.00, green: 0.28, blue: 0.58)
    static let pageBackground = Color(uiColor: .systemBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let darkCanvas = Color(red: 0.035, green: 0.035, blue: 0.075)
    static let panel = Color.white.opacity(0.075)
    static let panelBorder = Color.white.opacity(0.12)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if UIImage(named: "AujunpeakLogo") != nil {
                Image("AujunpeakLogo")
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .shadow(color: .red.opacity(0.22), radius: max(4, size * 0.12), y: 3)
        .accessibilityHidden(true)
    }
}

/// Shared surface used by the redesigned screens. Keeping the treatment here
/// means every tab feels like part of one app without touching any feature code.
struct AppGlassPanel<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 22
    var tint: Color = AppTheme.accent

    init(
        cornerRadius: CGFloat = 22,
        tint: Color = AppTheme.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.42), Color.white.opacity(0.07)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: tint.opacity(0.10), radius: 24, y: 12)
    }
}

struct AppCapsuleBadge: View {
    let title: String
    let icon: String
    var tint: Color = AppTheme.secondaryAccent

    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1)
            }
    }
}

struct AppGradientButtonStyle: ButtonStyle {
    var colors: [Color] = [AppTheme.accent, AppTheme.hotPink]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .shadow(color: colors.first?.opacity(0.28) ?? .clear, radius: 18, y: 8)
    }
}

struct AppAuroraBackground: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.darkCanvas
                Circle()
                    .fill(AppTheme.accent.opacity(0.22))
                    .frame(width: proxy.size.width * 0.92)
                    .blur(radius: 70)
                    .offset(x: animate ? proxy.size.width * 0.32 : -proxy.size.width * 0.34,
                            y: animate ? -proxy.size.height * 0.25 : -proxy.size.height * 0.05)
                Circle()
                    .fill(AppTheme.hotPink.opacity(0.15))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 80)
                    .offset(x: animate ? -proxy.size.width * 0.28 : proxy.size.width * 0.28,
                            y: animate ? proxy.size.height * 0.26 : proxy.size.height * 0.42)
                Circle()
                    .fill(AppTheme.secondaryAccent.opacity(0.10))
                    .frame(width: 180, height: 180)
                    .blur(radius: 42)
                    .position(x: proxy.size.width * 0.84, y: proxy.size.height * 0.58)
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.36), Color.black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}
