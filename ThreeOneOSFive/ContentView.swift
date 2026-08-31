
import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = false
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = false
    @State private var tabNavigation: AppTabNavigationState

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.files.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.files.rawValue) }
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(title: section.displayTitle, systemImage: section.systemImage)
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if UIImage(named: section.systemImage) != nil {
                                Image(section.systemImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            } else {
                                Image(systemName: section.systemImage)
                                    .frame(width: 18)
                            }
                            Text(section.displayTitle)
                        }
                        .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                        ? AppTheme.accent.opacity(0.14)
                        : Color.clear
                    )
                    .accessibilityAddTraits(section.rawValue == tabNavigation.selectedTab ? .isSelected : [])
                }
            }
            .navigationTitle("Aujunpeak VN")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            DashboardView(
                cleanerEnabled: $cleanerEnabled,
                wallpapersEnabled: $wallpapersEnabled,
                wallpapersSupported: false,
                onOpenGame: { _ in
                    tabNavigation.select(AppSection.files.rawValue)
                }
            )
        case .files:
            ZStack {
                AppDataBrowserView(tabSession: filesTabSession)
                FunctionOverlayView()
            }
        case .patches:
            ZStack {
                PatchProjectsView()
                KeyInfoOverlayView()
            }
        case .cleaner:
            CleanerView()
        case .wallpapers:
            WallpaperLabView()
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(cleanerEnabled: false, wallpapersEnabled: false, wallpapersSupported: false)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab), featureVisibility.isVisible(section) else {
            return .home
        }
        return section
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let customImage = UIImage(named: systemImage) {
            Image(uiImage: customImage.withRenderingMode(.alwaysOriginal))
        } else if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var displayTitle: String {
        switch self {
        case .home: return "Trang chủ"
        case .files: return "Function"
        case .patches: return "Info"
        case .cleaner: return "Cleaner"
        case .wallpapers: return "Wallpapers"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .files: return "AujunpeakTabIcon"
        case .patches: return "info.circle.fill"
        case .cleaner: return "sparkles"
        case .wallpapers: return "photo.on.rectangle.angled"
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @State private var showSettings = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool
    let onOpenGame: (String) -> Void
    @AppStorage("aujunpeak.selected.game") private var selectedGameKey = "freefire"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppNeonBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear.frame(height: 68)
                        shopBannerSection
                        gameGridSection
                        deviceMiniSection
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                }

                HomeAdminOverlayCard()
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .zIndex(10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task {
                await licenseSession.refreshStatus()
            }
        }
    }

    private var shopBannerSection: some View {
        Link(destination: URL(string: "https://huanha.shop/")!) {
            ZStack(alignment: .bottomLeading) {
                if UIImage(named: "AujunpeakPromo") != nil {
                    Image("AujunpeakPromo")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 188)
                        .clipped()
                } else {
                    LinearGradient(colors: [Color.blue, Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 188)
                }

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.84)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("AUJUNPEAK VN")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Panel game • hiệu ứng sáng • nhấn để mở huanha.shop")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    HStack(spacing: 8) {
                        Label("Shop chính thức", systemImage: "checkmark.seal.fill")
                        Label("24/7", systemImage: "bolt.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.cyan.opacity(0.75), Color.blue.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
            }
            .shadow(color: Color.blue.opacity(0.24), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var gameGridSection: some View {
        let games = homeGames
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Game Center")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("Chạm để mở Function theo từng game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(games) { game in
                    Button {
                        selectedGameKey = game.gameKey
                        onOpenGame(game.gameKey)
                    } label: {
                        HomeGameCard(
                            game: game,
                            iconURL: resolvedIconURL(for: game),
                            isSelected: selectedGameKey == game.gameKey
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var deviceMiniSection: some View {
        HStack(spacing: 12) {
            MiniInfoChip(icon: "iphone.gen3", title: "Thiết bị", value: AppInfo.displayMachineName)
            MiniInfoChip(icon: "checkmark.shield.fill", title: "Key", value: licenseSession.license?.status.uppercased() ?? "SYNC")
        }
    }

    private var homeGames: [RemoteGameSection] {
        let defaults = RemoteGameSection.fallbackGames
        if licenseSession.games.isEmpty { return defaults }
        var merged = licenseSession.games
        for item in defaults where !merged.contains(where: { $0.gameKey == item.gameKey }) {
            merged.append(item)
        }
        return merged.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func resolvedIconURL(for game: RemoteGameSection) -> String? {
        if let url = game.iconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return licenseSession.switches.first(where: {
            ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == game.gameKey &&
            !($0.gameIconURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.gameIconURL
    }
}

private struct MiniInfoChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

private struct HomeGameCard: View {
    let game: RemoteGameSection
    let iconURL: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            GameIconView(gameKey: game.gameKey, remoteURL: iconURL, size: 56, cornerRadius: 15)
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(game.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Mở nhanh")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Color.orange : Color.white.opacity(0.72))
            }
            Spacer(minLength: 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: isSelected ? [Color.orange.opacity(0.26), Color.red.opacity(0.12)] : [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isSelected ? Color.orange.opacity(0.42) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: isSelected ? Color.orange.opacity(0.18) : .clear, radius: 16, y: 8)
    }
}

private struct HomeAdminOverlayCard: View {
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.accent, AppTheme.accent.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("ADMIN HÀ VĂN HUẤN")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Aujunpeak VN • Hỗ trợ & liên hệ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Link(destination: zaloURL) {
                HStack(spacing: 6) {
                    Image(systemName: "message.fill")
                    Text("Zalo")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing), in: Capsule())
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 6)
    }
}

private struct FunctionOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @AppStorage("aujunpeak.selected.game") private var selectedGameKey = "freefire"
    @State private var refreshToken = 0

    private var availableGames: [RemoteGameSection] {
        let defaults = RemoteGameSection.fallbackGames
        if licenseSession.games.isEmpty { return defaults }
        var merged = licenseSession.games
        for item in defaults where !merged.contains(where: { $0.gameKey == item.gameKey }) {
            merged.append(item)
        }
        return merged.filter(\.enabled).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentGame: RemoteGameSection {
        availableGames.first(where: { $0.gameKey == selectedGameKey }) ?? availableGames.first ?? RemoteGameSection.fallbackGames[0]
    }

    private var visibleSwitches: [RemoteAdminSwitch] {
        let matched = licenseSession.switches.filter { ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == currentGame.gameKey }
        if matched.isEmpty && currentGame.gameKey == "freefire" { return licenseSession.switches }
        return matched
    }

    private func resolvedIconURL(for game: RemoteGameSection) -> String? {
        if let url = game.iconURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return url
        }
        return licenseSession.switches.first(where: {
            ($0.gameKey.isEmpty ? "freefire" : $0.gameKey) == game.gameKey &&
            !($0.gameIconURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })?.gameIconURL
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppNeonBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        functionHeader
                        gameSelector
                        functionTargetCard
                        remoteFunctions
                        statusCard
                            .id(refreshToken)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable { await licenseSession.refreshStatus() }
            }
            .navigationTitle("Function")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await licenseSession.refreshStatus() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if !availableGames.contains(where: { $0.gameKey == selectedGameKey }) {
                    selectedGameKey = availableGames.first?.gameKey ?? "freefire"
                }
                Task { await licenseSession.refreshStatus() }
            }
        }
    }

    private var gameSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableGames) { game in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedGameKey = game.gameKey
                        }
                    } label: {
                        HStack(spacing: 10) {
                            GameIconView(gameKey: game.gameKey, remoteURL: resolvedIconURL(for: game), size: 42, cornerRadius: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                Text(game.bundleID)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 6)
                        }
                        .padding(10)
                        .frame(width: 200, alignment: .leading)
                        .background((selectedGameKey == game.gameKey ? Color.orange.opacity(0.18) : Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(selectedGameKey == game.gameKey ? Color.orange.opacity(0.42) : Color.white.opacity(0.05), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private var remoteFunctions: some View {
        VStack(spacing: 10) {
            if visibleSwitches.isEmpty {
                VStack(spacing: 10) {
                    GameIconView(gameKey: currentGame.gameKey, remoteURL: resolvedIconURL(for: currentGame), size: 62, cornerRadius: 18)
                    Text("Chưa có chức năng cho \(currentGame.title)")
                        .font(.headline.weight(.bold))
                    Text("Admin có thể thêm switch riêng, gắn package .3105 và đồng bộ trực tiếp cho game này.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                }
            } else {
                ForEach(visibleSwitches) { item in
                    RemoteFunctionSwitchCard(
                        item: item,
                        onChange: { refreshToken &+= 1 }
                    )
                }
            }

            if licenseSession.switches.isEmpty && licenseSession.lastError != nil {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                    Text("Chức năng từ Admin tạm thời chưa đồng bộ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var functionHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color.red.opacity(0.95), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing))
                if UIImage(named: "AujunpeakLogo") != nil {
                    Image("AujunpeakLogo")
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 64, height: 64)
            .shadow(color: .red.opacity(0.35), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("Hà Văn Huấn")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                }
                Text("Aujunpeak VN")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Text("Trung tâm chức năng game")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.red.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private var functionTargetCard: some View {
        HStack(spacing: 12) {
            GameIconView(gameKey: currentGame.gameKey, remoteURL: resolvedIconURL(for: currentGame), size: 42, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text(currentGame.title)
                    .font(.subheadline.weight(.semibold))
                Text(currentGame.bundleID)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(licenseSession.license?.status.uppercased() ?? "SYNC")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1), in: Capsule())
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.red.opacity(0.16), lineWidth: 1)
        }
    }

    private var statusCard: some View {
        let activeCount = visibleSwitches.filter { $0.enabled && LocalRemoteSwitchService.isEnabled($0) }.count
        return HStack(spacing: 10) {
            Image(systemName: activeCount > 0 ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trạng thái")
                    .font(.subheadline.weight(.semibold))
                Text("\(currentGame.title): đang bật \(activeCount)/\(max(visibleSwitches.count, 1)) chức năng")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(activeCount > 0 ? "ACTIVE" : "READY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background((activeCount > 0 ? Color.green : Color.secondary).opacity(0.10), in: Capsule())
        }
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RemoteFunctionSwitchCard: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    let item: RemoteAdminSwitch
    let onChange: () -> Void
    @State private var isOn: Bool
    @State private var operationMessage: String?
    @State private var isBusy = false

    init(item: RemoteAdminSwitch, onChange: @escaping () -> Void) {
        self.item = item
        self.onChange = onChange
        _isOn = State(initialValue: item.enabled && LocalRemoteSwitchService.isEnabled(item))
    }

    private var displaySubtitle: String {
        if !item.enabled { return "Admin đang tắt chức năng này" }
        if item.hasPackage { return item.subtitle }
        return item.subtitle.isEmpty ? "Chưa có dữ liệu chức năng từ Admin" : item.subtitle
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? AppTheme.accent.opacity(0.16) : Color(uiColor: .tertiarySystemFill))
                if isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: item.icon.isEmpty ? "bolt.fill" : item.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isOn ? AppTheme.accent : Color.secondary)
                }
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(operationMessage ?? displaySubtitle)
                    .font(.caption)
                    .foregroundStyle(operationMessage?.hasPrefix("Lỗi:") == true ? Color.red : (item.enabled ? Color.secondary : Color.orange))
                    .lineLimit(3)

            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    guard item.enabled, !isBusy else { return }
                    if newValue && !item.hasPackage {
                        operationMessage = "Lỗi: Admin chưa gắn dữ liệu chức năng"
                        return
                    }
                    updateSwitch(newValue)
                }
            ))
            .labelsHidden()
            .disabled(!item.enabled || isBusy)
        }
        .padding(13)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isOn ? AppTheme.accent.opacity(0.18) : Color.primary.opacity(0.04), lineWidth: 1)
        }
        .opacity(item.enabled ? 1 : 0.65)
        .onAppear { isOn = item.enabled && LocalRemoteSwitchService.isEnabled(item) }
        .onChange(of: item.enabled) { enabled in
            if !enabled {
                do {
                    try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                    isOn = false
                    operationMessage = "Admin đã tắt chức năng"
                } catch {
                    operationMessage = "Lỗi: \(error.localizedDescription)"
                }
                onChange()
            }
        }
        .onChange(of: item.packageVersion) { _ in
            if isOn && item.hasPackage && !LocalRemoteSwitchService.matchesInstalledVersion(item) {
                operationMessage = "Admin vừa cập nhật • đang đồng bộ bản mới…"
                updateSwitch(true)
            }
        }
        .onChange(of: item.hasPackage) { hasPackage in
            if !hasPackage && isOn {
                try? LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                isOn = false
                operationMessage = "Admin đã gỡ dữ liệu chức năng"
                onChange()
            }
        }
    }

    private func updateSwitch(_ newValue: Bool) {
        isBusy = true
        operationMessage = newValue ? "Đang tải dữ liệu chức năng…" : "Đang tắt chức năng…"
        Task {
            do {
                if newValue {
                    let package = try await licenseSession.downloadPackage(for: item)
                    try await Task.detached(priority: .userInitiated) {
                        try LocalRemoteSwitchService.setEnabled(true, for: item, package: package)
                        try LocalRemoteSwitchService.applyInstalledPatch(for: item)
                    }.value
                } else {
                    try await Task.detached(priority: .userInitiated) {
                        try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                    }.value
                }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.18)) { isOn = newValue }
                    operationMessage = newValue
                        ? "\(LocalRemoteSwitchService.statusText(for: item)) • Đã tự động Apply Patch"
                        : "Đã tắt chức năng"
                    isBusy = false
                    onChange()
                }
            } catch {
                await MainActor.run {
                    isOn = LocalRemoteSwitchService.isEnabled(item)
                    isBusy = false
                    operationMessage = "Lỗi: \(error.localizedDescription)"
                    onChange()
                }
            }
        }
    }
}

private enum LocalRemoteSwitchService {
    static func isEnabled(_ item: RemoteAdminSwitch) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(item)) && localPackageExists(for: item)
    }

    static func matchesInstalledVersion(_ item: RemoteAdminSwitch) -> Bool {
        UserDefaults.standard.integer(forKey: versionKey(item)) == item.packageVersion
    }

    static func statusText(for item: RemoteAdminSwitch) -> String {
        guard let projectID = packageID(for: item),
              let existing = PatchProjectLibrary.load().first(where: { $0.id == projectID }),
              let project = existing.project else {
            return "Chức năng đã sẵn sàng"
        }
        return "Đã import • \(project.rules.count) rule • \(project.allBundleIdentifiers.first ?? item.gameBundleID ?? "game")"
    }

    static func applyInstalledPatch(for item: RemoteAdminSwitch) throws {
        guard let projectID = packageID(for: item),
              let installed = PatchProjectLibrary.load().first(where: { $0.id == projectID }),
              let baseProject = installed.project else {
            throw NSError(
                domain: "AujunpeakPatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy cấu hình patch đã cài."]
            )
        }

        let project = installed.summary.schemaVersion >= 2
            ? try PatchProjectLibrary.synchronizeWorkspace(item: installed)
            : baseProject
        _ = try DevicePatchService.apply(project: project)
    }

    static func setEnabled(_ enabled: Bool, for item: RemoteAdminSwitch, package: RemotePackagePayload?) throws {
        if enabled {
            guard let package else {
                throw NSError(domain: "AujunpeakPackage", code: 400, userInfo: [NSLocalizedDescriptionKey: "Thiếu dữ liệu chức năng từ Admin Server."])
            }
            try installDownloadedPackage(package, for: item)
            try writeMarker(for: item)
            UserDefaults.standard.set(true, forKey: storageKey(item))
            UserDefaults.standard.set(package.version, forKey: versionKey(item))
            UserDefaults.standard.set(package.sha256, forKey: hashKey(item))
        } else {
            try uninstallDownloadedPackage(for: item)
            try removeMarker(for: item)
            UserDefaults.standard.set(false, forKey: storageKey(item))
            UserDefaults.standard.removeObject(forKey: versionKey(item))
            UserDefaults.standard.removeObject(forKey: hashKey(item))
        }
    }

    static func packageID(for item: RemoteAdminSwitch) -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: packageIDKey(item)) else { return nil }
        return UUID(uuidString: raw)
    }

    private static func installDownloadedPackage(_ package: RemotePackagePayload, for item: RemoteAdminSwitch) throws {
        let data = package.data
        let summary = try PatchPackageCodec.inspect(data)
        let decoded = try decodePackage(data: data, summary: summary, password: package.password, item: item)

        if let previousID = packageID(for: item), previousID != summary.packageID,
           let previous = PatchProjectLibrary.load().first(where: { $0.id == previousID }) {
            try? PatchProjectLibrary.delete(previous)
        }

        let existing = PatchProjectLibrary.load().first(where: { $0.id == summary.packageID })
        try PatchProjectLibrary.installImportedPackage(data: data, decoded: decoded, summary: summary, existingURL: existing?.packageURL)
        try PatchKeyStore.store(decoded.contentKey, for: summary)
        UserDefaults.standard.set(summary.packageID.uuidString, forKey: packageIDKey(item))
    }

    private static func decodePackage(data: Data, summary: PatchPackageSummary, password: String?, item: RemoteAdminSwitch) throws -> DecodedPatchPackage {
        if let storedKey = try PatchKeyStore.load(for: summary) {
            return try PatchPackageCodec.decode(data, contentKey: storedKey)
        }
        if !summary.isPasswordProtected {
            return try PatchPackageCodec.decode(data, password: nil)
        }

        var candidates: [String] = []
        if let password, !password.isEmpty { candidates.append(password) }
        if ["builtin_drag", "builtin_nhe", "builtin_magic"].contains(item.configKey), !candidates.contains("james") {
            candidates.append("james")
        }
        if ["function_01", "function_02"].contains(item.configKey), !candidates.contains("huanha") {
            candidates.append("huanha")
        }
        for candidate in candidates {
            if let decoded = try? PatchPackageCodec.decode(data, password: candidate) {
                return decoded
            }
        }
        throw PatchPackageError.invalidPasswordOrCorruptedPackage
    }

    private static func uninstallDownloadedPackage(for item: RemoteAdminSwitch) throws {
        if let projectID = packageID(for: item), let existing = PatchProjectLibrary.load().first(where: { $0.id == projectID }) {
            try PatchProjectLibrary.delete(existing)
        }
        UserDefaults.standard.removeObject(forKey: packageIDKey(item))
    }

    private static func localPackageExists(for item: RemoteAdminSwitch) -> Bool {
        guard let projectID = packageID(for: item) else { return false }
        return PatchProjectLibrary.load().contains(where: { $0.id == projectID })
    }

    private static func writeMarker(for item: RemoteAdminSwitch) throws {
        let folder = try markerFolderURL()
        let marker = folder.appendingPathComponent(item.configKey + ".json")
        let payload: [String: Any] = [
            "config_key": item.configKey,
            "title": item.title,
            "enabled": true,
            "package_version": item.packageVersion,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try data.write(to: marker, options: [.atomic, .completeFileProtection])
    }

    private static func removeMarker(for item: RemoteAdminSwitch) throws {
        let marker = try markerFolderURL().appendingPathComponent(item.configKey + ".json")
        if FileManager.default.fileExists(atPath: marker.path) {
            try FileManager.default.removeItem(at: marker)
        }
    }

    private static func storageKey(_ item: RemoteAdminSwitch) -> String { "aujunpeak.remote.switch." + item.configKey }
    private static func packageIDKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".packageID" }
    private static func versionKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".version" }
    private static func hashKey(_ item: RemoteAdminSwitch) -> String { storageKey(item) + ".sha256" }

    private static func markerFolderURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("RemoteFunctions", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

private struct KeyInfoOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppNeonBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        keyHeader
                        keyDetails
                        deviceDetails
                        adminCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable { await licenseSession.refreshStatus() }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await licenseSession.refreshStatus() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private var keyHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.12, green: 0.05, blue: 0.20),
                                Color(red: 0.04, green: 0.10, blue: 0.22),
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 210, height: 210)
                    .blur(radius: 2)
                    .offset(x: 145, y: -82)

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 138, height: 138)
                    .offset(x: 142, y: -54)

                VStack(alignment: .leading, spacing: 17) {
                    HStack(spacing: 11) {
                        AppLogo(size: 52)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AUJUNPEAK VN")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("LICENSE CENTER")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundStyle(.white.opacity(0.62))
                        }

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("KEY INFORMATION")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Thông tin kích hoạt và thiết bị")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                        }

                        Spacer(minLength: 8)

                        Text(licenseStatusText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(licenseStatusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(licenseStatusColor.opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(licenseStatusColor.opacity(0.30), lineWidth: 1)
                            }
                    }
                }
                .padding(18)
            }
            .frame(height: 168)

            HStack(spacing: 0) {
                InfoHeroStat(
                    title: "THIẾT BỊ",
                    value: "\(licenseSession.license?.deviceCount ?? 0)/\(licenseSession.license?.maxDevices ?? 0)",
                    icon: "iphone"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 30)

                InfoHeroStat(
                    title: "THỜI HẠN",
                    value: "\(licenseSession.license?.durationDays ?? 0) ngày",
                    icon: "calendar"
                )

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 30)

                InfoHeroStat(
                    title: "VERSION",
                    value: AppUpdateChecker.currentVersion,
                    icon: "bolt.fill"
                )
            }
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.24))
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.62), Color.blue.opacity(0.32), Color.white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: AppTheme.accent.opacity(0.18), radius: 24, y: 10)
    }

    private var keyDetails: some View {
        InfoCard(title: "KEY", icon: "key.horizontal.fill") {
            InfoLine(title: "Key", value: licenseSession.license?.key ?? licenseSession.storedKey, monospaced: true)
            Divider()
            InfoLine(title: "Trạng thái", value: licenseStatusText)
            Divider()
            InfoLine(title: "Kích hoạt", value: displayDate(licenseSession.license?.activatedAt))
            Divider()
            InfoLine(title: "Hết hạn", value: displayDate(licenseSession.license?.expiresAt))
            Divider()
            InfoLine(title: "Thời hạn", value: "\(licenseSession.license?.durationDays ?? 0) ngày")
            Divider()
            InfoLine(title: "Thiết bị", value: "\(licenseSession.license?.deviceCount ?? 0) / \(licenseSession.license?.maxDevices ?? 0)")

            Button {
                UIPasteboard.general.string = licenseSession.license?.key ?? licenseSession.storedKey
            } label: {
                Label("Sao chép Key", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .padding(.top, 4)
        }
    }

    private var deviceDetails: some View {
        InfoCard(title: "THIẾT BỊ", icon: "iphone") {
            InfoLine(title: "Model", value: AppInfo.hardwareDisplayName)
            Divider()
            InfoLine(title: "iOS", value: AppInfo.osVersion)
            Divider()
            InfoLine(title: "Build", value: AppInfo.osBuild, monospaced: true)
            Divider()
            InfoLine(title: "App version", value: AppUpdateChecker.currentVersion)
            Divider()
            InfoLine(title: "Device ID", value: licenseSession.deviceID, monospaced: true)
        }
    }

    private var adminCard: some View {
        InfoCard(title: "HỖ TRỢ", icon: "person.crop.circle.badge.checkmark") {
            HStack {
                Text("Admin").foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 5) {
                    Text("Hà Văn Huấn")
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                }
            }
            Divider()
            InfoLine(title: "Panel", value: "Aujunpeak VN License")
            Divider()
            InfoLine(title: "Kênh liên hệ", value: "Zalo")
            Link(destination: zaloURL) {
                Label("Liên hệ Admin qua Zalo", systemImage: "message.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 4)

            Button(role: .destructive) {
                licenseSession.forgetKey()
            } label: {
                Label("Đổi / đăng xuất Key", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }

    private var licenseIsActive: Bool { licenseSession.license?.status == "active" }
    private var licenseStatusColor: Color { licenseIsActive ? .green : .orange }

    private var licenseStatusText: String {
        switch licenseSession.license?.status {
        case "active": return "ĐANG HOẠT ĐỘNG"
        case "expired": return "ĐÃ HẾT HẠN"
        case "revoked": return "ĐÃ BỊ KHÓA"
        case "unused": return "CHƯA KÍCH HOẠT"
        default: return licenseSession.storedKey.isEmpty ? "CHƯA CÓ KEY" : "ĐANG ĐỒNG BỘ"
        }
    }

    private func displayDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Chưa" }
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = input.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: "vi_VN")
        output.dateFormat = "dd/MM/yyyy HH:mm"
        return output.string(from: date)
    }
}

private struct InfoHeroStat: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 7)
    }
}

