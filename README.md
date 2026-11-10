# Traditional Preservation (Dairy) — Build 42 prototype (v0.0.1)

Made by `tp new` on 2026-11-09 from `~/MODS/TraditionalPreservationCore/template`. TEMPLATE: everything below describes the skeleton;
rewrite it as the mod takes shape. Settle the questions in `~/MODS/WIP/TPCore/SERIES.md` ("Designing a new mod") first.

## Install

`tp install Dairy` copies the mod to `~/Zomboid/mods/TraditionalPreservationDairy` after its tests pass.

## How it works (skeleton)

1. **Build a Yoghurt Incubator** (Build menu, Furniture): 4 planks + 8 nails + any hammer, Carpentry 2.
2. Put up to 4 Raw Dairy Batches in it and press **Craft**.
3. After 3 in-game days at the best temperature, take out the Finished Dairy Batches.

A batch works by the temperature where the station stands (outdoors, under a roof, in a basement), through the
shared weather ledger, and keeps working while the area is unloaded. Hover a running batch for its progress, time
left, temperature and rate.

`luajit tools/season_report.lua` prints the days a batch takes by month and place (golden-checked by `tp test`).

## Rebuilding the tileset

`python3 tools/build_tileset.py` (needs Pillow) paints the station and writes `42/media/traditionalpreservationdairy.tiles`,
`42/media/texturepacks/traditionalpreservationdairy.pack`, the icons and the generated `42/media/lua/shared/TraditionalPreservationDairy/Tiles.lua`
(don't edit it by hand). `luajit tests/test_tiles.lua` checks the entity scripts against it.

## Debug commands

In debug mode, `TPD.help()` in the Lua console lists commands for testing this mod. See `DEVHELP.md`.

## Engineering notes

- The shared core (Weather, Station, UI) is the required TP Core mod (`~/MODS/TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there.
- `tiledef` 5172 was picked by `tp new` as the next free number.
- Save keys: the ledger lives in global ModData under `TraditionalPreservationDairy` (totals `process<Place>`), and a run's recipe
  ModData holds `done`, `last`, `place`. Never rename them once the mod is out.
- Singleplayer only for now.
