#!/usr/bin/env python3
"""Comp sources for the HexKoc multi-source consensus (docs/MULTISOURCE_SPEC.md).

Every fetcher returns a list of "normalised source comps":

    {source, sourceId, url, name_en, tierLabel, tierScore, style, difficulty, mainChampion,
     units[{id, stars, items[], cell}], early[{id, stars, items}], mid[…], midLevel, late[…],
     augments[ids], altBuilds[{unit, items}], carousel[ids], tips[{stage, en}],
     stats{avgPlacement, top4Rate, winRate, pickRate, games}, updated}

Only `source`, `sourceId`, `name_en` and `units` are guaranteed; everything else may be
None/empty. A source that cannot be fetched or parsed raises; `build_data.collect_sources`
turns that into a warning and carries on (MetaTFT stays mandatory).

Python 3.9 compatible, no dependencies beyond `requests` (through the caller's Fetcher).
"""

import html
import json
import os
import re
import subprocess
from collections import OrderedDict

# --------------------------------------------------------------------------------------
# Source registry
# --------------------------------------------------------------------------------------

# key -> (label, weight, site url shown in the app)
SOURCE_META = OrderedDict([
    ("metatft", ("MetaTFT", 1.0, "https://www.metatft.com/comps")),
    ("tftacademy", ("TFT Academy", 1.0, "https://tftacademy.com/tierlist/comps")),
    ("blitz", ("Blitz", 0.9, "https://blitz.gg/tft/comps")),
    ("tacticstools", ("tactics.tools", 0.9, "https://tactics.tools/team-compositions")),
    ("tftactics", ("tftactics.gg", 0.7, "https://tftactics.gg/tierlist/team-comps/")),
    ("tftflow", ("TFTFlow", 0.6, "https://tftflow.com/tier-list")),
])

# Sources that vote with statistics only (no human-written tier list).
STATS_ONLY_SOURCES = ("metatft", "blitz", "tacticstools")

BROWSER_HEADERS = {
    "User-Agent": ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                   "(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"),
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
}

URL_TFTACADEMY_DATA = "https://tftacademy.com/tierlist/comps/__data.json"
URL_TFTACADEMY_HTML = "https://tftacademy.com/tierlist/comps"
URL_TFTACADEMY_COMP = "https://tftacademy.com/tierlist/comps/%s"
URL_BLITZ_PATCH = ("https://data.v2.iesdev.com/api/v1/query_objects/prod/tft/patch_info"
                   "?patch_type=latest")
URL_BLITZ_COMPS = ("https://data.v2.iesdev.com/api/v1/query_objects/prod/tft/analyzed_comps"
                   "?region=WORLD&rank=PLATINUM%%2B&mode=RANKED&portal=ALL&patch=%s")
URL_TACTICS_HTML = "https://tactics.tools/team-compositions"
URL_TACTICS_API = "https://api.tft.tools/team-compositions/1/%s"
URL_TFTFLOW_HTML = "https://tftflow.com/tier-list"
URL_TFTFLOW_REST = ("https://tftflow.com/wp-json/wp/v2/composition"
                    "?per_page=100&_fields=id,slug,link,content")
URL_TFTACTICS_HTML = "https://tftactics.gg/"

JS_LITERAL_HELPER = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "js_literal_to_json.js")

# --------------------------------------------------------------------------------------
# Shared helpers
# --------------------------------------------------------------------------------------

BOARD_COLS = 7
BOARD_ROWS = 4
FRONT_ROW_FIRST_CELL = 22

# Board indices are 0..27 with row = idx // 7 and row 0 = the FRONT row in every source we
# read (verified against MetaTFT positioning: TFT Academy Kha'Zix 1 / Hecarim 2 -> cells
# 23 / 24, Diana 8 -> 16, Ornn 16 -> 10). Our cells run 1..7 on the back row and 22..28 on
# the front row, so the front row start moves down by one row width per source row.
LETTER_TIER_SCORES = {"S+": 98, "S": 95, "A": 80, "B": 65, "C": 50, "D": 36}

# Curated playstyle labels -> our schema values.
PLAYSTYLE_ALIASES = {
    "1-cost reroll": "reroll5",
    "2-cost reroll": "reroll6",
    "3-cost reroll": "reroll7",
    "4-cost fast 8": "fast8",
    "fast 8": "fast8",
    "fast 9": "fast9",
    "lose streak": "standard",
    "standard": "standard",
    "slow roll (5)": "reroll5",
    "slow roll (6)": "reroll6",
    "slow roll (7)": "reroll7",
    "fast8": "fast8",
    "fast9": "fast9",
    "reroll1": "reroll5",
    "reroll2": "reroll6",
    "reroll12": "reroll6",
    "reroll3": "reroll7",
    "fast_8": "fast8",
    "fast_9": "fast9",
    "fast_10": "fast9",
    "roll_5": "reroll5",
    "roll_6": "reroll6",
    "roll_7": "reroll7",
}

