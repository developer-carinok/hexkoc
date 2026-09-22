import SwiftUI
import UIKit

struct CompTeamCodeCard: View {
    let comp: Comp
    @Binding var toast: String?
    @State private var showHelp = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Takım Kodu")

                Text(comp.teamCode.isEmpty ? "—" : comp.teamCode)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Takım kodu")

                HStack(spacing: 10) {
                    Button {
                        copy()
                    } label: {
                        Label("Kodu Kopyala", systemImage: "doc.on.doc.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.background)
                    .disabled(comp.teamCode.isEmpty)

                    Button {
                        showHelp = true
                    } label: {
                        Text("Nasıl kullanılır?")
                            .font(.subheadline.bold())
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.secondaryText)
                }
            }
        }
        .sheet(isPresented: $showHelp) {
            TeamCodeHelpView(teamCode: comp.teamCode)
        }
    }

    private func copy() {
        UIPasteboard.general.string = comp.teamCode
        Haptics.success()
        toast = "Kod kopyalandı"
    }
}
