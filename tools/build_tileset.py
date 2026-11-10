#!/usr/bin/env python3
"""Builds the Traditional Preservation (Dairy) art: the tileset (42/media/*.tiles and texturepacks/*.pack), its depth
shapes (common/media/tileGeometry.txt), the item icons, the build and mod icons, and the generated Tiles.lua.
The Hearth began here; it is TP Core's now (TraditionalPreservationCore/tools/build_tileset.py).

Each station is a pair of tiles, south facing then east facing. Both are round pots, standing on the floor with no
stool so they can be carried to a fire and set down by it; the facing shows only in where the incubator's lid lies
when it is off. The base tile is the bare open pot. Every stage, the empty one too, is an overlay that
TraditionalPreservationDairyWorld.lua layers over it, so a stage paints only what it adds: the incubator's lid lying
against the pot (empty and ready), on the pot (cooling), slid half off (too cold for a starter), or under the cloth wrap, and its set yoghurt; the crock's linen
cap, its wheat and milk, and its culture.
The overlay numbers are in OVERLAYS, keyed by the stage names the World's sprite tables use.

Usage: python3 tools/build_tileset.py [path/to/ProjectZomboid/projectzomboid] [contact-sheet.png]
Needs Pillow and the game (for the vanilla glass jar icon). Deterministic: a rerun with no change gives
byte-identical files.
"""
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "TraditionalPreservationCore")) / "tools"))
import pzart  # noqa: E402
from pzart import TILE_W, TILE_H, light_at, shrink  # noqa: E402
from pzart import tint as shade  # noqa: E402

MOD = "TraditionalPreservationDairy"
NAME = "traditionalpreservationdairy"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 8
PAGE_SIZE = 512
SS = 4  # supersampling
FOOT_X, FOOT_Y = pzart.FOOT
SQUASH = 0.5

# Facings, S and E, as the entity scripts' faces. Each station and overlay takes len(FACES) tiles from its number.
FACES = ["S", "E"]
INCUBATOR, CROCK = 0, 2
OVERLAYS = {
    "incubator": {"Cooling": 4, "Incubating": 6, "Ready": 8, "Empty": 16, "TooCold": 18},
    "crock": {"Cultivating": 10, "Developing": 12, "Ready": 14},
}

# Colours.
CLAY = (156, 84, 54)           # fired terracotta
LID_EDGE = (186, 112, 76)      # the lid's lit rim, so it stands apart from the pot where they meet
GAP = (30, 16, 12, 255)        # the dark line where the lid sits on the rim
RAW_CLAY = (138, 122, 108)     # thrown, not yet fired
CROCK_CLAY = (124, 64, 44)     # the crock is an older, darker pot
SLIP = (218, 198, 160)         # the crock's white slip band
INSIDE = (54, 30, 22)
CLOTH = (222, 212, 192)
STRIPE = (164, 50, 42)
LINEN = (196, 182, 152)
TWINE = (168, 142, 96)
SHEET = (232, 230, 220)        # a plain bed sheet, whiter than the incubator's striped cloth
YOGHURT = (240, 236, 222)
MILK = (226, 220, 200)
WHEAT = (196, 160, 92)
CULTURE = (236, 226, 196)
SHADOW = (0, 0, 0, 80)
SHADOW_BLUR = 3              # px of feathering round the floor shadow
OUTLINE = (44, 30, 22, 255)
WEATHER = 0.22
OVERLAY_WEATHER = 0.12
FOOT_SHADE = 0.7

