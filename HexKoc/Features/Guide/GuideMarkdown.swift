import Foundation

/// `guides.json` içindeki küçük markdown alt kümesi.
enum GuideBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case callout([String])
    case table(GuideTableKind)

    var id: String {
        switch self {
        case .heading(let level, let text): "h\(level)-\(text)"
        case .paragraph(let text): "p-\(text.prefix(40))-\(text.count)"
        case .bullets(let items): "ul-\(items.first ?? "")-\(items.count)"
        case .numbered(let items): "ol-\(items.first ?? "")-\(items.count)"
        case .callout(let lines): "q-\(lines.first ?? "")-\(lines.count)"
        case .table(let kind): "t-\(kind.rawValue)"
        }
    }
}

enum GuideTableKind: String {
    case shopOdds
    case xp
    case poolSizes
    case economy
    case itemRecipes
    case unknown

    var title: String {
        switch self {
        case .shopOdds: "Şans Tablosu"
        case .xp: "Seviye & XP"
        case .poolSizes: "Havuz Büyüklükleri"
        case .economy: "Ekonomi Kuralları"
        case .itemRecipes: "Tarif Tablosu"
        case .unknown: "Tablo"
        }
    }
}

enum GuideMarkdown {
    static func parse(_ body: String) -> [GuideBlock] {
        var blocks: [GuideBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var callout: [String] = []

        func flush() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
            if !bullets.isEmpty {
                blocks.append(.bullets(bullets))
                bullets = []
            }
            if !numbered.isEmpty {
                blocks.append(.numbered(numbered))
                numbered = []
            }
            if !callout.isEmpty {
                blocks.append(.callout(callout))
                callout = []
            }
        }

        for rawLine in body.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flush()
                continue
            }

            if let kind = tableKind(in: line) {
                flush()
                blocks.append(.table(kind))
                continue
            }

            if let heading = heading(in: line) {
                flush()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if !paragraph.isEmpty || !numbered.isEmpty || !callout.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
                continue
            }

            if let item = numberedItem(in: line) {
                if !paragraph.isEmpty || !bullets.isEmpty || !callout.isEmpty { flush() }
                numbered.append(item)
                continue
            }

            if line.hasPrefix("> ") || line == ">" {
                if !paragraph.isEmpty || !bullets.isEmpty || !numbered.isEmpty { flush() }
                callout.append(String(line.dropFirst(line.hasPrefix("> ") ? 2 : 1)))
                continue
            }

            if !bullets.isEmpty || !numbered.isEmpty || !callout.isEmpty { flush() }
            paragraph.append(line)
        }
        flush()
        return blocks
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        for level in [3, 2, 1] {
            let marker = String(repeating: "#", count: level) + " "
            if line.hasPrefix(marker) {
                return (level, String(line.dropFirst(marker.count)))
            }
        }
        return nil
    }

    private static func numberedItem(in line: String) -> String? {
        guard let dot = line.firstIndex(of: "."),
              line.distance(from: line.startIndex, to: dot) <= 2,
              Int(line[line.startIndex..<dot]) != nil,
              line.index(after: dot) < line.endIndex,
              line[line.index(after: dot)] == " "
        else { return nil }
        return String(line[line.index(dot, offsetBy: 2)...])
    }

    private static func tableKind(in line: String) -> GuideTableKind? {
        guard line.hasPrefix("[[table:"), line.hasSuffix("]]") else { return nil }
        let name = String(line.dropFirst("[[table:".count).dropLast(2))
        return GuideTableKind(rawValue: name) ?? .unknown
    }
}
