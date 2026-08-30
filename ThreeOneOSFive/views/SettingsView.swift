import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aujunpeak.appearance") private var appearanceMode = "system"
    private let zaloURL = URL(string: "https://zalo.me/0833091543")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo(size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Aujunpeak VN")
                                    .font(.headline)
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.blue)
                            }
                            Text("Giao diện & thông tin quản trị")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                }

                Section("Giao diện") {
                    Picker("Chế độ hiển thị", selection: $appearanceMode) {
                        Label("Tự động", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Sáng", systemImage: "sun.max.fill").tag("light")
                        Label("Tối", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Admin") {
                    HStack {
                        Label("Hà Văn Huấn", systemImage: "person.crop.circle.fill")
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                    LabeledContent("Ứng dụng", value: "Aujunpeak VN")
                    Link(destination: zaloURL) {
                        Label("Liên hệ Zalo", systemImage: "message.fill")
                            .fontWeight(.semibold)
                    }
                }
            }
            .tint(AppTheme.accent)
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
