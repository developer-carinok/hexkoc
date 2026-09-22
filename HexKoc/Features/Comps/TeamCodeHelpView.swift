import SwiftUI

/// Takım kodunu oyuna aktarma adımları. Metinler tek bir yerde.
enum TeamCodeHelp {
    static let steps: [String] = [
        "Bu ekrandaki **Kodu Kopyala** düğmesine dokun.",
        "TFT'yi aç. Lobide **Karşılaşma Ara** düğmesinin sağındaki **kask simgesine** dokunarak **Takım Planlayıcısı**'nı aç. Maç sırasında da aynı simge ekranda durur.",
        "Planlayıcıda **Takım Yapıştır / Takım Kodu Yapıştır** seçeneğine dokun. iOS pano izni sorarsa **Yapıştırmaya İzin Ver** de.",
        "Takıma bir ad ver ve onayla. Aktif takım olarak işaretlersen mağazadaki şampiyonlar vurgulanır (en fazla 20 takım kaydedilebilir).",
        "Not: Kod yalnızca şampiyonları taşır; eşyalar ve dizilim aktarılmaz, onları bu ekrandan takip et. Kodun sonunda TFTSet18 yazmalı."
    ]

    static let footnote = "Kaynak: Riot 13.5 ve 14.22 yama notları."
}

struct TeamCodeHelpView: View {
    let teamCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(TeamCodeHelp.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(Theme.background)
                                .frame(width: 26, height: 26)
                                .background(Theme.accent, in: Circle())
                            Text(.init(step))
                                .font(.subheadline)
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text(TeamCodeHelp.footnote)
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.top, 4)

                    if !teamCode.isEmpty {
                        ShareLink(item: teamCode) {
                            Label("Paylaş", systemImage: "square.and.arrow.up")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Kodu nasıl kullanırım?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