# Shapes: a profile is [(z, radius)] in pixels from the bottom up; the body is turned round it.
# Both pots stand straight on the floor, so either can go by the fire.
# The incubator: a wide-bellied pot with a short neck and a flared rim.
POT = [(0, 13), (6, 19), (16, 24), (24, 24), (32, 21), (38, 16.5), (41, 15), (44, 16.5)]
POT_LUGS = 30                  # height of the two lug handles
LID = [(0, 18), (2, 17.5), (5, 13), (7, 7), (7.5, 3), (11, 3), (11.5, 0)]
LID_RIM = 1.6                  # height of the lid's lit edge band
# When it is off, the lid stands on its rim leaning against the pot's belly, dome out: front left facing S, front
# right facing E. A lid lying flat beside the pot reached into the next square, whose floor the game draws over it.
LEAN_AT = (-17, -13)           # the lid's middle from the pot's foot, in pixels, facing S (mirrored facing E)
LEAN_TURN = 68                 # degrees from lying dome up to standing; 90 would be upright
# Too cold for a starter: the lid slid half off the mouth, to the floor lid's side, and tipped down over the rim.
SLID, SLID_DROP, SLID_TILT = 12, 3.5, 15  # sideways and down in pixels, tilt in degrees
# The cloth hangs over the lid and the shoulders to below the belly, tied at the neck.
CLOTH_BODY = [(14, 26.5), (20, 27), (26, 26.5), (33, 23.5), (39, 18), (41, 17), (44, 19.5), (47, 20), (51, 16),
              (54, 9), (55, 0)]
CLOTH_HEM, HEM_WAVE = 14, 2.5
CLOTH_STRIPES = [(17, 19), (21, 22)]
CLOTH_TIE = 40.5
SHEET_HEM = 3                  # the Wrapped Yoghurt Pot's sheet hangs nearly to the floor
# The crock: smaller, taller in proportion, with a slip band of zig-zags round the belly.
CROCK_BODY = [(0, 10), (4, 14), (12, 17), (19, 16), (25, 12.5), (28, 10.5), (31, 11.5)]
CROCK_BAND = (9, 17)
CAP = [(26, 14.5), (29, 14.5), (31.5, 13.5), (33.5, 10), (34.5, 0)]
CAP_TIE = 29
STRIPS = 72                    # slices round a body
LEVELS_PER_PX = 1.5            # bands up a body

# Item icons: name -> how it is painted.
ICON_SIZE = 32
ITEM_ICONS = ["YoghurtPotUnfired", "YoghurtPot", "JarOfYoghurt", "ActiveYoghurtStarter", "EmptyYoghurtContainer",
              "WrappedYoghurtPot"]

TILE_PROPS = {}
for base, group, custom in ((INCUBATOR, "Yoghurt", "Incubator"), (CROCK, "Starter Culture", "Crock")):
    for offset, facing in enumerate(FACES):
        # The engine only links the facings of tiles with a GroupName, and that link lets a moved station rotate.
        # Not solidtrans: the pot and the crock are small enough to walk past, and a solidtrans tile fades when the
        # player stands behind it, and the click picker skips faded objects.
        TILE_PROPS[base + offset] = [("BlocksPlacement", ""), ("CustomName", custom), ("Facing", facing),
                                     ("GroupName", group), ("IsMoveAble", ""), ("PickUpWeight", "100")]

# --- Drawing ----------------------------------------------------------------------------------------------------

def new_layer():
    return pzart.new_layer(SS)


def box(cx, cy, rx, ry):
    return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]


def poly(draw, points, colour):
    draw.polygon([(x * SS, y * SS) for x, y in points], fill=colour)


def line(draw, start, end, colour, width):
    draw.line([start[0] * SS, start[1] * SS, end[0] * SS, end[1] * SS], fill=colour, width=max(1, int(width * SS)))


def radius_at(profile, z):
    for (z0, r0), (z1, r1) in zip(profile, profile[1:]):
        if z0 <= z <= z1:
            t = (z - z0) / (z1 - z0) if z1 > z0 else 0
            t = t * t * (3 - 2 * t)  # smooth, so the curve has no corners
            return r0 + (r1 - r0) * t
    return profile[-1][1] if z > profile[-1][0] else profile[0][1]


def upward(profile, z):
    """How much the surface faces up at z: 1 flat on top, 0 upright, negative facing the floor."""
    step = 0.5
    slope = (radius_at(profile, z - step) - radius_at(profile, z + step)) / (2 * step)
    return slope / math.sqrt(1 + slope * slope)


def surface_point(base, profile, z, angle, r=None):
    r = radius_at(profile, z) if r is None else r
    return (base[0] + r * math.cos(angle), base[1] - z + r * SQUASH * math.sin(angle))


