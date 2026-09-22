# HexKoç data contract (schemaVersion 1)

Three JSON files, produced by `tools/build_data.py`, consumed by the iOS app. All ids are the game's
`DA_*` api names. Every localized string is an object `{"en": "...", "tr": "..."}` (both keys always
present; fall back to the other language when a translation is missing — never emit empty strings).
Numbers are plain JSON numbers. Fields marked `?` may be `null` but the key is always present.
Icon paths are relative to the app bundle's `Resources/Images/` folder; `iconURL` is the remote fallback.

## 1. `gamedata.json`
```jsonc
{
  "schemaVersion": 1,
  "generatedAt": "2026-09-22T16:00:00Z",           // ISO-8601 UTC
  "set": { "key": "TFTSet18", "number": 18, "name": "Enchanted Wilds", "patch": "18.2b" },
  "champions": [Champion],                           // 65 entries, sorted by cost then name.en
  "traits":    [Trait],                              // 36 entries, sorted by type then name.en
  "items":     [Item],                               // components + craftable + emblems + artifacts + radiant
  "augments":  [Augment],                            // all Set 18 augments (~250)
  "rules":     Rules
}
```
### Champion
```jsonc
{
  "id": "DA_18_Ahri",                                // canonical id = teamplanner character_id (Lux = "DA_Lux18_Base")
  "aliases": ["DA_18_Lux_Primal", ...],              // other ids that mean this champion (usually []), used to resolve MetaTFT ids
  "name": { "en": "Ahri", "tr": "Ahri" },
  "cost": 4,                                         // 1..5
  "traits": ["DA_18_Blossom", "DA_18_Spellweaver"], // Trait.id, game order
  "role": "MagicCaster",                             // MetaTFT role without "DA_Role_" prefix, or null
  "stats": { "hp": 850, "armor": 40, "mr": 40, "ad": 40, "attackSpeed": 0.8, "range": 4, "startMana": 20, "maxMana": 100 },
  "ability": { "name": {"en","tr"}, "desc": {"en","tr"} },   // plain text, tokens resolved (see PIPELINE_SPEC)
  "icon": "champions/DA_18_Ahri.png",
  "iconURL": "https://raw.communitydragon.org/latest/game/assets/characters/tft18_ahri/tft18_ahri_square.png",
  "splashURL": "https://…/tft18_ahri_splash_tile_27.png",   // ? may be null
  "teamCode": "3e9",                                 // exactly 3 lowercase hex chars
  "poolCount": 10,                                   // copies of this champion in the shared pool
  "recommendedItems": ["DA_ArchangelsStaff", "DA_SpearOfShojin"],  // ≤ 6 Item.id (may be [])
  "avgPlacement": 4.32,                              // ? global average placement when played (null if unknown)
  "popularity": 0.63                                 // ? 0..1 relative play frequency (null if unknown)
}
```
### Trait
```jsonc
{
  "id": "DA_18_Lunar",
  "name": { "en": "Lunar", "tr": "Ay" },
  "type": "origin" | "class" | "unique",            // unique = single-champion trait (Avatar, Bounty Seeker, …)
  "desc": { "en": "...", "tr": "..." },              // main description without the per-tier lines
  "breakpoints": [                                   // ascending by min; unique traits have one entry with min 1
    { "min": 2, "max": 2, "style": "bronze", "desc": {"en": "(2) 20% AS, 20 AP", "tr": "(2) …"} }
  ],                                                 // style: "bronze"|"silver"|"gold"|"prismatic"|"unique"
  "icon": "traits/DA_18_Lunar.png",
  "iconURL": "https://raw.communitydragon.org/latest/game/assets/ux/traiticons/trait_icon_18_lunar.png",
  "champions": ["DA_18_Diana", "DA_18_Aphelios", "DA_18_Alune"]   // sorted by cost then name.en
}
```
### Item
```jsonc
{
  "id": "DA_ArchangelsStaff",
  "name": { "en": "Archangel's Staff", "tr": "Başmelek Asası" },
  "desc": { "en": "...", "tr": "..." },              // may be "" → then app shows stats only (both keys still present)
  "kind": "component" | "craftable" | "emblem" | "artifact" | "radiant",
  "recipe": ["DA_Component_NeedlesslyLargeRod", "DA_Component_TearOfTheGoddess"],  // ? null when not craftable; exactly 2 component ids otherwise
  "icon": "items/DA_ArchangelsStaff.png",
  "iconURL": "https://raw.communitydragon.org/latest/game/assets/maps/tft/icons/items/hexcore/tft_item_archangelsstaff.png",
  "unique": false,
  "stats": { "AP": 55, "Mana": 15 },                 // readable effect keys only (hash keys like "{1543aa48}" dropped); may be {}
  "traitId": "DA_18_Vanguard"                        // ? for emblems: the trait granted; null otherwise
}
```
### Augment
```jsonc
{
  "id": "DA_FocusedFire",
  "name": { "en": "Focused Fire", "tr": "..." },
  "desc": { "en": "...", "tr": "..." },
  "rarity": "silver" | "gold" | "prismatic" | "unknown",
  "category": "combat" | "economy" | "trait" | "utility" | "unknown",   // from MetaTFT tags Augment.Category.* (Combat→combat, Economic→economy, Trait→trait, else utility)
  "icon": "augments/DA_FocusedFire.png",             // ? null when no icon could be downloaded
  "iconURL": "https://…png",                         // ? null when unknown
  "metaTier": "S" | "A" | "B" | "C" | "D",           // ? from MetaTFT global augment tier list; null if absent
  "traitId": "DA_18_Blossom"                         // ? for trait augments/emblem augments; null otherwise
}
```
### Rules
```jsonc
{
  "shopOdds": { "1": [100,0,0,0,0], "2": [100,0,0,0,0], …, "10": [5,10,20,40,25] },  // % for 1..5-cost at player level 1..10 (rows sum to 100)
  "xpToLevel": { "2": 2, "3": 6, "4": 10, "5": 20, "6": 36, "7": 48, "8": 80, "9": 84, "10": 100 },  // XP required to reach that level from the previous one
  "poolSizes": { "1": 30, "2": 25, "3": 18, "4": 10, "5": 9 },   // copies per champion per cost tier (from data)
  "economy": {
    "interestPer10Gold": 1, "maxInterest": 5, "baseIncome": 5,
    "streakGold": { "2": 1, "3": 1, "4": 2, "5": 3 },            // win/loss streak bonus by streak length (5 = 5+)
    "xpPerRound": 2, "xpPurchaseCost": 4, "xpPurchaseAmount": 4, "rerollCost": 2
  },
  "sources": ["MetaTFT", "CommunityDragon"]
}
```
Values in `rules` come from `tools/rules.json` (hand-maintained from research); the pipeline just copies it in.

