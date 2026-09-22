# WP2 — iOS app spec (HexKoç)

## Project setup
- `project.yml` (xcodegen 2.46): app target `HexKoc`, iOS 18.0, iPhone only, dikey + yatay, Swift language mode 5
  (`SWIFT_VERSION: "5.0"`), `SWIFT_STRICT_CONCURRENCY: minimal`, `DEVELOPMENT_TEAM: 7JZLNNY795`,
  `CODE_SIGN_STYLE: Automatic`, `PRODUCT_BUNDLE_IDENTIFIER: com.carinok.hexkoc`, `MARKETING_VERSION: 1.1`,
  `CURRENT_PROJECT_VERSION: 1`, `INFOPLIST_FILE: Config/App-Info.plist`, `GENERATE_INFOPLIST_FILE: NO`,
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`,
  `ENABLE_USER_SCRIPT_SANDBOXING: YES`. Sources: `HexKoc/`; resources: `Resources` as a **folder reference**
  (`- path: Resources  type: folder`) and `Assets.xcassets`. No SPM packages.
- `Config/App-Info.plist`: `CFBundleDisplayName` = `HexKoç`, `UILaunchScreen` dict (background color from asset
  catalog `LaunchBackground`), `UISupportedInterfaceOrientations` portrait + landscapeLeft + landscapeRight,
  `ITSAppUsesNonExemptEncryption` = false,
  `NSAppTransportSecurity` not needed (all HTTPS), `UIUserInterfaceStyle` = `Dark`, `CFBundleLocalizations` = `["tr"]`,
  `CFBundleDevelopmentRegion` = `tr`.
- Schemes: `HexKoc` (run Debug, archive Release). Build must pass:
  `xcodegen generate && xcodebuild -project HexKoc.xcodeproj -scheme HexKoc -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
- Reference for conventions: `~/Documents/LockDeck` (same author; xcodegen + release script), read-only.

## Architecture
- `Models/` Codable structs mirroring `docs/DATA_SCHEMA.md` exactly (`GameData`, `Champion`, `Trait`, `Item`,
  `Augment`, `Rules`, `CompsFile`, `Comp`, `CompUnit`, `GuidesFile`, `GuideArticle`, `Manifest`). Use a
  `LocalizedText { en, tr }` struct with `func text(_ lang: NameLanguage) -> String` (falls back to the other language).
  Decoding must be tolerant: unknown enum strings decode to a `.unknown`/default case, missing optional keys → nil.
- `Services/DataStore` (`@Observable`, `@MainActor`): loads bundled JSON from `Resources/Data/` on launch
  (synchronously, fast), then checks `Application Support/HexKoc/data/` for a cached newer set, then in the background
  calls `RemoteDataService.refreshIfNeeded()` (manifest check → download 3 files → validate decode → atomically replace
  cache → publish). Exposes lookups: `champion(id)`, `trait(id)`, `item(id)`, `augment(id)`, `comp(id)`,
  `compsUsing(champion:)`, `itemsByRecipe(componentA, componentB)`. Resolve champion aliases in `champion(id)`.
- `Services/ImageProvider`: `IconView(path: String?, url: URL?, size)` → loads bundled PNG via
  `Bundle.main.url(forResource:withExtension:subdirectory: "Images/...")` (cache decoded `UIImage`s in an
  `NSCache`), else `AsyncImage(url)` with a placeholder hexagon. Never block the main thread with disk IO in list cells
  (decode off-main, e.g. `Task.detached` + cache).
- `Services/TeamCode`: `encode(champions: [Champion]) -> String` and `decode(_ code: String, using: GameData) -> [Champion]`
  (for a "kod çözücü" tool: paste a code → see the comp).
- `Services/Settings` (`@AppStorage`): `nameLanguage` (`tr` default | `en`), `showEnglishSubtitle` (true).
- Features (one folder each): `Comps`, `Champions`, `Traits`, `Items`, `Augments`, `Guide`, `Tools`, `Settings`.
- `Shared/Theme.swift`: colors, cost colors, tier colors, trait style colors, typography helpers, `HexagonShape`,
  `CostBadge`, `TierBadge`, `Chip`, `SectionHeader`, `Toast`.

## Visual design
Dark only. Background `#0A0F1E`, surface `#141B2E`, elevated surface `#1C2540`, hairline `#2A3550`, text `#F1F5F9`,
secondary text `#94A3B8`, accent gold `#C9A55A`. Cost colors: 1 `#8C97A5`, 2 `#2FBF71`, 3 `#3B82F6`, 4 `#A855F7`,
5 `#F59E0B`. Tier colors: S `#FF5C5C`, A `#FFB020`, B `#3FA9F5`, C `#8A94A6`. Trait styles: bronze `#A0664B`,
silver `#B8C4D0`, gold `#E8B84A`, prismatic `#9FE0FF`, unique `#E6D3A0`. Corner radius 14, cards with 1 px hairline.
Champion icons are square with a 2 px border in the cost color; 3-star targets show three small gold stars above the icon.
Typography: system font; large titles `.title2.bold()`, numbers `.monospacedDigit()`. Haptics on copy actions.
Every list row ≥ 56 pt tall (used mid-game with one thumb).

