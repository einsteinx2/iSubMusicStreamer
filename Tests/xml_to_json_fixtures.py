#!/usr/bin/env python3
"""Convert the captured XML Subsonic fixtures to their JSON equivalents.

The home-lab servers were offline when JSON support was added, so the JSON fixture
corpus is generated from the real captured XML fixtures using the documented
Subsonic XML->JSON mapping (attributes -> fields, repeated children -> arrays,
element text -> "value", schema-typed numbers/booleans). When the servers are back,
real captures should be diffed against these files (see Fixtures/README.md).

Usage: python3 Tests/xml_to_json_fixtures.py
"""

import json
import xml.etree.ElementTree as ET
from pathlib import Path

XML_DIR = Path(__file__).parent / "iSubTests" / "Fixtures" / "XML"
JSON_DIR = Path(__file__).parent / "iSubTests" / "Fixtures" / "JSON"

# Element names that are repeated in the schema and therefore always serialize as
# JSON arrays -- but only when they are NOT a direct payload of subsonic-response
# (e.g. <album> is an array member inside albumList but the lone payload of getAlbum).
ARRAY_NAMES = {
    "index", "artist", "album", "song", "child", "entry", "chatMessage",
    "musicFolder", "playlist", "shortcut", "match",
}

BOOL_ATTRS = {"isDir", "isVideo", "playing", "public", "openSubsonic"}
INT_ATTRS = {
    "track", "year", "size", "duration", "bitRate", "playCount", "songCount",
    "albumCount", "discNumber", "minutesAgo", "time", "lastModified", "code",
    "currentIndex", "position", "userRating", "playerId", "offset", "totalHits",
}
FLOAT_ATTRS = {"gain", "averageRating"}
SKIPPED_XML_ONLY = {"malformed.xml"}


def strip_ns(tag: str) -> str:
    return tag.split("}", 1)[1] if "}" in tag else tag


def typed(name: str, value: str):
    if name in BOOL_ATTRS:
        return value == "true"
    if name in INT_ATTRS:
        return int(value)
    if name in FLOAT_ATTRS:
        return float(value)
    return value


def element_to_dict(element: ET.Element, parent_tag: str) -> dict:
    obj = {name: typed(name, value) for name, value in element.attrib.items()}
    text = (element.text or "").strip()
    if text:
        obj["value"] = text
    for kid in element:
        tag = strip_ns(kid.tag)
        kid_obj = element_to_dict(kid, strip_ns(element.tag))
        if tag in ARRAY_NAMES and strip_ns(element.tag) != "subsonic-response":
            obj.setdefault(tag, []).append(kid_obj)
        else:
            obj[tag] = kid_obj
    return obj


def convert(path: Path) -> dict:
    root = ET.parse(path).getroot()
    assert strip_ns(root.tag) == "subsonic-response", path
    return {"subsonic-response": element_to_dict(root, "")}


def main():
    JSON_DIR.mkdir(exist_ok=True)
    for xml_path in sorted(XML_DIR.glob("*.xml")):
        if xml_path.name in SKIPPED_XML_ONLY:
            continue
        out_path = JSON_DIR / (xml_path.stem + ".json")
        with out_path.open("w") as f:
            json.dump(convert(xml_path), f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"converted {xml_path.name} -> {out_path.name}")

    # JSON-only bad-response twin of malformed.xml (truncated document)
    (JSON_DIR / "malformed.json").write_text('{"subsonic-response": {"status": "ok", "version": "1.15.\n')
    print("wrote malformed.json")


if __name__ == "__main__":
    main()
