"""Validate the source and optionally the build against a read-only BNW + CP cache."""
import argparse
import hashlib
from pathlib import Path
import re
import sqlite3
import struct
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CIV = ROOT / "Civilizations" / "ArachnidEmpire"
DOMINION = ROOT / "Civilizations" / "ScorpionDominion"
WERRIBEE = ROOT / "Civilizations" / "WerribeePropertyNetwork"
CIVILIZATIONS = (CIV, DOMINION, WERRIBEE)
GUID = "4e2d7f10-235f-4323-95ec-6bda1a25d27a"
CP_GUID = "d1b6328c-ff44-4b0d-aad7-c657f83610cd"
NS = {"m": "http://schemas.microsoft.com/developer/msbuild/2003"}


def findtext(element, path):
    return element.findtext(path, namespaces=NS)


def source():
    project = ET.parse(ROOT / "CoolWackyCivs4.civ5proj")
    assert findtext(project, ".//m:Guid") == GUID
    assert findtext(project, ".//m:ProjectGuid") == "{D945A80A-4E05-4479-AD9F-46FBD36F7C21}"
    registrations = {}
    for item in project.findall("./m:ItemGroup/m:Content", NS):
        path = item.attrib["Include"]
        assert path not in registrations and "/" in path and (ROOT / path).is_file(), path
        registrations[path] = findtext(item, "m:ImportIntoVFS").lower() == "true"
    gameplay = {p.relative_to(ROOT).as_posix() for civ in CIVILIZATIONS for p in civ.rglob("*")
                if p.is_file() and "Documentation" not in p.parts}
    assert gameplay == registrations.keys(), (gameplay - registrations.keys(), registrations.keys() - gameplay)
    actions = [findtext(node, "m:FileName") for node in project.findall(".//m:ModActions/m:Action", NS)]
    assert len(actions) == len(set(actions)) == 12
    assert all(not registrations[path] for path in actions)
    assert all(imported for path, imported in registrations.items() if path not in actions)
    addins = [findtext(node, "m:FileName") for node in project.findall(".//m:ModContent/m:Content", NS)]
    assert [Path(addin).name for addin in addins] == [
        "ARACHNID_Console.xml", "SDOM_Council.xml", "WERRIBEE_Gameplay.xml",
    ]
    for addin in addins:
        assert registrations[addin]
        ui = ET.parse(ROOT / addin)
        script = ui.find("./Script").attrib["file"]
        relative = Path(addin).parent.parent
        assert sum(path in registrations and registrations[path] for path in [
            Path(addin).with_name(script).as_posix(), (relative / "Lua" / script).as_posix(),
        ]) == 1
    cp, = [node for node in project.findall(".//m:ModDependencies/m:Association", NS)
           if findtext(node, "m:Id") == CP_GUID]
    assert findtext(cp, "m:MinVersion") == findtext(cp, "m:MaxVersion") == "151"
    names = [path.name.lower() for path in CIV.rglob("*") if path.is_file() and "Documentation" not in path.parts]
    assert len(names) == len(set(names)) and all(name.startswith("arachnid_") for name in names)
    text_path = CIV / "Text" / "ARACHNID_Text.xml"
    language = ET.parse(text_path).findall("./Language_en_US/Row")
    keys = {row.attrib["Tag"] for row in language}
    assert len(keys) == len(language)
    for path in [*CIV.rglob("*.sql"), *CIV.rglob("*.xml")]:
        for key in re.findall(r"TXT_KEY_ARACHNID_[A-Z0-9_]+", path.read_text(encoding="utf8")):
            if key == "TXT_KEY_ARACHNID_GREETING_":
                assert key + "1" in keys
            elif key in {"TXT_KEY_ARACHNID_HISTORY", "TXT_KEY_ARACHNID_QUEEN_HISTORY"}:
                assert key + "_HEADING_1" in keys and key + "_TEXT_1" in keys
            else:
                assert key in keys, (path.name, key)
    dominion_locale()
    werribee_locale()
    runtime_names = [Path(path).name.lower() for path in registrations]
    assert len(runtime_names) == len(set(runtime_names))
    for civ in CIVILIZATIONS:
        for path in civ.rglob("*.xml"):
            ET.parse(path)
    return registrations, actions, addins


