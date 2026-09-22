#!/usr/bin/env python3
"""HexKoc (TFT Set 18) data pipeline.

Downloads CommunityDragon + MetaTFT data, normalises it into the schema described in
docs/DATA_SCHEMA.md and writes:

    data/v1/{gamedata,comps,guides,manifest}.json
    Resources/Data/*.json                       (byte-identical copies)
    Resources/Images/{champions,traits,items,augments}/<id>.png

Run `python3 tools/build_data.py --help` for the options. Python 3.9 compatible.
"""

import argparse
import hashlib
import io
import json
import os
import re
import sys
import time
from collections import OrderedDict
from datetime import datetime

import requests
from PIL import Image

import sources as comp_sources

# --------------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------------

SET_KEY = "TFTSet18"
SET_NUMBER = 18
SCHEMA_VERSION = 1

USER_AGENT = "HexKoc-data-pipeline/1.0 (personal TFT companion; contact developer@carinok.com)"
HTTP_TIMEOUT = 60
HTTP_RETRIES = 3
METATFT_SLEEP = 0.25

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(REPO_ROOT, "tools")
CACHE_DIR = os.path.join(TOOLS_DIR, "cache")
RULES_PATH = os.path.join(TOOLS_DIR, "rules.json")
GUIDES_SRC = os.path.join(TOOLS_DIR, "guides.json")
TRANSLATIONS_PATH = os.path.join(TOOLS_DIR, "translations.json")

CDRAGON_GAME = "https://raw.communitydragon.org/latest/game/"
URL_CD_EN = "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json"
URL_CD_TR = "https://raw.communitydragon.org/latest/cdragon/tft/tr_tr.json"
URL_TP = ("https://raw.communitydragon.org/latest/plugins/rcp-be-lol-game-data/global/"
          "default/v1/tftchampions-teamplanner.json")
URL_LK_EN = "https://data.metatft.com/lookups/TFTSet18_latest_en_us.json"
URL_LK_TR = "https://data.metatft.com/lookups/TFTSet18_latest_tr_tr.json"

MT_COMPS_BASE = "https://api-hc.metatft.com/tft-comps-api/"
MT_STAT_BASE = "https://api-hc.metatft.com/tft-stat-api/"
MT_STAT_FILTER = ("queue=1100&patch=current&days=3&rank=PLATINUM,EMERALD,DIAMOND,MASTER,"
                  "GRANDMASTER,CHALLENGER&permit_filter_adjustment=true")
MT_AUG_CDN = "https://cdn.metatft.com/file/metatft/augments/"

IMAGE_MAX_PX = 256
MIN_CLUSTER_GAMES = 500
LOW_SAMPLE_GAMES = 1500
TIER_BUCKETS = (("S", 6), ("A", 10), ("B", 14))

MIN_CHAMPIONS = 60
MIN_COMPS = 40

# CDragon trait effect style -> schema style
TRAIT_STYLE = {1: "bronze", 3: "silver", 4: "unique", 5: "gold", 6: "prismatic"}
TRAIT_TYPE_RANK = {"origin": 0, "class": 1, "unique": 2}
# Mechanic traits with no champions of their own (Eclipse activates from 3 Solar + 3 Lunar),
# so they never reach the "one champion, one breakpoint" rule below.
FORCED_UNIQUE_TRAITS = ("DA_18_Eclipse",)
ITEM_KIND_RANK = {"component": 0, "craftable": 1, "emblem": 2, "artifact": 3, "radiant": 4}
RARITY_RANK = {"silver": 0, "gold": 1, "prismatic": 2, "unknown": 3}

SCALE_TOKENS = {
    "en": {"scaleap": "(AP)", "scalead": "(AD)", "scalehealth": "(HP)",
           "scalearmor": "(Armor)", "scalemr": "(MR)", "scaleas": "(AS)"},
    "tr": {"scaleap": "(YG)", "scalead": "(SG)", "scalehealth": "(Can)",
           "scalearmor": "(Zırh)", "scalemr": "(BD)", "scaleas": "(SH)"},
}

WARNINGS = []
UNRESOLVED_TOKENS = []
UNKNOWN_UNITS = set()


def warn(message):
    WARNINGS.append(message)
    print("WARN: " + message)


def log(message):
    print(message)


# --------------------------------------------------------------------------------------
# Fetch layer
# --------------------------------------------------------------------------------------

class Fetcher(object):
    """Cached HTTP GET with retries. Every body lands in tools/cache/<sha1(url)>.<ext>."""

    def __init__(self, cache_dir=CACHE_DIR, use_cache=True):
        self.cache_dir = cache_dir
        self.use_cache = use_cache
        self.session = requests.Session()
        self.session.headers["User-Agent"] = USER_AGENT
        self.downloads = 0
        if not os.path.isdir(self.cache_dir):
            os.makedirs(self.cache_dir)

    def _cache_path(self, url, ext):
        return os.path.join(self.cache_dir, hashlib.sha1(url.encode("utf-8")).hexdigest() + ext)

    def _request(self, url, headers=None):
        last_error = None
        for attempt in range(HTTP_RETRIES):
            try:
                response = self.session.get(url, timeout=HTTP_TIMEOUT, headers=headers)
                if response.status_code == 200:
                    self.downloads += 1
                    if "metatft.com" in url:
                        time.sleep(METATFT_SLEEP)
                    return response
                last_error = "HTTP %d" % response.status_code
                if response.status_code == 404:
                    break
            except requests.RequestException as exc:  # pragma: no cover - network dependent
                last_error = str(exc)
            time.sleep(1.5 * (attempt + 1))
        raise IOError("GET failed (%s): %s" % (last_error, url))

    def get_json(self, url, headers=None):
        path = self._cache_path(url, ".json")
        if self.use_cache and os.path.exists(path):
            with open(path, "r", encoding="utf-8") as handle:
                return json.load(handle)
        data = self._request(url, headers).json()
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False)
        return data

    def get_text(self, url, headers=None):
        path = self._cache_path(url, ".txt")
        if self.use_cache and os.path.exists(path):
            with open(path, "r", encoding="utf-8") as handle:
                return handle.read()
        response = self._request(url, headers)
        response.encoding = response.encoding or "utf-8"
        text = response.text
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        return text

    def get_binary(self, url, ext=".png"):
        path = self._cache_path(url, ext)
        if self.use_cache and os.path.exists(path):
            with open(path, "rb") as handle:
                return handle.read()
        payload = self._request(url).content
        with open(path, "wb") as handle:
            handle.write(payload)
        return payload


def asset_url(asset_path):
    """CDragon game asset path -> raw.communitydragon.org PNG url."""
    if not asset_path:
        return None
    path = asset_path.lower().lstrip("/")
    path = re.sub(r"\.(tex|dds)$", ".png", path)
    if not path.endswith(".png"):
        path += ".png"
    return CDRAGON_GAME + path


# --------------------------------------------------------------------------------------
# Text cleaning
# --------------------------------------------------------------------------------------

RE_BR = re.compile(r"<br\s*/?>", re.I)
RE_CURVE_TAG = re.compile(r"<TFTCurveTable\b([^<>]*?)/?>", re.I)
RE_ATTR_TAG = re.compile(r"<TFTAttribute\b([^<>]*?)/?>", re.I)
RE_TAG_ATTRS = re.compile(r'([A-Za-z_]+)\s*=\s*"([^"]*)"')
RE_ANY_TAG = re.compile(r"<[^<>]*>")
RE_AT_TOKEN = re.compile(r"@([^@\n]{1,90}?)@")
RE_SCALE = re.compile(r"%i:([A-Za-z0-9_]+)%")
RE_FORMAT_HINT = re.compile(r'row\s*=\s*"([^"]+)"[^<>]*?format\s*=\s*"([^"]+)"', re.I)
RE_MULTIPLIER = re.compile(r"^(.*?)\s*\*\s*([0-9]+(?:\.[0-9]+)?)$")


class TokenContext(object):
    """Everything needed to resolve a single owner's description tokens."""

    def __init__(self, curve_table=None, attribute_values=None, variables=None, formats=None,
                 column=None):
        self.curve_table = curve_table or {}
        self.attribute_values = attribute_values or {}
        self.variables = variables or {}
        self.formats = formats or {}
        self.column = column

    def with_variables(self, variables, column=None):
        merged = dict(self.variables)
        merged.update(variables or {})
        return TokenContext(self.curve_table, self.attribute_values, merged, self.formats,
                            self.column if column is None else column)


def format_hints(*texts):
    """row -> format map harvested from MetaTFT-flavoured strings."""
    hints = {}
    for text in texts:
        if not text:
            continue
        if isinstance(text, (list, tuple)):
            hints.update(format_hints(*text))
            continue
        for row, fmt in RE_FORMAT_HINT.findall(text):
            hints.setdefault(row, fmt)
    return hints