DIFFICULTY_ALIASES = {"easy": "easy", "medium": "medium", "hard": "hard",
                      "conditional": "hard"}

# Units that exist on the board but are not champions (Elderwood saplings, dummies).
SUMMON_PREFIXES = ("DA_Elderwood18_", "DA_TrainingDummy")

RE_TAG = re.compile(r"<[^<>]*>")
RE_SPACES = re.compile(r"\s+")


def clean_source_text(text):
    """Third-party copy -> plain text (no entities, no markup, single spaces)."""
    if not text:
        return ""
    return RE_SPACES.sub(" ", RE_TAG.sub(" ", html.unescape(str(text)))).strip()


def board_cell(index):
    """Source board index 0..27 (row = idx // 7, row 0 = FRONT) -> our cell 1..28."""
    try:
        index = int(index)
    except (TypeError, ValueError):
        return None
    if not 0 <= index < BOARD_ROWS * BOARD_COLS:
        return None
    row, column = divmod(index, BOARD_COLS)
    return FRONT_ROW_FIRST_CELL - BOARD_COLS * row + column


def playstyle_of(label):
    return PLAYSTYLE_ALIASES.get((label or "").strip().lower())


def difficulty_of(label):
    return DIFFICULTY_ALIASES.get((label or "").strip().lower())


def rank_scores(values, floor_mask=None):
    """Stats-only ranking: top 15 % -> 95, next 25 % -> 80, next 30 % -> 65, rest 50.

    `values` are "lower is better" (average placement). Entries excluded by `floor_mask`
    (False = below the source's play-count floor) always land in the bottom bucket.
    """
    ranked = [index for index, value in enumerate(values)
              if value is not None and (floor_mask is None or floor_mask[index])]
    ranked.sort(key=lambda index: values[index])
    total = len(ranked)
    scores = [50] * len(values)
    for position, index in enumerate(ranked):
        share = (position + 1) / float(total) if total else 1.0
        if share <= 0.15:
            scores[index] = 95
        elif share <= 0.40:
            scores[index] = 80
        elif share <= 0.70:
            scores[index] = 65
        else:
            scores[index] = 50
    return scores


def score_to_letter(score):
    if score is None:
        return "X"
    if score >= 88:
        return "S"
    if score >= 74:
        return "A"
    if score >= 60:
        return "B"
    return "C"


def source_comp(source, source_id, name_en, units, **extra):
    """The normalised record every fetcher returns."""
    record = OrderedDict([
        ("source", source),
        ("sourceId", str(source_id)),
        ("url", extra.get("url") or SOURCE_META[source][2]),
        ("name_en", name_en or ""),
        ("tierLabel", extra.get("tier_label")),
        ("tierScore", extra.get("tier_score")),
        ("style", extra.get("style")),
        ("difficulty", extra.get("difficulty")),
        ("mainChampion", extra.get("main_champion")),
        ("units", units or []),
        ("early", extra.get("early") or []),
        ("mid", extra.get("mid") or []),
        ("midLevel", extra.get("mid_level")),
        ("late", extra.get("late") or []),
        ("augments", extra.get("augments") or []),
        ("altBuilds", extra.get("alt_builds") or []),
        ("carousel", extra.get("carousel") or []),
        ("tips", extra.get("tips") or []),
        ("stats", extra.get("stats")),
        ("updated", extra.get("updated")),
    ])
    return record


def unit_record(unit_id, stars=2, items=None, cell=None):
    return OrderedDict([("id", unit_id), ("stars", stars),
                        ("items", items or []), ("cell", cell)])


def stage_record(unit_id, stars=2, items=None):
    return OrderedDict([("id", unit_id), ("stars", stars), ("items", items or [])])


def stats_record(avg_placement=None, top4_rate=None, win_rate=None, pick_rate=None, games=None):
    return OrderedDict([("avgPlacement", avg_placement), ("top4Rate", top4_rate),
                        ("winRate", win_rate), ("pickRate", pick_rate), ("games", games)])


