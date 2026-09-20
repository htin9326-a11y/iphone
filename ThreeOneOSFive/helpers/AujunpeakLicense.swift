import Foundation
import SwiftUI
import UIKit
import CryptoKit

// MARK: - Aujunpeak VN License / Admin Server

enum AdminServerConfig {
    // Upload thư mục `aujunpeak-admin` vào domain/VPS ở cùng đường dẫn này,
    // hoặc đổi URL tại đây nếu bạn dùng domain/path khác.
    static let apiBaseURL = URL(string: "http://103.140.249.74:8082/api")!
}


struct RemoteGameSection: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let gameKey: String
    let title: String
    let bundleID: String
    let iconURL: String?
    let enabled: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, title, enabled
        case gameKey = "game_key"
        case bundleID = "bundle_id"
        case iconURL = "icon_url"
        case sortOrder = "sort_order"
    }

    static let fallbackGames: [RemoteGameSection] = [
        .init(id: 1, gameKey: "freefire", title: "Free Fire", bundleID: "com.dts.freefireth", iconURL: nil, enabled: true, sortOrder: 10),
        .init(id: 2, gameKey: "freefiremax", title: "Free Fire Max", bundleID: "com.dts.freefiremax", iconURL: nil, enabled: true, sortOrder: 20),
        .init(id: 3, gameKey: "pubg", title: "PUBG Mobile", bundleID: "com.tencent.ig", iconURL: nil, enabled: true, sortOrder: 30),
        .init(id: 4, gameKey: "lienquan", title: "Liên Quân", bundleID: "com.garena.game.kgvn", iconURL: nil, enabled: true, sortOrder: 40)
    ]
}

struct RemoteAdminSwitch: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let configKey: String
    let title: String
    let subtitle: String
    let icon: String
    let enabled: Bool
    let sortOrder: Int
    let hasPackage: Bool
    let packageVersion: Int
    let packageHash: String?
    let gameKey: String
    let gameName: String?
    let gameBundleID: String?
    let gameIconURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, icon, enabled
        case configKey = "config_key"
        case sortOrder = "sort_order"
        case hasPackage = "has_package"
        case packageVersion = "package_version"
        case packageHash = "package_sha256"
        case gameKey = "game_key"
        case gameName = "game_name"
        case gameBundleID = "game_bundle_id"
        case gameIconURL = "game_icon_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        configKey = try c.decode(String.self, forKey: .configKey)
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "bolt.fill"
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        hasPackage = try c.decodeIfPresent(Bool.self, forKey: .hasPackage) ?? false
        packageVersion = try c.decodeIfPresent(Int.self, forKey: .packageVersion) ?? 0
        packageHash = try c.decodeIfPresent(String.self, forKey: .packageHash)
        gameKey = try c.decodeIfPresent(String.self, forKey: .gameKey) ?? "freefire"
        gameName = try c.decodeIfPresent(String.self, forKey: .gameName)
        gameBundleID = try c.decodeIfPresent(String.self, forKey: .gameBundleID)
        gameIconURL = try c.decodeIfPresent(String.self, forKey: .gameIconURL)
    }
}

struct RemotePackagePayload: Sendable {
    let data: Data
    let password: String?
    let sha256: String
    let version: Int
}

struct RemoteLicenseInfo: Codable, Equatable {
    let key: String
    let status: String
    let activatedAt: String?
    let expiresAt: String?
    let durationDays: Int
    let maxDevices: Int
    let deviceCount: Int

    enum CodingKeys: String, CodingKey {
        case key, status
        case activatedAt = "activated_at"
        case expiresAt = "expires_at"
        case durationDays = "duration_days"
        case maxDevices = "max_devices"
        case deviceCount = "device_count"
    }
}

struct RemoteUpdateConfig: Codable, Equatable, Sendable {
    let enabled: Bool
    let version: String
    let url: String
    let notes: String?
}

struct RemoteClientSettings: Codable, Equatable, Sendable {
    let supportURL: String?
    let update: RemoteUpdateConfig?