## 2. `comps.json`
```jsonc
{
  "schemaVersion": 1,
  "generatedAt": "2026-09-22T16:00:00Z",
  "source": "MetaTFT",
  "set": "TFTSet18",
  "patch": "18.2b",
  "clusterId": 424,
  "comps": [Comp]                                    // sorted: tier S→C, then avgPlacement ascending
}
```
### Comp
```jsonc
{
  "id": "424000",                                    // MetaTFT cluster key, string
  "name": { "en": "Juggernaut Zyra Sivir", "tr": "Ezergeçer Zyra Sivir" },
  "tier": "S" | "A" | "B" | "C",
  "playstyle": "fast8" | "fast9" | "reroll5" | "reroll6" | "reroll7" | "standard",
  "difficulty": "easy" | "medium" | "hard",
  "stats": { "avgPlacement": 4.34, "playRate": 0.0246, "games": 21152 },
  "trend": "rising" | "falling" | "stable",
  "units": [                                         // 7–10 entries, ordered: carries first (most items), then cost desc, then name
    { "id": "DA_18_Zyra", "items": ["DA_ArchangelsStaff","DA_ArchangelsStaff","DA_HextechGunblade"],  // 0–3 Item.id
      "stars": 3,                                    // 3 = 3-star target, otherwise 2
      "isCarry": true,                               // true for units with ≥ 2 recommended items (max 3 carries)
      "cell": 7,                                     // ? 1..28 final-board cell, unique within the comp; null if unknown
      "importance": 0.92 }                           // 0..1 how often the unit is in the final board
  ],
  "traits": [ { "id": "DA_Juggernaut18", "count": 6, "style": "gold" } ],   // active traits computed from units; style per breakpoints, "none" if below first breakpoint (omit those)
  "teamCode": "02…TFTSet18",                         // 2 + 30 + 8 = 40 chars, see PIPELINE_SPEC
  "levelBoards": { "7": ["DA_18_Rakan", …], "8": [...], "9": [...], "10": [...] },   // keys present only when data exists
  "earlyBoards": { "4": [...], "5": [...], "6": [...] },                              // ditto
  "levelTiming": [ { "level": 5, "stage": 2, "round": 5 }, { "level": 8, "stage": 4, "round": 2 } ],  // ascending by level
  "augments": { "S": ["DA_BandOfThieves", …], "A": [...] },                          // ≤ 30 ids each, only ids present in gamedata
  "counters": [ { "compId": "424020", "placeChange": 0.55 } ],                        // ≤ 5, comps that beat this one (positive = we place worse)
  "goodAgainst": [ { "compId": "424013", "placeChange": -0.41 } ],                    // ≤ 5
  "starPriority": ["DA_18_Caitlyn", "DA_18_Rengar"],                                  // champions worth 3-starring (may be [])
  "coreUnits": ["DA_18_Zyra", "DA_Amumu18", "DA_Vi18", "DA_18_Sivir"],               // ≤ 5 by importance
  "tips": { "tr": ["…", "…"], "en": ["…"] }                                           // 3–7 generated sentences per language
}
```

## 3. `guides.json`
```jsonc
{
  "schemaVersion": 1,
  "generatedAt": "…",
  "articles": [
    { "id": "temeller", "category": "baslangic" | "ekonomi" | "strateji" | "set18" | "sozluk",
      "title": "TFT'ye başlarken", "summary": "1-2 cümle", "icon": "graduationcap.fill",   // SF Symbol name
      "minutes": 4,                                   // reading time
      "body": "markdown-ish text" }
  ]
}
```
`body` markdown subset the app must render: `# `/`## `/`### ` headings, paragraphs separated by blank lines,
`- ` bullet lists, `1. ` numbered lists, `**bold**`, `*italic*`, `> ` callout lines, and embedded tables on their
own line: `[[table:shopOdds]]`, `[[table:xp]]`, `[[table:poolSizes]]`, `[[table:economy]]`,
`[[table:itemRecipes]]` (rendered from `gamedata.rules` / items).

## 4. `manifest.json` (remote refresh)
```jsonc
{ "schemaVersion": 1, "generatedAt": "2026-09-22T16:00:00Z", "patch": "18.2b",
  "files": { "gamedata": "gamedata.json", "comps": "comps.json", "guides": "guides.json" } }
```
Remote base URL: `https://raw.githubusercontent.com/developer-carinok/hexkoc/main/data/v1/`.
The app downloads `manifest.json`; if `generatedAt` is newer than the cached/bundled one (and
`schemaVersion` matches), it downloads the three files atomically into Application Support and switches to them.
