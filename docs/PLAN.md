# HexKoç — TFT Set 18 (Enchanted Wilds) companion app — Master Plan

Owner: Kadir Gölcük (personal use, distributed via TestFlight). UI language: **Turkish**.
Planning: Fable (orchestrator). Implementation: Opus implementer agents. Date: 2026-09-22.

## Goal
A native iOS app that helps a beginner TFT Mobile player who does not know the comps by heart:
1. Browse the current meta team comps (tier list) with units, items, board positioning, level-by-level
   boards, augments, counters — and **copy the Team Planner code** so the comp can be imported in-game.
2. Look up champions, traits (breakpoints), items (recipes + in-app item combiner) and augments quickly
   mid-game.
3. Learn TFT (Turkish guides): basics, economy, leveling/rolling, positioning, Set 18 mechanics, glossary.
4. Data refreshes itself from a hosted JSON (GitHub raw) so comps stay current between app builds.

## Facts established by research (do not re-research)
- Current set: **TFT Set 18 "Enchanted Wilds"**, set key `TFTSet18`, released 2026-08-26, current patch **18.2b**.
  Riot switched patch naming to `<set>.<n>`; LoL/DDragon version 16.18.x corresponds to it.
- Set 18 runs on the new Unreal client; all game-object ids are prefixed `DA_` (e.g. `DA_18_Ahri`, `DA_Amumu18`,
  items `DA_ArchangelsStaff`, components `DA_Component_BFSword`, traits `DA_18_Lunar`, augments `DA_FocusedFire`).
- 65 playable champions (14/13/14/14/10 per cost). Variants that count as the same champion:
  Lux (`DA_Lux18_Base`) appears in MetaTFT data as `DA_18_Lux_Primal`, `DA_18_Lux_Inferno`, `DA_Lux18_Blossom`,
  `DA_Lux18_Blackthorn`, `DA_18_Lux_Fae`, `DA_18_Lux_Moonbeam` … → all map to `DA_Lux18_Base`.
  Adaptor champions carry `_AD`/`_AP` suffixes in their canonical ids (`DA_18_Akali_AD`, `DA_18_MasterYi_AD`,
  `DA_KogMaw18_AD`, `DA_Nidalee18_AP`, `DA_Gromp18_AP`) — keep those as-is.
- **Team Planner code format** (verified from MetaTFT source): `"02"` + ten slots × 3 lowercase hex chars
  (empty slot = `"000"`) + `"TFTSet18"`. Per-champion 3-hex code = `format(team_planner_code, "03x")` where
  `team_planner_code` comes from CommunityDragon `tftchampions-teamplanner.json` (Set 18 values are 1001…1085,
  e.g. Ahri 1001 → `3e9`, Akali 1002 → `3ea`, Taric 1072 → `430`).
- **Board cell numbering** (MetaTFT positioning data): 28 cells, `cell_1…cell_28`. `cell_22…28` = FRONT row
  (closest to the enemy, drawn at the top), left→right. `cell_15…21` = second row, `cell_8…14` = third row,
  `cell_1…7` = BACK row (closest to the player, drawn at the bottom), left→right.
  Hex layout: pointy-top hexagons; rows 2 and 4 from the top (cells 15–21 and 1–7) are shifted RIGHT by half
  a hex width; rows 1 and 3 (cells 22–28 and 8–14) are not shifted. Row pitch ≈ 0.866 × hex width.
- Data sources (all public, no auth):
  - CommunityDragon TFT data: `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json` and `tr_tr.json`
    (~24 MB each; `setData[]` entry with `mutator == "TFTSet18"`; `items[]` global list incl. augments).
  - CommunityDragon team planner codes:
    `https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/tftchampions-teamplanner.json`
    (key `TFTSet18`, 65 entries: `character_id`, `tier`(cost), `display_name`, `team_planner_code`, `traits`).
  - Images: `https://raw.communitydragon.org/latest/game/` + CDragon asset path lower-cased with `.tex`/`.dds` → `.png`.
    Verified 200 for all 74 Set 18 champion `tileIcon`s, all 36 trait icons, item icons, augment icons.
  - MetaTFT comps (unofficial but open): `https://api-hc.metatft.com/tft-comps-api/comps_data` and per-comp
    `comp_details`, `comp_options`, `comp_augment_tiers`, `unit_items_processed` (see PIPELINE_SPEC.md).
  - MetaTFT lookup (unit meta incl. team code + role + pool size):
    `https://data.metatft.com/lookups/TFTSet18_latest_en_us.json` (must include `.json`, 1.3 MB).