def dominion_locale():
    language = ET.parse(DOMINION / "Text" / "SDOM_Text.xml")
    rows = language.findall("./Language_en_US/Row")
    keys = {row.attrib["Tag"] for row in rows}
    assert len(rows) == len(keys)
    for path in [*DOMINION.rglob("*.sql"), *DOMINION.rglob("*.xml")]:
        if path.name == "SDOM_Text.xml":
            continue
        for key in re.findall(r"TXT_KEY_SDOM_[A-Z0-9_]+", path.read_text(encoding="utf8")):
            assert key in keys or key + "_HEADING_1" in keys and key + "_TEXT_1" in keys, (path, key)
    for row in language.findall("./Diplomacy_Responses/Row"):
        assert row.attrib["Response"].replace("%", "1") in keys
    for path in DOMINION.rglob("*.lua"):
        for key in re.findall(r'"((?:ERR|REASON)_[A-Z_]+)"', path.read_text(encoding="utf8")):
            assert "TXT_KEY_SDOM_" + key in keys, (path, key)


def werribee_locale():
    language = ET.parse(WERRIBEE / "Text/WERRIBEE_Text.xml")
    rows = language.findall("./Language_en_US/Row")
    keys = {row.attrib["Tag"] for row in rows}
    assert len(rows) == len(keys)
    for path in WERRIBEE.glob("SQL/*.sql"):
        for key in re.findall(r"TXT_KEY_WERRIBEE_[A-Z0-9_]+", path.read_text(encoding="utf8")):
            assert key in keys or key + "_HEADING_1" in keys and key + "_TEXT_1" in keys, (path, key)
    for row in language.findall("./Diplomacy_Responses/Row"):
        assert row.attrib["Response"].replace("%", "1") in keys
    for key in ("SALE_BODY", "SALE_TITLE", "MISSION_BODY", "MISSION_TITLE", "LYNNE_TITLE"):
        assert "TXT_KEY_WERRIBEE_" + key in keys


