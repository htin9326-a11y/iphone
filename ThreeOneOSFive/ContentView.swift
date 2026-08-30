import Foundation
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @State private var tabNavigation: AppTabNavigationState
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(FeatureVisibility.wallpapersStorageKey) private var wallpapersEnabled = true

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-files-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-patch-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-cleaner-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 4
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
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.patches.rawValue) }
        }
        .onChange(of: cleanerEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onChange(of: wallpapersEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
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
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
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
                            Text(language.text(section.titleKey))
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
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
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
                wallpapersSupported: wallpapersSupported
            )
        case .files:
            ZStack {
                // Original Files implementation remains mounted underneath.
                AppDataBrowserView(
                    tabSession: filesTabSession
                )
                FunctionOverlayView()
            }
        case .patches:
            ZStack {
                // Original Patches implementation remains mounted underneath.
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
        FeatureVisibility(
            cleanerEnabled: cleanerEnabled,
            wallpapersEnabled: wallpapersEnabled,
            wallpapersSupported: wallpapersSupported
        )
    }

    private var wallpapersSupported: Bool {
        WallpaperFeatureSupportPolicy.isSupported(major: AppInfo.versionTuple.major)
    }

    private var selectedVisibleSection: AppSection {
        guard let section = AppSection(rawValue: tabNavigation.selectedTab),
              featureVisibility.isVisible(section) else {
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
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .files: return "tab.files"
        case .patches: return "tab.patches"
        case .cleaner: return "tab.cleaner"
        case .wallpapers: return "tab.wallpapers"
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
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @State private var showSettings = false
    @Binding var cleanerEnabled: Bool
    @Binding var wallpapersEnabled: Bool
    let wallpapersSupported: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                List {
                    shopBannerSection
                    deviceSection
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 72)
                }

                HomeAdminOverlayCard()
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .zIndex(10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(language.text("accessibility.open_settings"))
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var shopBannerSection: some View {
        Section {
            Link(destination: URL(string: "https://huanha.shop/")!) {
                ZStack(alignment: .bottomLeading) {
                    Image("AujunpeakHomeBanner")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 168)
                        .clipped()

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("AUJUNPEAK VN")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("huanha.shop • Nhấn để truy cập")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(14)
                }
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: Color.blue.opacity(0.18), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var featuresSection: some View {
        Section {
            Toggle(isOn: $cleanerEnabled) {
                Label(language.text("tab.cleaner"), systemImage: "sparkles")
            }
            if wallpapersSupported {
                Toggle(isOn: $wallpapersEnabled) {
                    Label(language.text("tab.wallpapers"), systemImage: "photo.on.rectangle.angled")
                }
            }
        } header: {
            Text(language.text("dashboard.features"))
        } footer: {
            Text(language.text("dashboard.features_footer"))
        }
    }

    private var deviceSection: some View {
        Section {
            LabeledContent(language.text("dashboard.hardware_model")) {
                Text(AppInfo.displayMachineName)
                    .font(.body.monospaced())
            }
            LabeledContent(language.text("settings.ios_version")) {
                Text("\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                    .font(.body.monospaced())
            }
            HStack {
                Text(language.text("settings.compatibility"))
                Spacer()
                Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                .foregroundStyle(appState.isSupported ? Color.green : Color.red)
            }

            if appState.kernelExploitApplicable && AppInfo.versionTuple.major < 26 {
                HStack {
                    Text(language.text("dashboard.kernel_status"))
                    Spacer()
                    if appState.kernelExploitRunning {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(language.text("dashboard.kernel_running"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(language.text(appState.exploitStatus.isSuccess ? "dashboard.kernel_active" : "dashboard.kernel_inactive"))
                        .foregroundStyle(appState.exploitStatus.isSuccess ? Color.green : Color.secondary)
                    }
                }
            }
        } header: {
            Text(language.text("common.device"))
        } footer: {
            Text(language.text("settings.supported_range_summary"))
        }
    }
}


// MARK: - Aujunpeak custom presentation overlays
// These views intentionally sit above the original Home/Files/Patches UI.
// The original feature code remains in the project and is not deleted.

private struct HomeAdminOverlayCard: View {
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 6)
    }
}

private struct PatchCenterRoute: Identifiable {
    let id = UUID()
    let projectID: UUID
}

private struct FunctionOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @State private var refreshToken = 0
    @State private var applyPromptItem: RemoteAdminSwitch?
    @State private var patchCenterRoute: PatchCenterRoute?

    private var allFunctionItems: [RemoteAdminSwitch] {
        licenseSession.switches
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        functionHeader
                        functionTargetCard
                        remoteFunctions
                        statusCard
                            .id(refreshToken)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await licenseSession.refreshStatus()
                }
            }
            .navigationTitle("Function")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await licenseSession.refreshStatus() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                Task { await licenseSession.refreshStatus() }
            }
        }
        .sheet(item: $applyPromptItem) { item in
            ApplyPatchPromptView(
                title: item.title,
                targetBundleID: LocalRemoteSwitchService.targetBundleID(for: item),
                onApply: {
                    let projectID = LocalRemoteSwitchService.packageID(for: item)
                    applyPromptItem = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        if let projectID {
                            patchCenterRoute = PatchCenterRoute(projectID: projectID)
                        }
                    }
                },
                onLater: {
                    applyPromptItem = nil
                }
            )
        }
        .fullScreenCover(item: $patchCenterRoute) { route in
            ZStack(alignment: .topTrailing) {
                PatchDirectApplyView(projectID: route.projectID)
                Button {
                    patchCenterRoute = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
                .accessibilityLabel("Đóng")
                .zIndex(20)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .zIndex(100)
    }

    @ViewBuilder
    private var remoteFunctions: some View {
        VStack(spacing: 10) {
            ForEach(licenseSession.switches) { item in
                RemoteFunctionSwitchCard(
                    item: item,
                    onChange: { refreshToken &+= 1 },
                    onRequestApply: { requestedItem in applyPromptItem = requestedItem }
                )
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
                    .fill(
                        LinearGradient(
                            colors: [Color.red.opacity(0.95), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                Text("Trung tâm chức năng Aujunpeak VN")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.red.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private var functionTargetCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.red.opacity(0.18))
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.red)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("Target")
                    .font(.subheadline.weight(.semibold))
                Text("com.dts.freefireth")
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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.red.opacity(0.16), lineWidth: 1)
        }
    }

    private var statusCard: some View {
        let activeCount = allFunctionItems.filter { $0.enabled && LocalRemoteSwitchService.isEnabled($0) }.count
        return HStack(spacing: 10) {
            Image(systemName: activeCount > 0 ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trạng thái")
                    .font(.subheadline.weight(.semibold))
                Text("Đang bật \(activeCount)/\(allFunctionItems.count) chức năng")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(activeCount > 0 ? "ACTIVE" : "READY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    (activeCount > 0 ? Color.green : Color.secondary).opacity(0.10),
                    in: Capsule()
                )
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RemoteFunctionSwitchCard: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    let item: RemoteAdminSwitch
    let onChange: () -> Void
    let onRequestApply: (RemoteAdminSwitch) -> Void
    @State private var isOn: Bool
    @State private var operationMessage: String?
    @State private var isBusy = false

    init(
        item: RemoteAdminSwitch,
        onChange: @escaping () -> Void,
        onRequestApply: @escaping (RemoteAdminSwitch) -> Void
    ) {
        self.item = item
        self.onChange = onChange
        self.onRequestApply = onRequestApply
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

                if isOn && item.hasPackage && LocalRemoteSwitchService.packageID(for: item) != nil {
                    Button {
                        onRequestApply(item)
                    } label: {
                        Label("Apply Patch", systemImage: "checkmark.shield.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AppTheme.accent.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isOn ? AppTheme.accent.opacity(0.18) : Color.primary.opacity(0.04), lineWidth: 1)
        }
        .opacity(item.enabled ? 1 : 0.65)
        .onAppear {
            isOn = item.enabled && LocalRemoteSwitchService.isEnabled(item)
        }
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
            // Nếu Admin thay package trong khi switch đang bật, tự tải bản mới và giữ flow Apply Patch.
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
                    }.value
                } else {
                    try await Task.detached(priority: .userInitiated) {
                        try LocalRemoteSwitchService.setEnabled(false, for: item, package: nil)
                    }.value
                }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.18)) { isOn = newValue }
                    operationMessage = newValue ? LocalRemoteSwitchService.statusText(for: item) : "Đã tắt chức năng"
                    isBusy = false
                    if newValue { onRequestApply(item) }
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

private struct ApplyPatchPromptView: View {
    let title: String
    let targetBundleID: String
    let onApply: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 42, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Apply Patch")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text("Cấu hình đã sẵn sàng")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(targetBundleID)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                }
                Spacer()
                Label("Sẵn sàng", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: onApply) {
                Label("Apply Patch", systemImage: "checkmark.shield.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button("Để sau", action: onLater)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}

/// Remote switch tải package chức năng từ Admin Server sau khi key/device được xác thực.
/// Package không được nhúng trong IPA; bản tải về được lưu bằng complete file protection
/// trong Application Support/PatchProjects và chỉ tồn tại sau khi người dùng bật chức năng.
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
        let bundles = project.allBundleIdentifiers.joined(separator: ", ")
        return "Sẵn sàng • \(project.rules.count) rule • \(bundles)"
    }

    static func setEnabled(
        _ enabled: Bool,
        for item: RemoteAdminSwitch,
        package: RemotePackagePayload?
    ) throws {
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

    static func targetBundleID(for item: RemoteAdminSwitch) -> String {
        guard let projectID = packageID(for: item),
              let project = PatchProjectLibrary.load().first(where: { $0.id == projectID })?.project else {
            return "com.dts.freefireth"
        }
        return project.allBundleIdentifiers.first ?? "com.dts.freefireth"
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
        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existing?.packageURL
        )
        try PatchKeyStore.store(decoded.contentKey, for: summary)
        UserDefaults.standard.set(summary.packageID.uuidString, forKey: packageIDKey(item))
    }

    private static func decodePackage(
        data: Data,
        summary: PatchPackageSummary,
        password: String?,
        item: RemoteAdminSwitch
    ) throws -> DecodedPatchPackage {
        if let storedKey = try PatchKeyStore.load(for: summary) {
            return try PatchPackageCodec.decode(data, contentKey: storedKey)
        }
        if !summary.isPasswordProtected {
            return try PatchPackageCodec.decode(data, password: nil)
        }

        var candidates: [String] = []
        if let password, !password.isEmpty { candidates.append(password) }
        if ["builtin_drag", "builtin_nhe", "builtin_magic"].contains(item.configKey),
           !candidates.contains("james") {
            candidates.append("james")
        }
        if ["function_01", "function_02"].contains(item.configKey),
           !candidates.contains("huanha") {
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
        if let projectID = packageID(for: item),
           let existing = PatchProjectLibrary.load().first(where: { $0.id == projectID }) {
            try PatchProjectLibrary.delete(existing)
        }
        UserDefaults.standard.removeObject(forKey: packageIDKey(item))
    }

    private static func localPackageExists(for item: RemoteAdminSwitch) -> Bool {
        guard let projectID = packageID(for: item) else { return false }
        return PatchProjectLibrary.load().contains(where: { $0.id == projectID })
    }

    private static func writeMarker(for item: RemoteAdminSwitch) throws {
        let fm = FileManager.default
        let folder = try markerFolderURL()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
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

    private static func storageKey(_ item: RemoteAdminSwitch) -> String {
        "aujunpeak.remote.switch." + item.configKey
    }

    private static func packageIDKey(_ item: RemoteAdminSwitch) -> String {
        storageKey(item) + ".packageID"
    }

    private static func versionKey(_ item: RemoteAdminSwitch) -> String {
        storageKey(item) + ".version"
    }

    private static func hashKey(_ item: RemoteAdminSwitch) -> String {
        storageKey(item) + ".sha256"
    }

    private static func markerFolderURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
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
                Color(uiColor: .systemBackground)
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
                .zIndex(2)
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
        .background(Color(uiColor: .systemBackground))
        .zIndex(100)
    }

    private var keyHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [licenseIsActive ? Color.green : Color.orange, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "key.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 66, height: 66)
            .shadow(color: (licenseIsActive ? Color.green : Color.orange).opacity(0.25), radius: 16, y: 8)

            Text("KEY INFORMATION")
                .font(.system(size: 19, weight: .black, design: .rounded))
            Text("Thông tin kích hoạt Aujunpeak VN")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(licenseStatusText)
                .font(.caption.weight(.bold))
                .foregroundStyle(licenseIsActive ? Color.green : Color.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background((licenseIsActive ? Color.green : Color.orange).opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder((licenseIsActive ? Color.green : Color.orange).opacity(0.20), lineWidth: 1)
        }
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
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
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

    private var licenseIsActive: Bool {
        licenseSession.license?.status == "active"
    }

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
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
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
