import Foundation

/// Takım Planlayıcı kodu: "02" + 10 × 3 hane hex + "TFTSet18".
enum TeamCode {
    static let prefix = "02"
    static let setKey = "TFTSet18"
    static let slotCount = 10
    static let emptySlot = "000"
    static let length = prefix.count + slotCount * 3 + setKey.count

    static func encode(champions: [Champion]) -> String {
        var slots = champions.prefix(slotCount).map { slot(for: $0) }
        while slots.count < slotCount { slots.append(emptySlot) }
        return prefix + slots.joined() + setKey
    }

    static func decode(_ code: String, using data: GameData) -> [Champion] {
        analyze(code, using: data).champions
    }

    /// Kod çözücü ekranı için ayrıntılı sonuç.
    static func analyze(_ code: String, using data: GameData) -> Analysis {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Analysis(champions: [], unresolved: [], problem: nil)
        }
        guard trimmed.count >= prefix.count + 3 else {
            return Analysis(champions: [], unresolved: [], problem: "Kod çok kısa görünüyor.")
        }
        guard trimmed.hasPrefix(prefix) else {
            return Analysis(champions: [], unresolved: [], problem: "Kod \"\(prefix)\" ile başlamalı.")
        }

        var body = String(trimmed.dropFirst(prefix.count))
        var foundSet: String?
        if let range = body.range(of: "TFTSet", options: [.caseInsensitive, .backwards]) {
            foundSet = String(body[range.lowerBound...])
            body = String(body[..<range.lowerBound])
        }
        if let foundSet, foundSet.caseInsensitiveCompare(setKey) != .orderedSame {
            return Analysis(champions: [], unresolved: [], problem: "Bu kod \(foundSet) setine ait; HexKoç \(setKey) setini destekliyor.")
        }

        guard body.count % 3 == 0, !body.isEmpty else {
            return Analysis(champions: [], unresolved: [], problem: "Kodun uzunluğu beklenenden farklı.")
        }

        let index = championIndex(data)
        var champions: [Champion] = []
        var unresolved: [String] = []
        for chunk in body.lowercased().chunks(of: 3) {
            guard chunk != emptySlot else { continue }
            guard chunk.allSatisfy(\.isHexDigit) else {
                return Analysis(champions: champions, unresolved: unresolved, problem: "Kodda geçersiz karakter var: \"\(chunk)\".")
            }
            if let champion = index[chunk] {
                champions.append(champion)
            } else {
                unresolved.append(chunk)
            }
        }

        let problem: String? = foundSet == nil && champions.isEmpty
            ? "Kodun sonunda \(setKey) yazmalı."
            : nil
        return Analysis(champions: champions, unresolved: unresolved, problem: problem)
    }

    struct Analysis {
        var champions: [Champion]
        /// Tanınmayan 3 haneli kodlar (veri eski olabilir).
        var unresolved: [String]
        /// Kod hiç çözülemediyse kullanıcıya gösterilecek açıklama.
        var problem: String?

        var isEmpty: Bool { champions.isEmpty && unresolved.isEmpty }
    }

    private static func slot(for champion: Champion) -> String {
        let code = champion.teamCode.lowercased()
        guard code.count == 3, code.allSatisfy(\.isHexDigit) else { return emptySlot }
        return code
    }

    private static func championIndex(_ data: GameData) -> [String: Champion] {
        var index: [String: Champion] = [:]
        for champion in data.champions {
            let code = champion.teamCode.lowercased()
            guard code.count == 3 else { continue }
            index[code] = champion
        }
        return index
    }
}

private extension String {
    func chunks(of size: Int) -> [String] {
        guard size > 0 else { return [] }
        var result: [String] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(String(self[index..<end]))
            index = end
        }
        return result
    }
}