def database(cache, actions):
    with sqlite3.connect(":memory:") as db, sqlite3.connect(cache.resolve().as_uri() + "?mode=ro", uri=True) as baseline:
        baseline.backup(db)
        # Save caches may already contain this mod. Require a clean baseline for meaningful checks.
        assert not db.execute("SELECT 1 FROM Civilizations WHERE Type='CIVILIZATION_ARACHNID_EMPIRE'").fetchone()
        for action in actions:
            path = ROOT / action
            if path.suffix == ".sql":
                db.executescript(path.read_text(encoding="utf8"))
                continue
            for table in ET.parse(path).getroot():
                if table.tag == "Language_en_US":
                    db.execute("CREATE TABLE IF NOT EXISTS Language_en_US (Tag TEXT, Text TEXT)")
                for row in table:
                    data = {**row.attrib, **{child.tag: child.text for child in row}}
                    values = ", ".join("?" for _ in data)
                    db.execute(f"INSERT INTO {table.tag} ({', '.join(data)}) VALUES ({values})", list(data.values()))

        def one(query, *args):
            result = db.execute(query, args).fetchone()
            assert result is not None, query
            return result

        assert one("SELECT Playable, AIPlayable FROM Civilizations WHERE Type='CIVILIZATION_ARACHNID_EMPIRE'") == (1, 0)
        assert one("SELECT COUNT(*) FROM Civilization_CityNames WHERE CivilizationType='CIVILIZATION_ARACHNID_EMPIRE'") == (25,)
        for table, column, source, target, omitted in [
            ("Units", "UnitType", "UNIT_ARCHER", "UNIT_ARACHNID_BLACK_WIDOW",
             {"ID", "Type", "RangedCombat", "Description", "Civilopedia", "Strategy", "Help",
              "IconAtlas", "PortraitIndex", "UnitFlagAtlas", "UnitFlagIconOffset"}),
            ("Buildings", "BuildingType", "BUILDING_BARRACKS", "BUILDING_ARACHNID_BROOD_CHAMBER",
             {"ID", "Type", "Description", "Civilopedia", "Strategy", "Help", "IconAtlas", "PortraitIndex"}),
        ]:
            columns = [r[1] for r in db.execute(f"PRAGMA table_info({table})") if r[1] not in omitted]
            query = f"SELECT {', '.join(columns)} FROM {table} WHERE Type=?"
            assert one(query, source) == one(query, target)
            for name, in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
                                    ("Unit_%" if table == "Units" else "Building_%",)):
                fields = [r[1] for r in db.execute(f"PRAGMA table_info({name})")]
                if column in fields:
                    rest = ", ".join(f for f in fields if f != column)
                    query = f"SELECT {rest} FROM {name} WHERE {column}=? ORDER BY {rest}"
                    assert db.execute(query, (source,)).fetchall() == db.execute(query, (target,)).fetchall(), name

        assert one("SELECT Combat, RangedCombat, Moves, Range, Cost FROM Units WHERE Type='UNIT_ARACHNID_BLACK_WIDOW'") == (5, 8, 2, 2, 40)
        assert one("SELECT Cost, FaithCost, NeverCapture, ConquestProb, ShowInPedia, IsDummy FROM Buildings WHERE Type='BUILDING_ARACHNID_CHAMBER_SCIENCE'") == (-1, -1, 1, 0, 0, 1)
        assert one("SELECT Yield FROM Building_YieldChanges WHERE BuildingType='BUILDING_ARACHNID_CHAMBER_SCIENCE' AND YieldType='YIELD_SCIENCE'") == (1,)
        assert one("SELECT DefenseMod FROM UnitPromotions WHERE Type='PROMOTION_ARACHNID_ARMOURED'") == (15,)
        assert one("SELECT CombatPercent FROM UnitPromotions WHERE Type='PROMOTION_ARACHNID_APEX'") == (10,)
        assert one("SELECT COUNT(*) FROM UnitPromotions WHERE Type GLOB 'PROMOTION_ARACHNID_*' AND LostOnGifting=1 AND CannotBeChosen=1") == (6,)
        assert one("SELECT FriendlyHealChange, NeutralHealChange, EnemyHealChange FROM UnitPromotions WHERE Type='PROMOTION_ARACHNID_REGENERATION'") == (5, 5, 5)
        for option in ("EVENTS_BATTLES", "EVENTS_UNIT_PREKILL", "EVENTS_UNIT_CONVERTS", "EVENTS_UNIT_CREATED", "EVENTS_CITY",
                       "EVENTS_NEW_ERA", "EVENTS_RED_COMBAT", "EVENTS_RED_COMBAT_RESULT", "EVENTS_RED_COMBAT_ENDED"):
            assert one("SELECT Value FROM CustomModOptions WHERE Name=?", option) == (1,)
        ranged = ["ARCHER", "COMPOSITE_BOWMAN", "CROSSBOWMAN", "GATLINGGUN", "MACHINE_GUN", "BAZOOKA"]
        for name, next_name in zip(ranged, ranged[1:]):
            unit = "UNIT_ARACHNID_BLACK_WIDOW" if name == "ARCHER" else "UNIT_" + name
            assert one("SELECT UnitClassType FROM Unit_ClassUpgrades WHERE UnitType=?", unit) == ("UNITCLASS_" + next_name,)
        for name in ranged:
            row = one("SELECT Domain, RangedCombat, Range, PrereqTech FROM Units WHERE Type=?", "UNIT_" + name)
            assert row[0] == "DOMAIN_LAND" and row[1] > 0 and row[2] > 0 and row[3]
        dominion_database(db, one)
        werribee_database(db, one)
        print("BNW + Community Patch database validation passed.")