def paint_body(layer, base, profile, colour, hem=None):
    """Turns profile round a vertical axis standing on base (tile pixels). colour(angle, z) gives each patch's colour
    before the light; hem(angle) is where the body starts at each angle (a cloth's uneven edge). The far side goes
    down first, so the near side covers it and only its top shows."""
    draw = ImageDraw.Draw(layer)
    low, high = profile[0][0], profile[-1][0]
    bands = max(2, int((high - low) * LEVELS_PER_PX))
    angles = [2 * math.pi * i / STRIPS for i in range(STRIPS)]
    for first in sorted(angles, key=lambda a: math.sin(a + math.pi / STRIPS)):
        second = first + 2 * math.pi / STRIPS
        middle = (first + second) / 2
        start = hem(middle) if hem else low
        side = light_at(middle) if math.sin(middle) >= 0 else 0.72 + 0.2 * max(0.0, math.cos(middle - 2.2))
        for band in range(bands):
            z0 = low + (high - low) * band / bands
            z1 = low + (high - low) * (band + 1) / bands
            if z1 <= start:
                continue
            z0 = max(z0, start)
            up = upward(profile, (z0 + z1) / 2)
            tone = side * (1 - abs(up)) + (1.12 if up > 0 else 0.6) * abs(up)
            points = [surface_point(base, profile, z0, first), surface_point(base, profile, z0, second),
                      surface_point(base, profile, z1, second), surface_point(base, profile, z1, first)]
            poly(draw, points, shade(colour(middle, (z0 + z1) / 2), tone))


def paint_mouth(layer, base, profile, inner_gap, depth):
    """The rim's flat top and the dark inside of the mouth, deeper at the back."""
    draw = ImageDraw.Draw(layer)
    top, r = profile[-1]
    cx, cy = base[0], base[1] - top
    ri = r - inner_gap
    draw.ellipse(box(cx, cy, ri, ri * SQUASH), fill=shade(INSIDE, 1.0))
    for step in range(8):
        k = 1 - step / 8
        draw.ellipse(box(cx + ri * (1 - k) * 0.2, cy + ri * SQUASH * (1 - k) * 0.5, ri * k, ri * SQUASH * k * min(1, depth / ri)),
                     fill=shade(INSIDE, 1.0 - 0.06 * step))


def paint_surface(layer, base, z, r, colour, rng, specks=None):
    """A level surface inside a mouth: shade at the back rim, light in front, and specks floating in it."""
    draw = ImageDraw.Draw(layer)
    cx, cy = base[0], base[1] - z
    draw.ellipse(box(cx, cy, r, r * SQUASH), fill=shade(colour, 0.78))
    draw.ellipse(box(cx - 0.5, cy + 0.6, r - 1.2, (r - 1.2) * SQUASH), fill=shade(colour, 1.0))
    draw.ellipse(box(cx - r * 0.3, cy + 0.2, r * 0.35, r * 0.35 * SQUASH), fill=shade(colour, 1.05))
    for colour_speck, count in (specks or []):
        for _ in range(count):
            angle, reach = rng.uniform(0, 2 * math.pi), rng.uniform(0, 0.85) ** 0.5
            x, y = cx + math.cos(angle) * reach * r, cy + math.sin(angle) * reach * r * SQUASH
            draw.ellipse(box(x, y, 0.9, 0.5), fill=shade(colour_speck, rng.uniform(0.8, 1.15)))


def paint_shadow(layer, radius):
    """The soft shadow a pot casts on the floor (or the hearth) it stands on. Blurred to nothing at its edge: vanilla
    thins the grass round a player standing on the tile, and a hard-edged ellipse showed there as a ring."""
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(box(FOOT_X + 1.5, FOOT_Y + 1, radius + 2, (radius + 2) * SQUASH), fill=SHADOW)
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)))


def finish(layer, seed, depth):
    return pzart.weather(shrink(layer), random.Random(seed), depth)


# --- The incubator ----------------------------------------------------------------------------------------------

def pot_base():
    return (FOOT_X, FOOT_Y)