    enum CodingKeys: String, CodingKey {
        case supportURL = "support_url"
        case update
    }
}

private struct LicenseAPIResponse: Codable {
    let ok: Bool
    let code: String?
    let message: String?
    let license: RemoteLicenseInfo?
    let switches: [RemoteAdminSwitch]?
    let games: [RemoteGameSection]?
    let settings: RemoteClientSettings?
}

struct LicenseFailureNotice: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let title: String
    let message: String
}

@MainActor
final class LicenseSession: ObservableObject {
    @Published private(set) var license: RemoteLicenseInfo?
    @Published private(set) var switches: [RemoteAdminSwitch] = []
    @Published private(set) var games: [RemoteGameSection] = []
    @Published private(set) var clientSettings: RemoteClientSettings?
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var requiresActivation = false
    @Published private(set) var failureNotice: LicenseFailureNotice?

    private let keyStorageKey = "aujunpeak.remote.license.key"
    private let deviceStorageKey = "aujunpeak.remote.device.id"

    var storedKey: String {
        UserDefaults.standard.string(forKey: keyStorageKey) ?? ""
    }

    var deviceID: String {
        if let value = UserDefaults.standard.string(forKey: deviceStorageKey), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: deviceStorageKey)
        return value
    }

    var supportURL: URL {
        if let raw = clientSettings?.supportURL, let url = URL(string: raw) { return url }
        return URL(string: "https://zalo.me/0833091543")!
    }

    func bootstrap() async {
        guard !storedKey.isEmpty else {
            requiresActivation = true
            return
        }
        await refreshStatus()
    }

    func activate(key: String) async -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            lastError = "Vui lòng nhập key."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await request(endpoint: "activate.php", key: clean)
            guard response.ok, let info = response.license else {
                lastError = response.message ?? "Không thể kích hoạt key."
                return false
            }
            UserDefaults.standard.set(clean, forKey: keyStorageKey)
            license = info
            switches = (response.switches ?? []).sorted { $0.sortOrder < $1.sortOrder }
            games = (response.games ?? RemoteGameSection.fallbackGames).sorted { $0.sortOrder < $1.sortOrder }
            clientSettings = response.settings
            lastError = nil
            requiresActivation = false
            return true
        } catch {
            lastError = "Không kết nối được server: \(error.localizedDescription)"
            return false
        }
    }

    func refreshStatus() async {
        guard failureNotice == nil else { return }
        guard !storedKey.isEmpty else {
            requiresActivation = true
            license = nil
            switches = []
            games = RemoteGameSection.fallbackGames
            return
        }
        do {
            let response = try await request(endpoint: "status.php", key: storedKey)
            guard response.ok, let info = response.license else {
                let message = response.message ?? "Key không còn hợp lệ."
                lastError = message
                license = nil
                switches = []
                games = RemoteGameSection.fallbackGames
                requiresActivation = false
                failureNotice = LicenseFailureNotice(
                    code: response.code ?? "invalid",
                    title: failureTitle(for: response.code),
                    message: message
                )
                return
            }
            license = info
            switches = (response.switches ?? []).sorted { $0.sortOrder < $1.sortOrder }
            games = (response.games ?? RemoteGameSection.fallbackGames).sorted { $0.sortOrder < $1.sortOrder }
            clientSettings = response.settings
            requiresActivation = false
            lastError = nil
        } catch {
            lastError = "Mất kết nối server: \(error.localizedDescription)"
            if license == nil { requiresActivation = true }
        }
    }

    func forgetKey() {
        UserDefaults.standard.removeObject(forKey: keyStorageKey)
        license = nil
        switches = []
        games = []
        lastError = nil
        failureNotice = nil
        requiresActivation = true
    }

    func completeFailureLogout() {
        UserDefaults.standard.removeObject(forKey: keyStorageKey)
        license = nil
        switches = []
        games = []
        lastError = nil
        failureNotice = nil
        requiresActivation = true
    }

    func downloadPackage(for item: RemoteAdminSwitch) async throws -> RemotePackagePayload {
        guard item.hasPackage else {
            throw NSError(domain: "AujunpeakPackage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Admin chưa gắn dữ liệu chức năng cho nút này."])
        }
        guard !storedKey.isEmpty else {
            throw NSError(domain: "AujunpeakPackage", code: 401, userInfo: [NSLocalizedDescriptionKey: "Phiên key không còn hợp lệ."])
        }

        let url = AdminServerConfig.apiBaseURL.appendingPathComponent("package.php")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "key": storedKey,
            "device_id": deviceID,
            "switch_id": item.id,
            "app_version": AppUpdateChecker.currentVersion
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let message = object["message"] as? String {
                throw NSError(domain: "AujunpeakPackage", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
            }
            throw NSError(domain: "AujunpeakPackage", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Không thể tải dữ liệu chức năng từ Admin Server."])
        }

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let expected = (item.packageHash ?? http.value(forHTTPHeaderField: "X-Aujunpeak-Package-SHA256") ?? "").lowercased()
        if !expected.isEmpty && expected != digest.lowercased() {
            throw NSError(domain: "AujunpeakPackage", code: 422, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu chức năng không khớp chữ ký SHA-256."])
        }

        var password: String?
        if let encoded = http.value(forHTTPHeaderField: "X-Aujunpeak-Package-Password-B64"),
           let passwordData = Data(base64Encoded: encoded),
           let decodedPassword = String(data: passwordData, encoding: .utf8),
           !decodedPassword.isEmpty {
            password = decodedPassword
        }
        if password == nil && ["builtin_drag", "builtin_nhe", "builtin_magic"].contains(item.configKey) {
            password = "james"
        }

        let version = Int(http.value(forHTTPHeaderField: "X-Aujunpeak-Package-Version") ?? "") ?? item.packageVersion
        return RemotePackagePayload(data: data, password: password, sha256: digest, version: version)
    }

    private func failureTitle(for code: String?) -> String {
        switch code {
        case "revoked": return "KEY ĐÃ BỊ KHÓA"
        case "expired": return "KEY ĐÃ HẾT HẠN"
        case "device_not_bound": return "THIẾT BỊ ĐÃ BỊ RESET"
        case "invalid_key": return "KEY KHÔNG HỢP LỆ"
        case "not_activated": return "KEY CHƯA KÍCH HOẠT"
        default: return "PHIÊN ĐĂNG NHẬP THẤT BẠI"
        }
    }

    private func request(endpoint: String, key: String) async throws -> LicenseAPIResponse {
        let url = AdminServerConfig.apiBaseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "key": key,
            "device_id": deviceID,
            "device_name": UIDevice.current.model + " / " + AppInfo.displayMachineName,
            "app_version": AppUpdateChecker.currentVersion
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard response is HTTPURLResponse else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(LicenseAPIResponse.self, from: data)
    }
}
struct LicenseFailureOverlay: View {
    let notice: LicenseFailureNotice
    let onFinished: () -> Void
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.red.opacity(pulse ? 0.28 : 0.10), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.14))
                        .frame(width: 112, height: 112)
                    Circle()
                        .stroke(Color.red.opacity(0.45), lineWidth: 2)
                        .frame(width: appeared ? 126 : 86, height: appeared ? 126 : 86)
                        .opacity(appeared ? 0.1 : 0.8)
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.red)
                }

                Text("FAILED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.red)

                VStack(spacing: 7) {
                    Text(notice.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(notice.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.64))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Đang đăng xuất khỏi thiết bị…")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.top, 6)
            }
            .padding(28)
            .scaleEffect(appeared ? 1 : 0.86)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                appeared = true
            }
            pulse = true
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            onFinished()
        }
    }
}