def dominion_database(db, one):
    civ = "CIVILIZATION_SCORPION_DOMINION"
    unit = "UNIT_SDOM_EMPEROR_SCORPION"
    building = "BUILDING_SDOM_MOLTING_CHAMBER"
    assert one("SELECT Playable, AIPlayable FROM Civilizations WHERE Type=?", civ) == (1, 0)
    assert one("SELECT LeaderheadType FROM Civilization_Leaders WHERE CivilizationType=?", civ) == ("LEADER_SDOM_OVERLORD",)
    assert one("SELECT TraitType FROM Leader_Traits WHERE LeaderType='LEADER_SDOM_OVERLORD'") == ("TRAIT_SDOM_SURVIVAL",)
    cities = db.execute("SELECT CityName FROM Civilization_CityNames WHERE CivilizationType=? ORDER BY rowid", (civ,))
    assert [name for name, in cities] == [f"TXT_KEY_SDOM_CITY_{i}" for i in range(1, 21)]
    assert one("SELECT UnitClassType, UnitType FROM Civilization_UnitClassOverrides WHERE CivilizationType=?", civ) == ("UNITCLASS_SWORDSMAN", unit)
    assert one("SELECT BuildingClassType, BuildingType FROM Civilization_BuildingClassOverrides WHERE CivilizationType=?", civ) == ("BUILDINGCLASS_ARMORY", building)
    assert one("SELECT Combat, Moves, Cost, PrereqTech FROM Units WHERE Type=?", unit) == (15, 2, 75, "TECH_IRON_WORKING")
    assert one("SELECT ResourceType, Cost FROM Unit_ResourceQuantityRequirements WHERE UnitType=?", unit) == ("RESOURCE_IRON", 1)
    assert one("SELECT PromotionType FROM Unit_FreePromotions WHERE UnitType=? AND PromotionType LIKE 'PROMOTION_SDOM_%'", unit) == ("PROMOTION_SDOM_EXOSKELETON",)
    assert one("SELECT UnitClassType FROM Unit_ClassUpgrades WHERE UnitType=?", unit) == ("UNITCLASS_LONGSWORDSMAN",)
    for kind in ("WARRIOR", "SWORDSMAN", "LONGSWORDSMAN", "MUSKETMAN", "RIFLEMAN",
                 "GREAT_WAR_INFANTRY", "INFANTRY", "MECHANIZED_INFANTRY"):
        assert one("SELECT Class, Domain, RangedCombat FROM Units WHERE Type=?", "UNIT_" + kind) == ("UNITCLASS_" + kind, "DOMAIN_LAND", 0)
    for table, column, fields in (
        ("Buildings", "Type", "Cost, GoldMaintenance, PrereqTech, BuildingClass"),
        ("Building_DomainFreeExperiences", "BuildingType", "DomainType, Experience"),
        ("Building_ClassesNeededInCity", "BuildingType", "BuildingClassType"),
    ):
        query = f"SELECT {fields} FROM {table} WHERE {column}=? ORDER BY {fields}"
        assert db.execute(query, (building,)).fetchall() == db.execute(query, ("BUILDING_ARMORY",)).fetchall()
    assert db.execute("SELECT YieldType, Yield FROM Building_YieldChanges WHERE BuildingType=? ORDER BY Yield", (building,)).fetchall() == [("YIELD_PRODUCTION", 1), ("YIELD_SCIENCE", 2)]
    for suffix, values in {
        "ASCENDANT": (10, 0, 0, 0, 0, 1),
        "PINCERS": (0, 15, 0, 0, 0, 1),
        "CARAPACE": (0, 0, 20, 0, 0, 1),
        "APEX": (0, 0, 0, 10, 5, 1),
        "EXOSKELETON": (0, 0, 15, 0, 0, 0),
    }.items():
        query = """SELECT DefenseMod, AttackMod, RangedDefenseMod, CombatPercent, FriendlyHealChange,
                          LostOnGifting, CannotBeChosen, LostWithUpgrade FROM UnitPromotions WHERE Type=?"""
        assert one(query, "PROMOTION_SDOM_" + suffix) == (*values, 1, 0)
    for slot in range(1, 7):
        dummy = f"BUILDING_SDOM_APEX_{slot}"
        assert one("SELECT Cost, FaithCost, NeverCapture, ConquestProb, ShowInPedia, IsDummy FROM Buildings WHERE Type=?", dummy) == (-1, -1, 1, 0, 0, 1)
        assert one("SELECT YieldType, Yield FROM Building_YieldChanges WHERE BuildingType=?", dummy) == ("YIELD_SCIENCE", 2)
    for kind, value in (("MARATHON", 300), ("STANDARD", 100), ("EPIC", 150), ("QUICK", 67)):
        assert one("SELECT TrainPercent FROM GameSpeeds WHERE Type=?", "GAMESPEED_" + kind) == (value,)
    for option in ("EVENTS_UNIT_PREKILL", "EVENTS_UNIT_CREATED", "EVENTS_UNIT_CONVERTS", "EVENTS_UNIT_CAPTURE",
                   "EVENTS_CITY", "EVENTS_CITY_CAPITAL", "EVENTS_NEW_ERA"):
        assert one("SELECT Value FROM CustomModOptions WHERE Name=?", option) == (1,)