def format_number(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if abs(number - round(number)) < 1e-6:
        return str(int(round(number)))
    return ("%.2f" % number).rstrip("0").rstrip(".")


def percent_text(number, lang):
    """Turkish writes the sign in front of the number (%21), English behind it (21%)."""
    text = format_number(round(number))
    if text is None:
        return None
    return ("%" + text) if lang == "tr" else (text + "%")


def apply_format(value, fmt, lang="en"):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    fmt = (fmt or "").lower()
    if fmt == "percent":
        return percent_text(number * 100, lang)
    if fmt == "percentminusone":
        return percent_text((number - 1) * 100, lang)
    if fmt == "invertedpercent":
        return percent_text((1 - number) * 100, lang)
    return format_number(number)


def join_values(values, fmt, lang="en"):
    """Format 1..3 values, collapsing them when they are all equal."""
    rendered = []
    for value in values:
        text = apply_format(value, fmt, lang)
        if text is None:
            return None
        rendered.append(text)
    if not rendered:
        return None
    if len(set(rendered)) == 1:
        return rendered[0]
    return " / ".join(rendered)


def curve_points(pairs):
    """curveTable row -> sorted [(key, value)]. Keys are star levels / trait tiers."""
    points = []
    for pair in pairs or []:
        if isinstance(pair, (list, tuple)) and len(pair) >= 2:
            try:
                points.append((float(pair[0]), float(pair[1])))
            except (TypeError, ValueError):
                continue
        elif isinstance(pair, (int, float)):
            points.append((float(len(points)), float(pair)))
    return sorted(points)


def curve_value_at(points, key):
    """Riot curve tables interpolate linearly between their keys."""
    if not points:
        return None
    if key <= points[0][0]:
        return points[0][1]
    if key >= points[-1][0]:
        return points[-1][1]
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        if x0 <= key <= x1:
            if x1 == x0:
                return y1
            return y0 + (y1 - y0) * (key - x0) / (x1 - x0)
    return points[-1][1]


def curve_values(pairs, column=None):
    """Values to render for a curveTable row: one per column, else star 1-3."""
    points = curve_points(pairs)
    if not points:
        return None
    if column is not None:
        return [curve_value_at(points, column)]
    if points[-1][0] <= 1:
        return [points[-1][1]]
    return [curve_value_at(points, star) for star in (1, 2, 3)]


def attribute_values_for(values):
    if isinstance(values, list) and values:
        return values[:3]
    if isinstance(values, (int, float)):
        return [values]
    return None


def lookup_token(name, ctx):
    """Resolve a bare token name -> (values, format hint) or (None, None)."""
    if not name:
        return None, None
    candidates = [name]
    if name.startswith("TFTCalculationAttributes."):
        candidates.append(name.split(".", 1)[1])
    else:
        candidates.append("TFTCalculationAttributes." + name)

    for key in candidates:
        if key in ctx.variables:
            # CDragon variables are already written for the CDragon sentence around them,
            # so a MetaTFT format hint must not be applied on top of them.
            raw = ctx.variables[key]
            if isinstance(raw, list):
                values = raw[1:4] if len(raw) >= 4 else raw[:3]
            else:
                values = [raw]
            return values, None
    for key in candidates:
        if key in ctx.attribute_values:
            values = attribute_values_for(ctx.attribute_values[key])
            if values:
                return values, ctx.formats.get(key)
    for key in candidates:
        if key in ctx.curve_table:
            values = curve_values(ctx.curve_table[key], ctx.column)
            if values:
                return values, ctx.formats.get(key)
    return None, None


def _replace_curve_tag(match, ctx, lang="en"):
    attrs = dict((key.lower(), value) for key, value in RE_TAG_ATTRS.findall(match.group(1)))
    row = attrs.get("row")
    if not row:
        return ""
    column = ctx.column
    if attrs.get("column"):
        try:
            column = int(float(attrs["column"]))
        except ValueError:
            column = ctx.column
    pairs = ctx.curve_table.get(row)
    if pairs is None:
        UNRESOLVED_TOKENS.append(row)
        return ""
    values = curve_values(pairs, column)
    if not values:
        UNRESOLVED_TOKENS.append(row)
        return ""
    text = join_values(values, attrs.get("format") or ctx.formats.get(row), lang)
    if text is None:
        UNRESOLVED_TOKENS.append(row)
        return ""
    return text


def _replace_attr_tag(match, ctx, lang="en"):
    attrs = dict((key.lower(), value) for key, value in RE_TAG_ATTRS.findall(match.group(1)))
    attr_id = attrs.get("attributeid")
    if not attr_id:
        return ""
    values, fmt = lookup_token(attr_id, ctx)
    if not values:
        UNRESOLVED_TOKENS.append(attr_id)
        return ""
    text = join_values(values, attrs.get("format") or fmt, lang)
    return text if text is not None else ""


def _replace_at_token(match, ctx, lang="en"):
    raw = match.group(1).strip()
    multiplier = None
    base = raw
    mult_match = RE_MULTIPLIER.match(raw)
    if mult_match:
        base = mult_match.group(1).strip()
        multiplier = float(mult_match.group(2))
    values, fmt = lookup_token(base, ctx)
    if values is None:
        UNRESOLVED_TOKENS.append(base)
        return ""
    if multiplier is not None:
        # CDragon already spells the % sign out, so a scaled token renders as a bare number.
        # The lookup format still tells us how the raw value relates to that number.
        hint = (fmt or "").lower()
        scaled = []
        for value in values:
            try:
                number = float(value)
            except (TypeError, ValueError):
                UNRESOLVED_TOKENS.append(base)
                return ""
            if hint == "percentminusone":
                number -= 1
            elif hint == "invertedpercent":
                number = 1 - number
            scaled.append(number * multiplier)
        text = join_values(scaled, None, lang)
    else:
        text = join_values(values, fmt, lang)
    if text is None:
        UNRESOLVED_TOKENS.append(base)
        return ""
    return text


def clean_text(text, ctx=None, lang="en"):
    """Turn a raw CDragon/MetaTFT description into plain display text."""
    if not text:
        return ""
    ctx = ctx or TokenContext()
    result = text
    result = RE_CURVE_TAG.sub(lambda m: _replace_curve_tag(m, ctx, lang), result)
    result = RE_ATTR_TAG.sub(lambda m: _replace_attr_tag(m, ctx, lang), result)
    result = RE_BR.sub("\n", result)
    result = result.replace("&nbsp;", " ").replace(" ", " ")
    result = RE_ANY_TAG.sub("", result)
    result = RE_AT_TOKEN.sub(lambda m: _replace_at_token(m, ctx, lang), result)
    scale_map = SCALE_TOKENS.get(lang, SCALE_TOKENS["en"])
    result = RE_SCALE.sub(lambda m: scale_map.get(m.group(1).lower(), ""), result)
    # Anything that survived the passes above must not reach the app.
    if "<" in result or ">" in result:
        result = re.sub(r"<[^>]*>?", "", result).replace(">", "")
    if "@" in result:
        result = RE_AT_TOKEN.sub("", result).replace("@", "")
    result = re.sub(r"%i:[^%]*%?", "", result)
    result = result.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\r", "\n")
    result = result.replace("\r\n", "\n").replace("\r", "\n")
    result = re.sub(r"[ \t]{2,}", " ", result)
    result = re.sub(r" +([,.;:!?])", r"\1", result)
    result = re.sub(r"\(\s*\)", "", result)
    result = "\n".join(line.strip() for line in result.split("\n"))
    result = re.sub(r"\n{3,}", "\n\n", result)
    return result.strip()


RE_ROW = re.compile(r"<row>(.*?)</row>", re.S | re.I)


def split_rows(desc):
    """Trait description -> (main text, [row texts])."""
    if not desc:
        return "", []
    rows = RE_ROW.findall(desc)
    main = RE_ROW.sub("", desc)
    main = re.sub(r"(<br\s*/?>\s*)+$", "", main, flags=re.I)
    return main, rows


def localized(en_text, tr_text):
    """{"en":…, "tr":…} with cross-language fallback (never empty when one side exists)."""
    en_text = en_text or ""
    tr_text = tr_text or ""
    if not en_text:
        en_text = tr_text
    if not tr_text:
        tr_text = en_text
    return OrderedDict([("en", en_text), ("tr", tr_text)])


# --------------------------------------------------------------------------------------
# Team codes
# --------------------------------------------------------------------------------------

EMPTY_SLOT = "000"
TEAM_CODE_PREFIX = "02"
TEAM_CODE_SLOTS = 10


def champion_team_code(team_planner_code):
    return format(int(team_planner_code), "03x")


def encode_team_code(codes):
    slots = list(codes)[:TEAM_CODE_SLOTS]
    slots += [EMPTY_SLOT] * (TEAM_CODE_SLOTS - len(slots))
    return TEAM_CODE_PREFIX + "".join(slots) + SET_KEY


def decode_team_code(code, code_to_id=None):
    """Team planner code -> list of 3-hex slots (or champion ids when a map is given)."""
    if not code or not code.startswith(TEAM_CODE_PREFIX) or not code.endswith(SET_KEY):
        raise ValueError("malformed team code: %r" % code)
    body = code[len(TEAM_CODE_PREFIX):-len(SET_KEY)]
    if len(body) != TEAM_CODE_SLOTS * 3:
        raise ValueError("team code has %d slot chars, expected %d" % (len(body), TEAM_CODE_SLOTS * 3))
    slots = [body[i:i + 3] for i in range(0, len(body), 3)]
    slots = [slot for slot in slots if slot != EMPTY_SLOT]
    for slot in slots:
        int(slot, 16)  # raises ValueError when not hex
    if code_to_id is None:
        return slots
    return [code_to_id[slot] for slot in slots]


# --------------------------------------------------------------------------------------
# Source loading
# --------------------------------------------------------------------------------------

def load_sources(fetcher, with_comps=True):
    sources = {}
    log("Fetching CommunityDragon en_us.json …")
    sources["cd_en"] = fetcher.get_json(URL_CD_EN)
    log("Fetching CommunityDragon tr_tr.json …")
    sources["cd_tr"] = fetcher.get_json(URL_CD_TR)
    log("Fetching team planner codes …")
    sources["tp"] = fetcher.get_json(URL_TP)
    log("Fetching MetaTFT lookup (en) …")
    sources["lk_en"] = fetcher.get_json(URL_LK_EN)
    try:
        log("Fetching MetaTFT lookup (tr) …")
        sources["lk_tr"] = fetcher.get_json(URL_LK_TR)
    except (IOError, ValueError) as exc:
        warn("Turkish MetaTFT lookup unavailable (%s); Turkish item texts fall back to English" % exc)
        sources["lk_tr"] = {}

    try:
        sources["aug_tiers"] = fetcher.get_json(MT_STAT_BASE + "augments_tiers?" + MT_STAT_FILTER)
    except (IOError, ValueError) as exc:
        warn("augment tier list unavailable (%s); metaTier will be null" % exc)
        sources["aug_tiers"] = {}
    try:
        sources["unit_stats"] = fetcher.get_json(MT_STAT_BASE + "units?" + MT_STAT_FILTER)
    except (IOError, ValueError) as exc:
        warn("unit stat list unavailable (%s); avgPlacement/popularity will be null" % exc)
        sources["unit_stats"] = {}

    if with_comps:
        log("Fetching MetaTFT comps …")
        sources["comps"] = fetcher.get_json(MT_COMPS_BASE + "comps_data")
    return sources


def set_name(sources, cd_set):
    """CDragon still labels Set 18 "Set10"; the MetaTFT lookup has the real name."""
    lookup_name = ((sources.get("lk_en") or {}).get("_metadata") or {}).get("setName")
    if lookup_name:
        return lookup_name
    name = cd_set.get("name") or ""
    if not name or re.match(r"^Set\d+$", name):
        return "Enchanted Wilds"
    return name


def set_data(cdragon):
    for entry in cdragon.get("setData") or []:
        if entry.get("mutator") == SET_KEY:
            return entry
    raise SystemExit("FATAL: set %s not found in CommunityDragon data" % SET_KEY)


def index_by(records, key="apiName"):
    return dict((record[key], record) for record in records or [] if record.get(key))


# --------------------------------------------------------------------------------------
# Champions
# --------------------------------------------------------------------------------------

def unit_alias_index(lookup):
    """Every MetaTFT assetName -> its lookup unit record."""
    index = {}
    for unit in lookup.get("units") or []:
        for asset in unit.get("assetNames") or []:
            index[asset] = unit
    return index


def champion_stats(cd_champion):
    stats = cd_champion.get("stats") or {}

    def number(key, default=0):
        value = stats.get(key, default)
        try:
            value = float(value)
        except (TypeError, ValueError):
            return default
        return int(value) if abs(value - round(value)) < 1e-6 else round(value, 3)

    return OrderedDict([
        ("hp", number("hp")),
        ("armor", number("armor")),
        ("mr", number("magicResist")),
        ("ad", number("damage")),
        ("attackSpeed", round(float(stats.get("attackSpeed") or 0), 2)),
        ("range", number("range")),
        ("startMana", number("initialMana")),
        ("maxMana", number("mana")),
    ])


def unit_placement_stats(unit_stats_payload):
    """MetaTFT unit stats -> {unitId: (avgPlacement, popularity)}."""
    results = (unit_stats_payload or {}).get("results") or []
    totals = {}
    averages = {}
    for entry in results:
        unit = entry.get("unit")
        places = entry.get("places") or []
        total = sum(places)
        if not unit or total <= 0:
            continue
        weighted = sum((index + 1) * count for index, count in enumerate(places))
        averages[unit] = round(weighted / float(total), 3)
        totals[unit] = total
    peak = max(totals.values()) if totals else 0
    stats = {}
    for unit, total in totals.items():
        popularity = round(total / float(peak), 4) if peak else None
        stats[unit] = (averages.get(unit), popularity)
    return stats


def build_champions(sources, trait_name_to_id, recommended_items, item_ids):
    cd_set_en = set_data(sources["cd_en"])
    cd_set_tr = set_data(sources["cd_tr"])
    cd_champ_en = index_by(cd_set_en.get("champions"))
    cd_champ_tr = index_by(cd_set_tr.get("champions"))
    lookup_units = unit_alias_index(sources["lk_en"])
    placement = unit_placement_stats(sources.get("unit_stats"))
    canonical_ids = set(entry.get("character_id") for entry in (sources["tp"].get(SET_KEY) or []))

    champions = []
    for entry in (sources["tp"].get(SET_KEY) or []):
        champion_id = entry.get("character_id")
        if not champion_id:
            continue
        cd_en = cd_champ_en.get(champion_id)
        if cd_en is None:
            warn("champion %s missing from CommunityDragon; skipped" % champion_id)
            continue
        cd_tr = cd_champ_tr.get(champion_id) or {}
        unit = lookup_units.get(champion_id) or {}

        team_code = champion_team_code(entry.get("team_planner_code", 0))
        lookup_code = unit.get("code")
        if lookup_code and str(lookup_code) != team_code:
            warn("team code mismatch for %s (planner %s vs lookup %s)"
                 % (champion_id, team_code, lookup_code))

        aliases = []
        for alias in (unit.get("assetNames") or []) + [unit.get("apiName"), unit.get("characterName")]:
            if alias and alias != champion_id and alias not in canonical_ids and alias not in aliases:
                aliases.append(alias)

        trait_ids = []
        for trait_id in unit.get("traitApiNames") or []:
            if trait_id not in trait_ids:
                trait_ids.append(trait_id)
        if not trait_ids:
            for trait in entry.get("traits") or []:
                if trait.get("id") and trait["id"] not in trait_ids:
                    trait_ids.append(trait["id"])
        if not trait_ids:
            for name in cd_en.get("traits") or []:
                trait_id = trait_name_to_id.get(name)
                if trait_id and trait_id not in trait_ids:
                    trait_ids.append(trait_id)

        ability_en = cd_en.get("ability") or {}
        ability_tr = cd_tr.get("ability") or {}
        lookup_ability = unit.get("ability") or {}
        variables = {}
        for variable in ability_en.get("variables") or []:
            if variable.get("name") is not None:
                variables[variable["name"]] = variable.get("value")
        hints = format_hints(lookup_ability.get("desc"),
                             [row.get("desc") for row in lookup_ability.get("footer") or []])
        ctx = TokenContext(curve_table=unit.get("curveTable"),
                           attribute_values=lookup_ability.get("attributeValues"),
                           variables=variables, formats=hints)

        desc_en = clean_text(ability_en.get("desc"), ctx, "en")
        if not desc_en:
            desc_en = clean_text(lookup_ability.get("desc"), ctx, "en")
        desc_tr = clean_text(ability_tr.get("desc"), ctx, "tr")

        role = unit.get("role") or ""
        role = role[len("DA_Role_"):] if role.startswith("DA_Role_") else (role or None)

        avg_placement, popularity = placement.get(champion_id, (None, None))
        if avg_placement is None:
            for alias in aliases:
                if alias in placement:
                    avg_placement, popularity = placement[alias]
                    break

        recommended = [item for item in recommended_items.get(champion_id, []) if item in item_ids]

        champions.append(OrderedDict([
            ("id", champion_id),
            ("aliases", sorted(aliases)),
            ("name", localized(entry.get("display_name") or cd_en.get("name"), cd_tr.get("name"))),
            ("cost", int(entry.get("tier") or cd_en.get("cost") or 1)),
            ("traits", trait_ids),
            ("role", role),
            ("stats", champion_stats(cd_en)),
            ("ability", OrderedDict([
                ("name", localized(ability_en.get("name"), ability_tr.get("name"))),
                ("desc", localized(desc_en, desc_tr)),
            ])),
            ("icon", "champions/%s.png" % champion_id),
            ("iconURL", asset_url(cd_en.get("tileIcon"))),
            ("splashURL", asset_url(cd_en.get("squareIcon"))),
            ("teamCode", team_code),
            ("poolCount", int(unit.get("poolCount") or 0)),
            ("recommendedItems", recommended[:6]),
            ("avgPlacement", avg_placement),
            ("popularity", popularity),
        ]))

    champions.sort(key=lambda champion: (champion["cost"], champion["name"]["en"]))
    return champions


def build_recommended_items(fetcher, first_comp_key, cluster_id, alias_to_id):
    """Global per-unit item picks from MetaTFT (one call, cheapest useful source)."""
    if first_comp_key is None:
        return {}
    url = "%sunit_items_processed?comp=%s&cluster_id=%s" % (MT_COMPS_BASE, first_comp_key, cluster_id)
    try:
        payload = fetcher.get_json(url)
    except (IOError, ValueError) as exc:
        warn("unit_items_processed unavailable (%s); recommendedItems will be empty" % exc)
        return {}
    units = payload.get("units") or {}
    recommended = {}
    for unit_id, record in units.items():
        canonical = alias_to_id.get(unit_id, unit_id)
        items = []
        for item in record.get("items") or []:
            name = item.get("itemName")
            if name and name not in items:
                items.append(name)
        if items:
            recommended[canonical] = items[:6]
    return recommended


# --------------------------------------------------------------------------------------
# Traits
# --------------------------------------------------------------------------------------

def build_traits(sources, champions):
    cd_set_en = set_data(sources["cd_en"])
    cd_set_tr = set_data(sources["cd_tr"])
    cd_traits_tr = index_by(cd_set_tr.get("traits"))
    lookup_traits = index_by(sources["lk_en"].get("traits"))
    lookup_traits_tr = index_by((sources.get("lk_tr") or {}).get("traits"))

    champions_by_trait = {}
    for champion in champions:
        for trait_id in champion["traits"]:
            champions_by_trait.setdefault(trait_id, []).append(champion)

    traits = []
    for cd_trait in cd_set_en.get("traits") or []:
        trait_id = cd_trait.get("apiName")
        if not trait_id:
            continue
        cd_tr = cd_traits_tr.get(trait_id) or {}
        lookup = lookup_traits.get(trait_id) or {}
        lookup_tr = lookup_traits_tr.get(trait_id) or {}

        effects = cd_trait.get("effects") or lookup.get("effects") or []
        hints = format_hints(lookup.get("desc"), [effect.get("desc") for effect in lookup.get("effects") or []])
        base_ctx = TokenContext(curve_table=lookup.get("curveTable"), formats=hints)

        main_en, rows_en = split_rows(cd_trait.get("desc"))
        main_tr, rows_tr = split_rows(cd_tr.get("desc"))
        first_vars = (effects[0].get("variables") if effects else {}) or {}
        desc_ctx = base_ctx.with_variables(first_vars)
        desc_en = clean_text(main_en, desc_ctx, "en") or clean_text(lookup.get("desc"), base_ctx, "en")
        desc_tr = clean_text(main_tr, desc_ctx, "tr") or clean_text(lookup_tr.get("desc"), base_ctx, "tr")

        members = champions_by_trait.get(trait_id, [])
        trait_type = lookup.get("type")
        if trait_type not in TRAIT_TYPE_RANK:
            trait_type = "origin"
        if len(members) == 1 and len(effects) == 1 and int(effects[0].get("minUnits") or 1) <= 1:
            trait_type = "unique"
        if trait_id in FORCED_UNIQUE_TRAITS:
            trait_type = "unique"

        breakpoints = []
        for index, effect in enumerate(effects):
            minimum = int(effect.get("minUnits") or 0) or 1
            maximum = int(effect.get("maxUnits") or 0) or minimum
            variables = dict(effect.get("variables") or {})
            variables["MinUnits"] = minimum
            variables["MaxUnits"] = maximum
            ctx = base_ctx.with_variables(variables, column=index + 1)
            row_en = rows_en[index] if index < len(rows_en) else None
            row_tr = rows_tr[index] if index < len(rows_tr) else None
            lookup_effects = lookup.get("effects") or []
            lookup_effects_tr = lookup_tr.get("effects") or []
            if not row_en and index < len(lookup_effects):
                row_en = lookup_effects[index].get("desc")
            if not row_tr and index < len(lookup_effects_tr):
                row_tr = lookup_effects_tr[index].get("desc")
            text_en = clean_text(row_en, ctx, "en") or desc_en
            text_tr = clean_text(row_tr, ctx, "tr") or desc_tr
            style = "unique" if trait_type == "unique" else TRAIT_STYLE.get(effect.get("style"), "bronze")
            breakpoints.append(OrderedDict([
                ("min", minimum),
                ("max", maximum),
                ("style", style),
                ("desc", localized(text_en, text_tr)),
            ]))
        breakpoints.sort(key=lambda item: item["min"])
        if not breakpoints:
            warn("trait %s has no breakpoints" % trait_id)

        members_sorted = sorted(members, key=lambda champion: (champion["cost"], champion["name"]["en"]))
        traits.append(OrderedDict([
            ("id", trait_id),
            ("name", localized(cd_trait.get("name"), cd_tr.get("name"))),
            ("type", trait_type),
            ("desc", localized(desc_en, desc_tr)),
            ("breakpoints", breakpoints),
            ("icon", "traits/%s.png" % trait_id),
            ("iconURL", asset_url(cd_trait.get("icon"))),
            ("champions", [champion["id"] for champion in members_sorted]),
        ]))

    traits.sort(key=lambda trait: (TRAIT_TYPE_RANK.get(trait["type"], 9), trait["name"]["en"]))
    return traits


# --------------------------------------------------------------------------------------
# Items
# --------------------------------------------------------------------------------------

def item_kind(record):
    api_name = record.get("apiName") or ""
    name = record.get("name") or ""
    composition = record.get("composition") or []
    if api_name.startswith("DA_Component_"):
        return "component"
    if name.endswith("Emblem"):
        return "emblem"
    if api_name.startswith("DA_Artifact_"):
        return "artifact"
    if "Radiant" in api_name and not api_name.startswith("DA_18_Radiantize"):
        return "radiant"
    if len(composition) == 2:
        return "craftable"
    return None


def stat_key(row):
    key = row
    if key.startswith("Base_"):
        key = key[len("Base_"):]
    elif key.startswith("Base") and len(key) > 4 and key[4].isupper():
        key = key[4:]
    elif key.endswith("Base") and len(key) > 4:
        key = key[:-4]
    return key or row


def item_stats(cd_record, lookup_record):
    """Readable stat map: CDragon effects first, MetaTFT statLine as the fallback."""
    stats = OrderedDict()
    for key, value in sorted((cd_record.get("effects") or {}).items()):
        if key.startswith("{"):
            continue
        number = format_number(value)
        if number is None:
            continue
        stats[key] = float(number) if "." in number else int(number)
    if stats:
        return stats
    curve_table = (lookup_record or {}).get("curveTable") or {}
    for raw_attrs in RE_CURVE_TAG.findall((lookup_record or {}).get("statLine") or ""):
        attrs = dict((key.lower(), value) for key, value in RE_TAG_ATTRS.findall(raw_attrs))
        row = attrs.get("row")
        if not row or row.startswith("{"):
            continue
        values = curve_values(curve_table.get(row))
        if not values:
            continue
        text = apply_format(values[0], attrs.get("format"))
        if text is None:
            continue
        number = format_number(text.rstrip("%"))
        if number is None:
            continue
        stats[stat_key(row)] = float(number) if "." in number else int(number)
    return stats


def build_items(sources, trait_name_to_id):
    cd_items_en = index_by(sources["cd_en"].get("items"))
    cd_items_tr = index_by(sources["cd_tr"].get("items"))
    lookup_items = index_by(sources["lk_en"].get("items"))
    lookup_items_tr = index_by((sources.get("lk_tr") or {}).get("items"))

    items = []
    for api_name, record in cd_items_en.items():
        if not api_name.startswith("DA_") or record.get("isAugment"):
            continue
        kind = item_kind(record)
        if kind is None:
            continue
        cd_tr = cd_items_tr.get(api_name) or {}
        lookup = lookup_items.get(api_name) or {}
        lookup_tr = lookup_items_tr.get(api_name) or {}

        hints = format_hints(lookup.get("desc"), lookup.get("statLine"))
        ctx = TokenContext(curve_table=lookup.get("curveTable"),
                           variables=record.get("effects") or {}, formats=hints)
        desc_en = clean_text(record.get("desc"), ctx, "en") or clean_text(lookup.get("desc"), ctx, "en")
        ctx_tr = TokenContext(curve_table=lookup.get("curveTable"),
                              variables=cd_tr.get("effects") or record.get("effects") or {},
                              formats=hints)
        desc_tr = clean_text(cd_tr.get("desc"), ctx_tr, "tr") or clean_text(lookup_tr.get("desc"), ctx_tr, "tr")

        composition = record.get("composition") or []
        recipe = list(composition) if len(composition) == 2 else None

        trait_id = None
        if kind == "emblem":
            trait_name = (record.get("name") or "")[: -len(" Emblem")].strip()
            trait_id = trait_name_to_id.get(trait_name)
            for associated in record.get("associatedTraits") or lookup.get("associatedTraits") or []:
                if associated and associated.startswith("DA_"):
                    trait_id = trait_id or associated
            if trait_id is None and len(composition) == 2:
                warn("emblem %s (%s) has no matching trait" % (api_name, record.get("name")))

        items.append(OrderedDict([
            ("id", api_name),
            ("name", localized(record.get("name"), cd_tr.get("name") or lookup_tr.get("name"))),
            ("desc", localized(desc_en, desc_tr)),
            ("kind", kind),
            ("recipe", recipe),
            ("icon", "items/%s.png" % api_name),
            ("iconURL", asset_url(record.get("icon"))),
            ("unique", bool(record.get("unique"))),
            ("stats", item_stats(record, lookup)),
            ("traitId", trait_id),
        ]))

    items.sort(key=lambda item: (ITEM_KIND_RANK.get(item["kind"], 9), item["name"]["en"]))
    return items


# --------------------------------------------------------------------------------------
# Augments
# --------------------------------------------------------------------------------------

AUGMENT_CATEGORY = {
    "augment.category.combat": "combat",
    "augment.category.economic": "economy",
    "augment.category.trait": "trait",
    "augment.category.grantsemblem": "trait",
}
# Set 18 data carries no Augment.Category.Combat tag; MetaTFT's hand tags fill the gap.
AUGMENT_MANUAL_CATEGORY = {"combat": "combat", "econ": "economy", "trait": "trait"}


def augment_tier_map(payload):
    tiers = {}
    content = ((payload or {}).get("content") or {}).get("content") or {}
    for bucket in content.get("tierList") or []:
        label = bucket.get("label")
        if not label:
            continue
        for entry in bucket.get("content") or []:
            if entry.get("id"):
                tiers[entry["id"]] = label
    return tiers


def build_augments(sources, trait_name_to_id, trait_ids):
    cd_set_en = set_data(sources["cd_en"])
    cd_items_en = index_by(sources["cd_en"].get("items"))
    cd_items_tr = index_by(sources["cd_tr"].get("items"))
    lookup_augments = index_by(sources["lk_en"].get("augments"))
    lookup_augments_tr = index_by((sources.get("lk_tr") or {}).get("augments"))
    tiers = augment_tier_map(sources.get("aug_tiers"))

    augments = []
    for api_name in cd_set_en.get("augments") or []:
        if not isinstance(api_name, str) or not api_name.startswith("DA_"):
            continue
        record = cd_items_en.get(api_name)
        lookup = lookup_augments.get(api_name) or {}
        if record is None and not lookup:
            warn("augment %s has no CDragon/MetaTFT record; skipped" % api_name)
            continue
        record = record or {}
        cd_tr = cd_items_tr.get(api_name) or {}
        lookup_tr = lookup_augments_tr.get(api_name) or {}

        hints = format_hints(lookup.get("desc"))
        ctx = TokenContext(curve_table=lookup.get("curveTable"),
                           variables=record.get("effects") or lookup.get("effects") or {},
                           formats=hints)
        desc_en = clean_text(record.get("desc"), ctx, "en") or clean_text(lookup.get("desc"), ctx, "en")
        ctx_tr = TokenContext(curve_table=lookup.get("curveTable"),
                              variables=cd_tr.get("effects") or record.get("effects") or {},
                              formats=hints)
        desc_tr = clean_text(cd_tr.get("desc"), ctx_tr, "tr") or clean_text(lookup_tr.get("desc"), ctx_tr, "tr")

        rarity = (lookup.get("rarity") or "").lower()
        if rarity not in ("silver", "gold", "prismatic"):
            rarity = "unknown"

        category = None
        tags = [tag.lower() for tag in (lookup.get("tags") or [])]
        manual = [tag.lower() for tag in (lookup.get("manual_tags") or [])]
        for tag in tags:
            if tag in AUGMENT_CATEGORY:
                category = AUGMENT_CATEGORY[tag]
                break
        if category is None:
            for key in ("combat", "econ", "trait"):
                if key in manual:
                    category = AUGMENT_MANUAL_CATEGORY[key]
                    break
        if category is None:
            category = "utility" if (tags or manual) else "unknown"

        icon_url = asset_url(record.get("icon"))
        if not icon_url or "missing" in (record.get("icon") or "").lower():
            lookup_icon = (lookup.get("icon") or "").lower()
            icon_url = MT_AUG_CDN + lookup_icon + ".png" if lookup_icon else None

        trait_id = None
        for associated in lookup.get("associatedTraits") or record.get("associatedTraits") or []:
            if associated in trait_ids:
                trait_id = associated
                break
        if trait_id is None:
            name_en = record.get("name") or lookup.get("name") or ""
            for trait_name, candidate in trait_name_to_id.items():
                if trait_name and re.search(r"\b%s\b" % re.escape(trait_name), name_en):
                    trait_id = candidate
                    break

        augments.append(OrderedDict([
            ("id", api_name),
            ("name", localized(record.get("name") or lookup.get("name"),
                               cd_tr.get("name") or lookup_tr.get("name"))),
            ("desc", localized(desc_en, desc_tr)),
            ("rarity", rarity),
            ("category", category),
            ("icon", "augments/%s.png" % api_name if icon_url else None),
            ("iconURL", icon_url),
            ("metaTier", tiers.get(api_name)),
            ("traitId", trait_id),
        ]))

    augments.sort(key=lambda augment: (RARITY_RANK.get(augment["rarity"], 9), augment["name"]["en"]))
    return augments


# --------------------------------------------------------------------------------------
# Comps
# --------------------------------------------------------------------------------------

# Turkish locative suffix for the round number the sentence ends on (3-6'da vs 3-5'te).
TR_ROUND_SUFFIX = {1: "'de", 2: "'de", 3: "'te", 4: "'te", 5: "'te", 6: "'da", 7: "'de"}

PLAYSTYLE = {
    "fast 8": "fast8",
    "fast 9": "fast9",
    "lvl 5": "reroll5",
    "lvl 6": "reroll6",
    "lvl 7": "reroll7",
}


def split_units(raw, separator=","):
    if not raw:
        return []
    return [token.strip() for token in raw.split(separator) if token.strip()]


def resolve_units(unit_ids, alias_to_id, champions_by_id, context):
    """MetaTFT unit ids -> canonical champion ids (unknown ids are warned about and dropped)."""
    resolved = []
    for unit_id in unit_ids:
        canonical = alias_to_id.get(unit_id, unit_id)
        if canonical not in champions_by_id:
            if unit_id not in UNKNOWN_UNITS:
                UNKNOWN_UNITS.add(unit_id)
                warn("unknown unit %s (first seen in %s); dropped from boards" % (unit_id, context))
            continue
        if canonical not in resolved:
            resolved.append(canonical)
    return resolved


def comp_playstyle(levelling):
    return PLAYSTYLE.get((levelling or "").strip().lower(), "standard")


def comp_difficulty(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "medium"
    if number >= 0.06:
        return "hard"
    if number <= -0.03:
        return "easy"
    return "medium"


def comp_trend(trends):
    if not trends or len(trends) < 2:
        return "stable"
    first = trends[0].get("pick") or 0
    last = trends[-1].get("pick") or 0
    if not first:
        return "stable"
    change = (last - first) / float(first)
    if change >= 0.20:
        return "rising"
    if change <= -0.20:
        return "falling"
    return "stable"


def assign_cells(units, positioning, alias_map):
    """Greedy unique-cell assignment, most important unit first."""
    unit_positions = (positioning or {}).get("units") or {}
    taken = set()
    cells = {}
    for unit in sorted(units, key=lambda item: -item["importance"]):
        record = unit_positions.get(unit["id"])
        if record is None:
            for alias in alias_map.get(unit["id"], []):
                if alias in unit_positions:
                    record = unit_positions[alias]
                    break
        if record is None:
            cells[unit["id"]] = None
            continue
        positions = sorted(record.get("positions") or [],
                           key=lambda entry: -(entry.get("count") or 0))
        chosen = None
        for entry in positions:
            cell = entry.get("cell") or ""
            if not cell.startswith("cell_"):
                continue
            try:
                number = int(cell[len("cell_"):])
            except ValueError:
                continue
            if number in taken or not 1 <= number <= 28:
                continue
            chosen = number
            taken.add(number)
            break
        cells[unit["id"]] = chosen
    return cells


def comp_traits(unit_ids, champions_by_id, traits_by_id):
    counts = {}
    for unit_id in unit_ids:
        for trait_id in champions_by_id[unit_id]["traits"]:
            counts[trait_id] = counts.get(trait_id, 0) + 1
    active = []
    for trait_id, count in counts.items():
        trait = traits_by_id.get(trait_id)
        if not trait or not trait["breakpoints"]:
            continue
        reached = [bp for bp in trait["breakpoints"] if count >= bp["min"]]
        if not reached:
            continue
        active.append(OrderedDict([
            ("id", trait_id),
            ("count", count),
            ("style", reached[-1]["style"]),
        ]))
    active.sort(key=lambda entry: (-entry["count"], traits_by_id[entry["id"]]["name"]["en"]))
    return active


def best_option(entries, key):
    best = None
    best_score = None
    for entry in entries or []:
        score = entry.get(key)
        if score is None:
            continue
        if best_score is None or score > best_score:
            best, best_score = entry, score
    return best


def star_priority(units, raw_stars):
    """Only units that are actually in the comp and worth 3-starring, in board order."""
    priority = [unit["id"] for unit in units if unit["stars"] == 3]
    if not priority:
        priority = [unit["id"] for unit in units if unit["id"] in raw_stars]
    return priority


def name_list(names, limit):
    """Join at most `limit` names; append an ellipsis when some were left out."""
    if not names:
        return ""
    shown = ", ".join(names[:limit])
    return shown + " …" if len(names) > limit else shown


def build_comp_name(cluster, champions_by_id, traits_by_id, alias_to_id):
    parts_en, parts_tr = [], []
    entries = cluster.get("name") or []
    if not entries:
        for token in split_units(cluster.get("name_string")):
            entries.append({"name": token, "type": "trait" if token in traits_by_id else "unit"})
    for entry in entries:
        raw = entry.get("name")
        if not raw:
            continue
        if entry.get("type") == "trait":
            record = traits_by_id.get(raw)
        else:
            record = champions_by_id.get(alias_to_id.get(raw, raw))
        if record is None:
            record = traits_by_id.get(raw) or champions_by_id.get(raw)
        if record is None:
            warn("comp %s name part %s could not be resolved" % (cluster.get("Cluster"), raw))
            continue
        parts_en.append(record["name"]["en"])
        parts_tr.append(record["name"]["tr"])
    return localized(" ".join(parts_en), " ".join(parts_tr))


TIP_MAX_CHARS = 140


def trim_tip(tip):
    """Last-resort guard so a generated sentence always fits a phone-sized row."""
    if len(tip) <= TIP_MAX_CHARS:
        return tip
    cut = tip[:TIP_MAX_CHARS - 2]
    if " " in cut:
        cut = cut[:cut.rindex(" ")]
    return cut.rstrip(" ,.;:") + " …"


def build_tips(comp, champions_by_id, traits_by_id, items_by_id, comp_names):
    def champion_name(unit_id, lang):
        champion = champions_by_id.get(unit_id)
        return champion["name"][lang] if champion else unit_id

    def item_name(item_id, lang):
        item = items_by_id.get(item_id)
        return item["name"][lang] if item else item_id

    carries = [unit for unit in comp["units"] if unit["isCarry"]]
    if not carries:
        carries_for_name = comp["units"][:1]
    else:
        carries_for_name = carries
    carry_names_tr = name_list([champion_name(unit["id"], "tr") for unit in carries_for_name], 3)
    carry_names_en = name_list([champion_name(unit["id"], "en") for unit in carries_for_name], 3)

    tips_tr, tips_en = [], []
    playstyle = comp["playstyle"]
    if playstyle == "fast8":
        tips_tr.append("Ekonomi yap, 4-1/4-2'de 8. seviyeye çık ve %s için mağazayı çevir." % carry_names_tr)
        tips_en.append("Play for economy, hit level 8 on 4-1/4-2 and roll for %s." % carry_names_en)
    elif playstyle == "fast9":
        tips_tr.append("Ekonomi yap, 9. seviyeyi hedefle ve %s için mağazayı çevir." % carry_names_tr)
        tips_en.append("Play for economy, push to level 9 and roll for %s." % carry_names_en)
    elif playstyle.startswith("reroll"):
        level = playstyle[len("reroll"):]
        targets = comp["starPriority"]
        targets_tr = name_list([champion_name(unit_id, "tr") for unit_id in targets], 4)
        targets_en = name_list([champion_name(unit_id, "en") for unit_id in targets], 4)
        if targets_tr:
            tips_tr.append("%s. seviyede dur, 50 altının üstündeki parayla %s 3 yıldız olana kadar çevir."
                           % (level, targets_tr))
            tips_en.append("Stay at level %s and roll above 50 gold until %s are 3-star."
                           % (level, targets_en))
        else:
            tips_tr.append("%s. seviyede dur, 50 altının üstündeki parayla taşıyıcıları 3 yıldız olana "
                           "kadar çevir." % level)
            tips_en.append("Stay at level %s and roll above 50 gold until your carries are 3-star." % level)
    else:
        tips_tr.append("Standart tempo: her aşamada seviye atla, güçlü tahta koru.")
        tips_en.append("Standard tempo: level on curve every stage and keep a strong board.")

    for unit in carries[:3]:
        if not unit["items"]:
            continue
        tips_tr.append("%s: %s." % (champion_name(unit["id"], "tr"),
                                    ", ".join(item_name(item, "tr") for item in unit["items"])))
        tips_en.append("%s: %s." % (champion_name(unit["id"], "en"),
                                    ", ".join(item_name(item, "en") for item in unit["items"])))

    timings = [entry for entry in comp["levelTiming"] if 7 <= entry["level"] <= 9]
    if timings:
        entry = timings[-1]
        tips_tr.append("Oyuncular genelde %d-%d%s %d. seviyeye çıkıyor."
                       % (entry["stage"], entry["round"], TR_ROUND_SUFFIX.get(entry["round"], "'de"),
                          entry["level"]))
        tips_en.append("Players usually reach level %d on %d-%d."
                       % (entry["level"], entry["stage"], entry["round"]))

    if comp["traits"]:
        top = comp["traits"][:3]
        tips_tr.append("Aktif özellikler: %s."
                       % name_list(["%s (%d)" % (traits_by_id[t["id"]]["name"]["tr"], t["count"]) for t in top], 3))
        tips_en.append("Active traits: %s."
                       % name_list(["%s (%d)" % (traits_by_id[t["id"]]["name"]["en"], t["count"]) for t in top], 3))

    if comp["counters"]:
        counter_id = comp["counters"][0]["compId"]
        names = comp_names.get(counter_id)
        if names:
            tips_tr.append("Dikkat: %s bu kompu yeniyor." % names["tr"])
            tips_en.append("Watch out: %s beats this comp." % names["en"])

    if comp["difficulty"] == "hard":
        tips_tr.append("Zor komp: dizilim ve eşya önceliği kritik.")
        tips_en.append("Hard comp: positioning and item priority are critical.")

    while len(tips_tr) < 3 or len(tips_en) < 3:
        core_tr = ", ".join(champion_name(unit_id, "tr") for unit_id in comp["coreUnits"])
        core_en = ", ".join(champion_name(unit_id, "en") for unit_id in comp["coreUnits"])
        filler_tr = "Ana birimler: %s." % core_tr if core_tr else "Güçlü tahta koru ve canını koru."
        filler_en = "Core units: %s." % core_en if core_en else "Keep a strong board and protect your health."
        if filler_tr in tips_tr and filler_en in tips_en:
            filler_tr = "Eşyaları ana taşıyıcıya ver, yan birimleri sonra güçlendir."
            filler_en = "Give items to the main carry first, upgrade side units later."
        if filler_tr in tips_tr:
            break
        tips_tr.append(filler_tr)
        tips_en.append(filler_en)

    return OrderedDict([("tr", [trim_tip(tip) for tip in tips_tr[:7]]),
                        ("en", [trim_tip(tip) for tip in tips_en[:7]])])


def build_comps(fetcher, sources, gamedata, max_comps=None):
    champions_by_id = dict((champion["id"], champion) for champion in gamedata["champions"])
    traits_by_id = dict((trait["id"], trait) for trait in gamedata["traits"])
    items_by_id = dict((item["id"], item) for item in gamedata["items"])
    augment_ids = set(augment["id"] for augment in gamedata["augments"])
    alias_to_id = {}
    alias_map = {}
    for champion in gamedata["champions"]:
        alias_to_id[champion["id"]] = champion["id"]
        alias_map[champion["id"]] = champion["aliases"]
        for alias in champion["aliases"]:
            alias_to_id[alias] = champion["id"]

    payload = sources["comps"]
    data = (payload.get("results") or {}).get("data") or {}
    cluster_id = data.get("cluster_id") or payload.get("cluster_id")
    clusters = data.get("cluster_details") or {}

    keys = sorted(clusters.keys())
    kept = [key for key in keys
            if ((clusters[key].get("overall") or {}).get("count") or 0) >= MIN_CLUSTER_GAMES]
    if max_comps:
        kept = kept[:max_comps]
    log("Comps: %d clusters, %d with >= %d games" % (len(keys), len(kept), MIN_CLUSTER_GAMES))

    comps = []
    for index, key in enumerate(kept, 1):
        cluster = clusters[key]
        log("  [%d/%d] comp %s" % (index, len(kept), key))
        try:
            comp = build_single_comp(fetcher, cluster, key, cluster_id, champions_by_id, traits_by_id,
                                     items_by_id, augment_ids, alias_to_id, alias_map)
        except Exception as exc:  # keep going: one bad cluster must not kill the build
            warn("comp %s failed (%s: %s); skipped" % (key, type(exc).__name__, exc))
            continue
        if comp:
            comps.append(comp)

    assign_tiers(comps)
    finalize_comps(comps, champions_by_id, traits_by_id, items_by_id)
    comps.sort(key=lambda comp: ("SABC".index(comp["tier"]), comp["stats"]["avgPlacement"]))
    return comps, cluster_id


def build_single_comp(fetcher, cluster, key, cluster_id, champions_by_id, traits_by_id, items_by_id,
                      augment_ids, alias_to_id, alias_map):
    details = fetcher.get_json("%scomp_details?comp=%s&cluster_id=%s" % (MT_COMPS_BASE, key, cluster_id))
    details = details.get("results") or {}
    try:
        options = fetcher.get_json("%scomp_options?comp=%s&cluster_id=%s" % (MT_COMPS_BASE, key, cluster_id))
        options = ((options.get("results") or {}).get("options") or {}).get(str(key)) or {}
    except (IOError, ValueError) as exc:
        warn("comp %s options unavailable (%s)" % (key, exc))
        options = {}
    try:
        augment_payload = fetcher.get_json("%scomp_augment_tiers?comp=%s&cluster_id=%s"
                                           % (MT_COMPS_BASE, key, cluster_id))
        augment_payload = (augment_payload.get("results") or {}).get(str(key)) or {}
    except (IOError, ValueError) as exc:
        warn("comp %s augments unavailable (%s)" % (key, exc))
        augment_payload = {}

    overall = cluster.get("overall") or details.get("overall") or {}
    total_games = overall.get("count") or 0

    unit_ids = resolve_units(split_units(cluster.get("units_string")), alias_to_id, champions_by_id,
                             "comp %s units" % key)
    if not unit_ids:
        warn("comp %s has no resolvable units; skipped" % key)
        return None

    importance = {}
    unit_stats = details.get("unit_stats") or []
    if isinstance(unit_stats, dict):
        unit_stats = list(unit_stats.values())
    for record in unit_stats:
        canonical = alias_to_id.get(record.get("unit"))
        if canonical is None:
            continue
        count = record.get("count") or 0
        value = (count / float(total_games)) if total_games else 1.0
        importance[canonical] = max(0.0, min(1.0, round(value, 4)))

    builds = {}
    build_scores = {}
    for build in cluster.get("builds") or []:
        canonical = alias_to_id.get(build.get("unit"))
        if canonical is None or canonical in builds:
            continue
        items = [item for item in (build.get("buildName") or []) if item in items_by_id][:3]
        if items:
            builds[canonical] = items
            build_scores[canonical] = float(build.get("score") or 0)

    stars = set(resolve_units(cluster.get("stars") or [], alias_to_id, champions_by_id,
                              "comp %s stars" % key))

    units = []
    for unit_id in unit_ids:
        items = builds.get(unit_id, [])
        units.append(OrderedDict([
            ("id", unit_id),
            ("items", items),
            ("stars", 3 if unit_id in stars else 2),
            ("isCarry", False),
            ("cell", None),
            ("importance", importance.get(unit_id, 1.0)),
        ]))

    # Item count first (as specified); MetaTFT's build score breaks ties, so the comp's
    # actual carry wins over a tank that also happens to hold three items.
    def carry_rank(unit):
        return (-len(unit["items"]), -build_scores.get(unit["id"], 0.0),
                -champions_by_id[unit["id"]]["cost"], champions_by_id[unit["id"]]["name"]["en"])

    for unit in sorted(units, key=carry_rank)[:3]:
        if len(unit["items"]) >= 2:
            unit["isCarry"] = True

    cells = assign_cells(units, details.get("positioning"), alias_map)
    for unit in units:
        unit["cell"] = cells.get(unit["id"])

    units.sort(key=lambda unit: (not unit["isCarry"],) + carry_rank(unit))

    code_units = sorted(unit_ids, key=lambda unit_id: (-champions_by_id[unit_id]["cost"],
                                                       champions_by_id[unit_id]["name"]["en"]))[:10]
    team_code = encode_team_code([champions_by_id[unit_id]["teamCode"] for unit_id in code_units])

    level_boards = OrderedDict()
    for level in sorted(options.keys(), key=lambda value: int(value)):
        entry = best_option(options.get(level), "score")
        if not entry:
            continue
        board = resolve_units(split_units(entry.get("units_list"), "&"), alias_to_id, champions_by_id,
                              "comp %s level %s" % (key, level))
        if board:
            level_boards[str(level)] = board

    early_boards = OrderedDict()
    early = details.get("early_options") or {}
    for level in sorted(early.keys(), key=lambda value: int(value)):
        entry = best_option(early.get(level), "count")
        if not entry:
            continue
        board = resolve_units(split_units(entry.get("unit_list"), "&"), alias_to_id, champions_by_id,
                              "comp %s early %s" % (key, level))
        if board:
            early_boards[str(level)] = board

    level_timing = []
    for entry in details.get("levels") or []:
        stage, round_number = entry.get("stage"), entry.get("round")
        if stage in (None, "") or round_number in (None, ""):
            continue
        try:
            level_timing.append(OrderedDict([("level", int(entry.get("level"))),
                                             ("stage", int(stage)),
                                             ("round", int(round_number))]))
        except (TypeError, ValueError):
            continue
    level_timing.sort(key=lambda entry: entry["level"])

    augments = OrderedDict()
    for entry in augment_payload.get("augments") or []:
        tier = entry.get("tier")
        augment_id = entry.get("id")
        if tier not in ("S", "A") or augment_id not in augment_ids:
            continue
        bucket = augments.setdefault(tier, [])
        if len(bucket) < 30 and augment_id not in bucket:
            bucket.append(augment_id)
    augments = OrderedDict((tier, augments[tier]) for tier in ("S", "A") if augments.get(tier))

    counters, good_against = [], []
    for entry in details.get("counters") or []:
        against = entry.get("against")
        if against is None or str(against) == str(key):
            continue
        if (entry.get("similarity") or 0) >= 0.9:
            continue
        change = entry.get("place_change")
        if change is None:
            continue
        record = OrderedDict([("compId", str(against)), ("placeChange", round(float(change), 3))])
        if change > 0:
            counters.append(record)
        elif change < 0:
            good_against.append(record)
    counters.sort(key=lambda entry: -entry["placeChange"])
    good_against.sort(key=lambda entry: entry["placeChange"])

    core_units = [unit["id"] for unit in sorted(units, key=lambda item: -item["importance"])[:5]]
    trends = cluster.get("trends") or details.get("trends") or []
    play_rate = trends[-1].get("pick") if trends else None

    return OrderedDict([
        ("id", str(key)),
        ("name", build_comp_name(cluster, champions_by_id, traits_by_id, alias_to_id)),
        ("tier", "C"),
        ("playstyle", comp_playstyle(cluster.get("levelling"))),
        ("difficulty", comp_difficulty(cluster.get("difficulty"))),
        ("stats", OrderedDict([
            ("avgPlacement", round(float(overall.get("avg") or 0), 3)),
            ("playRate", round(float(play_rate), 5) if play_rate is not None else 0.0),
            ("games", int(total_games)),
        ])),
        ("trend", comp_trend(trends)),
        ("units", units),
        ("traits", comp_traits(unit_ids, champions_by_id, traits_by_id)),
        ("teamCode", team_code),
        ("levelBoards", level_boards),
        ("earlyBoards", early_boards),
        ("levelTiming", level_timing),
        ("augments", augments),
        ("counters", counters),
        ("goodAgainst", good_against),
        ("starPriority", star_priority(units, stars)),
        ("coreUnits", core_units),
        ("tips", OrderedDict([("tr", []), ("en", [])])),
    ])


def assign_tiers(comps):
    ordered = sorted(comps, key=lambda comp: (comp["stats"]["games"] < LOW_SAMPLE_GAMES,
                                              comp["stats"]["avgPlacement"]))
    index = 0
    for tier, size in TIER_BUCKETS:
        for comp in ordered[index:index + size]:
            comp["tier"] = tier
        index += size
    for comp in ordered[index:]:
        comp["tier"] = "C"


def finalize_comps(comps, champions_by_id, traits_by_id, items_by_id):
    """Drop references to comps that were not exported, then generate tips."""
    valid = set(comp["id"] for comp in comps)
    names = dict((comp["id"], comp["name"]) for comp in comps)
    for comp in comps:
        comp["counters"] = [entry for entry in comp["counters"] if entry["compId"] in valid][:5]
        comp["goodAgainst"] = [entry for entry in comp["goodAgainst"] if entry["compId"] in valid][:5]
    for comp in comps:
        comp["tips"] = build_tips(comp, champions_by_id, traits_by_id, items_by_id, names)


# --------------------------------------------------------------------------------------
# Multi-source consensus (docs/MULTISOURCE_SPEC.md)
# --------------------------------------------------------------------------------------

# Order source comps are seeded into clusters in: curated and heavy sources first.
SEED_ORDER = ("tftacademy", "blitz", "tacticstools", "metatft", "tftactics", "tftflow")
# Order in which a source's board/items/stages win when several describe one comp.
# tactics.tools comes last: it ships no positions, so MetaTFT's board beats it.
CURATED_ORDER = ("tftacademy", "blitz", "tftflow", "tftactics", "metatft", "tacticstools")
CONSENSUS_TIERS = (("S", 85), ("A", 72), ("B", 58))
# A comp only one or two sites list cannot outrank the ones everybody agrees on.
AGREEMENT_CAPS = {1: "B", 2: "A"}
MATCH_JACCARD = 0.5
MATCH_SHARED_UNITS = 5
UNMEASURED_IMPORTANCE = 0.5
MIN_COMP_UNITS = 7
MAX_COMP_UNITS = 10
STAGE_EARLY_LABEL = "Erken (2-1 → 3-2)"
STAGE_MID_LABEL = "Orta (%s. seviye)"
STAGE_LATE_LABEL = "Tavan (9-10)"


def load_translations():
    """sha1(en) -> Turkish source-tip text; an absent file simply means `tr` stays null."""
    if not os.path.exists(TRANSLATIONS_PATH):
        warn("tools/translations.json not found; source tips stay English only")
        return {}
    with open(TRANSLATIONS_PATH, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    table = {}
    for digest, entry in (payload.get("entries") or {}).items():
        turkish = (entry or {}).get("tr")
        if not turkish:
            continue
        table[digest] = turkish
        english = (entry or {}).get("en")
        if english:
            table.setdefault(sha1_text(comp_sources.clean_source_text(english)), turkish)
    return table


def sha1_text(text):
    return hashlib.sha1((text or "").encode("utf-8")).hexdigest()


def collect_sources(fetcher, gamedata, metatft_comps, generated_at):
    """Fetch every extra source; a failure is a warning, never a build failure."""
    catalog = comp_sources.Catalog(gamedata, warn=warn)
    code_to_id = {}
    for champion in gamedata["champions"]:
        code_to_id.setdefault(champion["teamCode"], champion["id"])

    def decode(code):
        return decode_team_code(code, code_to_id)

    records = OrderedDict()
    status = []

    def record_status(key, ok, count):
        label, _, url = comp_sources.SOURCE_META[key]
        status.append(OrderedDict([("key", key), ("label", label), ("url", url),
                                   ("fetchedAt", generated_at), ("ok", ok), ("count", count)]))

    records["metatft"] = comp_sources.normalise_metatft(metatft_comps, catalog)
    record_status("metatft", True, len(records["metatft"]))
    for key, fetch in comp_sources.FETCHERS.items():
        started = time.time()
        try:
            comps = fetch(fetcher, catalog, decode) if key == "tacticstools" \
                else fetch(fetcher, catalog)
        except Exception as exc:  # any source may break; MetaTFT alone is mandatory
            warn("source %s unavailable (%s: %s); skipped" % (key, type(exc).__name__, exc))
            record_status(key, False, 0)
            continue
        records[key] = comps
        record_status(key, True, len(comps))
        log("  %-13s %3d comps (%.1f s)" % (key, len(comps), time.time() - started))
    return records, status


def record_units(record):
    return set(unit["id"] for unit in record["units"])


def match_score(units, carry, cluster):
    """Best Jaccard against a cluster member, 0 when the comp does not belong there."""
    best = 0.0
    for member in cluster.values():
        other = record_units(member)
        shared = len(units & other)
        union = len(units | other)
        if not union:
            continue
        jaccard = shared / float(union)
        matches = jaccard >= MATCH_JACCARD or (
            shared >= MATCH_SHARED_UNITS and carry and carry == member["mainChampion"])
        if matches and jaccard > best:
            best = jaccard
    return best


def cluster_records(records_by_source):
    """Group source comps that describe the same comp; one comp per source per cluster."""
    clusters = []
    for key in SEED_ORDER:
        for record in records_by_source.get(key) or []:
            units = record_units(record)
            if not units:
                continue
            best_cluster, best_score = None, 0.0
            for cluster in clusters:
                if key in cluster:
                    continue
                score = match_score(units, record["mainChampion"], cluster)
                if score > best_score:
                    best_cluster, best_score = cluster, score
            if best_cluster is None:
                clusters.append(OrderedDict([(key, record)]))
            else:
                best_cluster[key] = record
    return clusters


def consensus_tier(cluster):
    """Weighted mean of the available tier scores -> (letter, score, situational)."""
    total, weight_sum = 0.0, 0.0
    for key, record in cluster.items():
        if record["tierScore"] is None:
            continue
        weight = comp_sources.SOURCE_META[key][1]
        total += weight * record["tierScore"]
        weight_sum += weight
    if not weight_sum:
        return "C", 0.0, True
    score = total / weight_sum
    tier = "C"
    for letter, minimum in CONSENSUS_TIERS:
        if score >= minimum:
            tier = letter
            break
    cap = AGREEMENT_CAPS.get(len(cluster))
    if cap and "SABC".index(tier) < "SABC".index(cap):
        tier = cap
    return tier, round(score, 2), False


def curated_members(cluster):
    """Cluster members in the order their curated data wins."""
    return [(key, cluster[key]) for key in CURATED_ORDER if key in cluster]


def first_value(cluster, field):
    for _, record in curated_members(cluster):
        if record.get(field):
            return record[field]
    return None


def merge_units(cluster, metatft_comp, champions_by_id):
    """Units from the highest-weight curated source; MetaTFT fills the gaps it leaves."""
    members = curated_members(cluster)
    primary = None
    for _, record in members:
        if len(record["units"]) >= MIN_COMP_UNITS:
            primary = record
            break
    if primary is None:
        # Every board is short (a source listed a partial comp): take the fullest one.
        primary = max([record for _, record in members] or [None],
                      key=lambda record: len(record["units"]) if record else 0)
    if primary is None or not primary["units"]:
        return []
    # Items and cells the curated board leaves empty come from MetaTFT; without a MetaTFT
    # member the remaining sources fill in, in weight order.
    fillers = [record for _, record in members if record is not primary]
    if cluster.get("metatft") is not None and cluster["metatft"] is not primary:
        fillers = [cluster["metatft"]]

    metatft_units = {}
    if metatft_comp:
        metatft_units = dict((unit["id"], unit) for unit in metatft_comp["units"])
    main_champions = set(record["mainChampion"] for record in cluster.values()
                         if record["mainChampion"])

    units = []
    taken_cells = set()
    for source_unit in primary["units"]:
        unit_id = source_unit["id"]
        if unit_id not in champions_by_id or any(unit["id"] == unit_id for unit in units):
            continue
        items, cell = list(source_unit["items"]), source_unit["cell"]
        stars = 3 if any(unit["id"] == unit_id and unit["stars"] == 3
                         for record in cluster.values() for unit in record["units"]) else 2
        for record in fillers:
            other = next((unit for unit in record["units"] if unit["id"] == unit_id), None)
            if other is None:
                continue
            if not items and other["items"]:
                items = list(other["items"])
            if cell is None and other["cell"] is not None:
                cell = other["cell"]
        if cell in taken_cells:
            cell = None
        if cell is not None:
            taken_cells.add(cell)
        reference = metatft_units.get(unit_id)
        if reference is not None:
            importance = reference["importance"]
        else:
            # Curated-only units: MetaTFT never saw them on this board, so they rank
            # behind the measured ones (1.0 when the comp has no MetaTFT data at all).
            importance = UNMEASURED_IMPORTANCE if metatft_units else 1.0
        units.append(OrderedDict([
            ("id", unit_id),
            ("items", items[:3]),
            ("stars", stars),
            ("isCarry", False),
            ("cell", cell),
            ("importance", importance),
        ]))

    def carry_rank(unit):
        champion = champions_by_id[unit["id"]]
        return (unit["id"] not in main_champions, -len(unit["items"]), -unit["importance"],
                -champion["cost"], champion["name"]["en"])

    ordered = sorted(units, key=carry_rank)
    for unit in [unit for unit in ordered if len(unit["items"]) >= 2][:3]:
        unit["isCarry"] = True
    units.sort(key=lambda unit: (not unit["isCarry"],) + carry_rank(unit))
    return units[:MAX_COMP_UNITS]


def stage_units(entries, champions_by_id, limit=10):
    board = []
    for entry in entries or []:
        if entry["id"] not in champions_by_id or any(unit["id"] == entry["id"] for unit in board):
            continue
        board.append(OrderedDict([("id", entry["id"]), ("stars", entry["stars"]),
                                  ("items", list(entry["items"])[:3])]))
        if len(board) >= limit:
            break
    return board


def build_stages(cluster, units, champions_by_id):
    """`stages.early|mid|late` merged from the curated sources, MetaTFT as the fallback."""
    stages = OrderedDict()
    early = stage_units(first_value(cluster, "early"), champions_by_id)
    if early:
        stages["early"] = OrderedDict([("label", STAGE_EARLY_LABEL), ("units", early)])

    mid_level = "7"
    mid = []
    for _, record in curated_members(cluster):
        if record["mid"]:
            mid = stage_units(record["mid"], champions_by_id)
            mid_level = record["midLevel"] or mid_level
            break
    if mid:
        stages["mid"] = OrderedDict([("label", STAGE_MID_LABEL % mid_level), ("units", mid)])

    # Late = the final board plus the curated "max cap" additions, capped at ten units.
    late_source = first_value(cluster, "late") or []
    late = [OrderedDict([("id", unit["id"]), ("stars", unit["stars"]), ("items", unit["items"])])
            for unit in units]
    known = set(unit["id"] for unit in late)
    for entry in late_source:
        if entry["id"] in known or entry["id"] not in champions_by_id:
            continue
        known.add(entry["id"])
        late.append(OrderedDict([("id", entry["id"]), ("stars", entry["stars"]),
                                 ("items", list(entry["items"])[:3])]))
    if len(late) > len(units):
        stages["late"] = OrderedDict([("label", STAGE_LATE_LABEL), ("units", late[:10])])
    return stages


def build_source_list(cluster):
    entries = []
    for key in sorted(cluster.keys(), key=lambda key: (-comp_sources.SOURCE_META[key][1], key)):
        record = cluster[key]
        entry = OrderedDict([
            ("key", key),
            ("label", comp_sources.SOURCE_META[key][0]),
            ("tier", record["tierLabel"] or "C"),
            ("name", record["name_en"]),
            ("url", record["url"]),
        ])
        # Statistical sources can show their own average placement next to the tier.
        if key in comp_sources.STATS_ONLY_SOURCES and record["stats"]:
            entry["score"] = record["stats"]["avgPlacement"]
        entries.append(entry)
    return entries


def build_source_tips(cluster, translations):
    tips = []
    for key, record in curated_members(cluster):
        for tip in record["tips"]:
            english = tip["en"]
            turkish = translations.get(sha1_text(tip.get("raw") or english)) \
                or translations.get(sha1_text(english))
            tips.append(OrderedDict([("source", key), ("stage", tip["stage"]),
                                     ("en", english), ("tr", turkish)]))
    return tips


def consensus_name(cluster, metatft_comp, units, traits, champions_by_id, traits_by_id):
    """EN from the best curated source, TR generated from trait + carry."""
    english = ""
    for key in ("tftacademy", "blitz", "tacticstools", "tftactics", "tftflow", "metatft"):
        if key in cluster and cluster[key]["name_en"]:
            english = cluster[key]["name_en"]
            break
    generated_en = generated_name(units, traits, champions_by_id, traits_by_id, "en")
    generated_tr = generated_name(units, traits, champions_by_id, traits_by_id, "tr")
    if metatft_comp:
        generated_en = metatft_comp["name"]["en"] or generated_en
        generated_tr = metatft_comp["name"]["tr"] or generated_tr
    name = localized(english or generated_en, generated_tr or english)
    subtitle = None
    if generated_en and generated_en != name["en"]:
        subtitle = localized(generated_en, generated_tr or generated_en)
    return name, subtitle


def generated_name(units, traits, champions_by_id, traits_by_id, lang):
    """"<strongest trait> <main carry>" — the fallback when no source named the comp."""
    parts = []
    named = [entry for entry in traits
             if traits_by_id.get(entry["id"]) and traits_by_id[entry["id"]]["type"] != "unique"]
    if named:
        best = max(named, key=lambda entry: (entry["count"], -len(entry["id"])))
        parts.append(traits_by_id[best["id"]]["name"][lang])
    carries = [unit for unit in units if unit["isCarry"]] or units[:1]
    if carries:
        parts.append(champions_by_id[carries[0]["id"]]["name"][lang])
    return " ".join(parts)


def slugify(text):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", (text or "").lower())).strip("-")


def build_consensus_comps(clusters, metatft_by_id, gamedata, translations):
    champions_by_id = dict((champion["id"], champion) for champion in gamedata["champions"])
    traits_by_id = dict((trait["id"], trait) for trait in gamedata["traits"])
    items_by_id = dict((item["id"], item) for item in gamedata["items"])
    augment_ids = set(augment["id"] for augment in gamedata["augments"])

    scored = []
    used_ids = set()
    for cluster in clusters:
        metatft_comp = metatft_by_id.get(cluster["metatft"]["sourceId"]) if "metatft" in cluster \
            else None
        units = merge_units(cluster, metatft_comp, champions_by_id)
        if len(units) < MIN_COMP_UNITS:
            warn("cluster %s has only %d units; skipped"
                 % (list(cluster.values())[0]["name_en"], len(units)))
            continue
        unit_ids = [unit["id"] for unit in units]
        traits = comp_traits(unit_ids, champions_by_id, traits_by_id)
        tier, score, situational = consensus_tier(cluster)
        name, subtitle = consensus_name(cluster, metatft_comp, units, traits,
                                        champions_by_id, traits_by_id)

        if metatft_comp:
            comp_id = metatft_comp["id"]
        else:
            primary_key, primary = curated_members(cluster)[0]
            comp_id = "%s-%s" % (primary_key, slugify(primary["name_en"]) or primary["sourceId"])
            suffix = 2
            while comp_id in used_ids:
                comp_id = "%s-%d" % (comp_id, suffix)
                suffix += 1
        used_ids.add(comp_id)

        code_units = sorted(unit_ids, key=lambda unit_id: (-champions_by_id[unit_id]["cost"],
                                                           champions_by_id[unit_id]["name"]["en"]))[:10]
        stats = consensus_stats(cluster, metatft_comp)
        augments = consensus_augments(cluster, metatft_comp, augment_ids)
        alt_builds = [entry for entry in (first_value(cluster, "altBuilds") or [])
                      if entry["unit"] in champions_by_id
                      and all(item in items_by_id for item in entry["items"])]
        carousel = [item_id for item_id in (first_value(cluster, "carousel") or [])
                    if item_id in items_by_id]
        playstyle = first_value(cluster, "style") or (metatft_comp["playstyle"]
                                                      if metatft_comp else "standard")
        difficulty = first_value(cluster, "difficulty") or (metatft_comp["difficulty"]
                                                            if metatft_comp else "medium")

        comp = OrderedDict([
            ("id", comp_id),
            ("name", name),
            ("subtitle", subtitle),
            ("tier", tier),
            ("playstyle", playstyle),
            ("difficulty", difficulty),
            ("stats", stats),
            ("trend", metatft_comp["trend"] if metatft_comp else "stable"),
            ("units", units),
            ("traits", traits),
            ("teamCode", encode_team_code([champions_by_id[unit_id]["teamCode"]
                                           for unit_id in code_units])),
            ("levelBoards", metatft_comp["levelBoards"] if metatft_comp else OrderedDict()),
            ("earlyBoards", metatft_comp["earlyBoards"] if metatft_comp else OrderedDict()),
            ("levelTiming", metatft_comp["levelTiming"] if metatft_comp else []),
            ("stages", build_stages(cluster, units, champions_by_id)),
            ("augments", augments),
            ("counters", metatft_comp["counters"] if metatft_comp else []),
            ("goodAgainst", metatft_comp["goodAgainst"] if metatft_comp else []),
            ("starPriority", [unit["id"] for unit in units if unit["stars"] == 3]),
            ("coreUnits", [unit["id"] for unit
                           in sorted(units, key=lambda unit: -unit["importance"])[:5]]),
            ("altBuilds", alt_builds),
            ("carousel", carousel),
            ("sources", build_source_list(cluster)),
            ("sourceCount", len(cluster)),
            ("situational", situational),
            ("sourceTips", build_source_tips(cluster, translations)),
            ("tips", OrderedDict([("tr", []), ("en", [])])),
        ])
        scored.append((comp, score))

    scored.sort(key=lambda entry: ("SABC".index(entry[0]["tier"]), entry[0]["situational"],
                                   -entry[0]["sourceCount"], -entry[1], entry[0]["id"]))
    return [comp for comp, _ in scored]


def consensus_stats(cluster, metatft_comp):
    """MetaTFT numbers, with win/top4 rates from the statistical sources when matched."""
    if metatft_comp:
        stats = OrderedDict([("avgPlacement", metatft_comp["stats"]["avgPlacement"]),
                             ("playRate", metatft_comp["stats"]["playRate"]),
                             ("games", metatft_comp["stats"]["games"])])
    else:
        stats = OrderedDict([("avgPlacement", 0.0), ("playRate", 0.0), ("games", 0)])
    top4, win = None, None
    for key in ("blitz", "tacticstools"):
        record = cluster.get(key)
        numbers = record["stats"] if record else None
        if not numbers:
            continue
        top4 = top4 if top4 is not None else numbers.get("top4Rate")
        win = win if win is not None else numbers.get("winRate")
        if not metatft_comp and not stats["avgPlacement"]:
            stats["avgPlacement"] = numbers.get("avgPlacement") or 0.0
            stats["playRate"] = numbers.get("pickRate") or 0.0
            stats["games"] = numbers.get("games") or 0
    stats["top4Rate"] = top4
    stats["winRate"] = win
    return stats


def consensus_augments(cluster, metatft_comp, augment_ids):
    """S = curated picks + MetaTFT S, A = MetaTFT A minus S."""
    top = []
    for key in ("tftacademy", "blitz", "tacticstools"):
        record = cluster.get(key)
        for augment_id in (record["augments"] if record else []):
            if augment_id in augment_ids and augment_id not in top:
                top.append(augment_id)
    for augment_id in (metatft_comp["augments"].get("S") if metatft_comp else []) or []:
        if augment_id not in top:
            top.append(augment_id)
    second = [augment_id for augment_id
              in (metatft_comp["augments"].get("A") if metatft_comp else []) or []
              if augment_id not in top]
    augments = OrderedDict()
    if top:
        augments["S"] = top[:30]
    if second:
        augments["A"] = second[:30]
    return augments


# --------------------------------------------------------------------------------------
# Verification
# --------------------------------------------------------------------------------------

def verify_team_codes(comps, champions, verbose=False):
    """decode(teamCode) must give back the comp's first ten units (cost desc, then name)."""
    code_to_id = {}
    for champion in champions:
        code_to_id.setdefault(champion["teamCode"], champion["id"])
    by_id = dict((champion["id"], champion) for champion in champions)

    for comp in comps:
        code = comp["teamCode"]
        if len(code) != 40:
            raise SystemExit("FATAL: comp %s team code length %d (expected 40)" % (comp["id"], len(code)))
        expected = sorted((unit["id"] for unit in comp["units"]),
                          key=lambda unit_id: (-by_id[unit_id]["cost"], by_id[unit_id]["name"]["en"]))[:10]
        try:
            decoded = decode_team_code(code, code_to_id)
        except (ValueError, KeyError) as exc:
            raise SystemExit("FATAL: comp %s team code does not decode (%s)" % (comp["id"], exc))
        if decoded != expected:
            raise SystemExit("FATAL: comp %s team code decodes to %s, expected %s"
                             % (comp["id"], decoded, expected))
        if verbose:
            log("  %s %s -> %s" % (comp["id"], code, ", ".join(decoded)))
    return True


def verify_references(gamedata, comps):
    """Every id referenced by comps must exist in gamedata."""
    champion_ids = set(champion["id"] for champion in gamedata["champions"])
    trait_ids = set(trait["id"] for trait in gamedata["traits"])
    item_ids = set(item["id"] for item in gamedata["items"])
    augment_ids = set(augment["id"] for augment in gamedata["augments"])
    comp_ids = set(comp["id"] for comp in comps)
    problems = []

    for champion in gamedata["champions"]:
        for trait_id in champion["traits"]:
            if trait_id not in trait_ids:
                problems.append("champion %s -> trait %s" % (champion["id"], trait_id))
        for item_id in champion["recommendedItems"]:
            if item_id not in item_ids:
                problems.append("champion %s -> item %s" % (champion["id"], item_id))
    for item in gamedata["items"]:
        for component in item["recipe"] or []:
            if component not in item_ids:
                problems.append("item %s -> component %s" % (item["id"], component))
    for comp in comps:
        for unit in comp["units"]:
            if unit["id"] not in champion_ids:
                problems.append("comp %s -> unit %s" % (comp["id"], unit["id"]))
            for item_id in unit["items"]:
                if item_id not in item_ids:
                    problems.append("comp %s -> item %s" % (comp["id"], item_id))
        for trait in comp["traits"]:
            if trait["id"] not in trait_ids:
                problems.append("comp %s -> trait %s" % (comp["id"], trait["id"]))
        for bucket in comp["augments"].values():
            for augment_id in bucket:
                if augment_id not in augment_ids:
                    problems.append("comp %s -> augment %s" % (comp["id"], augment_id))
        for entry in comp["counters"] + comp["goodAgainst"]:
            if entry["compId"] not in comp_ids:
                problems.append("comp %s -> comp %s" % (comp["id"], entry["compId"]))
        for board in list(comp["levelBoards"].values()) + list(comp["earlyBoards"].values()):
            for unit_id in board:
                if unit_id not in champion_ids:
                    problems.append("comp %s board -> unit %s" % (comp["id"], unit_id))
        for stage in comp["stages"].values():
            for unit in stage["units"]:
                if unit["id"] not in champion_ids:
                    problems.append("comp %s stage -> unit %s" % (comp["id"], unit["id"]))
                for item_id in unit["items"]:
                    if item_id not in item_ids:
                        problems.append("comp %s stage -> item %s" % (comp["id"], item_id))
        for entry in comp["altBuilds"]:
            if entry["unit"] not in champion_ids:
                problems.append("comp %s altBuild -> unit %s" % (comp["id"], entry["unit"]))
            for item_id in entry["items"]:
                if item_id not in item_ids:
                    problems.append("comp %s altBuild -> item %s" % (comp["id"], item_id))
        for item_id in comp["carousel"]:
            if item_id not in item_ids:
                problems.append("comp %s carousel -> item %s" % (comp["id"], item_id))
    return problems


def verify_text(gamedata, comps):
    """No raw markup may survive in any localized string."""
    offenders = []

    def check(where, value):
        for lang in ("en", "tr"):
            text = value.get(lang) or ""
            for token in ("<", ">", "@", "%i:"):
                if token in text:
                    offenders.append("%s[%s] contains %r" % (where, lang, token))

    for champion in gamedata["champions"]:
        check("champion %s ability" % champion["id"], champion["ability"]["desc"])
        check("champion %s name" % champion["id"], champion["name"])
    for trait in gamedata["traits"]:
        check("trait %s" % trait["id"], trait["desc"])
        for breakpoint_entry in trait["breakpoints"]:
            check("trait %s bp%d" % (trait["id"], breakpoint_entry["min"]), breakpoint_entry["desc"])
    for item in gamedata["items"]:
        check("item %s" % item["id"], item["desc"])
    for augment in gamedata["augments"]:
        check("augment %s" % augment["id"], augment["desc"])
    for comp in comps:
        check("comp %s name" % comp["id"], comp["name"])
        if comp["subtitle"]:
            check("comp %s subtitle" % comp["id"], comp["subtitle"])
        for index, tip in enumerate(comp["sourceTips"]):
            # Curated prose legitimately uses ">" ("Ravager > Executioner"), so only real
            # markup and entities are offences here.
            for lang in ("en", "tr"):
                text = tip[lang] or ""
                if RE_ANY_TAG.search(text) or re.search(r"&[a-zA-Z#0-9]+;", text):
                    offenders.append("comp %s sourceTip %d[%s] contains markup"
                                     % (comp["id"], index, lang))
    return offenders


# --------------------------------------------------------------------------------------
# Images
# --------------------------------------------------------------------------------------

def save_icon(fetcher, url, destination):
    """Download an icon, downscale to <= 256 px, keep alpha. True on success."""
    if not url:
        return False
    if os.path.exists(destination):
        return True
    try:
        payload = fetcher.get_binary(url)
    except IOError as exc:
        warn("icon download failed (%s): %s" % (exc, url))
        return False
    try:
        image = Image.open(io.BytesIO(payload))
        image.load()
        if image.mode not in ("RGBA", "RGB"):
            image = image.convert("RGBA")
        if image.width > IMAGE_MAX_PX or image.height > IMAGE_MAX_PX:
            image = image.resize((IMAGE_MAX_PX, IMAGE_MAX_PX), Image.LANCZOS)
        directory = os.path.dirname(destination)
        if not os.path.isdir(directory):
            os.makedirs(directory)
        image.save(destination, "PNG")
        return True
    except Exception as exc:  # corrupt/unsupported payloads must not kill the build
        warn("icon processing failed (%s: %s): %s" % (type(exc).__name__, exc, url))
        return False


def download_images(fetcher, gamedata, images_root):
    counts = {"downloaded": 0, "failed": 0}
    groups = (
        ("champions", gamedata["champions"], True),
        ("traits", gamedata["traits"], True),
        ("items", gamedata["items"], True),
        ("augments", gamedata["augments"], False),
    )
    for folder, records, required in groups:
        directory = os.path.join(images_root, folder)
        if not os.path.isdir(directory):
            os.makedirs(directory)
        failures = []
        for record in records:
            destination = os.path.join(directory, "%s.png" % record["id"])
            existed = os.path.exists(destination)
            if save_icon(fetcher, record.get("iconURL"), destination):
                if not existed:
                    counts["downloaded"] += 1
            else:
                counts["failed"] += 1
                failures.append(record["id"])
                if not required:
                    record["icon"] = None
        if failures:
            if required:
                raise SystemExit("FATAL: %d %s icons could not be downloaded: %s"
                                 % (len(failures), folder, ", ".join(failures[:10])))
            warn("%d %s icons missing: %s" % (len(failures), folder, ", ".join(failures[:10])))
        log("Images: %s ok (%d records)" % (folder, len(records)))
    return counts


# --------------------------------------------------------------------------------------
# Writers
# --------------------------------------------------------------------------------------

def dump_json(payload):
    return json.dumps(payload, ensure_ascii=False, indent=1, sort_keys=False) + "\n"


def write_outputs(documents, out_dir, resources_dir):
    targets = [out_dir]
    if resources_dir:
        targets.append(os.path.join(resources_dir, "Data"))
    for directory in targets:
        if not os.path.isdir(directory):
            os.makedirs(directory)
    for name, payload in documents.items():
        text = dump_json(payload)
        for directory in targets:
            with open(os.path.join(directory, name), "w", encoding="utf-8") as handle:
                handle.write(text)


def load_rules():
    if not os.path.exists(RULES_PATH):
        raise SystemExit("FATAL: %s is missing" % RULES_PATH)
    with open(RULES_PATH, "r", encoding="utf-8") as handle:
        return json.load(handle, object_pairs_hook=OrderedDict)


def load_guides(generated_at):
    if os.path.exists(GUIDES_SRC):
        with open(GUIDES_SRC, "r", encoding="utf-8") as handle:
            guides = json.load(handle, object_pairs_hook=OrderedDict)
        guides.setdefault("schemaVersion", SCHEMA_VERSION)
        guides["generatedAt"] = guides.get("generatedAt") or generated_at
        guides.setdefault("articles", [])
        return guides
    warn("tools/guides.json not found; writing an empty guides.json")
    return OrderedDict([("schemaVersion", SCHEMA_VERSION),
                        ("generatedAt", generated_at),
                        ("articles", [])])


# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Build HexKoc data files from CommunityDragon + MetaTFT.")
    parser.add_argument("--out", default=os.path.join(REPO_ROOT, "data", "v1"),
                        help="JSON output directory (default: data/v1)")
    parser.add_argument("--resources", default=os.path.join(REPO_ROOT, "Resources"),
                        help="app Resources directory (ignored with --skip-images)")
    parser.add_argument("--skip-images", action="store_true",
                        help="JSON only; nothing is written to --resources")
    parser.add_argument("--no-cache", action="store_true", help="ignore tools/cache/")
    parser.add_argument("--verify-codes", action="store_true",
                        help="print every decoded comp team code (verification always runs)")
    parser.add_argument("--max-comps", type=int, default=None, help="only build the first N comps")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    started = time.time()
    generated_at = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    fetcher = Fetcher(use_cache=not args.no_cache)
    sources = load_sources(fetcher)

    cd_set_en = set_data(sources["cd_en"])
    trait_name_to_id = {}
    for trait in cd_set_en.get("traits") or []:
        if trait.get("name"):
            trait_name_to_id.setdefault(trait["name"], trait["apiName"])
    trait_ids = set(trait_name_to_id.values())

    rules = load_rules()
    lookup_patch = ((sources["lk_en"].get("_metadata") or {}).get("patch") or "").strip()
    if not lookup_patch or lookup_patch.lower() == "pbe":
        patch = rules.get("patch") or "unknown"
        log("Lookup patch is %r; using rules.json patch %s" % (lookup_patch, patch))
    else:
        patch = lookup_patch

    comps_payload = sources["comps"]
    comps_data = (comps_payload.get("results") or {}).get("data") or {}
    clusters = comps_data.get("cluster_details") or {}
    first_key = sorted(clusters.keys())[0] if clusters else None
    cluster_id = comps_data.get("cluster_id") or comps_payload.get("cluster_id")

    lookup_units = unit_alias_index(sources["lk_en"])
    alias_to_id = {}
    for entry in sources["tp"].get(SET_KEY) or []:
        canonical = entry.get("character_id")
        if not canonical:
            continue
        alias_to_id[canonical] = canonical
        unit = lookup_units.get(canonical) or {}
        for asset in (unit.get("assetNames") or []) + [unit.get("apiName"), unit.get("characterName")]:
            if asset and asset not in alias_to_id:
                alias_to_id[asset] = canonical

    items = build_items(sources, trait_name_to_id)
    item_ids = set(item["id"] for item in items)
    recommended = build_recommended_items(fetcher, first_key, cluster_id, alias_to_id)
    champions = build_champions(sources, trait_name_to_id, recommended, item_ids)
    traits = build_traits(sources, champions)
    augments = build_augments(sources, trait_name_to_id, trait_ids)

    if len(champions) < MIN_CHAMPIONS:
        raise SystemExit("FATAL: only %d champions built (expected >= %d)" % (len(champions), MIN_CHAMPIONS))

    gamedata = OrderedDict([
        ("schemaVersion", SCHEMA_VERSION),
        ("generatedAt", generated_at),
        ("set", OrderedDict([("key", SET_KEY), ("number", SET_NUMBER),
                             ("name", set_name(sources, cd_set_en)), ("patch", patch)])),
        ("champions", champions),
        ("traits", traits),
        ("items", items),
        ("augments", augments),
        ("rules", rules),
    ])

    assert_metatft_units_resolve(sources, champions)

    metatft_comps, comps_cluster_id = build_comps(fetcher, sources, gamedata, args.max_comps)

    log("Fetching comp sources …")
    source_records, source_status = collect_sources(fetcher, gamedata, metatft_comps,
                                                    generated_at)
    clusters = cluster_records(source_records)
    log("Consensus: %d source comps -> %d clusters"
        % (sum(len(records) for records in source_records.values()), len(clusters)))
    comps = build_consensus_comps(clusters, dict((comp["id"], comp) for comp in metatft_comps),
                                  gamedata, load_translations())
    finalize_comps(comps, dict((champion["id"], champion) for champion in champions),
                   dict((trait["id"], trait) for trait in traits),
                   dict((item["id"], item) for item in items))
    if not args.max_comps and len(comps) < MIN_COMPS:
        raise SystemExit("FATAL: only %d comps built (expected >= %d)" % (len(comps), MIN_COMPS))

    log("Verifying team codes …")
    verify_team_codes(comps, champions, verbose=args.verify_codes)
    problems = verify_references(gamedata, comps)
    if problems:
        raise SystemExit("FATAL: %d dangling references, e.g. %s" % (len(problems), problems[:5]))
    offenders = verify_text(gamedata, comps)
    if offenders:
        raise SystemExit("FATAL: %d descriptions still contain markup, e.g. %s" % (len(offenders), offenders[:5]))

    comps_document = OrderedDict([
        ("schemaVersion", SCHEMA_VERSION),
        ("generatedAt", generated_at),
        ("source", "MetaTFT"),
        ("set", SET_KEY),
        ("patch", patch),
        ("clusterId", comps_cluster_id),
        ("sources", source_status),
        ("comps", comps),
    ])

    image_counts = {"downloaded": 0, "failed": 0}
    resources_dir = None if args.skip_images else args.resources
    if not args.skip_images:
        image_counts = download_images(fetcher, gamedata, os.path.join(args.resources, "Images"))

    documents = OrderedDict([
        ("gamedata.json", gamedata),
        ("comps.json", comps_document),
        ("guides.json", load_guides(generated_at)),
        ("manifest.json", OrderedDict([
            ("schemaVersion", SCHEMA_VERSION),
            ("generatedAt", generated_at),
            ("patch", patch),
            ("files", OrderedDict([("gamedata", "gamedata.json"),
                                   ("comps", "comps.json"),
                                   ("guides", "guides.json")])),
        ])),
    ])
    write_outputs(documents, args.out, resources_dir)

    print_summary(gamedata, comps, image_counts, args, started, source_status, source_records,
                  len(clusters))
    return 0


def assert_metatft_units_resolve(sources, champions):
    """Every MetaTFT unit id used by comps must map to a canonical champion."""
    known = set()
    for champion in champions:
        known.add(champion["id"])
        known.update(champion["aliases"])
    clusters = ((sources["comps"].get("results") or {}).get("data") or {}).get("cluster_details") or {}
    unresolved = set()
    for cluster in clusters.values():
        for unit_id in split_units(cluster.get("units_string")):
            if unit_id not in known:
                unresolved.add(unit_id)
        for unit_id in cluster.get("stars") or []:
            if unit_id not in known:
                unresolved.add(unit_id)
    if unresolved:
        raise SystemExit("FATAL: MetaTFT unit ids do not resolve: %s" % ", ".join(sorted(unresolved)))
    log("All MetaTFT unit ids resolve to canonical champions.")


def print_summary(gamedata, comps, image_counts, args, started, source_status=None,
                  source_records=None, cluster_count=0):
    tier_counts = OrderedDict()
    for comp in comps:
        tier_counts[comp["tier"]] = tier_counts.get(comp["tier"], 0) + 1
    log("")
    log("=" * 68)
    log("HexKoc data build complete in %.1f s" % (time.time() - started))
    log("  set            : %s (%s) patch %s"
        % (gamedata["set"]["key"], gamedata["set"]["name"], gamedata["set"]["patch"]))
    log("  champions      : %d" % len(gamedata["champions"]))
    log("  traits         : %d" % len(gamedata["traits"]))
    log("  items          : %d" % len(gamedata["items"]))
    log("  augments       : %d (%d without icon)"
        % (len(gamedata["augments"]), sum(1 for a in gamedata["augments"] if not a["icon"])))
    log("  comps          : %d (%s)"
        % (len(comps), ", ".join("%s:%d" % (tier, count) for tier, count in sorted(tier_counts.items()))))
    if source_status:
        log("  sources        : %s"
            % ", ".join("%s %s" % (entry["key"], entry["count"] if entry["ok"] else "FAILED")
                        for entry in source_status))
        multi = sum(1 for comp in comps if comp["sourceCount"] >= 2)
        situational = sum(1 for comp in comps if comp["situational"])
        translated = sum(1 for comp in comps for tip in comp["sourceTips"] if tip["tr"])
        tips_total = sum(len(comp["sourceTips"]) for comp in comps)
        log("  clusters       : %d (%d comps with >= 2 sources, %d situational)"
            % (cluster_count, multi, situational))
        log("  source tips    : %d (%d translated)" % (tips_total, translated))
        unmatched = OrderedDict()
        for comp in comps:
            if comp["sourceCount"] != 1:
                continue
            key = comp["sources"][0]["key"]
            if key in comp_sources.STATS_ONLY_SOURCES:
                continue
            unmatched.setdefault(key, []).append(comp["name"]["en"])
        if unmatched:
            for key, names in unmatched.items():
                log("  unmatched %-6s: %d (%s)"
                    % (key, len(names), name_list(sorted(names), 4)))
        else:
            log("  unmatched      : 0 curated comps stand alone")
    log("  images         : %d new, %d failed%s"
        % (image_counts["downloaded"], image_counts["failed"], " (skipped)" if args.skip_images else ""))
    log("  unresolved tok : %d (%d distinct)"
        % (len(UNRESOLVED_TOKENS), len(set(UNRESOLVED_TOKENS))))
    log("  warnings       : %d" % len(WARNINGS))
    log("  json out       : %s%s" % (args.out, "" if args.skip_images else " + %s/Data" % args.resources))
    log("=" * 68)


if __name__ == "__main__":
    sys.exit(main())