class Catalog(object):
    """Champion/item/trait lookups the fetchers need, built from the finished gamedata."""

    def __init__(self, gamedata, warn=None):
        self.warn = warn or (lambda message: None)
        self.champions = OrderedDict((champion["id"], champion)
                                     for champion in gamedata["champions"])
        self.traits = OrderedDict((trait["id"], trait) for trait in gamedata["traits"])
        self.items = OrderedDict((item["id"], item) for item in gamedata["items"])
        self.alias_to_id = {}
        self.champion_by_name = {}
        for champion in gamedata["champions"]:
            self.alias_to_id[champion["id"]] = champion["id"]
            for alias in champion["aliases"]:
                self.alias_to_id.setdefault(alias, champion["id"])
            self.champion_by_name.setdefault(_norm_name(champion["name"]["en"]), champion["id"])
        self.item_by_name = {}
        for item in gamedata["items"]:
            self.item_by_name.setdefault(_norm_name(item["name"]["en"]), item["id"])
        self._unknown = set()

    def unit_id(self, raw, context=""):
        """Source unit id -> canonical champion id (None for summons and unknown ids)."""
        if not raw:
            return None
        canonical = self.alias_to_id.get(raw)
        if canonical:
            return canonical
        if raw.startswith(SUMMON_PREFIXES):
            return None
        if raw not in self._unknown:
            self._unknown.add(raw)
            self.warn("unknown unit %s from %s; dropped" % (raw, context or "a source"))
        return None

    def unit_ids(self, raws, context=""):
        resolved = []
        for raw in raws or []:
            canonical = self.unit_id(raw, context)
            if canonical and canonical not in resolved:
                resolved.append(canonical)
        return resolved

    def unit_by_display(self, name):
        """Display name ("Khazix", "Lux (Blossom)") -> champion id."""
        if not name:
            return None
        base = re.sub(r"\s*\([^)]*\)\s*$", "", name)
        return self.champion_by_name.get(_norm_name(base))

    def item_ids(self, raws, limit=3, unique=False):
        """Item ids in source order. Builds may repeat an item, carousels may not."""
        resolved = []
        for raw in raws or []:
            if raw in self.items and not (unique and raw in resolved):
                resolved.append(raw)
            if len(resolved) >= limit:
                break
        return resolved

    def item_by_display(self, name):
        return self.item_by_name.get(_norm_name(name))

    def item_ids_by_display(self, names, limit=3, unique=False):
        resolved = []
        for name in names or []:
            item_id = self.item_by_display(name)
            if item_id and not (unique and item_id in resolved):
                resolved.append(item_id)
            if len(resolved) >= limit:
                break
        return resolved

    def augment_ids(self, raws, augment_ids, limit=30):
        return [raw for raw in raws or [] if raw in augment_ids][:limit]

    def champion_name(self, unit_id, lang="en"):
        champion = self.champions.get(unit_id)
        return champion["name"][lang] if champion else unit_id

    def trait_name(self, trait_id, lang="en"):
        trait = self.traits.get(trait_id)
        return trait["name"][lang] if trait else None


def _norm_name(name):
    return re.sub(r"[^a-z0-9]", "", (name or "").lower())


# --------------------------------------------------------------------------------------
# TFT Academy — curated tier list, boards, items, augments and tips
# --------------------------------------------------------------------------------------

def devalue_unflatten(flat):
    """SvelteKit `__data.json` flat array -> plain value (ints are indices into `flat`)."""
    resolved = {}

    def hydrate(index):
        if index < 0:
            return 0 if index == -6 else None      # -1 undefined, -2 hole, -3 NaN, ±Infinity
        if index in resolved:
            return resolved[index]
        value = flat[index]
        if isinstance(value, list):
            out = []
            resolved[index] = out
            for item in value:
                out.append(hydrate(item) if isinstance(item, int) else item)
            return out
        if isinstance(value, dict):
            out = OrderedDict()
            resolved[index] = out
            for key, item in value.items():
                out[key] = hydrate(item) if isinstance(item, int) else item
            return out
        resolved[index] = value
        return value

    return hydrate(0) if flat else None


def _tftacademy_guides_from_data(payload):
    for node in payload.get("nodes") or []:
        if not node or node.get("type") != "data":
            continue
        value = devalue_unflatten(node.get("data") or [])
        if isinstance(value, dict) and value.get("guides"):
            return value["guides"]
    return []