private struct InfoLine: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 10)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct GameIconView: View {
    let gameKey: String
    let remoteURL: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if let url = normalizedRemoteURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            fallbackImage
                                .opacity(0.34)
                            ProgressView()
                                .controlSize(.small)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .failure:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var fallbackImage: some View {
        if let asset = builtinAssetName {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var normalizedRemoteURL: URL? {
        guard let raw = remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let direct = URL(string: raw), direct.scheme != nil {
            return direct
        }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        return nil
    }

    private var builtinAssetName: String? {
        switch gameKey {
        case "freefire": return "GameIconFreeFire"
        case "freefiremax": return "GameIconFreeFireMax"
        case "pubg": return "GameIconPUBG"
        case "lienquan": return "GameIconLienQuan"
        default: return nil
        }
    }
}

private struct AppNeonBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if UIImage(named: "AppBackgroundNeon") != nil {
                    Image("AppBackgroundNeon")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .opacity(0.28)
                        .blur(radius: 28)
                }
                LinearGradient(colors: [Color.black.opacity(0.25), Color.black.opacity(0.75), Color.black.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(0..<18, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? Color.blue.opacity(0.14) : Color.pink.opacity(0.12))
                        .frame(width: CGFloat(18 + (index % 5) * 12), height: CGFloat(18 + (index % 5) * 12))
                        .position(
                            x: CGFloat((index * 41) % Int(max(proxy.size.width, 1))),
                            y: CGFloat((index * 97) % Int(max(proxy.size.height, 1)))
                        )
                        .blur(radius: 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