- Apple: Team `7JZLNNY795`, ASC API key `K5565AAZPA` (issuer `2b798c52-072f-470e-8808-fe953150cba6`, key file in
  `~/.appstoreconnect/private_keys/`). Bundle id **`com.carinok.hexkoc`** registered 2026-09-22 (id `3MCB663UGN`).
  Release flow copied from `~/Documents/LockDeck/scripts/release.sh` (xcodegen + xcodebuild archive + exportArchive
  upload with `ExportOptions.plist`). TestFlight internal group "Kişisel" + tester kadirgolcuk@icloud.com.

## Product decisions
- Name: **HexKoç** (display name), bundle `com.carinok.hexkoc`, SKU `hexkoc-2026`, primary language Turkish.
- Native SwiftUI, iOS 18.0+, iPhone only (portrait), Swift language mode 5 (Xcode 26), no third-party packages.
- Dark, game-like theme (navy background, gold accent, TFT cost colors). Big tap targets — used mid-game.
- All data bundled (JSON + PNG icons) so the app works offline; a background refresh pulls newer JSON from
  `https://raw.githubusercontent.com/developer-carinok/hexkoc/main/data/v1/` and caches it. Icons for ids
  missing from the bundle are loaded from their `iconURL` at runtime.
- Names are shown in Turkish by default (as in the Turkish TFT client) with English in small text;
  a setting flips the primary language to English.

## Repository layout (`~/Documents/HexKoc`, GitHub `developer-carinok/hexkoc`, public)
```
project.yml                 xcodegen spec (target HexKoc)
HexKoc/                     Swift sources (App/, Models/, Services/, Features/, Shared/)
Resources/                  folder reference copied into the bundle: Data/*.json, Images/**/*.png
Config/                     App-Info.plist, App.entitlements
Assets.xcassets/            AppIcon (1024 px, no alpha), AccentColor
tools/                      build_data.py (pipeline), make_icon.py, requirements.txt, cache/ (git-ignored)
data/v1/                    gamedata.json, comps.json, guides.json, manifest.json  ← remote refresh source
docs/                       this plan + DATA_SCHEMA.md + PIPELINE_SPEC.md + APP_SPEC.md
scripts/                    release.sh, tf_status.py
.github/workflows/          refresh-data.yml (daily cron: run pipeline, commit data/v1 JSON only)
```

## Work packages
- **WP1 Data pipeline** (`tools/build_data.py`) → produces `data/v1/*.json` + `Resources/Data/*.json` + `Resources/Images/**`.
  Spec: PIPELINE_SPEC.md + DATA_SCHEMA.md.
- **WP2 iOS app** (SwiftUI) consuming the schema. Spec: APP_SPEC.md + DATA_SCHEMA.md. Must build with
  `xcodegen generate && xcodebuild -scheme HexKoc -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
- **WP3 Turkish guide content** (`data/v1/guides.json`) — written from researched Set 18 rules.
- **WP4 Release**: app icon, `scripts/release.sh`, archive, upload, TestFlight group + tester, verification.

## Acceptance criteria
1. App launches offline with bundled data; comps list shows ≥ 40 comps with tiers; detail shows board, items,
   team code copy button, level boards, augments, counters, Turkish tips.
2. Team code copied for a comp decodes back to the same champions (`tools/build_data.py --verify-codes`).
3. Champions / traits / items / augments browsable and searchable (Turkish + English names).
4. Item combiner: tap two components → shows the result; full recipe grid available.
5. Guides render (markdown-ish), shop odds + XP tables shown.
6. Remote refresh: if `manifest.json` on GitHub has a newer `generatedAt`, new JSON is downloaded and used.
7. Archive + upload to TestFlight succeeds; build processes to VALID; tester invited.