struct LicenseCheckOverlay: View {
    let succeeded: Bool
    let hasStoredKey: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.90)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill((succeeded ? AppTheme.secondaryAccent : AppTheme.accent).opacity(0.14))
                        .frame(width: 92, height: 92)

                    if succeeded {
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(AppTheme.secondaryAccent)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.secondaryAccent)
                    }
                }

                Text(succeeded ? "KEY ĐÃ XÁC THỰC" : "ĐANG KIỂM TRA KEY")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    succeeded
                    ? "Thiết bị đã sẵn sàng sử dụng"
                    : (hasStoredKey ? "Đang đồng bộ trạng thái thiết bị…" : "Đang chuẩn bị hệ thống…")
                )
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
            }
            .padding(28)
            .frame(maxWidth: 290)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        (succeeded ? AppTheme.secondaryAccent : AppTheme.accent).opacity(0.34),
                        lineWidth: 1
                    )
            }
        }
    }
}

struct LicenseActivationView: View {
    @EnvironmentObject private var licenseSession: LicenseSession
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!
    @State private var keyText = ""
    @State private var shake = false
    @FocusState private var keyFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.62)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { keyFocused = false }

                VStack(spacing: 0) {
                    Capsule()
                        .fill(AppTheme.borderStrong)
                        .frame(width: 42, height: 4)
                        .padding(.top, 10)
                        .padding(.bottom, 13)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            keyPreview
                            keyField

                            if let error = licenseSession.lastError, !error.isEmpty {
                                HStack(alignment: .top, spacing: 9) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.78))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(Color.red.opacity(0.20), lineWidth: 1)
                                }
                            }

                            loginButton
                            contactButton
                            deviceLine
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }
                }
                .frame(maxWidth: 560)
                .frame(height: min(proxy.size.height * 0.78, 620))
                .background(AppTheme.surface, in: AujunpeakTopSheetShape(radius: 28))
                .overlay(alignment: .top) {
                    AujunpeakTopSheetShape(radius: 28)
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 26, y: -8)
                .offset(x: shake ? -7 : 0)
                .onAppear {
                    if keyText.isEmpty { keyText = licenseSession.storedKey }
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            AppLogo(size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Aujunpeak")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Đăng nhập bằng Key để mở toàn bộ chức năng")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "lock.open.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var keyPreview: some View {
        HStack(spacing: 9) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 30, height: 30)
                .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("KEY")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.1)
                Text(keyText.isEmpty ? "AJP-XXXX-XXXX-XXXX" : keyText.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(AppTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
    }

    private var keyField: some View {
        HStack(spacing: 9) {
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            TextField("Nhập Key của bạn", text: $keyText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .textContentType(.password)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($keyFocused)
                .submitLabel(.go)
                .onSubmit { performLogin() }

            Button {
                keyText = UIPasteboard.general.string ?? keyText
                keyFocused = true
            } label: {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 11)
        .frame(height: 52)
        .background(AppTheme.base, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(AppTheme.borderStrong, lineWidth: 1)
        }
    }

    private var loginButton: some View {
        Button(action: performLogin) {
            HStack(spacing: 9) {
                if licenseSession.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                }
                Text(licenseSession.isLoading ? "Đang kiểm tra…" : "LOGIN KEY")
            }
            .font(.headline.weight(.black))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 53)
        }
        .buttonStyle(AppGradientButtonStyle(colors: [AppTheme.surfaceElevated, AppTheme.base]))
        .disabled(licenseSession.isLoading || keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    private var contactButton: some View {
        Link(destination: zaloURL) {
            HStack(spacing: 8) {
                Image(systemName: "bag.fill")
                Text("Liên hệ mua Key")
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var deviceLine: some View {
        HStack(spacing: 7) {
            Image(systemName: "iphone.gen3")
            Text("Thiết bị • \(licenseSession.deviceID.prefix(18))…")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(AppTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func performLogin() {
        let trimmed = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !licenseSession.isLoading else { return }
        keyFocused = false
        Task {
            let ok = await licenseSession.activate(key: trimmed)
            if !ok {
                await MainActor.run {
                    withAnimation(.default.repeatCount(3, autoreverses: true)) { shake.toggle() }
                }
            }
        }
    }
}
