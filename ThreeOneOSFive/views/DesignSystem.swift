import SwiftUI
import ImageIO


enum AppTheme {
    // Aujunpeak monochrome UI palette. The app surface is intentionally kept
    // on one neutral base so every screen feels like the same product.
    static let base = Color(red: 0.098039, green: 0.101961, blue: 0.109804) // #191A1C
    static let surface = base
    static let surfaceElevated = Color(red: 0.118, green: 0.122, blue: 0.130)
    static let border = Color(red: 0.170, green: 0.180, blue: 0.195)
    static let borderStrong = Color(red: 0.220, green: 0.230, blue: 0.245)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let accent = Color.white.opacity(0.92)
    static let secondaryAccent = Color.white.opacity(0.74)
    static let hotPink = Color.white.opacity(0.74)
    static let darkCanvas = base
    static let panel = surface
    static let panelBorder = border
    static let contentMaxWidth: CGFloat = 860
    static let compactPageInset: CGFloat = 14
    static let pageBackground = base
    static let consoleBackground = surfaceElevated
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
    static let contentCardCornerRadius: CGFloat = 20
    static let contentCardInset: CGFloat = 16
    static let contentCardPadding: CGFloat = 16
}

struct AppCardBorder: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: AppTheme.contentCardCornerRadius,
            style: .continuous
        )
        .strokeBorder(
            Color(uiColor: .separator).opacity(0.22),
            lineWidth: 0.5
        )
        .accessibilityHidden(true)
    }
}

struct AujunpeakSlantedCardShape: Shape {
    var cut: CGFloat = 13

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) * 0.18)
        var path = Path()
        path.move(to: CGPoint(x: c, y: 0))
        path.addLine(to: CGPoint(x: rect.width - c * 0.45, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: c))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - c * 0.7))
        path.addLine(to: CGPoint(x: rect.width - c * 0.55, y: rect.height))
        path.addLine(to: CGPoint(x: c, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height - c))
        path.addLine(to: CGPoint(x: 0, y: c))
        path.closeSubpath()
        return path
    }
}

struct AujunpeakTopSheetShape: Shape {
    var radius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width, rect.height) * 0.25)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: r))
        path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width - r, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: r), control: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct AujunpeakPanel<Content: View>: View {
    let content: Content
    var cut: CGFloat = 12

    init(cut: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.cut = cut
        self.content = content()
    }

    var body: some View {
        content
            .background(AppTheme.surface, in: AujunpeakSlantedCardShape(cut: cut))
            .overlay {
                AujunpeakSlantedCardShape(cut: cut)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
    }
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
            AppTheme.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.base)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let logo = UIImage(named: "AujunpeakLogo") {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
            } else if let icon = UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}


// MARK: - Aujunpeak VN animated background
struct AnimatedGIFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        configure(view)
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if !uiView.isAnimating {
            configure(uiView)
        }
    }

    private func configure(_ view: UIImageView) {
        let result = Self.frames(from: data)
        view.animationImages = result.images
        view.animationDuration = result.duration
        view.animationRepeatCount = 0
        view.startAnimating()
    }

    private static func frames(from data: Data) -> (images: [UIImage], duration: TimeInterval) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return ([], 0)
        }

        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: TimeInterval = 0

        for index in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }

            var delay: TimeInterval = 0.08
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
               let gif = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                let clamped = gif[kCGImagePropertyGIFDelayTime as String] as? Double
                delay = max(unclamped ?? clamped ?? 0.08, 0.04)
            }

            images.append(UIImage(cgImage: cgImage))
            duration += delay
        }

        return (images, max(duration, 0.8))
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
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
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
    var colors: [Color] = [AppTheme.surfaceElevated, AppTheme.base]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(AppTheme.borderStrong, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
    }
}

struct AppAnimatedBackground: View {
    var opacity: Double = 1

    var body: some View {
        AppTheme.base
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct AppAuroraBackground: View {
    var body: some View {
        AppTheme.base
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
