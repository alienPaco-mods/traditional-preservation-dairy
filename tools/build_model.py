#!/usr/bin/env python3
"""Builds the towel bundle (42/media/Models_X/TowelBundle.glb) and its texture: what a wrapped pot, jar or bucket
looks like on the ground, and the Wrapped Yogurt Pot too.

One mesh for every container: a squat bundle of towels round the pot, gathered at the top under a twine tie, with
the ends puffed out above it. It is a lathe (PROFILE swept around Y) with folds pressed into it, deepest towards the
tie. Units: the bundle is 1 tall and 1 across at its widest (Y up, base on the ground). Each container's size is
the `scale` of its TowelBundle_* model in 42/media/scripts/TraditionalPreservationDairy_items.txt (worked out there).
A model's scale is the same every way, so a tall, narrow container gets a narrow copy of the mesh (NARROW).

The texture: the towel's weave on the left (BODY_U), with two red stripes round the belly, and the twine on the
right (TIE_U). The glb writer is Fish & Meat's (tools/build_model.py there).

Usage: python3 tools/build_model.py
Needs Pillow and numpy. Deterministic: a rerun with no change gives byte-identical files.
"""
import json
import math
import random
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# (height, radius): the towel from the floor to the tie, then the ends above it.
PROFILE = [
    (0.0, 0.36), (0.03, 0.43), (0.12, 0.49), (0.30, 0.50), (0.46, 0.47), (0.58, 0.38), (0.66, 0.24),
    (0.70, 0.15), (0.73, 0.13), (0.76, 0.15), (0.82, 0.21), (0.89, 0.20), (0.95, 0.13), (1.0, 0.0),
]
TIE = (0.695, 0.765)  # heights the twine covers
SEGMENTS = 40
RINGS_PER_STEP = 3  # rings between two profile points, for the folds to bend smoothly
FOLDS = 7  # round the bundle
FOLD_DEPTH = 0.05  # share of the radius, at the tie; a third of it at the floor
FOLD_TWIST = 0.9  # radians the folds turn from the floor to the tie
EARS = 3  # the towel ends above the tie
EAR_DEPTH = 0.30
WOBBLE = 0.025  # random share of the radius, per ring and segment, so it isn't turned on a lathe
NARROW = {"TowelBundleTall": 0.4}  # mesh name: width as a share of the round bundle's, the height kept (the clay jar)
SEED = 7

BODY_U, TIE_U = (0.0, 0.8), (0.84, 1.0)
WRAPS = 2  # the weave repeats twice round the bundle
STRIPES = [(0.26, 0.30), (0.34, 0.36)]  # heights of the red stripes
TEXTURE_SIZE, SAVED_TEXTURE_SIZE = 256, 128
GAIN = 1.6  # the game lights models darker than icons
TOWEL = (228, 220, 202)
STRIPE = (168, 60, 52)
TWINE, TWINE_DARK = (168, 142, 96), (112, 88, 56)


def rings():
    """(height, radius, fold strength) down the profile, with RINGS_PER_STEP rings between its points."""
    out = []
    for (y0, r0), (y1, r1) in zip(PROFILE, PROFILE[1:]):
        for step in range(RINGS_PER_STEP):
            t = step / RINGS_PER_STEP
            out.append((y0 + (y1 - y0) * t, r0 + (r1 - r0) * t))
    out.append(PROFILE[-1])
    return out


def radius_at(y, r, angle, rng_row):
    tie = (TIE[0] + TIE[1]) / 2
    if y <= tie:
        strength = FOLD_DEPTH * (1 / 3 + 2 / 3 * y / tie)
        fold = math.sin(FOLDS * angle + FOLD_TWIST * y / tie)
    else:
        # The ends: lobes, deepest halfway up the puff.
        share = (y - tie) / (1 - tie)
        strength = EAR_DEPTH * math.sin(math.pi * share)
        fold = math.cos(EARS * angle)
    return r * (1 + strength * fold + rng_row)


def build_mesh():
    rng = random.Random(SEED)
    positions, uvs = [], []
    profile = rings()
    for y, r in profile:
        wobble = [rng.uniform(-WOBBLE, WOBBLE) for _ in range(SEGMENTS)]
        wobble.append(wobble[0])
        for segment in range(SEGMENTS + 1):
            angle = 2 * math.pi * segment / SEGMENTS
            radius = radius_at(y, r, angle, wobble[segment]) if r > 0 else 0.0
            positions.append((radius * math.cos(angle), y, radius * math.sin(angle)))
            if TIE[0] <= y <= TIE[1]:
                u = TIE_U[0] + (TIE_U[1] - TIE_U[0]) * segment / SEGMENTS
            else:
                u = BODY_U[0] + (BODY_U[1] - BODY_U[0]) * segment / SEGMENTS
            uvs.append((u, 1 - y))
    width = SEGMENTS + 1
    indices = []
    for ring in range(len(profile) - 1):
        for segment in range(SEGMENTS):
            a = ring * width + segment
            b, c, d = a + 1, a + width + 1, a + width
            indices += [a, c, b, a, d, c]
    # The floor: a fan from a centre point.
    centre = len(positions)
    positions.append((0.0, 0.0, 0.0))
    uvs.append(((BODY_U[0] + BODY_U[1]) / 2, 1.0))
    for segment in range(SEGMENTS):
        indices += [centre, segment, segment + 1]
    positions = np.array(positions, dtype=float)
    # Bundle 1 across at its widest, whatever the folds did.
    widest = np.max(np.hypot(positions[:, 0], positions[:, 2]))
    positions[:, 0] *= 0.5 / widest
    positions[:, 2] *= 0.5 / widest
    return positions, smooth_normals(positions, indices), np.array(uvs, dtype=float), indices