## Navigation (TabView, 5 tabs)
1. **Komplar** (`list.bullet.rectangle.portrait`) — CompListView.
2. **Şampiyonlar** (`person.3.fill`) — segmented picker at top: `Şampiyonlar | Özellikler`.
3. **Eşyalar** (`shield.lefthalf.filled`) — segmented: `Birleştirici | Tüm Eşyalar`.
4. **Güçlendirmeler** (`sparkles`) — AugmentListView.
5. **Rehber** (`book.fill`) — guides + tools; toolbar gear → SettingsView.

### CompListView
- Header line: `Yama 18.2b · MetaTFT verisi · <generatedAt as "22 Eyl 2026 19:00">`.
- Search field (`Komp veya şampiyon ara`) matching comp names (tr/en) and unit names.
- Filter chips: `Tümü`, `Hızlı 8`, `Hızlı 9`, `Yeniden Çevir` (reroll5/6/7), `Standart`; plus a `Kolay` toggle
  (difficulty easy only).
- Rows grouped by tier with tier section headers (S/A/B/C). Row: tier badge, name (primary language) + playstyle chip
  (`Hızlı 8`, `Hızlı 9`, `5. sv Reroll`, `6. sv Reroll`, `7. sv Reroll`, `Standart`), difficulty chip (`Kolay`/`Orta`/`Zor`),
  trend arrow (▲ green / ▼ red / — gray), `Ort. 4.34` (avgPlacement, 2 decimals), horizontally scrolling unit icon
  strip (cost border, 3★ marker, carry items as 3 tiny icons under the carry).
- Tap → CompDetailView.

### CompDetailView (ScrollView of cards)
1. Header card: name, tier badge, chips (playstyle, difficulty, trend), stats row `Ort. sıralama · Seçilme % · Oyun`.
2. **Takım Kodu** card: monospaced code (middle-truncated), primary button `Kodu Kopyala` (UIPasteboard.general.string,
   haptic, toast "Kod kopyalandı"), secondary `Nasıl kullanılır?` → sheet `TeamCodeHelpView` with numbered steps
   (constant array `TeamCodeHelp.steps`, Turkish; initial text below) and a `Paylaş` (ShareLink) button.
3. **Tahta Dizilimi** card: `BoardView(board: comp.units with cells)` — 4 rows × 7 pointy-top hexagons; front row on
   top (cells 22–28), back row at bottom (cells 1–7); rows 2 and 4 from the top shifted right by half a hex; each hex
   with the unit icon clipped to a hexagon, cost-colored stroke, 3★ marker; units without a cell are listed under the
   board as "Konumu bilinmiyor" chips. Caption: `Üst sıra = ön hat (rakibe yakın)`. Tap a unit → ChampionDetailView.
4. **Birimler** card: rows (icon, name tr + en subtitle, cost badge, `Taşıyıcı` tag when isCarry, ★★★ when stars == 3,
   item icons with names). Tap → ChampionDetailView; tap an item → ItemDetailView.
5. **Seviye Tahtaları** card: segmented `Erken (4-6)` | `7` | `8` | `9` | `10` (only levels present). Shows icon grid for
   `earlyBoards`/`levelBoards`. Beneath: `levelTiming` chips `5. sv → 2-5`, `8. sv → 4-2` …
6. **Aktif Özellikler** card: chips with trait icon, name, count, colored by style; tap → TraitDetailView.
7. **Güçlendirmeler** card: two rows (`S seviye`, `A seviye`) of augment chips (icon + name), horizontally scrollable; tap → AugmentDetailView.
8. **Karşı Komplar** card: `Bunlara dikkat` (counters) and `Bunlara karşı iyi` (goodAgainst) rows → tap navigates to that comp.
9. **Nasıl Oynanır** card: `tips` bullets (primary language).
10. Footer: `Veri: MetaTFT · CommunityDragon`.

Initial `TeamCodeHelp.steps` (Turkish, will be refined by the orchestrator later — keep in ONE constant):
1. "TFT'yi aç. Ana ekranda **Takım Planlayıcı**'yı (Team Planner) seç; maç sırasında da sağ üstteki planlayıcı simgesinden açabilirsin."
2. "Planlayıcıda **Kodu İçe Aktar / Yapıştır** düğmesine dokun."
3. "HexKoç'tan kopyaladığın kodu yapıştır ve onayla. Şampiyonlar planlayıcıya yüklenir ve mağazada vurgulanır."
4. "Kod yeni sete ait olmalı (sonunda TFTSet18 yazar). Set değişince kodlar geçersiz olur."

