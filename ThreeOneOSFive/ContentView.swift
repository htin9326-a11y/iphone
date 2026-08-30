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
                    deviceSection
                    featuresSection
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

private struct FunctionOverlayView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    @State private var refreshToken = 0

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
        .background(Color(uiColor: .systemBackground))
        .zIndex(100)
    }

    @ViewBuilder
    private var remoteFunctions: some View {
        if licenseSession.switches.isEmpty {
            VStack(spacing: 8) {
                if licenseSession.lastError == nil {
                    ProgressView()
                } else {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                Text(licenseSession.lastError ?? "Đang tải chức năng từ Admin…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            VStack(spacing: 10) {
                ForEach(licenseSession.switches) { item in
                    RemoteFunctionSwitchCard(item: item) {
                        refreshToken &+= 1
                    }
                }
            }
            .id(refreshToken)
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
                Text("Chức năng được đồng bộ từ Admin Server")
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
        let activeCount = licenseSession.switches.filter { $0.enabled && LocalRemoteSwitchService.isEnabled($0) }.count
        return HStack(spacing: 10) {
            Image(systemName: activeCount > 0 ? "checkmark.seal.fill" : "circle.dashed")
                .foregroundStyle(activeCount > 0 ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trạng thái")
                    .font(.subheadline.weight(.semibold))
                Text("Đang bật \(activeCount)/\(licenseSession.switches.count) chức năng")
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
    let item: RemoteAdminSwitch
    let onChange: () -> Void
    @State private var isOn: Bool
    @State private var operationMessage: String?
    @State private var isBusy = false
    @State private var showApplyPrompt = false
    @State private var showPatchCenter = false

    init(item: RemoteAdminSwitch, onChange: @escaping () -> Void) {
        self.item = item
        self.onChange = onChange
        _isOn = State(initialValue: item.enabled && LocalRemoteSwitchService.isEnabled(item))
    }

    private var displaySubtitle: String {
        switch item.configKey {
        case "function_01": return item.subtitle + " • Bụng.3105"
        case "function_02": return item.subtitle + " • Cổ.3105"
        default: return item.subtitle
        }
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
                Text(operationMessage ?? (item.enabled ? displaySubtitle : "Admin đang tắt chức năng này"))
                    .font(.caption)
                    .foregroundStyle(operationMessage?.hasPrefix("Lỗi:") == true ? Color.red : (item.enabled ? Color.secondary : Color.orange))
                    .lineLimit(3)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    guard item.enabled, !isBusy else { return }
                    isBusy = true
                    operationMessage = newValue ? "Đang nạp package…" : "Đang gỡ package…"
                    Task {
                        do {
                            try await Task.detached(priority: .userInitiated) {
                                try LocalRemoteSwitchService.setEnabled(newValue, for: item)
                            }.value
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.18)) { isOn = newValue }
                                operationMessage = newValue
                                    ? LocalRemoteSwitchService.statusText(for: item)
                                    : "Đã gỡ package và workspace local"
                                isBusy = false
                                if newValue && LocalRemoteSwitchService.hasBundledPatch(for: item) {
                                    showApplyPrompt = true
                                }
                                onChange()
                            }
                        } catch {
                            await MainActor.run {
                                isOn = LocalRemoteSwitchService.isEnabled(item)
                                operationMessage = "Lỗi: \(error.localizedDescription)"
                                isBusy = false
                                onChange()
                            }
                        }
                    }
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
                    try LocalRemoteSwitchService.setEnabled(false, for: item)
                    isOn = false
                    operationMessage = "Admin đã tắt • package local đã gỡ"
                } catch {
                    operationMessage = "Lỗi: \(error.localizedDescription)"
                }
                onChange()
            }
        }
        .sheet(isPresented: $showApplyPrompt) {
            ApplyPatchPromptView(
                title: item.title,
                packageName: LocalRemoteSwitchService.bundledPatchDisplayName(for: item),
                targetBundleID: LocalRemoteSwitchService.targetBundleID(for: item),
                onApply: {
                    showApplyPrompt = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showPatchCenter = true
                    }
                },
                onLater: {
                    showApplyPrompt = false
                }
            )
        }
        .fullScreenCover(isPresented: $showPatchCenter) {
            ZStack(alignment: .topTrailing) {
                PatchProjectsView()
                Button {
                    showPatchCenter = false
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
    }
}

private struct ApplyPatchPromptView: View {
    let title: String
    let packageName: String
    let targetBundleID: String
    let onApply: () -> Void
    let onLater: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.orange.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 78, height: 78)
                .shadow(color: .red.opacity(0.28), radius: 18, y: 8)

                VStack(spacing: 6) {
                    Text("Package đã sẵn sàng")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text(title)
                        .font(.headline)
                    Text(packageName)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(spacing: 10) {
                    HStack {
                        Text("Target")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(targetBundleID)
                            .font(.system(.caption, design: .monospaced))
                    }
                    Divider()
                    HStack {
                        Text("Trạng thái")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label("Đã import", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Nhấn Apply Patch để mở đúng màn Patch gốc của app. Tại đó bạn chọn package vừa import và dùng nút Apply Patch có sẵn.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: onApply) {
                    Label("Apply Patch", systemImage: "checkmark.shield.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Để sau", action: onLater)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .navigationTitle("Apply Patch")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Switch 01/02 nạp package .3105 vào hệ Patch Library/Workspace của chính Aujunpeak VN.
/// Đồng thời tạo một bản mirror trong Documents/AppDataBrowserImports để kiểm tra package local.
/// AppDataBrowser thật duyệt container ứng dụng được ContainerStore resolve; thư mục mirror này
/// không phải container của ứng dụng đích và không được coi là thao tác Apply.
private enum LocalRemoteSwitchService {
    private static let packagePassword = "huanha"

    static func isEnabled(_ item: RemoteAdminSwitch) -> Bool {
        UserDefaults.standard.bool(forKey: storageKey(item)) && localPackageExists(for: item)
    }

    static func statusText(for item: RemoteAdminSwitch) -> String {
        guard let source = try? bundledPatchURL(for: item),
              let data = try? Data(contentsOf: source, options: .mappedIfSafe),
              let summary = try? PatchPackageCodec.inspect(data),
              let decoded = try? PatchPackageCodec.decode(
                data,
                password: summary.isPasswordProtected ? packagePassword : nil
              ) else {
            return "Package đã import nhưng không đọc được metadata"
        }
        let bundles = decoded.project.allBundleIdentifiers.joined(separator: ", ")
        return "Đã import • \(decoded.project.rules.count) rule • \(bundles)"
    }

    static func setEnabled(_ enabled: Bool, for item: RemoteAdminSwitch) throws {
        if enabled {
            try installBundledPackage(for: item)
            try writeMarker(for: item)
            UserDefaults.standard.set(true, forKey: storageKey(item))
        } else {
            try uninstallBundledPackage(for: item)
            try removeMarker(for: item)
            UserDefaults.standard.set(false, forKey: storageKey(item))
        }
    }

    static func hasBundledPatch(for item: RemoteAdminSwitch) -> Bool {
        bundledPatchFilename(for: item) != nil
    }

    static func bundledPatchDisplayName(for item: RemoteAdminSwitch) -> String {
        bundledPatchFilename(for: item) ?? "Không có package"
    }

    static func targetBundleID(for item: RemoteAdminSwitch) -> String {
        guard let source = try? bundledPatchURL(for: item),
              let data = try? Data(contentsOf: source, options: .mappedIfSafe),
              let summary = try? PatchPackageCodec.inspect(data),
              let decoded = try? PatchPackageCodec.decode(
                data,
                password: summary.isPasswordProtected ? packagePassword : nil
              ) else {
            return "com.dts.freefireth"
        }
        return decoded.project.allBundleIdentifiers.first ?? "com.dts.freefireth"
    }

    private static func bundledPatchFilename(for item: RemoteAdminSwitch) -> String? {
        switch item.configKey {
        case "function_01": return "Bụng.3105"
        case "function_02": return "Cổ.3105"
        default: return nil
        }
    }

    private static func bundledPatchURL(for item: RemoteAdminSwitch) throws -> URL? {
        guard let filename = bundledPatchFilename(for: item) else { return nil }
        let ns = filename as NSString
        guard let source = Bundle.main.url(
            forResource: ns.deletingPathExtension,
            withExtension: ns.pathExtension
        ) else {
            throw NSError(
                domain: "AujunpeakBundledPatch",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy \(filename) trong app."]
            )
        }
        return source
    }

    private static func installBundledPackage(for item: RemoteAdminSwitch) throws {
        guard let source = try bundledPatchURL(for: item),
              let filename = bundledPatchFilename(for: item) else {
            // Switch không gắn package vẫn được dùng như switch cấu hình local.
            return
        }

        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        let summary = try PatchPackageCodec.inspect(data)
        let decoded = try PatchPackageCodec.decode(
            data,
            password: summary.isPasswordProtected ? packagePassword : nil
        )

        // Nếu cùng package đã tồn tại thì update tại chỗ để tránh tạo bản trùng.
        let existing = PatchProjectLibrary.load().first(where: { $0.id == summary.packageID })
        try PatchProjectLibrary.installImportedPackage(
            data: data,
            decoded: decoded,
            summary: summary,
            existingURL: existing?.packageURL
        )
        try PatchKeyStore.store(decoded.contentKey, for: summary)

        // Mirror package vào Documents để AppDataBrowser của chính app nhìn thấy file thật.
        let fm = FileManager.default
        let browserFolder = try appDataBrowserImportURL()
        try fm.createDirectory(at: browserFolder, withIntermediateDirectories: true)
        let mirror = browserFolder.appendingPathComponent(filename)
        if fm.fileExists(atPath: mirror.path) { try fm.removeItem(at: mirror) }
        try data.write(to: mirror, options: .atomic)
    }

    private static func uninstallBundledPackage(for item: RemoteAdminSwitch) throws {
        if let source = try bundledPatchURL(for: item) {
            let data = try Data(contentsOf: source, options: .mappedIfSafe)
            if let summary = try? PatchPackageCodec.inspect(data),
               let existing = PatchProjectLibrary.load().first(where: { $0.id == summary.packageID }) {
                try PatchProjectLibrary.delete(existing)
            }
        }

        if let filename = bundledPatchFilename(for: item) {
            let mirror = try appDataBrowserImportURL().appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: mirror.path) {
                try FileManager.default.removeItem(at: mirror)
            }
        }
    }

    private static func localPackageExists(for item: RemoteAdminSwitch) -> Bool {
        guard let filename = bundledPatchFilename(for: item),
              let mirror = try? appDataBrowserImportURL().appendingPathComponent(filename) else {
            return UserDefaults.standard.bool(forKey: storageKey(item))
        }
        return FileManager.default.fileExists(atPath: mirror.path)
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
            "local_package": bundledPatchFilename(for: item) ?? NSNull(),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try data.write(to: marker, options: .atomic)
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

    private static func markerFolderURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("RemoteFunctions", isDirectory: true)
    }

    private static func appDataBrowserImportURL() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("AppDataBrowserImports", isDirectory: true)
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
                        serverDetails
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
            Text("Thông tin đồng bộ từ Aujunpeak Admin Server")
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

    private var serverDetails: some View {
        InfoCard(title: "SERVER", icon: "server.rack") {
            InfoLine(title: "API", value: "103.140.249.74:8082", monospaced: true)
            Divider()
            InfoLine(title: "Switch từ Admin", value: "\(licenseSession.switches.count)")
            Divider()
            InfoLine(title: "Đồng bộ", value: licenseSession.lastError == nil ? "Đã kết nối" : "Có cảnh báo")
            if let error = licenseSession.lastError, !error.isEmpty {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