def paint_pot(layer, base, profile, clay, lugs=None, band=None):
    """A thrown pot: wheel ridges, the two lug handles, and a slip band of zig-zags if band is (low, high)."""
    rng = random.Random(sum(clay))
    ridges = {round(z) for z in [rng.uniform(4, profile[-1][0] - 4) for _ in range(5)]}

    def colour(angle, z):
        if band and band[0] <= z <= band[1]:
            middle, half = (band[0] + band[1]) / 2, (band[1] - band[0]) / 2
            zig = middle + (half - 1.6) * (2 * abs((angle * 10 / math.pi) % 2 - 1) - 1)
            if abs(z - zig) < 0.9 or abs(z - band[0]) < 0.6 or abs(z - band[1]) < 0.6:
                return SLIP
        return shade(clay, 0.93 if round(z) in ridges else 1.0)[:3]

    paint_body(layer, base, profile, colour)
    if lugs:
        draw = ImageDraw.Draw(layer)
        r = radius_at(profile, lugs)
        for side in (-1, 1):
            x, y = base[0] + side * (r + 1), base[1] - lugs
            draw.ellipse(box(x, y, 2.6, 1.8), fill=shade(clay, 0.66 if side > 0 else 0.92))
            draw.ellipse(box(x + side * 0.6, y - 0.4, 1.2, 0.8), fill=shade(clay, 0.5 if side > 0 else 0.7))


def paint_incubator(face):
    layer = new_layer()
    paint_shadow(layer, POT[3][1])
    paint_pot(layer, pot_base(), POT, CLAY, lugs=POT_LUGS)
    layer = pzart.darken_down(layer, FOOT_Y - POT[-1][0] * 0.6, FOOT_Y, FOOT_SHADE, SS)
    paint_mouth(layer, pot_base(), POT, 2.2, 10)
    return finish(layer, 10 + face, WEATHER)


def paint_lid(layer, base, clay, edge, under=GAP):
    """The lid: a dark line under it (the gap on the rim, or its shadow on the floor), a lit band round its edge, and
    the dome and knob in the pot's own clay."""
    draw = ImageDraw.Draw(layer)
    r = LID[0][1]
    draw.ellipse(box(base[0], base[1] + 0.8, r + 0.6, (r + 0.6) * SQUASH), fill=under)
    paint_body(layer, base, LID, lambda angle, z: edge if z < LID_RIM else clay)


def lid_layer():
    layer = new_layer()
    top = POT[-1][0]
    paint_lid(layer, (FOOT_X, FOOT_Y - top + 1), CLAY, LID_EDGE)
    return layer


def slid_lid_layer(face):
    """The lid pushed half off: shifted to the floor lid's side so the milk shows behind it, and tipped down
    where it overhangs the rim. A warning that the milk has cooled past the point a starter takes."""
    side = -1 if FACES[face] == "S" else 1
    layer = new_layer()
    top = POT[-1][0]
    cx, cy = FOOT_X + side * SLID, FOOT_Y - top + 1 + SLID_DROP
    paint_lid(layer, (cx, cy), CLAY, LID_EDGE)
    # Tip it about the far edge, which still rests on the rim; PIL turns positive angles anticlockwise.
    pivot = ((cx - side * LID[0][1]) * SS, cy * SS)
    return layer.rotate(-side * SLID_TILT, resample=Image.BICUBIC, center=pivot)


def leaning_lid(layer, face):
    """The lid off the pot, stood on its rim against the belly, dome out, with a little shadow at its foot."""
    side = -1 if FACES[face] == "S" else 1
    x, y = FOOT_X + side * -LEAN_AT[0], FOOT_Y + LEAN_AT[1]
    r = LID[0][1]
    lid = new_layer()
    paint_lid(lid, (x, y), CLAY, LID_EDGE, under=SHADOW)
    # PIL turns positive angles anticlockwise: the dome, which points up, swings out to the lid's own side.
    lid = lid.rotate(-side * LEAN_TURN, resample=Image.BICUBIC, center=(x * SS, y * SS))
    draw = ImageDraw.Draw(layer)
    foot = r * math.sin(math.radians(LEAN_TURN))
    draw.ellipse(box(x + side * 2, y + foot - 1, 8, 3), fill=SHADOW)
    layer.alpha_composite(lid)


