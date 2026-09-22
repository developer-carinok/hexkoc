# Multi-source comps ("ortak görüş" tier list) — spec addendum

Goal: comps and their tiers reflect several widely used TFT sites, not only MetaTFT. Every comp shows which
sources list it and what each source says; the consensus tier is a weighted blend. Curated content (guides,
early/mid boards, item priorities, augments, positioning) is preferred over pure statistics when available.


> **2026-09-22 research update:** final source set = MetaTFT (1.0), TFT Academy (1.0, use `/tierlist/comps/__data.json`
> devalue payload), Blitz (0.9, `data.v2.iesdev.com … analyzed_comps`), tactics.tools (0.9, `api.tft.tools/team-compositions/1/<patchId>`),
> tftactics.gg (0.7, comps JSON inside the JS bundle, display names mapped via gamedata), TFTFlow (0.6, tier-list HTML + WP REST boards).
> **Dropped:** OP.GG/lolchess and BunnyMuffins (terms of service prohibit scraping), Mobalytics (Cloudflare challenge), tftsense (no audience).
> Popularity (SimilarWeb, monthly visits): TFT Academy 8.7M, MetaTFT 7.8M, Blitz 3.6M (all games), tftactics 2.6M, tactics.tools 1.6M, TFTFlow 0.95M.

## Sources (verified 2026-09-22; ids are the game's `DA_*` api names in all of them)

