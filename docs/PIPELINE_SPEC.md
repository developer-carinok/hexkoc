# WP1 — Data pipeline spec (`tools/build_data.py`)

Python 3.9+ (system python is 3.9.6), dependencies: `requests`, `Pillow` (create `tools/requirements.txt`; use a
venv at `.venv/` in the repo root, git-ignored). Single script, idempotent, no interactive prompts.

```
python3 tools/build_data.py                 # full build → data/v1/*.json, Resources/Data/*.json, Resources/Images/**
  --out data/v1  --resources Resources      # output roots (defaults as shown)
  --skip-images                             # JSON only (used by the GitHub Action)
  --no-cache                                # ignore tools/cache/
  --verify-codes                            # decode every comp teamCode back to champion ids and assert equality
  --max-comps N                             # debugging
```
Print a short summary at the end (counts of champions/traits/items/augments/comps, number of images downloaded,
warnings). Exit non-zero on any hard failure (missing set, < 40 comps, < 60 champions).

## HTTP
- `User-Agent: HexKoc-data-pipeline/1.0 (personal TFT companion; contact developer@carinok.com)`.
- Timeout 60 s, 3 retries with backoff, 0.25 s sleep between MetaTFT calls. Cache every GET body in
  `tools/cache/<sha1(url)>.json|.png` (git-ignored) and reuse unless `--no-cache`.

## Sources
| id | URL | notes |
|---|---|---|
| CD_EN | `https://raw.communitydragon.org/latest/cdragon/tft/en_us.json` | 24 MB. `setData[]` entry with `mutator == "TFTSet18"`; `items[]` global |
| CD_TR | `https://raw.communitydragon.org/latest/cdragon/tft/tr_tr.json` | same shape, Turkish strings |
| TP | `https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/default/v1/tftchampions-teamplanner.json` | `["TFTSet18"]` list: `character_id, tier, display_name, team_planner_code, traits[{name,id}]` |
| LK | `https://data.metatft.com/lookups/TFTSet18_latest_en_us.json` | units (81; `assetNames` = DA ids incl. variants, `code` 3-hex, `codeValue`, `poolCount`, `role`, `traitApiNames`, `ability.desc` with `<TFTCurveTable>`/`<TFTAttribute>` tags, `curveTable`, `attributeValues`), traits (`effects[].desc`, `curveTable`, `type` origin/class), augments (257; `apiName, name, desc, icon, rarity, tags, curveTable`), items |
| MT_COMPS | `https://api-hc.metatft.com/tft-comps-api/comps_data` | `results.data.cluster_id`, `results.data.cluster_details{key: cluster}` |
| MT_DET | `https://api-hc.metatft.com/tft-comps-api/comp_details?comp=<key>&cluster_id=<cluster_id>` | positioning, levels, early_options, final_levels, unit_stats, counters, trends, traits |
| MT_OPT | `https://api-hc.metatft.com/tft-comps-api/comp_options?comp=<key>&cluster_id=<cluster_id>` | `results.options[key][level]` → list of `{units_list ("&"-joined), score, avg, count}` |
| MT_AUG | `https://api-hc.metatft.com/tft-comps-api/comp_augment_tiers?comp=<key>&cluster_id=<cluster_id>` | `results[key].augments[{id, tier}]` |
| MT_UNITITEMS | `https://api-hc.metatft.com/tft-comps-api/unit_items_processed?comp=<key>&cluster_id=<cluster_id>` | global per-unit `{avg, pick, items[{itemName}]}` — call once with the first comp |
| MT_AUGTIERS | `https://api-hc.metatft.com/tft-stat-api/augments_tiers?queue=1100&patch=current&days=3&rank=PLATINUM,EMERALD,DIAMOND,MASTER,GRANDMASTER,CHALLENGER&permit_filter_adjustment=true` | `content.content.tierList[{label: "S"/"A"/…, content[{id,type}]}]` global augment tiers |
| MT_UNITS | `https://api-hc.metatft.com/tft-stat-api/units?queue=1100&patch=current&days=3&rank=PLATINUM,EMERALD,DIAMOND,MASTER,GRANDMASTER,CHALLENGER&permit_filter_adjustment=true` | `results[{unit, places[8]}]` → avgPlacement = Σ(i+1)·places[i]/Σplaces; popularity = Σplaces / max over units |
| IMG | `https://raw.communitydragon.org/latest/game/` + asset path (lower-case, `.tex`/`.dds` → `.png`) | champions (`tileIcon`), traits (`icon`), items (`icon`), augments (`icon` when not `missing-*`) |
| IMG_AUG | `https://cdn.metatft.com/file/metatft/augments/<LK augment icon lower-cased>.png` | e.g. `t_augmenticon_advancedloan.png` (verified 200). Use when CDragon icon path contains `missing` or 404s |

Patch string: parse from MetaTFT page title is not possible; read `LK._metadata.patch` — if it is `"pbe"` or empty,
fall back to the constant in `tools/rules.json` (`"patch": "18.2b"`), which the operator updates.