def cloth_layer(cloth=CLOTH, stripes=CLOTH_STRIPES, hem=CLOTH_HEM):
    """The cloth over the lidded pot: cream with red stripes near the hem, folds, tied with twine at the neck."""
    layer = new_layer()
    base = pot_base()

    def colour(angle, z):
        fold = 0.93 + 0.07 * math.sin(angle * 9) + 0.03 * math.sin(angle * 23)
        for low, high in stripes:
            if low <= z - HEM_WAVE * math.sin(angle * 5) * 0.4 <= high:
                return shade(STRIPE, fold)[:3]
        return shade(cloth, fold)[:3]

    paint_body(layer, base, CLOTH_BODY, colour, hem=lambda angle: hem + HEM_WAVE * math.sin(angle * 5))
    draw = ImageDraw.Draw(layer)
    r = radius_at(CLOTH_BODY, CLOTH_TIE)
    for step in range(32):
        a0, a1 = math.pi * step / 32, math.pi * (step + 1) / 32
        line(draw, surface_point(base, CLOTH_BODY, CLOTH_TIE, a0, r + 0.4), surface_point(base, CLOTH_BODY, CLOTH_TIE, a1, r + 0.4),
             shade(TWINE, light_at((a0 + a1) / 2)), 1.1)
    # The knot and its two loose ends, on the front left.
    kx, ky = surface_point(base, CLOTH_BODY, CLOTH_TIE, 2.1, r + 0.6)
    draw.ellipse(box(kx, ky, 1.4, 1.1), fill=shade(TWINE, 0.9))
    line(draw, (kx, ky), (kx - 2, ky + 6), shade(TWINE, 0.8), 0.7)
    line(draw, (kx, ky), (kx + 1, ky + 5), shade(TWINE, 0.7), 0.7)
    return layer


def incubator_overlay(stage, face):
    if stage == "Cooling":
        layer = lid_layer()
    elif stage == "TooCold":
        # The milk shows in the gap the lid leaves.
        layer = new_layer()
        top, r = POT[-1]
        paint_surface(layer, pot_base(), top - 3, r - 3.2, MILK, random.Random(face))
        layer.alpha_composite(slid_lid_layer(face))
    elif stage == "Incubating":
        layer = cloth_layer()
    else:
        layer = new_layer()
        if stage == "Ready":
            top, r = POT[-1]
            paint_surface(layer, pot_base(), top - 3, r - 3.2, YOGHURT, random.Random(face))
        leaning_lid(layer, face)
    return finish(layer, 20 + face, OVERLAY_WEATHER)


# --- The crock --------------------------------------------------------------------------------------------------

def crock_base():
    return (FOOT_X, FOOT_Y)


def paint_crock(face):
    layer = new_layer()
    paint_shadow(layer, CROCK_BODY[2][1])
    paint_pot(layer, crock_base(), CROCK_BODY, CROCK_CLAY, band=CROCK_BAND)
    layer = pzart.darken_down(layer, FOOT_Y - CROCK_BODY[-1][0] * 0.6, FOOT_Y, FOOT_SHADE, SS)
    paint_mouth(layer, crock_base(), CROCK_BODY, 1.6, 7)
    return finish(layer, 30 + face, WEATHER)


def cap_layer():
    """A linen cap over the crock's mouth, tied round under the rim."""
    layer = new_layer()
    base = crock_base()
    paint_body(layer, base, CAP, lambda angle, z: shade(LINEN, 0.95 + 0.05 * math.sin(angle * 11))[:3],
               hem=lambda angle: CAP[0][0] + 1.2 * math.sin(angle * 7))
    draw = ImageDraw.Draw(layer)
    r = radius_at(CAP, CAP_TIE)
    for step in range(24):
        a0, a1 = math.pi * step / 24, math.pi * (step + 1) / 24
        line(draw, surface_point(base, CAP, CAP_TIE, a0, r + 0.3), surface_point(base, CAP, CAP_TIE, a1, r + 0.3),
             shade(TWINE, light_at((a0 + a1) / 2)), 0.9)
    return layer


