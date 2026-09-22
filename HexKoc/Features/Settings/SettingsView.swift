import SwiftUI

struct SettingsView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var toast: String?

    var body: some View {
        @Bindable var settings = settings

        return ScrollView {
            VStack(spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Görünüm")

                        Picker("İsim dili", selection: $settings.nameLanguage) {
                            ForEach(NameLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Alt başlıkta diğer dili göster", isOn: $settings.showEnglishSubtitle)
                            .font(.subheadline)
                            .tint(Theme.accent)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Veri")

                        HStack {
                            Text("Yama")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text(store.patch)
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.text)
                        }
                        HStack {
                            Text("Son güncelleme")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text(Format.dateTime(store.generatedDate))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Theme.text)
                        }

                        Button {
                            Task { await refresh() }
                        } label: {
                            HStack {
                                if store.isRefreshing {
                                    ProgressView().tint(Theme.background)
                                }
                                Text("Verileri şimdi güncelle")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.background)
                        .disabled(store.isRefreshing)

                        if let message = store.lastRefreshMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Hakkında")
                        HStack {
                            Text("Sürüm")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                            Spacer()
                            Text(Self.versionText)
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Theme.text)
                        }
                        Text("Veriler MetaTFT ve CommunityDragon'dan alınır. HexKoç, Riot Games ile bağlantılı değildir.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
    }

    private func refresh() async {
        await store.refresh(force: true)
        toast = store.lastRefreshMessage
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