def werribee_database(db, one):
    civ = "CIVILIZATION_WERRIBEE_PROPERTY_NETWORK"
    leader = "LEADER_LYNNE_STEINHAUER"
    unit = "UNIT_WERRIBEE_SENIOR_SALES_CONSULTANT"
    office = "BUILDING_WERRIBEE_REAL_ESTATE_OFFICE"
    assert one("SELECT Playable, AIPlayable FROM Civilizations WHERE Type=?", civ) == (1, 1)
    assert one("""SELECT IconAtlas, AlphaIconAtlas, PortraitIndex, MapImage, DawnOfManImage
                  FROM Civilizations WHERE Type=?""", civ) == (
        "WERRIBEE_ATLAS", "WERRIBEE_ALPHA_ATLAS", 0, "WERRIBEE_Map.dds", "WERRIBEE_Dawn.dds",
    )
    assert one("SELECT ArtDefineTag, IconAtlas, PortraitIndex FROM Leaders WHERE Type=?", leader) == (
        "WERRIBEE_LeaderScene.xml", "WERRIBEE_ATLAS", 1,
    )
    scene = ET.parse(WERRIBEE / "Art/WERRIBEE_LeaderScene.xml").getroot()
    assert scene.attrib["FallbackImage"] == "WERRIBEE_Diplomacy.dds"
    assert one("SELECT IconAtlas, PortraitIndex, UnitFlagAtlas, UnitFlagIconOffset FROM Units WHERE Type=?",
               unit) == ("WERRIBEE_ATLAS", 2, "WERRIBEE_FLAG_ATLAS", 0)
    assert one("SELECT IconAtlas, PortraitIndex FROM Buildings WHERE Type=?", office) == ("WERRIBEE_ATLAS", 3)
    assert one("SELECT LeaderheadType FROM Civilization_Leaders WHERE CivilizationType=?", civ) == (leader,)
    assert one("SELECT TraitType FROM Leader_Traits WHERE LeaderType=?", leader) == ("TRAIT_SOLD_UNDER_THE_HAMMER",)
    assert one("SELECT PrimaryVictoryPursuit, SecondaryVictoryPursuit FROM Leaders WHERE Type=?", leader) == (
        "VICTORY_PURSUIT_DIPLOMACY", "VICTORY_PURSUIT_SCIENCE",
    )
    for table, column, label, count in (
        ("Civilization_CityNames", "CityName", "CITY", 25), ("Civilization_SpyNames", "SpyName", "SPY", 10),
    ):
        query = f"SELECT {column} FROM {table} WHERE CivilizationType=? ORDER BY rowid"
        assert db.execute(query, (civ,)).fetchall() == [(f"TXT_KEY_WERRIBEE_{label}_{i}",) for i in range(1, count + 1)]
    assert one("SELECT UnitClassType, UnitType FROM Civilization_UnitClassOverrides WHERE CivilizationType=?", civ) == (
        "UNITCLASS_MERCHANT", unit,
    )
    assert one("SELECT BuildingClassType, BuildingType FROM Civilization_BuildingClassOverrides WHERE CivilizationType=?", civ) == (
        "BUILDINGCLASS_MARKET", office,
    )
    shared_exclusions = {"ID", "Type", "Description", "Civilopedia", "Strategy", "Help", "IconAtlas", "PortraitIndex"}
    for table, original, clone, column, excluded in (
        ("Units", "UNIT_MERCHANT", unit, "UnitType", shared_exclusions | {"UnitFlagAtlas", "UnitFlagIconOffset"}),
        ("Buildings", "BUILDING_MARKET", office, "BuildingType", shared_exclusions),
    ):
        fields = ", ".join(row[1] for row in db.execute(f"PRAGMA table_info({table})") if row[1] not in excluded)
        query = f"SELECT {fields} FROM {table} WHERE Type=?"
        assert one(query, original) == one(query, clone)
        for related, in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE ?",
                                   ("Unit%" if table == "Units" else "Building_%",)):
            fields = [row[1] for row in db.execute(f"PRAGMA table_info({related})")]
            if column not in fields or related == "Building_ImprovementYieldChanges":
                continue
            rest = ", ".join(field for field in fields if field not in (column, "ID"))
            query = f"SELECT {rest} FROM {related} WHERE {column}=? ORDER BY {rest}"
            assert db.execute(query, (original,)).fetchall() == db.execute(query, (clone,)).fetchall(), related
    assert one("SELECT PrereqTech FROM Buildings WHERE Type=?", office) == ("TECH_CURRENCY",)
    assert one("SELECT BuildType FROM Unit_Builds WHERE UnitType=?", unit) == ("BUILD_CUSTOMS_HOUSE",)
    assert one("SELECT GreatPeopleUnitClass FROM Specialists WHERE Type='SPECIALIST_MERCHANT'") == ("UNITCLASS_MERCHANT",)
    assert one("""SELECT OutsideBorders, InAdjacentFriendly, InEnemyTerritory, IgnoreOwnership
                  FROM Improvements WHERE Type='IMPROVEMENT_CUSTOMS_HOUSE'""") == (0, 0, 0, 0)
    assert db.execute("""SELECT ImprovementType, YieldType, Yield FROM Building_ImprovementYieldChanges
                         WHERE BuildingType=? ORDER BY ImprovementType""", (office,)).fetchall() == [
        (f"IMPROVEMENT_{improvement}", "YIELD_GOLD", 1) for improvement in ("FARM", "PASTURE", "TRADING_POST")
    ]
    for suffix, flat, gold, production, great_people, building_production in [
        ("PRIME_REAL_ESTATE", 1, 0, 0, 0, 0), ("PROPERTY_SALE", 0, 0, 10, 0, 0),
        ("CONNECTED_SUBURB", 0, 5, 5, 0, 0), ("CONNECTED_METROPOLIS", 0, 10, 10, 0, 0),
        ("APPRAISAL_YIELD", 1, 0, 0, 0, 0), ("APPRAISAL_MODIFIER", 0, 10, 0, 0, 0),
        ("VENDOR_NETWORK", 0, 15, 0, 15, 0), ("HOUSING_DEMAND", 1, 0, 0, 0, 0),
        ("PROPERTY_BOOM", 0, 0, 0, 0, 10),
    ]:
        building = "BUILDING_WERRIBEE_DUMMY_" + suffix
        assert one("""SELECT Cost, FaithCost, GoldMaintenance, NeverCapture, ConquestProb, ShowInPedia, IsDummy,
                             GreatPeopleRateModifier, BuildingProductionModifier FROM Buildings WHERE Type=?""",
                   building) == (-1, -1, 0, 1, 0, 0, 1, great_people, building_production)
        assert db.execute("SELECT YieldType, Yield FROM Building_YieldChanges WHERE BuildingType=?",
                          (building,)).fetchall() == ([("YIELD_GOLD", flat)] if flat else [])
        assert db.execute("""SELECT YieldType, Yield FROM Building_YieldModifiers WHERE BuildingType=?
                             ORDER BY YieldType""", (building,)).fetchall() == [
            (kind, amount) for kind, amount in [("YIELD_GOLD", gold), ("YIELD_PRODUCTION", production)] if amount
        ]
    for option in ("EVENTS_CITY", "EVENTS_CITY_CAPITAL", "EVENTS_GREAT_PEOPLE", "EVENTS_PLAYER_TURN",
                   "EVENTS_TILE_IMPROVEMENTS", "EVENTS_UNIT_CREATED", "EVENTS_UNIT_CONVERTS", "EVENTS_UNIT_PREKILL"):
        assert one("SELECT Value FROM CustomModOptions WHERE Name=?", option) == (1,)
    for column, table in [
        ("FlavorType", "Flavors"), ("MajorCivApproachType", "MajorCivApproachTypes"),
        ("MinorCivApproachType", "MinorCivApproachTypes"),
    ]:
        relation = {"FlavorType": "Leader_Flavors", "MajorCivApproachType": "Leader_MajorCivApproachBiases",
                    "MinorCivApproachType": "Leader_MinorCivApproachBiases"}[column]
        query = f"SELECT {column} FROM {relation} WHERE LeaderType=? EXCEPT SELECT Type FROM {table}"
        assert db.execute(query, (leader,)).fetchall() == []