def crock_overlay(stage, face):
    rng = random.Random(40 + face)
    if stage == "Cultivating":
        layer = cap_layer()
    else:
        layer = new_layer()
        top, r = CROCK_BODY[-1]
        specks = [(WHEAT, 40)] if stage == "Developing" else [(WHEAT, 3)]
        paint_surface(layer, crock_base(), top - 2.5, r - 2.4, MILK if stage == "Developing" else CULTURE, rng, specks)
    return finish(layer, 50 + face, OVERLAY_WEATHER)


# --- Item icons -------------------------------------------------------------------------------------------------

def outlined(art):
    """Scales art down into an icon and rings it with a dark line, as vanilla's icons are."""
    art = art.crop(art.getbbox())
    size = ICON_SIZE - 4
    scale = size / max(art.size)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    icon.alpha_composite(art, ((ICON_SIZE - art.width) // 2, (ICON_SIZE - art.height) // 2))
    alpha = icon.getchannel("A").point(lambda v: 255 if v > 90 else 0)
    solid = icon.copy()
    solid.putalpha(alpha)
    result = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    pixels, mask = result.load(), alpha.load()
    for y in range(ICON_SIZE):
        for x in range(ICON_SIZE):
            if mask[x, y] == 0 and any(0 <= x + dx < ICON_SIZE and 0 <= y + dy < ICON_SIZE and mask[x + dx, y + dy]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                pixels[x, y] = OUTLINE
    result.alpha_composite(solid)
    return result


def pot_icon(clay, lidded):
    layer = new_layer()
    base = (FOOT_X, FOOT_Y)
    paint_pot(layer, base, POT, clay, lugs=POT_LUGS)
    if lidded:
        paint_lid(layer, (FOOT_X, FOOT_Y - POT[-1][0] + 1), clay, shade(clay, 1.2)[:3])
    else:
        paint_mouth(layer, base, POT, 2.2, 10)
    return outlined(shrink(layer))


def wrapped_pot_icon():
    """The Yoghurt Pot in a plain sheet down to the floor, tied at the neck: it carries hot milk."""
    layer = new_layer()
    paint_pot(layer, pot_base(), POT, CLAY, lugs=POT_LUGS)
    layer.alpha_composite(cloth_layer(SHEET, [], SHEET_HEM))
    return outlined(shrink(layer))


def jar_icon(jar, mask, contents, cap):
    """The vanilla glass jar filled with contents, lighter at the top; with a linen cap tied on if cap is set."""
    icon = jar.copy()
    pixels = icon.load()
    fluid = [(x, y) for y in range(mask.height) for x in range(mask.width) if mask.getpixel((x, y))[3] > 0]
    top = min(y for _, y in fluid) + 3
    bottom = max(y for _, y in fluid)
    for x, y in fluid:
        if y >= top:
            depth = (y - top) / max(1, bottom - top)
            colour = shade(contents, 1.04 - 0.16 * depth) if y > top else shade(contents, 1.12)
            pixels[x, y] = colour[:3] + (255,)
    if cap:
        draw = ImageDraw.Draw(icon)
        left = min(x for x, y in fluid if y == min(yy for _, yy in fluid))
        right = max(x for x, y in fluid if y == min(yy for _, yy in fluid))
        lid_top = min(y for x in range(icon.width) for y in range(icon.height) if icon.getpixel((x, y))[3] > 0)
        draw.rectangle([left - 2, lid_top - 1, right + 2, lid_top + 4], fill=shade(LINEN, 1.0), outline=OUTLINE)
        draw.line([left - 3, lid_top + 6, left - 1, lid_top + 4], fill=shade(LINEN, 0.85))
        draw.line([right + 3, lid_top + 6, right + 1, lid_top + 4], fill=shade(LINEN, 0.8))
        draw.line([left - 1, lid_top + 3, right + 1, lid_top + 3], fill=shade(TWINE, 0.85))
    return icon


def clay_jar_icon(jar):
    """A vanilla clay jar with set yoghurt filling its mouth: the dark inside of the mouth turned white."""
    icon = jar.copy()
    pixels = icon.load()
    for y in range(3, 12):
        for x in range(19, 29):
            r, g, b, a = pixels[x, y]
            if a > 128 and 120 <= r + g + b < 260:
                pixels[x, y] = shade(YOGHURT, 1.0 - 0.025 * (y - 3) - 0.01 * (x - 19))[:3] + (255,)
    return icon


def cup_icon():
    """An empty yoghurt cup, open, with the foil gone: a square white tub, narrower at the foot, with a purple band,
    as vanilla's cups are square."""
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    cx, foot, height = FOOT_X, FOOT_Y, 26

    def corners(half, y):
        """A square seen from above at 2:1, as left, front, right, back."""
        return [(cx - half, y), (cx, y + half * SQUASH), (cx + half, y), (cx, y - half * SQUASH)]

    def side(bottom, top, i, j, low=0.0, high=1.0):
        """The quad between the bottom and top squares on edge i-j, from low to high up the side."""
        def at(k, t):
            return (bottom[k][0] + (top[k][0] - bottom[k][0]) * t, bottom[k][1] + (top[k][1] - bottom[k][1]) * t)
        return [at(i, low), at(j, low), at(j, high), at(i, high)]

    bottom, top = corners(10, foot), corners(13, foot - height)
    white, band = (234, 232, 228), (126, 70, 132)
    for (i, j), light in (((0, 1), 1.0), ((1, 2), 0.8)):
        poly(draw, side(bottom, top, i, j), shade(white, light))
        poly(draw, side(bottom, top, i, j, 0.3, 0.62), shade(band, light))
    # The open top: the rim, then the inside walls, lit on the far side and in shadow on the near.
    poly(draw, top, shade(white, 1.05))
    inner = corners(11.5, foot - height + 1)
    poly(draw, inner, shade(white, 0.72))
    floor = corners(9, foot - height + 9)
    poly(draw, [inner[0], inner[3], inner[2], floor[2], floor[3], floor[0]], shade(white, 0.9))
    return outlined(shrink(layer))


def write_icons(folder, game):
    folder.mkdir(parents=True, exist_ok=True)
    jars = pzart.extract_sprites(game / "media/texturepacks/UI2.pack", {"Item_GlassJar", "Item_GlassJar_Mask",
                                 "Item_ClayJar_Fired", "Item_ClayJar_Glazed_Fired"})
    jar, mask = jars["Item_GlassJar"], jars["Item_GlassJar_Mask"]
    icons = {
        "YoghurtPotUnfired": pot_icon(RAW_CLAY, lidded=True),
        "YoghurtPot": pot_icon(CLAY, lidded=True),
        "JarOfYoghurt": jar_icon(jar, mask, YOGHURT, cap=False),
        "ActiveYoghurtStarter": jar_icon(jar, mask, CULTURE, cap=True),
        "EmptyYoghurtContainer": cup_icon(),
        "WrappedYoghurtPot": wrapped_pot_icon(),
    }
    assert list(icons) == ITEM_ICONS
    # The same Jar of Yoghurt item, as it looks in a clay jar: World sets it by the jar it was collected in.
    icons["JarOfYoghurt_Clay"] = clay_jar_icon(jars["Item_ClayJar_Fired"])
    icons["JarOfYoghurt_Glazed"] = clay_jar_icon(jars["Item_ClayJar_Glazed_Fired"])
    for name, icon in icons.items():
        icon.save(folder / f"Item_{name}.png")


# --- Depth --------------------------------------------------------------------------------------------------------
# B42 draws each tile against a depth shape from tileGeometry.txt. A tile with none gets a flat default that hid
# whatever we paint on the floor in front of the pot: its shadow and the lid. Each station gets a thin slab over its
# whole floor and a cross of two boxes round its pot. Units are vanilla's: 10000 across a tile; up, about 129 a
# pixel (measured on vanilla's fridge, appliances_refrigeration_01_0, against its sprite).
GEOMETRY_UNIT = 10000
HEIGHT_PER_PX = 129
SLAB = 100


def geometry_boxes(profile):
    radius = max(r for _, r in profile) / (pzart.DIAMOND_HALF_W * math.sqrt(2)) * GEOMETRY_UNIT
    wide, narrow = round(radius * 0.92), round(radius * 0.6)
    height = round(profile[-1][0] * HEIGHT_PER_PX)
    half = GEOMETRY_UNIT // 2
    return [((-half, 0, -half), (half, SLAB, half)),
            ((-wide, 0, -narrow), (wide, height, narrow)),
            ((-narrow, 0, -wide), (narrow, height, wide))]


def write_geometry(path):
    """tileGeometry.txt for the stations and every overlay: the game reads it from common/media only."""
    shapes = {INCUBATOR: geometry_boxes(POT), CROCK: geometry_boxes(CROCK_BODY)}
    owners = {**{index: INCUBATOR for index in OVERLAYS["incubator"].values()},
              **{index: CROCK for index in OVERLAYS["crock"].values()}, INCUBATOR: INCUBATOR, CROCK: CROCK}
    lines = ["tileGeometry", "{", "    VERSION = 2,", "", "    tileset", "    {", f"        name = {TILESET},", ""]
    for first in sorted(owners):
        for index in range(first, first + len(FACES)):
            lines += [f"        /* {TILESET}_{index} */", "        tile", "        {",
                      f"            xy = {index % COLUMNS}x{index // COLUMNS},", ""]
            for low, high in shapes[owners[first]]:
                lines += ["            box", "            {", "                translate = 0x0x0,",
                          "                rotate = 0x0x0,", "                min = {}x{}x{},".format(*low),
                          "                max = {}x{}x{},".format(*high), "            }", ""]
            lines += ["        }", ""]
    lines += ["    }", "}", ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf8")


# --- Output -----------------------------------------------------------------------------------------------------

def lua_tiles():
    prefix = TILESET + "_"
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": len(FACES),
        "STATIONS": [prefix + str(base + offset) for base in (INCUBATOR, CROCK) for offset in range(len(FACES))],
        "INCUBATOR": INCUBATOR,
        "CROCK": CROCK,
        "OVERLAYS": OVERLAYS,
    }


def contact_sheet(tiles, path):
    """Every stage over its station, for checking the art by eye; kept out of the mod."""
    rows = [(INCUBATOR, OVERLAYS["incubator"]), (CROCK, OVERLAYS["crock"])]
    sheet = Image.new("RGBA", (TILE_W * 6, TILE_H * 2), (96, 110, 88, 255))
    for y, (base, stages) in enumerate(rows):
        for x, index in enumerate([None] + list(stages.values())):
            cell = tiles[base].copy()
            if index is not None:
                cell.alpha_composite(tiles[index])
            sheet.alpha_composite(cell, (x * TILE_W, y * TILE_H))
    sheet.save(path)


def main():
    default_game = Path.home() / ".local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else default_game
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    pzart.write_lua_tiles(media, MOD, lua_tiles(), "tools/build_tileset.py")
    write_icons(media / "textures", game)
    tiles = {}
    for face in range(len(FACES)):
        tiles[INCUBATOR + face] = paint_incubator(face)
        tiles[CROCK + face] = paint_crock(face)
        for stage, index in OVERLAYS["incubator"].items():
            tiles[index + face] = incubator_overlay(stage, face)
        for stage, index in OVERLAYS["crock"].items():
            tiles[index + face] = crock_overlay(stage, face)
    pzart.write_pack(media / "texturepacks" / f"{NAME}.pack", tiles, NAME, TILESET, PAGE_SIZE)
    pzart.write_tiles(media / f"{NAME}.tiles", [(TILESET, COLUMNS, ROWS)], TILE_PROPS)
    write_geometry(media.parent.parent / "common" / "media" / "tileGeometry.txt")
    empty = tiles[INCUBATOR].copy()
    empty.alpha_composite(tiles[OVERLAYS["incubator"]["Empty"]])
    pzart.write_build_icon(empty, media / "textures" / "Item_YoghurtIncubator.png")
    pzart.write_build_icon(tiles[CROCK], media / "textures" / "Item_StarterCultureCrock.png")
    # The mod list shows the pot wrapped in its cloth, the incubator's most telling stage.
    wrapped = tiles[INCUBATOR].copy()
    wrapped.alpha_composite(tiles[OVERLAYS["incubator"]["Incubating"]])
    pzart.write_mod_icon(wrapped, media.parent / "icon.png")
    if len(sys.argv) > 2:
        contact_sheet(tiles, sys.argv[2])
    print(f"wrote {NAME}.pack and {NAME}.tiles to {media}")


if __name__ == "__main__":
    main()