## Champion set (65)
Canonical list = TP `TFTSet18` entries. For each: `id = character_id`, `cost = tier`, `teamCode = format(team_planner_code, "03x")`,
`name.en = display_name`. Lookup record: LK unit whose `assetNames` contains `id` → `aliases = assetNames - {id}`,
`role`, `poolCount`, `code` (assert equals teamCode), `traitApiNames` (→ `traits`). CDragon record: CD_EN champion
with `apiName == id` (all 65 exist) → `stats`, `ability` (en), `tileIcon` → icon URL, `squareIcon` → splashURL,
`traits` display names (map to trait ids via CD trait `name`). CD_TR champion with the same apiName → `name.tr`,
`ability.name.tr`, `ability.desc.tr`. Assert every MetaTFT unit id seen in comps resolves via id or aliases.

## Traits (36)
From CD_EN set18 `traits[]` (+ CD_TR for tr strings, + LK traits for `type` and per-breakpoint EN descs).
`type`: LK `type` ("origin"/"class"); if the trait has exactly one champion and a single breakpoint with min 1 →
`"unique"`. Breakpoint style from CD `effects[].style`: `1→bronze, 3→silver, 4→unique, 5→gold, 6→prismatic`
(anything else → bronze); unique-type traits always `unique`. `desc` = main text without tier lines.
`champions` = champions whose `traits` include the trait id.

