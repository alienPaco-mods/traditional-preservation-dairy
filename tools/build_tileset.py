#!/usr/bin/env python3
"""Builds the Yoghurt Incubator tileset (42/media/*.tiles and texturepacks/*.pack), its icons and the generated Tiles.lua.

Made by `tp new`: the station is a placeholder crate. TEMPLATE: paint the real station (and any attached sprites
for its stages) here, with the helpers in _tpcore/tools/pzart.py; see the other mods' builders.

Usage: python3 tools/build_tileset.py
Needs Pillow. Deterministic: a rerun with no change gives byte-identical files.
"""
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "_tpcore")) / "tools"))
import pzart  # noqa: E402

MOD = "TraditionalPreservationDairy"
NAME = "traditionalpreservationdairy"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 8
PAGE_SIZE = 512
SS = 8
SEED = 1

# Facings, S and E, as the entity scripts' faces. Each station takes len(FACES) tiles from its base.
FACES = ["S", "E"]
# name: (base tile, GroupName, CustomName, crate half width in tiles, height in pixels, colour). Placeholder crates
# until step 3's art; the crock is the smaller, darker one.
STATIONS = {
    "INCUBATOR": (0, "Yoghurt", "Incubator", 0.36, 46, (150, 112, 70)),
    "CROCK": (2, "Starter Culture", "Crock", 0.24, 34, (120, 84, 60)),
}
PLANKS = 4

TILE_PROPS = {}
for base, group, custom, _, _, _ in STATIONS.values():
    for offset, facing in enumerate(FACES):
        # The engine only links the facings of tiles with a GroupName, and that link lets a moved station rotate.
        TILE_PROPS[base + offset] = [("BlocksPlacement", ""), ("CustomName", custom), ("Facing", facing),
                                     ("GroupName", group), ("IsMoveAble", ""), ("PickUpWeight", "100"),
                                     ("solidtrans", "")]


def corner(x, y, z=0.0):
    px, py = pzart.project(x, y, z)
    return (px * SS, py * SS)


def paint_crate(facing, h, height, wood):
    """A plank crate. The E face is the S face mirrored, so the two read as turned."""
    layer = pzart.new_layer(SS)
    draw = ImageDraw.Draw(layer)
    sides = [
        # (polygon, shade): the side facing down-left (+y), the side facing down-right (+x), the lid.
        ([corner(-h, h), corner(h, h), corner(h, h, height), corner(-h, h, height)], 0.85),
        ([corner(h, -h), corner(h, h), corner(h, h, height), corner(h, -h, height)], 0.62),
        ([corner(-h, -h, height), corner(h, -h, height), corner(h, h, height), corner(-h, h, height)], 1.0),
    ]
    for polygon, shade in sides:
        draw.polygon(polygon, fill=pzart.tint(wood, shade))
    # Plank seams on the two sides, and an edge round every face.
    for step in range(1, PLANKS):
        z = height * step / PLANKS
        draw.line([corner(-h, h, z), corner(h, h, z)], fill=pzart.tint(wood, 0.55), width=SS)
        draw.line([corner(h, -h, z), corner(h, h, z)], fill=pzart.tint(wood, 0.4), width=SS)
    for polygon, _ in sides:
        draw.line(polygon + polygon[:1], fill=pzart.tint(wood, 0.35), width=SS)
    tile = pzart.weather(pzart.shrink(layer), random.Random(SEED), 0.35)
    return tile.transpose(Image.FLIP_LEFT_RIGHT) if facing == "E" else tile


def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "STATIONS": [prefix + str(base + offset) for base, *_ in STATIONS.values() for offset in range(len(FACES))],
        **{name: spec[0] for name, spec in STATIONS.items()},
    }


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    (media / "texturepacks").mkdir(parents=True, exist_ok=True)
    tiles = {base + offset: paint_crate(facing, half, height, wood)
             for base, _, _, half, height, wood in STATIONS.values() for offset, facing in enumerate(FACES)}
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    pzart.write_build_icon(tiles[0], media / "textures" / "Item_YoghurtIncubator.png")
    pzart.write_build_icon(tiles[STATIONS["CROCK"][0]], media / "textures" / "Item_StarterCultureCrock.png")
    pzart.write_mod_icon(tiles[0], media.parent / "icon.png")
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
