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
    gameplay = {p.relative_to(ROOT).as_posix() for p in CIV.rglob("*")
                if p.is_file() and "Documentation" not in p.parts}
    assert gameplay == registrations.keys(), (gameplay - registrations.keys(), registrations.keys() - gameplay)
    actions = [findtext(node, "m:FileName") for node in project.findall(".//m:ModActions/m:Action", NS)]
    assert len(actions) == len(set(actions)) == 4
    assert all(not registrations[path] for path in actions)
    assert all(imported for path, imported in registrations.items() if path not in actions)
    addins = [findtext(node, "m:FileName") for node in project.findall(".//m:ModContent/m:Content", NS)]
    assert len(addins) == 1 and registrations[addins[0]] and addins[0].endswith("ARACHNID_Console.xml")
    ui = ET.parse(ROOT / addins[0])
    assert ui.find("./Script").attrib["file"] == "ARACHNID_Console.lua"
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
    for path in CIV.rglob("*.xml"):
        ET.parse(path)
    return registrations, actions, addins


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
        assert one("SELECT FriendlyHealChange, NeutralHealChange, EnemyHealChange FROM UnitPromotions WHERE Type='PROMOTION_ARACHNID_REGENERATION'") == (5, 5, 5)
        for option in ("EVENTS_BATTLES", "EVENTS_UNIT_PREKILL", "EVENTS_UNIT_CONVERTS", "EVENTS_CITY",
                       "EVENTS_NEW_ERA", "EVENTS_RED_COMBAT", "EVENTS_RED_COMBAT_RESULT", "EVENTS_RED_COMBAT_ENDED"):
            assert one("SELECT Value FROM CustomModOptions WHERE Name=?", option) == (1,)
        ranged = ["ARCHER", "COMPOSITE_BOWMAN", "CROSSBOWMAN", "GATLINGGUN", "MACHINE_GUN", "BAZOOKA"]
        for name, next_name in zip(ranged, ranged[1:]):
            unit = "UNIT_ARACHNID_BLACK_WIDOW" if name == "ARCHER" else "UNIT_" + name
            assert one("SELECT UnitClassType FROM Unit_ClassUpgrades WHERE UnitType=?", unit) == ("UNITCLASS_" + next_name,)
        for name in ranged:
            row = one("SELECT Domain, RangedCombat, Range, PrereqTech FROM Units WHERE Type=?", "UNIT_" + name)
            assert row[0] == "DOMAIN_LAND" and row[1] > 0 and row[2] > 0 and row[3]
        print("BNW + Community Patch database validation passed.")


def assets():
    atlases = ET.parse(CIV / "XML" / "ARACHNID_Atlases.xml")
    for row in atlases.findall("./IconTextureAtlases/Row"):
        size = int(row.findtext("IconSize"))
        width, height = (size * int(row.findtext(field)) for field in ("IconsPerRow", "IconsPerColumn"))
        asset = CIV / "Art" / row.findtext("Filename")
        with asset.open("rb") as handle:
            header = handle.read(128)
        assert header[:4] == b"DDS " and struct.unpack_from("<II", header, 12) == (height, width), asset.name
    for name, size in {"Dawn": (1024, 768), "Diplomacy": (1280, 960), "Map": (360, 410),
                       "Panel": (888, 608), "Tree": (848, 388)}.items():
        header = (CIV / "Art" / f"ARACHNID_{name}.dds").read_bytes()[:128]
        assert header[:4] == b"DDS " and struct.unpack_from("<II", header, 12)[::-1] == size, name
    print("DDS references and dimensions passed.")


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