def _tftacademy_guides_from_html(fetcher):
    """Fallback: the SvelteKit boot script carries the same list as a JS literal."""
    page = fetcher.get_text(URL_TFTACADEMY_HTML, headers=BROWSER_HEADERS)
    anchor = page.find("kit.start(")
    if anchor < 0:
        raise ValueError("tftacademy boot script not found")
    segment = page[anchor:]
    match = re.search(r"\bdata:\s*\[", segment)
    if not match:
        raise ValueError("tftacademy data array not found")
    start = segment.index("[", match.start())
    literal = segment[start:_match_bracket(segment, start)]
    process = subprocess.Popen(["node", JS_LITERAL_HELPER], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate(literal.encode("utf-8"))
    if process.returncode != 0:
        raise ValueError("node could not evaluate the tftacademy literal: %s"
                         % err.decode("utf-8", "replace")[:200])
    guides = []
    _collect_guides(json.loads(out.decode("utf-8")), guides)
    return guides


def _collect_guides(node, out):
    if isinstance(node, dict):
        if "title" in node and "altBuilds" in node:
            out.append(node)
            return
        for value in node.values():
            _collect_guides(value, out)
    elif isinstance(node, list):
        for value in node:
            _collect_guides(value, out)


def _match_bracket(text, start):
    """Index just past the bracket that matches the one at `start` (strings are skipped)."""
    closers = {"[": "]", "{": "}", "(": ")"}
    stack = []
    index = start
    while index < len(text):
        char = text[index]
        if char in ("'", '"', "`"):
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                    continue
                if text[index] == char:
                    break
                index += 1
        elif char in closers:
            stack.append(closers[char])
        elif char in ("]", "}", ")"):
            if not stack or stack.pop() != char:
                raise ValueError("unbalanced literal")
            if not stack:
                return index + 1
        index += 1
    raise ValueError("unterminated literal")


def _tftacademy_units(entries, catalog, with_cell=True):
    units = []
    seen = set()
    for entry in entries or []:
        unit_id = catalog.unit_id((entry or {}).get("apiName"), "tftacademy")
        if not unit_id or unit_id in seen:
            continue
        seen.add(unit_id)
        stars = 3 if (entry.get("stars") or 0) >= 3 else 2
        items = catalog.item_ids(entry.get("items"))
        if with_cell:
            units.append(unit_record(unit_id, stars, items, board_cell(entry.get("boardIndex"))))
        else:
            units.append(stage_record(unit_id, stars, items))
    return units


def fetch_tftacademy(fetcher, catalog):
    try:
        payload = fetcher.get_json(URL_TFTACADEMY_DATA, headers=BROWSER_HEADERS)
        guides = _tftacademy_guides_from_data(payload)
    except (IOError, ValueError, KeyError, TypeError) as exc:
        catalog.warn("tftacademy __data.json unusable (%s); trying the HTML route" % exc)
        guides = _tftacademy_guides_from_html(fetcher)
    if not guides:
        raise ValueError("tftacademy returned no comps")

    comps = []
    for guide in guides:
        title = clean_source_text(guide.get("title"))
        if not title:
            continue
        units = _tftacademy_units(guide.get("finalComp"), catalog)
        if not units:
            continue
        tier_label = (guide.get("tier") or "").strip().upper() or "C"
        slug = guide.get("compSlug") or guide.get("id") or title
        tips = []
        for tip in guide.get("tips") or []:
            text = clean_source_text(tip.get("tip"))
            if text:
                tips.append(OrderedDict([("stage", clean_source_text(tip.get("stage")) or "Genel"),
                                         ("en", text), ("raw", tip.get("tip"))]))
        augments_tip = clean_source_text(guide.get("augmentsTip"))
        if augments_tip:
            tips.append(OrderedDict([("stage", "Güçlendirme"), ("en", augments_tip),
                                     ("raw", guide.get("augmentsTip"))]))
        alt_builds = []
        for entry in guide.get("altBuilds") or []:
            unit_id = catalog.unit_id((entry or {}).get("apiName"), "tftacademy altBuilds")
            items = catalog.item_ids(entry.get("items"))
            if unit_id and items:
                alt_builds.append(OrderedDict([("unit", unit_id), ("items", items)]))
        comps.append(source_comp(
            "tftacademy", slug, title, units,
            url=URL_TFTACADEMY_COMP % slug if guide.get("compSlug") else None,
            tier_label=tier_label,
            tier_score=LETTER_TIER_SCORES.get(tier_label),
            style=playstyle_of(guide.get("style")),
            difficulty=difficulty_of(guide.get("difficulty")),
            main_champion=catalog.unit_id((guide.get("mainChampion") or {}).get("apiName"),
                                          "tftacademy mainChampion"),
            early=_tftacademy_units(guide.get("earlyComp"), catalog, with_cell=False),
            late=_tftacademy_units(guide.get("maxCap"), catalog, with_cell=False),
            augments=[entry.get("apiName") for entry in guide.get("augments") or []
                      if entry and not entry.get("disabled") and entry.get("apiName")],
            alt_builds=alt_builds,
            carousel=catalog.item_ids([entry.get("apiName")
                                       for entry in guide.get("carousel") or [] if entry],
                                      limit=6, unique=True),
            tips=tips,
            updated=guide.get("updated"),
        ))
    return comps


# --------------------------------------------------------------------------------------
# Blitz — statistical comps with boards, level variations and augments
# --------------------------------------------------------------------------------------

BLITZ_TIER_SCORES = {1: 95, 2: 80, 3: 65, 4: 50, 5: 36}
BLITZ_TIER_LABELS = {1: "S", 2: "A", 3: "B", 4: "C", 5: "D"}


def _blitz_name(comp, catalog):
    parts = []
    for token in (comp.get("api_name") or "").split(","):
        kind, _, value = token.partition(":")
        if kind == "trait":
            parts.append(catalog.trait_name(value) or value)
        elif kind == "unit":
            unit_id = catalog.unit_id(value, "blitz name")
            if unit_id:
                parts.append(catalog.champion_name(unit_id))
    return " ".join(part for part in parts if part)


def _blitz_positions(entries, catalog):
    cells = {}
    for entry in entries or []:
        unit_id = catalog.unit_id((entry or {}).get("unit_api_name"), "blitz positions")
        if unit_id and unit_id not in cells:
            cells[unit_id] = board_cell(entry.get("board_position"))
    return cells


def _blitz_units(entries, catalog, cells=None, with_cell=True):
    cells = cells or {}
    units = []
    seen = set()
    for entry in entries or []:
        unit_id = catalog.unit_id((entry or {}).get("name"), "blitz units")
        if not unit_id or unit_id in seen:
            continue
        seen.add(unit_id)
        stars = 3 if float(entry.get("star_level") or 0) >= 3 else 2
        items = catalog.item_ids(entry.get("items"))
        if with_cell:
            units.append(unit_record(unit_id, stars, items, cells.get(unit_id)))
        else:
            units.append(stage_record(unit_id, stars, items))
    return units


def _blitz_best(entries, rank_key="comps_rank"):
    best = None
    for entry in entries or []:
        if best is None:
            best = entry
            continue
        if entry.get(rank_key) is not None and best.get(rank_key) is not None:
            if entry[rank_key] < best[rank_key]:
                best = entry
        elif (entry.get("avg_placement") or 9) < (best.get("avg_placement") or 9):
            best = entry
    return best or {}


def fetch_blitz(fetcher, catalog):
    patch_payload = fetcher.get_json(URL_BLITZ_PATCH, headers=BROWSER_HEADERS)
    rows = patch_payload.get("data") or []
    patch = (rows[0].get("patch") if rows else None) or patch_payload.get("patch")
    if not patch:
        raise ValueError("blitz patch id not found")
    payload = fetcher.get_json(URL_BLITZ_COMPS % patch, headers=BROWSER_HEADERS)
    entries = payload.get("data") or []
    if not entries:
        raise ValueError("blitz returned no comps")

    comps = []
    for entry in entries:
        stats = entry.get("stats") or {}
        cells = _blitz_positions(entry.get("units_positions"), catalog)
        units = _blitz_units(entry.get("units"), catalog, cells)
        if not units:
            continue
        variations = entry.get("variations") or {}
        levels = variations.get("levels") or {}
        mid_level = "7" if levels.get("7") else ("8" if levels.get("8") else None)
        mid = _blitz_units(_blitz_best(levels.get(mid_level)).get("units"), catalog,
                           with_cell=False) if mid_level else []
        if not mid:
            mid = _blitz_units(_blitz_best(variations.get("lvl8"), "nb_boards").get("units"),
                               catalog, with_cell=False)
            mid_level = mid_level or "8"
        tier = stats.get("tier")
        playstyle = None
        for tag in entry.get("tags") or []:
            playstyle = playstyle or playstyle_of(tag)
        comps.append(source_comp(
            "blitz", entry.get("api_name") or entry.get("name"),
            _blitz_name(entry, catalog) or clean_source_text(entry.get("name")), units,
            tier_label=BLITZ_TIER_LABELS.get(tier),
            tier_score=BLITZ_TIER_SCORES.get(tier),
            style=playstyle,
            main_champion=(catalog.unit_id((entry.get("carry_units") or [None])[0], "blitz carry")
                           if entry.get("carry_units") else None),
            early=_blitz_units(_blitz_best(variations.get("early"), "early_rank").get("units"),
                               catalog, with_cell=False),
            mid=mid, mid_level=mid_level,
            late=_blitz_units(_blitz_best(variations.get("lvl9")).get("units"),
                              catalog, with_cell=False),
            augments=[augment for augment in entry.get("augments") or [] if augment],
            carousel=catalog.item_ids(entry.get("carousel_priority"), limit=6, unique=True),
            stats=stats_record(_round(stats.get("avg_placement"), 3),
                               _round(stats.get("top_4_percent"), 4),
                               _round(stats.get("top_1_percent"), 4),
                               _round(stats.get("pick_rate"), 5),
                               stats.get("nb_games")),
        ))
    return comps


def _round(value, digits):
    try:
        return round(float(value), digits)
    except (TypeError, ValueError):
        return None


# --------------------------------------------------------------------------------------
# tactics.tools — statistical groups (unit set from the group's team code)
# --------------------------------------------------------------------------------------

TACTICS_MIN_GAMES = 200


def fetch_tacticstools_api(fetcher, patch_id):
    """The list the site itself loads (31 groups); the HTML only ships 5."""
    return fetcher.get_json(URL_TACTICS_API % patch_id, headers=BROWSER_HEADERS)


def _tactics_patch_and_groups(fetcher, catalog):
    page = fetcher.get_text(URL_TACTICS_HTML, headers=BROWSER_HEADERS)
    match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    if not match:
        raise ValueError("tactics.tools __NEXT_DATA__ not found")
    next_data = json.loads(match.group(1))
    page_props = ((next_data.get("props") or {}).get("pageProps") or {})
    patch_id = (((page_props.get("aperture") or {}).get("patch") or {}).get("_0"))
    if patch_id:
        try:
            return patch_id, (fetch_tacticstools_api(fetcher, patch_id).get("groups") or [])
        except (IOError, ValueError) as exc:
            catalog.warn("tactics.tools API unavailable (%s); using the 5 embedded groups" % exc)
    return patch_id, ((page_props.get("initialData") or {}).get("groups") or [])


def _tactics_name(full, catalog, carry_id):
    traits = sorted(full.get("traits") or [],
                    key=lambda row: (-(row[1] or 0), -(row[2] or 0)))
    parts = []
    if traits:
        parts.append(catalog.trait_name(traits[0][0]) or traits[0][0])
    if carry_id:
        parts.append(catalog.champion_name(carry_id))
    return " ".join(parts)


def fetch_tacticstools(fetcher, catalog, decode_team_code):
    patch_id, groups = _tactics_patch_and_groups(fetcher, catalog)
    if not groups:
        raise ValueError("tactics.tools returned no groups")

    rows = []
    for group in groups:
        full = (group or {}).get("full") or {}
        unit_ids = []
        try:
            unit_ids = catalog.unit_ids(decode_team_code(full.get("code")), "tacticstools")
        except (ValueError, KeyError, TypeError):
            unit_ids = []
        if not unit_ids:
            comps = full.get("comps") or []
            unit_ids = catalog.unit_ids((comps[0].get("units") if comps else []), "tacticstools")
        if not unit_ids:
            continue
        rows.append((full, unit_ids))
    if not rows:
        raise ValueError("tactics.tools groups had no resolvable units")

    places = [full.get("place") for full, _ in rows]
    mask = [(full.get("count") or 0) >= TACTICS_MIN_GAMES for full, _ in rows]
    scores = rank_scores(places, mask)

    comps = []
    for index, (full, unit_ids) in enumerate(rows):
        carries = [catalog.unit_id(entry[0], "tacticstools carry")
                   for entry in (full.get("carryUnits") or [])]
        carries = [carry for carry in carries if carry]
        star_units = set()
        for raw, values in (full.get("starUnits") or {}).items():
            unit_id = catalog.unit_id(raw, "tacticstools stars")
            if unit_id and values and (values[0] or 0) >= 0.5:
                star_units.add(unit_id)
        items_by_unit = {}
        for row in sorted(full.get("unitItems") or [], key=lambda row: -(row.get("count") or 0)):
            unit_id = catalog.unit_id(row.get("unitId"), "tacticstools items")
            item_id = row.get("itemId")
            if not unit_id or item_id not in catalog.items:
                continue
            bucket = items_by_unit.setdefault(unit_id, [])
            if item_id not in bucket and len(bucket) < 3:
                bucket.append(item_id)
        units = [unit_record(unit_id, 3 if unit_id in star_units else 2,
                             items_by_unit.get(unit_id, []) if unit_id in carries else [])
                 for unit_id in unit_ids]
        late = []
        lvl9 = sorted(full.get("lvl9Comps") or [], key=lambda entry: -(entry.get("count") or 0))
        if lvl9:
            late = [stage_record(unit_id) for unit_id
                    in catalog.unit_ids(lvl9[0].get("units"), "tacticstools lvl9")]
        count = full.get("count") or 0
        comps.append(source_comp(
            "tacticstools", full.get("code") or ("group%d" % index),
            _tactics_name(full, catalog, carries[0] if carries else None), units,
            tier_label=score_to_letter(scores[index]),
            tier_score=scores[index],
            main_champion=carries[0] if carries else None,
            late=late,
            augments=[entry[0] for entry in (full.get("augmentSingles") or [])
                      if entry and isinstance(entry, list) and entry],
            stats=stats_record(_round(full.get("place"), 3),
                               _round((full.get("top4") or 0) / float(count), 4) if count else None,
                               _round((full.get("win") or 0) / float(count), 4) if count else None,
                               None, count),
        ))
    return comps


# --------------------------------------------------------------------------------------
# TFTFlow — curated tier list (cards) + boards from the WordPress REST API
# --------------------------------------------------------------------------------------

TFTFLOW_TIER_SCORES = {"S+": 98, "S": 92, "A": 78, "B": 64, "C": 50}

RE_TFTFLOW_ATTR = re.compile(r'([a-z-]+)="([^"]*)"')
RE_TFTFLOW_NAME = re.compile(r'class="tier-comp-name"[^>]*>(.*?)</div>', re.S)
RE_TFTFLOW_ECON = re.compile(r'class="econ-badge econ-badge--([a-z0-9]+)"')
RE_TFTFLOW_HREF = re.compile(r'<a href="([^"]+)"[^>]*class="comp-bg-link"')
RE_TFTFLOW_HEX = re.compile(r'<g class="hex-container" data-index="(\d+)"(.*?)'
                            r'(?=<g class="hex-container"|\Z)', re.S)
RE_TFTFLOW_CHAMPION = re.compile(r'data-champion-apiname="([^"]+)"')
RE_TFTFLOW_ITEM = re.compile(r'data-item-apiname="([^"]+)"')
RE_TFTFLOW_STAR = re.compile(r'class="star star-(\d)"')


def _tftflow_cards(page):
    cards = []
    chunks = page.split('<div class="comp-card-wrapper"')
    for chunk in chunks[1:]:
        header, _, body = chunk.partition(">")
        attributes = dict(RE_TFTFLOW_ATTR.findall(header))
        comp_id = attributes.get("data-comp-id")
        if not comp_id:
            continue
        name = RE_TFTFLOW_NAME.search(body)
        econ = RE_TFTFLOW_ECON.search(body)
        href = RE_TFTFLOW_HREF.search(body)
        cards.append({
            "id": comp_id,
            "tier": (attributes.get("data-current-base-tier") or "").strip(),
            "maxTier": (attributes.get("data-current-max-tier") or "").strip(),
            "name": clean_source_text(name.group(1)) if name else "",
            "style": playstyle_of(econ.group(1)) if econ else None,
            "url": href.group(1) if href else None,
        })
    return cards


def _tftflow_board(content, catalog):
    start = content.find('<g id="hexagon-grid"')
    if start < 0:
        return []
    end = content.find("</svg>", start)
    board = content[start:end if end > 0 else len(content)]
    units = []
    seen = set()
    for index, body in RE_TFTFLOW_HEX.findall(board):
        champion = RE_TFTFLOW_CHAMPION.search(body)
        if not champion:
            continue
        unit_id = catalog.unit_id(champion.group(1), "tftflow board")
        if not unit_id or unit_id in seen:
            continue
        seen.add(unit_id)
        stars = 3 if "3" in RE_TFTFLOW_STAR.findall(body) else 2
        units.append(unit_record(unit_id, stars, catalog.item_ids(RE_TFTFLOW_ITEM.findall(body)),
                                 board_cell(index)))
    return units


def fetch_tftflow(fetcher, catalog):
    page = fetcher.get_text(URL_TFTFLOW_HTML, headers=BROWSER_HEADERS)
    cards = _tftflow_cards(page)
    if not cards:
        raise ValueError("tftflow tier list had no comp cards")
    posts = fetcher.get_json(URL_TFTFLOW_REST, headers=BROWSER_HEADERS)
    boards = {}
    for post in posts or []:
        link = post.get("link") or ""
        if "/set18/" not in link:
            continue
        content = ((post.get("content") or {}).get("rendered") or "")
        boards[str(post.get("id"))] = (link, content)
        if post.get("slug"):
            boards[post["slug"]] = (link, content)

    comps = []
    seen = set()
    for card in cards:
        if card["id"] in seen:
            continue
        seen.add(card["id"])
        slug = (card["url"] or "").rstrip("/").rsplit("/", 1)[-1]
        link, content = boards.get(card["id"], boards.get(slug, (None, None)))
        if not content:
            continue
        units = _tftflow_board(content, catalog)
        if not units:
            continue
        tier_label = card["tier"] or "C"
        comps.append(source_comp(
            "tftflow", card["id"], card["name"] or slug.replace("-", " ").title(), units,
            url=card["url"] or link,
            tier_label=tier_label,
            tier_score=TFTFLOW_TIER_SCORES.get(tier_label),
            style=card["style"],
        ))
    return comps


# --------------------------------------------------------------------------------------
# tftactics.gg (Blitz-owned) — curated tier list inside the site's JS bundle
# --------------------------------------------------------------------------------------

TFTACTICS_TIER_LABELS = {1: "S", 2: "A", 3: "B", 4: "C"}
RE_TFTACTICS_BUNDLE = re.compile(r"/static/js/main\.[a-f0-9]+\.chunk\.js")


def _js_string_literal(text, start):
    """Read the single-quoted JS string that starts at/after `start`; unescape \\' and \\\\."""
    index = text.index("'", start) + 1
    out = []
    while index < len(text):
        char = text[index]
        if char == "\\":
            following = text[index + 1]
            if following in ("'", "\\"):
                out.append(following if following == "'" else "\\\\")
                index += 2
                continue
            out.append(char)
            out.append(following)
            index += 2
            continue
        if char == "'":
            return "".join(out)
        out.append(char)
        index += 1
    raise ValueError("unterminated JS string")


def fetch_tftactics(fetcher, catalog):
    page = fetcher.get_text(URL_TFTACTICS_HTML, headers=BROWSER_HEADERS)
    match = RE_TFTACTICS_BUNDLE.search(page)
    if not match:
        raise ValueError("tftactics bundle url not found")
    bundle = fetcher.get_text("https://tftactics.gg" + match.group(0), headers=BROWSER_HEADERS)

    entries = []
    for hit in re.finditer(re.escape('JSON.parse(\'[{"name":"'), bundle):
        try:
            payload = json.loads(_js_string_literal(bundle, hit.start()))
        except ValueError:
            continue
        candidates = [comp for comp in payload
                      if isinstance(comp, dict) and 18 in (comp.get("set") or [])
                      and comp.get("characters")]
        if candidates:
            entries = candidates
            break
    if not entries:
        raise ValueError("tftactics comp list not found in the bundle")

    comps = []
    for entry in entries:
        units = []
        seen = set()
        for character in entry.get("characters") or []:
            unit_id = catalog.unit_by_display(character.get("name"))
            if not unit_id or unit_id in seen:
                continue
            seen.add(unit_id)
            position = re.sub(r"[^0-9]", "", character.get("position") or "")
            cell = board_cell(int(position) - 1) if position else None
            units.append(unit_record(unit_id, 2,
                                     catalog.item_ids_by_display(character.get("items")), cell))
        if len(units) < 6:
            continue
        tier = entry.get("tier")
        tier_label = TFTACTICS_TIER_LABELS.get(tier, "C")
        name = clean_source_text(entry.get("name"))
        mid = [stage_record(unit_id) for unit_id
               in [catalog.unit_by_display(value) for value in entry.get("mid") or []] if unit_id]
        comps.append(source_comp(
            "tftactics", name or str(tier), name, units,
            tier_label=tier_label,
            tier_score=LETTER_TIER_SCORES.get(tier_label),
            style=playstyle_of(entry.get("playstyle")),
            main_champion=units[0]["id"] if units else None,
            mid=mid,
            carousel=catalog.item_ids_by_display(
                [row.get("component") for row in entry.get("carrousel") or []],
                limit=6, unique=True),
        ))
    return comps


# --------------------------------------------------------------------------------------
# MetaTFT — the comps the existing pipeline already built
# --------------------------------------------------------------------------------------

def normalise_metatft(comps, catalog):
    """Finished MetaTFT comps (docs/DATA_SCHEMA.md) -> normalised source records."""
    records = []
    for comp in comps:
        units = [unit_record(unit["id"], unit["stars"], list(unit["items"]), unit["cell"])
                 for unit in comp["units"]]
        carries = [unit["id"] for unit in comp["units"] if unit["isCarry"]]
        early_level = sorted(comp["earlyBoards"].keys(), key=int)
        late_level = sorted(comp["levelBoards"].keys(), key=int)
        records.append(source_comp(
            "metatft", comp["id"], comp["name"]["en"], units,
            url="https://www.metatft.com/comps",
            tier_label=comp["tier"],
            tier_score=LETTER_TIER_SCORES.get(comp["tier"]),
            style=comp["playstyle"],
            difficulty=comp["difficulty"],
            main_champion=carries[0] if carries else None,
            early=[stage_record(unit_id) for unit_id
                   in comp["earlyBoards"].get(early_level[-1] if early_level else "", [])],
            mid=[stage_record(unit_id) for unit_id in comp["levelBoards"].get("7", [])],
            mid_level="7" if comp["levelBoards"].get("7") else None,
            late=[stage_record(unit_id) for unit_id
                  in comp["levelBoards"].get(late_level[-1] if late_level else "", [])],
            augments=list(comp["augments"].get("S") or []),
            stats=stats_record(comp["stats"]["avgPlacement"], None, None,
                               comp["stats"]["playRate"], comp["stats"]["games"]),
        ))
    return records


FETCHERS = OrderedDict([
    ("tftacademy", fetch_tftacademy),
    ("blitz", fetch_blitz),
    ("tacticstools", fetch_tacticstools),
    ("tftactics", fetch_tftactics),
    ("tftflow", fetch_tftflow),
])