def assets():
    for civ, prefix in ((CIV, "ARACHNID"), (DOMINION, "SDOM"), (WERRIBEE, "WERRIBEE")):
        atlas_assets(civ, prefix)
    print("DDS references and dimensions passed.")


def atlas_assets(civ, prefix):
    atlases = ET.parse(civ / "XML" / f"{prefix}_Atlases.xml")
    for row in atlases.findall("./IconTextureAtlases/Row"):
        size = int(row.findtext("IconSize"))
        width, height = (size * int(row.findtext(field)) for field in ("IconsPerRow", "IconsPerColumn"))
        asset = civ / "Art" / row.findtext("Filename")
        with asset.open("rb") as handle:
            header = handle.read(128)
        assert header[:4] == b"DDS " and struct.unpack_from("<II", header, 12) == (height, width), asset.name
    sizes = {"Dawn": (1024, 768), "Diplomacy": (1280, 960), "Map": (360, 410)}
    if civ == CIV:
        sizes.update({"Panel": (888, 608), "Tree": (848, 388)})
    elif civ == DOMINION:
        sizes["Panel"] = (904, 624)
    for name, size in sizes.items():
        header = (civ / "Art" / f"{prefix}_{name}.dds").read_bytes()[:128]
        assert header[:4] == b"DDS " and struct.unpack_from("<II", header, 12)[::-1] == size, name