| key | site | fetch | weight | tier scale |
|---|---|---|---|---|
| `metatft` | MetaTFT (existing) | existing endpoints | 1.0 | rank of avgPlacement (see below) |
| `tftacademy` | tftacademy.com/tierlist/comps | GET HTML with a browser UA → the SvelteKit boot script (`kit.start(app, element, {…, data: [ … ]})`): find `data:\s*\[`, bracket-match the array, evaluate it as a JS literal with node `vm.runInNewContext` (contains `void 0`, unquoted keys) → walk it for objects having `title` and `altBuilds` (63 comps). Fields: `title`, `tier` (S/A/B/C/X), `style` ("4-Cost Fast 8", "3-Cost Reroll", "2-Cost Reroll", "1-Cost Reroll", "Fast 9", "Lose Streak"), `difficulty` (EASY/MEDIUM/HARD/CONDITIONAL), `mainChampion{apiName,cost}`, `earlyComp[{apiName,items,stars}]`, `finalComp[{apiName,boardIndex,items,stars}]` (boardIndex 0–27: row = idx // 7, col = idx % 7, row 0 = FRONT → our cell = 22 − 7·row + col + … see mapping), `maxCap[{apiName,predecessors}]`, `altBuilds[{apiName,items}]`, `augments[{apiName}]`, `augmentsTip`, `carousel[{apiName}]` (component priority), `tips[{stage,tip}]` (EN), `compSlug` (URL `https://tftacademy.com/tierlist/comps/<compSlug>`), `updated`. Summon units (`DA_Elderwood18_*`, `DA_TrainingDummy*`) must be dropped from boards. | 1.0 | S=95 A=80 B=65 C=50 X=situational (no vote) |
| `opgg` | op.gg/tft/meta-trends/comps | GET HTML → concatenate all `self.__next_f.push([1,"…"])` chunk strings (JSON-decode each) → find the JSON array whose objects have `teamCode` (33 comps). Fields: `name{en_US, tr_TR, …}`, `teamCode`, `units[{key, items[], tier(2|3 = star target), cell{x 1..7, y 1..4}, isCore, priority}]`, `traits`, `badge[{key:difficulty,value 1..5}]`, `stat{opTier (OP/S/A/B/C/D), opScore, deck{avgPlacement, winRate, top4Rate, pickRate, compsCount}}`, `early{level:"5", units[{characterId, cell}]}`, `middle{level:"7", …}`. Cell mapping: our cell = (y − 1)·7 + x (y = 4 is the FRONT row). | 0.9 | OP=98 S=92 A=78 B=64 C=50 D=36 |
| `tacticstools` | tactics.tools/team-compositions | GET HTML → `<script id="__NEXT_DATA__">` JSON → `props.pageProps.initialData.groups[]` (5 groups server-rendered; the rest via the site's API — see research report; if the API is not reachable use the 5 + the `aperture`/`initialKey` request pattern). Per group `full`: `comps[{units, spatItems, count, place, top4, win}]` (variants), `carryUnits`, `starUnits`, `unitItems`, `levels`, `lvl9Comps`, `augmentSingles`, `code` (team code), `place`, `top4`, `win`, `count`. | 0.9 | rank of `place` |
| `tftflow` | tftflow.com/tier-list | GET HTML → `<div class="comp-card-wrapper" data-comp-id data-tier-modifier data-is-max-tier …>` cards (111), tier sections, `tier-comp-name`, `econ-badge econ-badge--fast8|fast9|reroll1|reroll2|reroll3|reroll12`, champion image URLs carrying `DA_18_*` ids. Exact parsing per research report. | 0.6 | S+=98 S=92 A=78 B=64 C=50 |
| `bunnymuffins` | bunnymuffins.lol/meta | HTML with tiers, names and team codes (`02…TFTSet18` → decode to units with our team-code decoder). Per research report. | 0.5 | S=95 A=80 B=65 C=50 |
| others | mobalytics / tftactics(Blitz) / lolchess | only if the research report finds an accessible route; same normalisation | 0.8 | per report |

Fetch rules: browser User-Agent, 60 s timeout, cache in `tools/cache/`, a source failure must NOT fail the build
(log a warning, continue with the others; MetaTFT stays mandatory). Record `sourceStatus` in `comps.json`.

## Normalised source comp
```
{ source, sourceId, url?, name_en, name_tr?, tierLabel, tierScore (0–100 or null for situational),
  style?, difficulty?, mainChampion?, units[{id, stars, items[], cell?}],
  early?[{id, stars, items}], mid?[{id, …}], augments?[ids], altBuilds?[{id, items}], carousel?[component ids],
  tips?[{stage, en}], stats?{avgPlacement, top4Rate, winRate, pickRate, games}, updated? }
```
Stats-only sources get `tierScore` from their rank among that source's comps (top 15 % → 95, next 25 % → 80,
next 30 % → 65, rest 50), ignoring comps below the source's play-count floor.

## Matching (clustering) across sources
- Resolve aliases first (Lux variants → `DA_Lux18_Base`); drop summons/dummies.
- `sim(a,b)` = Jaccard of unit-id sets; match if `sim ≥ 0.5`, or (`|a∩b| ≥ 5` and same main carry).
- Seed order: tftacademy, opgg, tacticstools, metatft, tftflow, bunnymuffins. Each source comp joins the best
  existing cluster it matches, else starts a new cluster. One cluster may hold at most one comp per source
  (if a source has two matching comps, the second starts a new cluster → keeps "variants" apart).

## Consensus comp (extends the existing `Comp` schema — all new keys optional for the app)
- `tier`: weighted mean of available `tierScore`s (weights above) → S ≥ 88, A ≥ 74, B ≥ 60, else C. A comp listed by
  a single stats-only source keeps that source's rank-tier but is capped at B. `situational: true` when every
  letter-tier source says X.
- `sources`: `[{ "key": "tftacademy", "label": "TFT Academy", "tier": "S", "name": "Lunarwood Kha'zix", "url": "…" }, …]`
  ordered by weight; `sourceCount`.
- `name.en`: tftacademy title > opgg en_US > metatft generated. `name.tr`: opgg tr_TR > metatft generated Turkish
  (trait + carry). `subtitle`: the other-language name when different.
- `units`: from the highest-weight curated source (tftacademy finalComp → opgg → metatft). Items: curated first;
  MetaTFT builds fill units without curated items. `stars`: 3 when any curated source says 3★ (opgg tier 3 /
  tftacademy stars 3) else MetaTFT rule. `isCarry` as before (≥ 2 items). `cell` from the curated board (mapped),
  fallback MetaTFT positioning; team code recomputed from `units`.
- `stages` (new): `{ "early": {"label": "Erken (2-1 → 3-2)", "units": [...]}, "mid": {"label": "Orta (7. seviye)", "units": [...]}, "late": {"label": "Tavan (9-10)", "units": [...]} }`
  early = tftacademy earlyComp (with items/stars) else opgg early(5) else metatft early 5; mid = opgg middle(7)
  else metatft level 7; late = tftacademy maxCap merged onto the final board (max 10) else metatft level 9/10.
  Keep `earlyBoards`/`levelBoards` as today (MetaTFT).
- `augments`: `S` = union of curated lists (tftacademy augments, opgg none) + MetaTFT S; `A` = MetaTFT A minus S.
- `altBuilds` (new): `[{ "unit": id, "items": [ids] }]` from tftacademy; `carousel` (new): `[component ids]`.
- `sourceTips` (new): `[{ "source": "tftacademy", "stage": "Stage 2", "en": "…", "tr": "…"|null }]` — tr from
  `tools/translations.json` (`entries[sha1(en)].tr`), null when missing. `augmentsTip` goes in as stage "Güçlendirme".
- `tips` (generated, tr/en) stay as today. `difficulty`: tftacademy > opgg badge (1-2 easy, 3 medium, 4-5 hard) > metatft.
- `playstyle`: tftacademy style ("1-Cost Reroll"→reroll5, "2-Cost"→reroll6, "3-Cost"→reroll7, "4-Cost Fast 8"→fast8,
  "Fast 9"→fast9, "Lose Streak"→standard) > tftflow badge > metatft.
- `stats`: MetaTFT numbers + `winRate`/`top4Rate` from opgg when matched.
- `comps.json` top level adds `"sources": [{key,label,url,fetchedAt,ok,count}]` for the About screen.

Sorting: tier (S→C), then `sourceCount` desc, then consensus score desc. Situational comps go last within C.

## App
- Comp rows: consensus tier badge + `N kaynak` micro-chip. Detail/game-mode header: a horizontally scrolling row
  of source badges ("TFT Academy S", "OP.GG A", "MetaTFT 4.17", "tactics.tools B"…), tap → open the source URL.
- Game mode: **Erken Oyun** shows `stages.early` first (label + tiles with items/stars) then the MetaTFT level rows;
  **Orta Oyun** shows `stages.mid` first; **Son Tahta** adds `stages.late` ("Tavan") row; **Eşyalar** shows curated
  items and an "Alternatif" strip from `altBuilds` + a "İlk karusel" line from `carousel`; **İpuçları** shows
  `sourceTips` (tr, else en with an "EN" tag) grouped by stage before the generated tips.
- Settings → Hakkında lists `comps.sources` with fetch time and ok/failed.
