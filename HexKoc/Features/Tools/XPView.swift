import SwiftUI

struct XPView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Card { XPTable(rules: store.rules) }
                Card { PoolSizeTable(rules: store.rules) }
                Card { EconomyTable(rules: store.rules) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Theme.background)
        .navigationTitle("Seviye & XP")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct XPTable: View {
    let rules: Rules

    private var xpPerRound: Int { rules.economy.xpPerRound ?? 2 }
    private var purchaseCost: Int { rules.economy.xpPurchaseCost ?? 4 }
    private var purchaseAmount: Int { rules.economy.xpPurchaseAmount ?? 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Seviye & XP")

            HStack(spacing: 0) {
                Text("Sv").frame(width: 30, alignment: .leading)
                Text("XP").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Toplam").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Altın").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Tur").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(Theme.secondaryText)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Hairline() }

            ForEach(rules.xpLevels, id: \.self) { level in
                let xp = rules.xp(toLevel: level) ?? 0
                HStack(spacing: 0) {
                    Text("\(level)")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30, alignment: .leading)
                    Text("\(xp)").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("\(rules.cumulativeXP(toLevel: level))").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("\(gold(for: xp))").frame(maxWidth: .infinity, alignment: .trailing)
                    Text("\(rounds(for: xp))").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.text)
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Hairline().opacity(0.4) }
            }

            Text("Her tur bedava \(xpPerRound) XP kazanırsın. \(purchaseCost) altın = \(purchaseAmount) XP. \"Altın\" sütunu o seviyeyi tamamen satın alma maliyeti, \"Tur\" sütunu hiç XP almadan beklersen geçecek tur sayısı.")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func gold(for xp: Int) -> Int {
        guard xp > 0, purchaseAmount > 0 else { return 0 }
        return Int(ceil(Double(xp) / Double(purchaseAmount))) * purchaseCost
    }

    private func rounds(for xp: Int) -> Int {
        guard xp > 0, xpPerRound > 0 else { return 0 }
        return Int(ceil(Double(xp) / Double(xpPerRound)))
    }
}

struct PoolSizeTable: View {
    let rules: Rules

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Havuz Büyüklükleri", subtitle: "şampiyon başına kopya")

            ForEach(Array(rules.poolSizes.keys.compactMap(Int.init).sorted()), id: \.self) { cost in
                HStack {
                    CostBadge(cost: cost)
                    Text("\(cost) altınlık")
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(rules.poolSize(cost: cost) ?? 0) kopya")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(Theme.text)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Hairline().opacity(0.4) }
            }
        }
    }
}

struct EconomyTable: View {
    let rules: Rules

    private var economy: Economy { rules.economy }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Ekonomi Kuralları")

            row("Faiz", "\(economy.interestPer10Gold ?? 1) altın / 10 altın (en fazla \(economy.maxInterest ?? 5))")
            row("Temel gelir", "\(economy.baseIncome ?? 5) altın")
            row("PvP galibiyeti", "+\(economy.pvpWinGold ?? 1) altın")
            if !streakRows.isEmpty {
                row("Seri bonusu", streakRows.map { "\($0.label) +\($0.gold)" }.joined(separator: " / "))
            }
            row("Yeniden çevirme", "\(economy.rerollCost ?? 2) altın")
            row("XP satın alma", "\(economy.xpPurchaseCost ?? 4) altın = \(economy.xpPurchaseAmount ?? 4) XP")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Hairline().opacity(0.4) }
    }

    /// Aynı bonusu veren ardışık seri uzunluklarını "2-4 tur" gibi tek satırda toplar.
    private var streakRows: [(label: String, gold: Int)] {
        let tiers = economy.streakTiers
        guard !tiers.isEmpty else { return [] }
        var result: [(label: String, gold: Int)] = []
        var index = 0
        while index < tiers.count {
            let gold = tiers[index].gold
            var end = index
            while end + 1 < tiers.count, tiers[end + 1].gold == gold { end += 1 }
            let first = tiers[index].length
            let last = tiers[end].length
            let isLast = end == tiers.count - 1
            let label: String
            if isLast {
                label = "\(first)+ tur"
            } else if first == last {
                label = "\(first) tur"
            } else {
                label = "\(first)-\(last) tur"
            }
            result.append((label: label, gold: gold))
            index = end + 1
        }
        return result
    }
}