def package(folder, registrations, actions, addins):
    manifest, = folder.glob("*.modinfo")
    mod = ET.parse(manifest).getroot()
    assert mod.attrib == {"id": GUID, "version": "1"}
    seen = set()
    for file in mod.findall("./Files/File"):
        assert file.text not in seen
        seen.add(file.text)
        assert file.attrib["import"] == str(int(registrations[file.text]))
        contents = (folder / file.text).read_bytes()
        assert file.attrib["md5"].lower() == hashlib.md5(contents).hexdigest()
        assert contents == (ROOT / file.text).read_bytes(), file.text
    assert seen == registrations.keys()
    assert [action.text for action in mod.findall("./Actions/OnModActivated/UpdateDatabase")] == actions
    assert [item.attrib["file"] for item in mod.findall("./EntryPoints/EntryPoint")] == addins
    assert mod.find(f"./Dependencies/Mod[@id='{CP_GUID}']").attrib["minversion"] == "151"
    print(f"Built manifest and all {len(seen)} runtime files passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, help="Unmodified Civ5DebugDatabase.db from BNW + CP v151")
    parser.add_argument("--build", type=Path, help="Folder containing the built .modinfo")
    options = parser.parse_args()
    registrations, actions, addins = source()
    print("Project registration, unique names, localization and XML passed.")
    assets()
    if options.database:
        database(options.database, actions)
    if options.build:
        package(options.build, registrations, actions, addins)
