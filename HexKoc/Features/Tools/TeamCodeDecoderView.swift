import SwiftUI
import UIKit

struct TeamCodeDecoderView: View {
    @Environment(DataStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var code = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Takım Kodu")

                        TextField("02…TFTSet18", text: $code, axis: .vertical)
                            .font(.system(.footnote, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lineLimit(2...4)
                            .padding(10)
                            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))

                        HStack(spacing: 10) {
                            Button {
                                code = UIPasteboard.general.string ?? code
                                Haptics.tap()
                            } label: {
                                Label("Panodan Yapıştır", systemImage: "doc.on.clipboard")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .foregroundStyle(Theme.background)

                            if !code.isEmpty {
                                Button("Temizle") { code = "" }
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                }

                resultCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
        .navigationTitle("Kod Çözücü")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var analysis: TeamCode.Analysis {
        TeamCode.analyze(code, using: store.gameData)
    }

    @ViewBuilder
    private var resultCard: some View {
        let result = analysis
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "Çözülen Takım",
                    subtitle: result.champions.isEmpty ? nil : "\(result.champions.count) şampiyon"
                )

                if let problem = result.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.tier(.a))
                        .fixedSize(horizontal: false, vertical: true)
                } else if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Bir takım kodu yapıştır; içindeki şampiyonları göstereyim.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                } else if result.isEmpty {
                    Text("Kodda şampiyon bulunamadı.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                if !result.champions.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(result.champions) { champion in
                            NavigationLink(value: Route.champion(champion.id)) {
                                VStack(spacing: 4) {
                                    ChampionIcon(champion: champion, size: 52)
                                    Text(champion.name.text(settings.nameLanguage))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !result.unresolved.isEmpty {
                    Text("Tanınmayan \(result.unresolved.count) slot: \(result.unresolved.joined(separator: ", ")). Veri güncel olmayabilir.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