## Items
From CD_EN `items[]` with `apiName` starting `DA_` and not `isAugment`:
- `component`: `DA_Component_*` (10).
- `craftable`: has 2-element `composition` and name does not end with "Emblem" (45 incl. Tactician's Cape/Crown/Shield).
- `emblem`: name ends with "Emblem" (craftable ones have a recipe; `traitId` = matching trait by name prefix, e.g. "Vanguard Emblem" → `DA_18_Vanguard`; "Ravager Emblem" → `DA_18_Slayer` — match on trait `name.en`).
- `artifact`: `DA_Artifact_*` (30).
- `radiant`: apiName contains `Radiant` and is not an augment (42; exclude `DA_18_Radiantize*`).
Skip everything else (wisps, consumables, tactician items without recipe, etc.).
`stats`: `effects` entries whose key does not start with `{`. `desc` en/tr from CD (strip HTML/tokens; may be "").

## Augments (~250)
Source list = CD_EN set18 `augments[]` ids. Details from CD_EN `items[]` (name/desc) and CD_TR (tr), rarity/category/icon
from LK augments matched by `apiName`. `rarity` from LK `rarity` (Silver/Gold/Prismatic → lower-case; else "unknown").
`category` from LK `tags` (`Augment.Category.Combat`→combat, `Economic`→economy, `Trait`→trait, otherwise utility).
`metaTier` from MT_AUGTIERS labels. `traitId`: if LK `associatedTraits` non-empty or name contains a trait name.
Icon: CD icon if not `missing`, else IMG_AUG from LK `icon`.

## Text cleaning (all `desc` fields, both languages)
1. `<br>`/`<br/>` → `\n`; `&nbsp;` → space; drop all other HTML tags but keep their inner text
   (`<magicDamage>`, `<physicalDamage>`, `<trueDamage>`, `<tftitemrules>`, `<rules>`, `<expandRow>`, `<row>` …).
2. `<TFTCurveTable row="R" [column="c"] [format="f"] …/>` → value from the owner's `curveTable[R]` (LK): a list of
   `[star, value]` pairs; with `column` use pair index `c-1`, else the first pair. If the values differ across stars
   1–3, render as `v1 / v2 / v3`. Format: `percent` → `round(v*100)%`, `percentMinusOne` → `round((v-1)*100)%`,
   otherwise number without trailing `.0`.
3. `<TFTAttribute … attributeID="TFTCalculationAttributes.X"/>` → owner's `attributeValues["TFTCalculationAttributes.X"]`
   first three values as `a / b / c` (collapsed when equal).
4. `@X@`, `@X*100@`, `@X*100.0@`, `@TFTUnitProperty…@` (CDragon style): resolve `X` from the same curveTable /
   attributeValues (try exact key, then key without the `TFTCalculationAttributes.` prefix, then CD `variables`);
   `*100` → percent. Unresolvable → remove the token entirely.
5. `%i:scaleAP%` → `(AP)`, `%i:scaleAD%` → `(AD)`, `%i:scaleHealth%` → `(HP)`, `%i:scaleArmor%` → `(Armor)`,
   `%i:scaleMR%` → `(MR)`, `%i:scaleAS%` → `(AS)`, any other `%i:…%` → removed. In tr strings use
   `(BG)`, `(SH)`, `(Can)`, `(Zırh)`, `(BD)`, `(SH)` respectively.
6. Collapse runs of spaces, trim, collapse 3+ newlines to 2.

## Comps
From MT_COMPS `cluster_details`. Keep clusters with `overall.count ≥ 500`. For each cluster `key`:
- `id = key`, `stats = {avgPlacement: overall.avg, playRate: last trends[].pick, games: overall.count}`.
- `name`: `name[]` parts in order: `type == "trait"` → trait `name.<lang>`, `type == "unit"` → champion `name.<lang>`
  (resolve aliases). Join with spaces.
- `playstyle`: `levelling`: `"Fast 8"→fast8`, `"Fast 9"→fast9`, `"lvl 5"→reroll5`, `"lvl 6"→reroll6`, `"lvl 7"→reroll7`, else `standard`.
- `difficulty`: `difficulty ≥ 0.06 → hard`, `≤ -0.03 → easy`, else `medium`.
- `trend`: compare `pick` of the last trend day vs the first (≥ +20 % → rising, ≤ −20 % → falling, else stable); stable if < 2 days.
- `tier`: rank all kept comps by `avgPlacement` ascending; comps with `games < 1500` are ranked after the others.
  Top 6 → S, next 10 → A, next 14 → B, rest → C.
- `units`: from `units_string` (resolve aliases, dedupe). Items per unit: MT_COMPS `builds[]` entry for that unit
  (`buildName`, max 3 items, only ids present in gamedata items) — if none, []. `stars = 3` if unit id in `stars`,
  else 2. `isCarry` = has ≥ 2 items (cap 3 carries by item count then cost). `importance` = MT_DET
  `unit_stats[unit].count / overall.count` clamped to 0..1 (1.0 if missing). Order: carries first (items desc),
  then cost desc, then name.en.
- `cell` (board): MT_DET `positioning.units[unit].positions[]` (`cell`, `count`), also for aliases. Greedy:
  iterate units by importance desc; assign the highest-count cell not yet taken (`cell_N` → N). Units with no
  positioning data get `null`.
- `traits`: count trait occurrences over units; keep traits reaching at least the first breakpoint; style from the
  highest reached breakpoint.
- `teamCode`: units sorted by cost desc then name.en, first 10, `"02" + "".join(teamCode) + "000" * (10 - n) + "TFTSet18"`.
- `levelBoards`: MT_OPT `options[key][level]` → the entry with the highest `score` → `units_list.split("&")` (resolve aliases).
- `earlyBoards`: MT_DET `early_options[level]` → entry with the highest `count` → `unit_list.split("&")`.
- `levelTiming`: MT_DET `levels[]` with non-empty stage/round → `{level, stage:int, round:int}` sorted by level.
- `augments`: MT_AUG `augments` grouped by tier S and A (≤ 30 each; only ids present in gamedata).
- `counters`: MT_DET `counters[]` excluding self, `similarity < 0.9`, sorted by `place_change` desc → top 5 with
  `place_change > 0`; `goodAgainst` = the 5 most negative. Keep only compIds that are in the exported comp list
  (do a second pass after filtering).
- `starPriority` = `stars` (resolved), `coreUnits` = top 5 units by importance.
- `tips.tr` / `tips.en`: template sentences (3–7):
  - playstyle: fast8 → "Ekonomi yap, 4-1/4-2'de 8. seviyeye çık ve {carries} için mağazayı çevir." /
    fast9 → "…9. seviyeyi hedefle…", reroll5/6/7 → "{N}. seviyede dur, 50 altının üstündeki parayla {starPriority} 3 yıldız olana kadar çevir.",
    standard → "Standart tempo: her aşamada seviye atla, güçlü tahta koru."
  - carry items: "{carry}: {item1}, {item2}, {item3}." (per carry, Turkish item names).
  - level timing: "Oyuncular genelde {stage}-{round}'da {level}. seviyeye çıkıyor." for levels 7–9.
  - traits: "Aktif özellikler: {trait (count)}, …".
  - counters: "Dikkat: {compName} bu kompu yeniyor." (first counter).
  - difficulty: hard → "Zor komp: dizilim ve eşya önceliği kritik."
  EN equivalents in plain English.
- After building, run `--verify-codes` logic always (assert decode(teamCode) == unit ids of the first 10).

## Images
Download into `Resources/Images/{champions|traits|items|augments}/<id>.png`. If a PNG's width > 256, downscale to
256×256 (LANCZOS, keep alpha). Skip files that already exist. Record failures as warnings and set the JSON `icon` to
`null` for augments; champions/traits/items must all succeed (hard failure otherwise).

## Outputs
- `data/v1/gamedata.json`, `comps.json`, `guides.json` (copy from `tools/guides.json` if it exists, else write an
  empty articles list), `manifest.json`. JSON: `ensure_ascii=False`, `indent=1`, sorted keys off (keep schema order).
- Copy the same JSON into `Resources/Data/`.
- `rules` section from `tools/rules.json` (create it with the values listed in DATA_SCHEMA.md if missing).

## Verification checklist (must pass before hand-off)
- `python3 tools/build_data.py --verify-codes` exits 0; prints ≥ 60 champions, 36 traits, ≥ 120 items, ≥ 200 augments, ≥ 40 comps.
- `python3 - <<EOF` style spot checks: comp `424000` (Zyra Juggernaut) has Zyra on cell 7 or 1 and Amumu on 24–27; teamCode starts with `02` and ends with `TFTSet18`, length 40.
- `jq` (or python) validation that every referenced id (units, items, augments, counters, traits) exists in gamedata / comps.
- No `<`, `@`, `%i:` left in any `desc` string (grep the outputs).
