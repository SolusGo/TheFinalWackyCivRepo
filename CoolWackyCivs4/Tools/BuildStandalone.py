"""Build an unpacked Civ V mod with its .modinfo without requiring ModBuddy."""

import argparse
import hashlib
from pathlib import Path
from shutil import copyfile
from xml.etree import ElementTree as ET

from Validate import NS, ROOT, findtext


PROPERTIES = (
    "Name", "Stability", "Teaser", "Description", "Authors", "HideSetupGame", "Homepage",
    "AffectsSavedGames", "MinCompatibleSaveVersion", "SupportsSinglePlayer",
    "SupportsMultiplayer", "SupportsHotSeat", "SupportsMac", "ReloadAudioSystem",
    "ReloadLandmarkSystem", "ReloadStrategicViewSystem", "ReloadUnitSystem",
)


def build(output_parent):
    project = ET.parse(ROOT / "CoolWackyCivs4.civ5proj")
    settings = project.find("m:PropertyGroup", NS)
    name = findtext(settings, "m:Name")
    version = findtext(settings, "m:ModVersion")
    folder = output_parent / f"{name} (v {version})"
    folder.mkdir(parents=True)

    manifest = ET.Element("Mod", id=findtext(settings, "m:Guid"), version=version)
    properties = ET.SubElement(manifest, "Properties")
    for key in PROPERTIES:
        value = findtext(settings, f"m:{key}")
        if value is None and key != "HideSetupGame":
            continue
        ET.SubElement(properties, key).text = {"true": "1", "false": "0"}.get(
            (value or "").lower(), value or "0"
        )

    dependencies = ET.SubElement(manifest, "Dependencies")
    for dependency in settings.findall("m:ModDependencies/m:Association", NS):
        attributes = {
            key.lower(): findtext(dependency, f"m:{key}") for key in ("Id", "MinVersion", "MaxVersion")
        }
        kind = findtext(dependency, "m:Type")
        if kind == "Mod":
            attributes["title"] = findtext(dependency, "m:Name")
        ET.SubElement(dependencies, kind, attributes)
    ET.SubElement(manifest, "References")
    ET.SubElement(manifest, "Blocks")

    files = ET.SubElement(manifest, "Files")
    for item in project.findall("./m:ItemGroup/m:Content", NS):
        path = item.attrib["Include"]
        destination = folder / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        copyfile(ROOT / path, destination)
        imported = findtext(item, "m:ImportIntoVFS").lower() == "true"
        ET.SubElement(files, "File", md5=hashlib.md5(destination.read_bytes()).hexdigest().upper(),
                      **{"import": str(int(imported))}).text = path

    actions = ET.SubElement(manifest, "Actions")
    for action in settings.findall("m:ModActions/m:Action", NS):
        trigger = findtext(action, "m:Set")
        group = actions.find(trigger)
        if group is None:
            group = ET.SubElement(actions, trigger)
        ET.SubElement(group, findtext(action, "m:Type")).text = findtext(action, "m:FileName")

    entry_points = ET.SubElement(manifest, "EntryPoints")
    for content in settings.findall("m:ModContent/m:Content", NS):
        entry = ET.SubElement(entry_points, "EntryPoint", type=findtext(content, "m:Type"),
                              file=findtext(content, "m:FileName"))
        for key in ("Name", "Description"):
            ET.SubElement(entry, key).text = findtext(content, f"m:{key}")

    ET.indent(manifest, space="  ")
    result = folder / f"{folder.name}.modinfo"
    ET.ElementTree(manifest).write(result, encoding="utf-8", xml_declaration=True)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_parent", type=Path, help="Parent for a new unpacked mod folder")
    args = parser.parse_args()
    try:
        print(build(args.output_parent.resolve()))
    except FileExistsError as error:
        parser.exit(1, f"Choose an output parent without an existing build: {error.filename}\n")