def smooth_normals(positions, indices):
    normals = np.zeros_like(positions)
    triangles = np.array(indices).reshape(-1, 3)
    a, b, c = positions[triangles[:, 0]], positions[triangles[:, 1]], positions[triangles[:, 2]]
    faces = np.cross(b - a, c - a)
    for corner in range(3):
        np.add.at(normals, triangles[:, corner], faces)
    # The seam's two columns share their normals, so it doesn't show.
    width = SEGMENTS + 1
    rows = (len(positions) - 1) // width
    for ring in range(rows):
        first, last = ring * width, ring * width + SEGMENTS
        both = normals[first] + normals[last]
        normals[first] = normals[last] = both
    lengths = np.linalg.norm(normals, axis=1)
    lengths[lengths == 0] = 1
    normals /= lengths[:, None]
    # Outward from the axis where a face pair cancels out (the apex).
    return normals


def bright(colour, gain=GAIN):
    return tuple(min(255, round(c * gain)) for c in colour)


def paint_texture():
    size = TEXTURE_SIZE
    image = Image.new("RGB", (size, size), bright(TOWEL))
    pixels = image.load()
    rng = random.Random(SEED)
    body_end = round(BODY_U[1] * size)
    for x in range(body_end):
        for y in range(size):
            height = 1 - y / size
            colour = TOWEL
            if any(low <= height <= high for low, high in STRIPES):
                colour = STRIPE
            # The weave: faint threads both ways, and the folds' creases darker.
            weave = 0.97 + 0.03 * ((x // 2 + y // 2) % 2)
            crease = 1 - 0.10 * max(0.0, math.sin(2 * math.pi * WRAPS * FOLDS / 2 * x / body_end)) ** 6
            speck = rng.uniform(0.97, 1.03)
            pixels[x, y] = bright(tuple(c * weave * crease * speck for c in colour))
    # The twine: dark twists slanting across.
    for x in range(round(TIE_U[0] * size), size):
        for y in range(size):
            twist = (x + y // 2) % 9 < 2
            pixels[x, y] = bright(TWINE_DARK if twist else TWINE)
    image = image.filter(ImageFilter.GaussianBlur(0.6))
    return image.resize((SAVED_TEXTURE_SIZE, SAVED_TEXTURE_SIZE), Image.LANCZOS)


def write_glb(path, positions, normals, uvs, indices):
    positions = positions.astype("<f4")
    normals = normals.astype("<f4")
    uvs = uvs.astype("<f4")
    indices = np.array(indices, dtype="<u2")
    chunks, views, accessors = bytearray(), [], []

    def add(array, kind, component, target, bounds=False):
        offset = len(chunks)
        chunks.extend(array.tobytes())
        chunks.extend(b"\0" * (-len(chunks) % 4))
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": array.nbytes, "target": target})
        accessor = {"bufferView": len(views) - 1, "componentType": component, "count": len(array), "type": kind}
        if bounds:
            accessor["min"] = array.min(axis=0).tolist()
            accessor["max"] = array.max(axis=0).tolist()
        accessors.append(accessor)
        return len(accessors) - 1

    primitive = {
        "attributes": {
            "POSITION": add(positions, "VEC3", 5126, 34962, bounds=True),
            "NORMAL": add(normals, "VEC3", 5126, 34962),
            "TEXCOORD_0": add(uvs, "VEC2", 5126, 34962),
        },
        "indices": add(indices, "SCALAR", 5123, 34963),
    }
    document = {
        "asset": {"version": "2.0", "generator": "TraditionalPreservationDairy build_model.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": "TowelBundle"}],
        "meshes": [{"name": "TowelBundle", "primitives": [primitive]}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(chunks)}],
    }
    text = json.dumps(document, separators=(",", ":")).encode("utf8")
    text += b" " * (-len(text) % 4)
    total = 12 + 8 + len(text) + 8 + len(chunks)
    with open(path, "wb") as out:
        out.write(struct.pack("<4sII", b"glTF", 2, total))
        out.write(struct.pack("<I4s", len(text), b"JSON") + text)
        out.write(struct.pack("<I4s", len(chunks), b"BIN\0") + bytes(chunks))


def main():
    media = Path(__file__).resolve().parent.parent / "42" / "media"
    (media / "Models_X").mkdir(parents=True, exist_ok=True)
    positions, normals, uvs, indices = build_mesh()
    write_glb(media / "Models_X" / "TowelBundle.glb", positions, normals, uvs, indices)
    for name, share in NARROW.items():
        narrow = positions * np.array([share, 1.0, share])
        write_glb(media / "Models_X" / f"{name}.glb", narrow, smooth_normals(narrow, indices), uvs, indices)
    paint_texture().save(media / "textures" / "TowelBundleModel.png")
    print(f"wrote the towel bundle's model and texture to {media}")


if __name__ == "__main__":
    main()