### ChampionsView / ChampionDetailView
- Grid (3 columns) grouped by cost with cost headers `1 Altın … 5 Altın`; search by tr/en name and trait name; filter chip
  row of traits (multi-select) narrows the grid.
- Detail: splash header (AsyncImage `splashURL`, gradient fade), name (primary) + secondary language name, cost badge,
  trait chips (→ TraitDetailView), **Yetenek** card (name + desc in primary language, toggle `EN/TR`), **İstatistikler**
  grid (Can, Zırh, BD, SH, Saldırı Hızı, Menzil, Mana start/max), **Önerilen Eşyalar** (icons → ItemDetailView),
  **Kullanan Komplar** list (rows like CompListView, compact), `Havuz: 10 kopya`, `Takım kodu: 3e9` (small).

### TraitsView / TraitDetailView
- List: icon, name, type chip (`Köken`/`Sınıf`/`Özel`), breakpoint chips (`2 / 4 / 6`) colored by style, champion icons row.
- Detail: icon, name, desc, breakpoints list (style dot + min + desc), champions grid by cost.

### ItemsView
- **Birleştirici**: 10 component icons in a 5×2 grid; tap selects (up to 2, highlighted). With 1 selected: show
  all 10 results (component + each other component → item card). With 2: show the single result card (icon, name,
  desc, stats). `Temizle` button. Below: a full 10×10 recipe table (compact grid of result icons, scrollable) as `Tarif Tablosu`.
- **Tüm Eşyalar**: sections `Bileşenler`, `Birleştirilmiş`, `Amblemler`, `Yapıtlar`, `Işıltılı`; search. Row: icon,
  name, recipe icons (a + b). Tap → ItemDetailView (icon, name, desc, recipe with component names, stats table,
  `Bu eşyayı taşıyan komplar` (comps whose carry items include it)).

### AugmentListView / AugmentDetailView
- Search; segmented `Tümü | Gümüş | Altın | Prizmatik`; sort by metaTier (S first) then name. Row: icon (hexagon),
  name, rarity dot, metaTier badge, category chip (`Savaş`/`Ekonomi`/`Özellik`/`Fayda`). Detail: desc, related trait link,
  comps that list it in S/A augments.

### GuideView
- List grouped by category (`Başlangıç`, `Ekonomi`, `Strateji`, `Set 18`, `Sözlük`) with icon, title, summary, `4 dk`.
- Top "Araçlar" row: `Şans Tablosu`, `Seviye & XP`, `Kod Çözücü`.
  - ShopOddsView: table level 1–10 × cost 1–5 (%), a level stepper highlights the row.
  - XPView: levels with XP needed, cumulative, "kaç tur/altın" helper (2 XP per round free, 4 gold = 4 XP).
  - TeamCodeDecoderView: paste field → decoded champions grid + validation message.
- ArticleView: renders `body` with a small custom markdown renderer (see DATA_SCHEMA §3): headings, paragraphs,
  bullets, numbered, bold/italic, `> ` callouts, `[[table:*]]` embeds.

### SettingsView
- `İsim dili` picker (Türkçe / İngilizce), `Alt başlıkta diğer dili göster` toggle, `Verileri şimdi güncelle` button
  (shows result toast + last update date + patch), `Hakkında` (version/build, attribution: "Veriler MetaTFT ve
  CommunityDragon'dan alınır. HexKoç, Riot Games ile bağlantılı değildir.").

## Behaviors
- All navigation via `NavigationStack` per tab; `navigationDestination(for:)` for `Comp.ID`, `Champion.ID`, `Trait.ID`,
  `Item.ID`, `Augment.ID` value types so any screen can link to any entity.
- Toast component for copy feedback (auto-hide 1.6 s).
- Performance: lists use `LazyVStack`; icon loading cached; JSON decoding done once at launch (< 300 ms on device).
- Accessibility labels on icons (names). Dynamic Type supported up to xxxLarge without clipping badges.
- Empty/failed remote refresh must be silent (bundled data always works offline).

## Deliverables checklist
- Builds and runs on the iPhone 17 Pro simulator; screenshots of: comp list, comp detail (board visible), item combiner, guide article.
- `scripts/release.sh` and `scripts/tf_status.py` adapted from LockDeck (scheme `HexKoc`, app id to be filled in later).
- `Assets.xcassets/AppIcon.appiconset` with a 1024×1024 PNG (no alpha) generated by `tools/make_icon.py`
  (dark navy background, gold hexagon outline with a smaller filled hexagon inside; simple and legible).
