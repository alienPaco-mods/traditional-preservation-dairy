# Changelog: Traditional Preservation (Dairy)

## 0.0.26
Needs TP Core 0.1.52.
- **Frost** (ROADMAP NEXT 1; user, session 76): everything here freezes at 0 C, on TP Core's frost ledger by place
  (`M.FROST`, `Frost.point(0)`). Six hours frozen in all (`Frost.THROUGH_HOURS`) freeze a thing through, once: live
  Kefir Grains go Hungry (loose, wet on a Drying Cloth, or in a kefir pot, in milk or out; one milk change brings them
  back), kefir separates (in a container or ready in the pot; strained, it takes the pot's frost hours along), a Yogurt
  or a Jar of Yogurt is Thawed (unhappiness +10, named "(Thawed)"; a cup spooned from a thawed jar is too). An Active
  Yogurt Starter loses 1/48 of the way to rotten each frozen hour (`Frost.STARTER_RUIN_HOURS`). No calories lost.
  Dried grains, milk and butter are safe; what sets or cultures in the Culturing Pot or the crock only pauses, as
  before. Cooked or burnt food never freezes. A basement never freezes, nor a place by a lit fire or banked embers.
- Sandbox **Frost harms** (on). Off, frost does no harm; the records still run.
- Save keys: item ModData `tpdFrost`, `tpdKefirFrost`, `tpdThawed`; a kefir pot's `grainFrost` and `kefirFrost`;
  a Drying Cloth lot's `frost` and `hungry`. Kefir grains on a cloth now keep data with their lot.
- Console: `TPD.frost(hours)` freezes the grains, kefir, yogurts and starters near you (default 6: through);
  `TPD.grains()`, `TPD.ages()` and `TPD.pots()` show frozen hours. Tests: `tests/test_frost.lua`.

## 0.0.25
- **Starter Culture Crock Info on the pot's path** (user, session 71, `WIP/TPCore/art/crock_info_mock.png`): a band
  with the crock's stage and time to its next change (grey empty, green cultivating, developing and ready, amber
  cultured and waiting for milk or stopped by the cold), the Station block (`TPStation_StarterCultureCrock.png`) with
  the culture's speed while it works, and the holdings: the wheat's slot (greyed "Add Wheat" while empty, 20 while it
  cultures, then "used", or "clabber" for a crock started on soured milk), an arrow into the crock's milk (half a
  litre loaded, a litre once fed; the place's heat as a bar beside it with the culture's best, 25 and 35°C; bubbles
  and its state line "62%, 9h" while it works) and an arrow out to the two starters (greyed "at ready", then green
  "Collect", a click collects). Wheat dragged onto the slot loads with the warm milk at hand (the cauldron's first);
  milk dragged onto the tank loads it (warm, the wheat carried), clabbers it (soured) or feeds it (fresh, once
  cultured), one container at a time. Load from the Cauldron (empty, a cauldron within 2 tiles), Feed Fresh Milk
  (cultured) and Collect Starters (2) (ready) as buttons. A lore line beside the holdings (bonny clabber). Replaces
  the old rows and Progress bar; their strings are gone.
- The crock judges loading milk at the whole degree it shows: milk reading 45°C (45.3) no longer reads "Too hot for
  the grain at 45", nor 35°C (34.6) too cool. The crock's Too hot / Too cool reasons have their °C.
- The crock remembers a clabber start (`clabber` in its modData, cleared when emptied).
- Lore lines checked: the Culturing Pot's yogurt line says woollen blankets (sheepskins dropped, unsourced), the
  kefir line opens "By tradition" (the bag by the door is told, not documented).

## 0.0.24
- **Culturing Pot Info on the settled look** (user, session 69; TP Core 0.1.47's starter slot): a band with the pot's
  state and time to its next change, the Station block (`TPStation_CulturingPot.png`), and the holdings: the starter's
  slot (dashed and greyed while it waits, the yogurt starter and the grains split on the diagonal when either fits,
  one when only one does; bright when in; cleared to "used" at the wrap), an arrow into the milk's tank (its heat as a
  bar in every state, bubbles while it sets or ferments, its state line "50%, 3h"), and for kefir an arrow out to the
  grains that come back ("110 at ready", green and clickable to strain once ready). A starter or grains dragged onto
  the slot go in, milk dragged onto the tank pours in; a click or right click on a slot opens what it takes. Fill Jars
  and Fill Cups (set), Pour Out (cooling, too cold) and Strain Kefir (ready) as buttons, and **Pour from the Cauldron**
  whenever a Stone Hearth's cauldron is within 2 tiles and the pot has room (scalded milk for yogurt, any milk the
  grains survive for kefir; greyed with the reason, its hover the cauldron's litres and heat). Lore beside the holdings,
  yogurt's or kefir's. The old rows and bars are gone.


## 0.0.23
- The Yogurt Incubator is the **Culturing Pot** (it makes kefir too), the Yogurt Pot the **Lidded Clay Pot** (Unfired as
  well), the Wrapped Yogurt Pot the **Wrapped Clay Pot**; recipes, tooltips, help, guide, README and Workshop text
  follow. Display names only: item and entity ids, modData and ledger keys keep their names, so placed pots load as
  before. The pot's build tooltip names kefir.
- **Milk with no starter goes either way** (user, session 69: the starter decides the process): Add Kefir Grains takes a
  pot of milk with no yogurt starter yet once it is 45°C or cooler (35 to 45°C weakens live grains, as before), and it
  becomes a kefir pot; over 45°C it is greyed with the milk's heat, at 35 to 45°C its hover warns the live grains come out Hungry and says to wait below 35°C. Was: grains only into an empty pot. A set or
  setting pot still refuses grains. The too-cold help names kefir as the way out; README and guide 5 follow.

## 0.0.22
- Kefir grains take a fiftieth of the Drying Cloth's room each (`M.GRAIN_ROOM` 1 of 50, was ten to a lot; TP Core
  0.1.44's room): fifty a cloth as before, one lay of any count is one lot, and a single grain no longer takes a fifth.

## 0.0.21
- Kefir grains on the Drying Cloth show as lumpy grains in Cloth Info's cells (TP Core 0.1.39's patterns); `TPCell_KefirGrains`.

## 0.0.20
- Temperatures in the game's text read with the degree sign ("12°C", was "12 C"), as TP Core 0.1.37's.

## 0.0.19
- The window rows read the station's full name and Info (Yogurt Incubator Info, Starter Culture Crock Info), as vanilla's Fireplace Info and
  Generator Info; the window's title is the bare name. The short "Vessel Info", "Tub Info" and the like are gone.

## 0.0.18
- **Every vanilla jar** (series recipe audit, 2026-11-19): Wrap and Unwrap take the Glazed Ceramic Jar too (wrapped as
  the Ceramic Jar), and Collect into a Jar takes the glassmaking Jar (`Base.JarCrafted`, also "Jar" in game), 1 L.
- **Hand recipes work from the floor** (series recipe audit, 2026-11-19): every hand recipe but Packing has
  `CanBeDoneFromFloor`, so its inputs aren't carried into the inventory first (vanilla moves them otherwise): Wrap and Unwrap, Wrap and Unwrap Yogurt Pot, Open Kefir Grains.
- **The game's names**: Ceramic Jar, Glazed Ceramic Jar and Ceramic Pot (was "Clay Jar", "Clay Pot") in the README,
  Workshop text, guide, DEVHELP, the Jars line of Incubator Info and the crock's tooltip.

## 0.0.17
- **Info in the main menu too** (user, session 53): every station's Info row is also at the bottom of the main right-click menu, besides its submenu (TP Core's `UI.topInfo`). Incubator Info and Crock Info.

## 0.0.16
- **Info windows open from the right-click menu only** (user, session 53): a left click on a station is vanilla's again, as for every vanilla workstation (a container opens its loot window). Incubator Info and Crock Info are in their menus.

## 0.0.15
- **Kefir grains dry on TP Core's Drying Cloth** (2026-11-19; needs TP Core 0.1.20): ten grains to a lot, by the
  same curve as before (about 2 days at 25 C and up, 5 at 10 C, waiting in a shut room and when frozen). Dry, they
  come off as Dried Kefir Grains; taken off early, as live grains. Dead grains aren't laid. **Spread Kefir Grains**
  is gone; a Kefir Grains on a Cloth from an older save still dries where it lies and is collected as before. Grain
  overlays for the cloth (tiles 24 to 33). `TPD.kit("kefir")` adds a Sheet and 2 Stones for the cloth.

## 0.0.14
- **A Yogurt Incubator or Starter Culture Crock with anything in it can't be picked up** (2026-11-19): milk, a
  starter, kefir grains or a culture keep it where it is, and its time goes by its place; empty, it picks up as
  before. Hot milk still travels in a Wrapped Yogurt Pot.

## 0.0.13
- **Aired rooms** (2026-11-19, TP Core 0.1.15): kefir grains on a cloth dry by moving air: in a shut room they wait
  (*It won't dry here: the room is shut. Open a window.*; `M.STILL_AIR_PLACE`). The yogurt history keeps the rooms'
  new means with each reading. Everything else reads TP Core's new place temperatures (a shut room stuffier in
  summer, harder in autumn). `tools/season_report.lua`: an aired room column (was loft). Needs TP Core 0.1.15.

## 0.0.12
- **No shed column** (2026-11-19, TP Core 0.1.14): TP Core has no Enclosed place any more, so `tools/season_report.lua`
  drops *In a shed*. Nothing changes in game.

## 0.0.11
- **By a fire** (2026-11-18, TP Core 0.1.11): butter, milk in a bottle, kefir grains and grains drying on a cloth count by a fire or banked embers when within 2 tiles of one (28 / 24 C). Ready kefir in a pot by a fire, and its grains starving there, now age by the pot's noted fire; before, time there counted nothing. Needs TP Core 0.1.11.

## 0.0.10
- **Docs** (2026-11-17): the Stone Hearth takes 12 Clay (TP Core 0.1.9; was 2). README, guide, Workshop text.

## 0.0.9
- **Docs** (2026-11-16): the Stone Hearth is built of 12 Stone Blocks, 2 Clay and a trowel (TP Core 0.1.7; was 8 Clay Bricks). README, guide 5, Workshop text; nothing changes in game.

## 0.0.8
- **Internal** (2026-11-16): the kefir grains loot goes through TP Core's `Loot.add` and names the packet by `GRAIN_PACKET`, not a second copy of its name. Same lists and weights; nothing changes in game. Needs TP Core 0.1.5.

## 0.0.7
- **Workshop text** (2026-11-16): it said no loot table is changed; it now names the Packet of Kefir Grains loot. Nothing changes in game.

## 0.0.6
- **Kefir in the player's guide** (2026-11-16): guide 5 has a new chapter 10, Kefir (finding grains, a batch, speed by place, the grains' states, starving, drying, the fluids and the cure), kefir rows in the Almanac, the Yearly Plan, Tips, Troubleshooting, What the stations show and the Tester's Toolkit; later chapters renumbered 11 to 19. README header now shows the right version. Docs only: nothing changes in game.

## 0.0.5
- **Kefir, part 3: grains that starve, and drying them** (2026-11-16, `TraditionalPreservationDairyKefir.lua`, the new `TPKefirGrains` action). **Starving**: out of milk (carried, stored, in a pot with no milk, or left in a finished batch from the moment it is ready) each grain goes Hungry at about 2 days and dies at about 7 at 20 C, on milk's curve (a fridge about 5 times as long, frozen they wait), each on its own clock: a grain item keeps it in modData, a pot keeps its unfed grains in lots so grains put in apart keep theirs. Milk feeds them. A place over 35 C turns live grains Hungry, over 45 C kills them, in milk or out. Grains coming back from dried don't go Hungry but die at 7 days. A finished batch's grains are done with it at Ready (grown, hungry ones live again), so grains starved after it stay Hungry. Grain items are named by state: Kefir Grains (Live), (Hungry), (Reviving), (Dead); the Add Kefir Grains row *Coming back from dried* is now *Reviving*. A pot whose grains are all dead says so instead of *frozen*. **Spread Kefir Grains to Dry** (a grain's right-click menu, One or All, a cloth from the strain cloths): the grains and the cloth become Kefir Grains on a Cloth, drying where it is left on the place's temperature, 2 days at 25 C and up, 5 at 10 C, paused frozen; **Collect Dried Kefir Grains** once dry gives Dried Kefir Grains and the cloth back. Grains and cloths catch up when looked at or moved (TP Core's `PlaceKeepingUI`). **Separated kefir bakes** as soured milk does (cake batter, muffins, cereal). Console: `TPD.grains()`, `TPD.starve(hours)`, `TPD.give("cloth")`. Season report golden: the new ledger totals only. test_kefir_grains, test_baking, test_console, test_kefir_menu. TESTING_GUIDE 43p-43u (and 43b, 43g, 43i, 43n).

## 0.0.4
- **Fresh kefir reads Kefir (Fresh)** (2026-11-16): anything that goes off shows *(Fresh)* in its good state, as milk does; was plain Kefir. Both cow's and sheep's (still one name, so never Mixed Beverages). TESTING_GUIDE 43a.
- **Scalded milk reads Cow's Milk (Scalded, Fresh)** (2026-11-16): scalded milk still rots, so it shows *(Fresh)* too; sheep's and animal's the same. Fluid names only. README, guide 5, TESTING_GUIDE.

## 0.0.3
- **Kefir, part 2: the culture in the Yogurt Incubator** (2026-11-16, `TraditionalPreservationDairyKefir.lua`, the new `TPKefirIncubator` action). One culture per pot: **Add Kefir Grains** into an empty pot makes it a kefir pot (a row per kind carried, Live, Hungry, Coming back from dried, with One, Enough for full speed and All; dead ones in red), and it refuses a yogurt starter, as a pot of yogurt milk or one with a starter refuses grains. **Pour Milk**: any milk, raw or scalded, from a container or a Stone Hearth's cauldron within 2 tiles, up to 5 L, no cooling and no wrap; milk over 45 C is refused (it would kill the grains), at 35 to 45 C the live grains turn Hungry. It ferments on the place's temperature: 24 hours at 18 to 25 C with a live grain to every 40 ml (125 for 5 L), slower with fewer (hungry and dried grains count half), 0.15 at 4 C to 1.5 at 30 to 35 C, paused frozen. More milk dilutes what has fermented; grains can go in mid-batch. Live grains grow a tenth a batch, by the share of it done at 15 to 28 C; the part-grain stays with the pot. Hungry grains come back Live, dried ones over 2 batches. Ready kefir ages in the pot from then and keeps that age when strained. **Strain Kefir** into any empty container through a Strainer, or a cloth (the butter's) at twice the time, none used up; the grains come out with the first strain. **Take Out Kefir Grains** before the milk. Status, Pot Info and the tooltip say grains, speed, fermented and hours to ready; the pot wears a linen cap while it ferments. Console: `TPD.pots()` and `TPD.age(hours)` take kefir pots; `TPD.kit("kefir")` now 25 live grains, a pot of 1 L of milk, a Strainer and a Ripped Sheet as well. test_kefir_pot, test_kefir_menu, test_console. TESTING_GUIDE 43h-43o.
- **Season report: kefir** (2026-11-16): a table for a 5 L kefir pot with 125 live grains, hours to ready and grains out, by month and place (golden updated). The tables' header had lost the **In a shed** column (the Smokehouse's place, added in 0.0.1's refactor), so every column from Basement on was named one to the left; fixed. Nothing changes in game.
## 0.0.2
- **Naming sweep** (2026-11-16, TP Core's DEVGUIDE "How code is named"): a pot's saved table is its `batch` (`M.batchOf`), a crock's its `crock`, a station's `M.stationModData`; the ledger's `M.MILK_PROCESS`, `M.KEFIR_PROCESS`; `M.recordWeather`; a kefir grain's saved `grainState` (was `state`); carried milk's `carry`; the windows' `potView` / `crockView`. Tests and golden results unchanged; nothing changes in game. Pre-release: an old test save's stations read as new, so test on a fresh save.

## 0.0.1
- **One or All** (2026-11-16, TP Core's `PiecesUI`): Put Butter in a Pot and Put Butter in the Cauldron put one butter (the oldest) or all that fit. test_menu.
- **Butter in a pot as fluid** (2026-11-16): a pot and the cauldron are one route at two sizes, on TP Core's `ItemFluid`. **Put Butter in a Pot** (a butter's right-click menu, Cooking 2) puts each Butter or Salted Butter carried into an empty Pot, Forged Pot, Saucepan or Copper Saucepan (or one holding melting butter) as a quarter litre of Butter (Melting), 6 to a pot, 2 to a saucepan; no kettle. Kept steaming an hour on any stove or fire it is Clarified Butter (Melted), strained as the cauldron's is (Strain Clarified Butter); an hour more and it **burns**: the vessel becomes a burnt Pot of Butter or Saucepan of Butter (new saucepan items with vanilla's saucepan look), and Scrape Out Burnt Butter gives it back, condition kept. Raw it can't be poured into another container, only thrown away (Empty), and goes rancid when its oldest butter would have. The cauldron never burns. **Gone:** Add Butter to the Pot, Pour Off Clarified Butter, the two-butter cap and the unburnt Pot of Butter (`PotOfButter` / `PotForgedButter` are now `PotOfBurntButter` / `PotForgedBurntButter`; no migration before release). `TPD.kit("butter")`: nine butter, a pot, a saucepan, a burnt pot. test_butter, test_menu (the pot row), test_console. TESTING_GUIDE 42d-42f rewritten.
- **Clarified Butter's icon** (2026-11-16): vanilla's butter block in ghee's amber (`tools/build_tileset.py`, `recoloured`), was Lard's.
- **Console: butter nearby** (2026-11-16): `TPD.butter()` and `TPD.rancid(days)` take butter in containers within 4 tiles (a fridge, a freezer) as well as carried, through TP Core's `PlaceKeepingUI.near`; before, butter put in a fridge couldn't be checked. Found in the butter test (42b).
- **Kefir, part 1: fluids, grains and loot** (2026-11-16, `TraditionalPreservationDairyKefir.lua`; the culture in the incubator comes next). **Kefir**: a fluid with its milk's food less the lactose (about 25 kcal and 6 g of sugar a litre), hunger and thirst as milk. A fluid's food is its type's, so cow's and sheep's milk each make a kefir of their own (`CowKefir`, `SheepKefir`), mixed by share, and both are called Kefir: the engine shows two fluids of one name as one. Animal's Milk (vanilla's, from Milk Powder and water) has cow's food and makes the cow's, so no container holds three kinds (which read Mixed Beverages). Left long it **separates** (curds and whey: a little unhappiness) at about 3 days at 20 C and **rots** at about 10, on milk's curve through TP Core's FluidAgeing (Milk goes off and its speed apply). **Fresh kefir eases food sickness**, 10 a litre, through TP Core's `Drink`, only while sick, on the shared food sickness cooldown of 3 game hours. **Packet of Kefir Grains** (loot only: a farm's storage shelves, a Gigamart's farming shelf, very rarely a home fridge or kitchen cupboard) opens like a seed packet into 10 **Dried Kefir Grains**; **Kefir Grains** (a gram each) keep a state and clock in modData (Live, Hungry, Reactivating, Dead). Icons painted by `tools/build_tileset.py`. Season report: a kefir column, the same as milk's (golden updated). test_kefir.
- **Butter that keeps** (2026-11-15, `TraditionalPreservationDairyButter.lua`). **Butter goes rancid by place** on TP Core's `PlaceKeeping`, as Potted Meat does: 30 days fresh, 45 to rotten in a 15 C cellar, about 75 / 110 in a powered fridge, 20 / 30 in a 20 C room, 15 / 22 at 25 C and over, never frozen; vanilla's Butter, store or churned, gets these days the first time it is seen. **Salted Butter** (Salt Butter: a butter and a salt) keeps three times as long, 90 / 120, starting as far into its days as the butter was. **Clarified Butter**: Put Butter in a Pot (and Add Butter to the Pot for a second), cook it on any stove or fire, Pour Off Clarified Butter through a cloth or Strainer (kept) gives one for each and the pot back; it never spoils, as Lard; burnt, Scrape Out Burnt Butter. **Many at once in the Stone Hearth's cauldron:** Put Butter in the Cauldron (TP Core's `CauldronUI.addPieces`), a quarter litre of Butter (Melting) a butter; an hour's steaming makes it Clarified Butter (Melted), ladled into any container and strained, a quarter litre to a Clarified Butter (Strain Clarified Butter); raw, it goes rancid by its oldest butter. Every step but scraping takes **Cooking 2**. Sandbox **Butter keeps by place** (on; off, butter never spoils, as vanilla's). Console: `TPD.butter()`, `TPD.rancid(days)`, `TPD.give` butter / salted / clarified, `TPD.kit("butter")` (with a Ripped Sheet). test_butter, test_console, test_menu (the cauldron row). Fish & Meat's Potted Meat takes Clarified Butter when Dairy is on. In-game step in TP Core's `TESTING_GUIDE.md`.
- **Guide shortened** (2026-11-15): what TP Core's guide has in full (the cauldron's general rules, the loft, the copper) points there; repeated secrets, tips and a margin note cut; no dev note or "before this change" history. Nothing changes in game.
- **README** (2026-11-15): no dev-machine path. Nothing changes in game.
- **Docs and comments** (2026-11-15): decisions are stated plainly, without attributions (CHANGELOG, comments, the items script). Nothing changes in game.
- **README** (2026-11-15): the opening says milk goes off, soured milk bakes and starts a crock, scalded milk doesn't sour, and milk carriers can be wrapped.
- **Refactor with TP Core's Stone Hearth split** (2026-11-15): the cauldron's fluid rules are TP Core's `CauldronFluid.*`, the cauldron itself `Cauldron.ID` and `Cauldron.of` (were reached through `Fire`); the cauldron actions' and menu's fire is `fire` (`action.fire`). test_incubator stands in for the script manager, as TP Core's Cauldron teaches its recipe on the same event. Nothing changes in game.
- **Refactor with TP Core's names** (2026-11-15): TP Core's `Hearth` is `Fire`; `M.isHearth` is `M.hasCauldron`, `M.hearthsNear` `M.cauldronsNear`, `M.HEARTH` `M.FIRESIDE`; text keys `PourFromCauldron`, `LoadFromCauldron`, `NoCauldron`, `CauldronHelp*`. Nothing changes in game.
- **A held cup, crock seed or incubator item leaves the hands** (TP Core's `Action.removeItem` now uses vanilla's `Remove`; Fish & Meat refactor B3), and so does a pot swapped or burnt by the wrap (`swapForFresh`, `burnWrap`; were `DoRemoveItem`). test_jar's and test_wrap's stand-in containers have `Remove`. In-game step 158f of TP Core's `TESTING_GUIDE.md`.
- **Refactor** (TP Core's refactor pass, step c): nothing changes in game but two fixes. **Split:** carried milk (the heat record, `stampHeat`, pours, the cauldron's hooks) is in the new `TraditionalPreservationDairyCarry.lua`, wrapping (wrap, unwrap, the renaming, `burnWrap`) in `TraditionalPreservationDairyWrap.lua`; the main file requires both, and every `M.<name>` still works. One hour-by-hour walk (**`M.walkHours`**) brings both a pot and carried milk up to now, stopping where a fire burns out; emptied pots and crocks clear named field lists. The wrap's burning rides on TP Core's one minute look at the heat (`Station.onHeatNear`; `World.BURN_RADIUS` gone, the same 8 tiles). The World's two updates share one helper; the pot's stage picks its overlay by name. **`M.incubatorOf(station)`**, **`M.crockOf(station)`** (the saved state, for checks every tick), **`M.hasMilk(item, ml)`**, **`M.YOGHURT`**; the actions use TP Core's `Action.removeItem` and `Hearth.redraw`, the menus `UI.refuse` and `UI.firstSelected`. The checks for whether Dairy's World is loaded are gone (it always is in single player; rule 13). `M.PLACES` is TP Core's places plus the two fire places, so **Enclosed** (the Smokehouse) is in `TPD.weather()` and the season report (golden updated: one new column, the same as Open). `placeAt`'s fallback is `Weather.DEFAULT_PLACE`. **Pre-release leftovers gone:** `M.isWrappedPot`, `M.OLD_JAR_ML` (now `M.SPAWNED_JAR_ML`, for a jar never filled at a pot), `M.cupsLeft` and the `tpdCups` / `tpdMl` jar fields, the clay-jar icon fix, the cow's-milk fallback for pots from before the milk's kind was kept, `M.hasAny`. `TPD.tiles` uses `Station.near`. **Fixed:** feeding the crock, or loading it from a carried container, now clears the milk's age record when it empties the container, as a clabber did (new milk poured in could have started at the old milk's age); frozen milk no longer sets on Forgiving (`M.setRate` goes through `Weather.rate`'s frozen stop, as the crock's culture does; above 0 C nothing changes). Tests: test_menu and test_console load the World, the stand-in station got the methods its redraw asks, a feed checks the fix; test_incubator checks frozen milk on Forgiving; test_jar a spawned jar instead of a pre-F4 one. In-game step 157 of TP Core's `TESTING_GUIDE.md`.
- **Milk follows vanilla's Food Spoilage setting**: milk's age runs at the game's Food Spoilage speed (TP Core's `FluidAgeing.foodRotSpeed`: Very Fast 1.7 to Very Slow 0.4) times the sandbox's **Milk spoiling speed**, which now multiplies on top. Default settings change nothing; on Very Slow milk keeps 2.5 times as long. Sandbox tooltip, guide 5, README. test_incubator. In-game step 150 of TP Core's `TESTING_GUIDE.md` passed (INGAME_PASS 149).
- **Refactor** (2026-11-14, with TP Core's Weather.lua tidy): the crock's culture rate is `Weather.rate`. Nothing changes in game; tests and golden results unchanged.
- **Refactor** (2026-11-14, with TP Core's HearthUI tidy): the milk notes in Hearth Info come through `CauldronUI.addNotes` and read the cauldron as `info.part`; `M.isHearth` and `M.hearthsNear` ask TP Core's `Hearth.isFitted` / `Hearth.fittedNear` with `Hearth.CAULDRON`. Nothing changes in game; tests and golden results unchanged.
- **The crock's build refuses stoves, fridges and washers; no station in front of a door** (after TP Core's in-game step 146b, where the crock built on a stove and couldn't be seen): vanilla's build ghost only asks the put-down rule on a solid square, so the crock's build recipe now asks TP Core's `TraditionalPreservationCore.offAppliances` (no appliance on the square, and not in front of a door). The Yogurt Incubator's asks `TraditionalPreservationCore.doorFits`, and both are kept from a door's front when put down (`UI.keepDoorsFree(Tiles.STATIONS)`). In-game step 147 of TP Core's `TESTING_GUIDE.md` passed (INGAME_PASS 146).
- **Refactor** (2026-11-14, with TP Core's Hearth.lua split): the place temperature and the crock's marks come from `Weather` (TP Core dropped the `Hearth.placeTemperature` and `Hearth.mark` aliases); `M.hoursToHot(cauldron, banked)` passes banked on to `Hearth.hoursToHot`. Nothing changes in game; tests and golden results unchanged.
- **Refactor** (2026-11-14, with TP Core's scalded-into-states fold): milk's spec names scalded milk as a state made by heat (`states = { Scalded = { fluids = M.SCALDED_MILKS, heat = true } }`, `M.SCALDED_STATE`) in place of its `scalded` field; `TPD.ages()` asks `FluidAgeing.inState`. The carried-milk record (`tpdCarry`) is unchanged. Nothing changes in game; tests and golden results unchanged.
- **Refactor** (2026-11-14, with TP Core's copper-to-cauldron rename): the code reads TP Core's new names (`Hearth.CAULDRON`, `Hearth.cauldronState`, `CAULDRON_ML`), its own say cauldron (`M.cauldronHot`, `M.cauldronScalded`, `M.cauldronToPot`, `TPStarterCrock.cauldronReady`, the `CauldronNoMilk`, `CauldronNotHot`, `CauldronNotHeld` keys). Nothing changes in game; tests and golden results unchanged. The mod list's description and guide 5's loop diagram say the Forged Cauldron (were "a Hearth's copper", "HEARTH'S COPPER").
- **Refactor** (2026-11-14, with TP Core's FluidAgeing refactor): the carried-milk record's `steamed` field from test builds is no longer read (nothing released wrote it). Nothing else changes.
- **The wrap goes on at 45 C exactly**: the incubator wrapped at the first ten-minute reading at or under 45 C, by then a degree or two colder, and cold-month pots fell short; it now works out the crossing within the step (`M.advanceBatch`; cooling is exponential). A 5 L pot now sets indoors from April to November (was May to October; November 1.5 + 9.3 hours), in a basement from April to January, by a campfire in the open from February to November; every other cell about 0.1 to 0.5 hours quicker. Golden re-recorded; README, guide 5 (the Almanac's tables, the Yearly Plan) and the Workshop text from `tools/season_report.lua`. In-game step 139 of `TESTING_GUIDE.md` (INGAME_PASS 138).
- **Console** (2026-11-14): `TPD.help()`'s last line names TP Core's renamed `cauldronInfo` and `stone`.
- **Pour from the Cauldron**: the incubator's *Pour from the Hearth* and the crock's *From the Hearth* now read **Pour from the Cauldron** and **From the Cauldron**; the notes and refusals say *a cauldron within 2 tiles* (*No cauldron within 2 tiles* when there is none). Text keys unchanged. Guide, README, DEVHELP, Workshop text.
- **Docs pass after TP Core's Stone Hearth hub**: guide 5, README, DEVHELP and Workshop text: build a Stone Hearth and fit the Forged Cauldron (materials, skills and XP), Pour into / Fill from / Empty the Cauldron, Stone Hearth Info; `TPC.copper` is TP Core's `TPC.cauldron` now (the crock kit's hint and the help line too).
- **The Forged Cauldron** (TP Core, 2026-11-13, the Stone Hearth hub's step ii, install 2a): the Hearth's copper is now the Forged Cauldron, fitted on a Stone Hearth; texts say cauldron, and the missing-Hearth refusal says to build a Stone Hearth and fit a Forged Cauldron. The menu icon is Core's `Item_TPCauldronFull`. In-game step 128 of `TESTING_GUIDE.md`, passed.
- **The copper's state under its own key** (TP Core, 2026-11-13, the Stone Hearth hub's step i): Make Starter Culture and Fill the Pot from the Hearth read the copper with `Hearth.copperState` (`TPStarterCrock`, `TPYoghurtIncubator`); `test_menu.lua` builds the new state. Nothing changes in game.
- **The Hearth's new look and build** (TP Core, 2026-11-13): README, guide 5 and the Workshop text give the new materials and describe the copper as a kettle hung over the fire.
- **Docs regenerated** (2026-11-13): the README's and the Dairymaid's Almanac's pot tables (fire under a roof and in the open added), the crock's times, the Yearly Plan and the Workshop text from `tools/season_report.lua`; a pot now sets indoors from May to October (the warmer room), November just misses (5.8 of 6 h); the crock pauses frozen (about 90 days from January in an unheated room).
- **A frozen crock pauses** (realism pass L6): the Starter Culture Crock's culture stops at 0 C and below (TP Core's `Weather.frozen`) and goes on once thawed, on Forgiving, Normal and Harsh alike; Off still ignores the weather. Setting in the pot is unchanged (warm milk). A crock started indoors on the first of January now takes about 2170 hours to cultivate (was 800, the curve's slowest rate), as the unheated room sits below freezing much of the month; the basement and every fire are unchanged. The info block already says the crock has stopped. Golden re-recorded. Test in `test_incubator.lua`. In-game step 118 of `TESTING_GUIDE.md`.
- **The realism pass's Core part** (TP Core, 2026-11-13): an unheated room or loft is 2 C warmer in the cold months; a fire under an open roof or in the open warms the air it stands in instead of holding 28 C (indoors unchanged). `tools/season_report.lua` gains *By a fire, under a roof* and *in the open* columns. A pot's history reads a fire outside by that hour's weather (`M.pastTemperature`). The guide's tables wait for the cultures' frozen stop (ROADMAP, the curve edits). Note: November's 5 L pot indoors now just misses setting (5.8 of 6 hours): the wrap goes on at the first ten-minute reading at or under 45 C, and a slower-cooling pot crosses it just after one.
- **Wrapped containers look wrapped**: a wrapped pot, jar or bucket shows its own vanilla icon
  bundled in a striped towel under a twine tie (`towel_wrap` in tools/build_tileset.py; six looks, `M.WRAPPED_LOOKS`),
  and lies on the ground as one towel bundle sized to the container (new `tools/build_model.py`,
  `Models_X/TowelBundle.glb`, the `TowelBundle_*` models: sizes from vanilla's meshes, a bucket taken as 30 cm). Set
  through the item's ModData (`customInventoryIcon`, `worldStaticModel`) on wrapping, cleared on unwrapping. The
  Wrapped Yogurt Pot gets the same icon style and the bundle as its model (was the vanilla clay jar). Tests
  (TESTING_GUIDE step 112).
- After the first look in game: the recipes are named **Wrap** and **Unwrap** (were "Wrap a Pot, Jar
  or Bucket" and "Unwrap a Pot, Jar or Bucket"); the clay jar's bundle is sized by the jar's width (scale 0.28, was
  0.433: twice as wide as the jar), then on a narrow copy of the bundle (`TowelBundleTall.glb`, 0.4 as wide) at
  scale 0.42: as narrow as the jar and about as tall (in game).
- **A hold at the scald** (from the realism pass, pick A with 20 minutes): milk reads Scalded only after
  20 minutes at 85 C or more in all (`M.SCALD_HOLD_HOURS`), in the copper (TP Core's `Hearth.heldHours`) or in a pot on
  a stove or fire (TP Core's `FluidAgeing`, `scaldHold`). Pour from the Hearth refuses steaming milk until then and
  says how many minutes are left (`M.copperScalded`, `M.holdMinutesLeft`); carried milk drawn from the copper or taken
  off the heat is scalded only once held (the `tpdCarry` record, for milk ageing off too). Everything that reads
  Scalded follows: the incubator, never souring, Churn Butter. `TPD.milk` at 85 C or more gives a pot that has had
  its hold. Texts, tests, README, guide (TESTING_GUIDE step 111).
- **The Yearly Plan** (guide chapter 17): setting yogurt, starting the crock and keeping raw milk as the game's planting seasons: season, best and poor months, out of season, where and how long at best, from the Dairymaid's Almanac; the fire, embers and powered room for any month. The Tester's Toolkit is now chapter 18.
- **Docs pass, sweep step G** (2026-11-12): seven kinds of place (guide, README); banked embers are a Hearth's or a Firebox's; README: a Loft column, the grid's hours and the crock in a powered room, milk ages in a loft too; Workshop text names Fish & Meat.
- Needs Build 42.22 or newer (`versionMin`, was 42.20: everything is checked on 42.22). Workshop text (sweep step F).
- **A powered room in the numbers** (2026-11-12): the season report has an *Indoors, grid on* column (22 C, its own
  ledger and history with the grid on); the guide gives the figures under its month table: 2.2 + 7.0 hours for 5 L,
  about 9 for 1 L, the crock's first stage about 32 hours.
- **On TP Core's shared modules** (2026-11-12; nothing a player sees): the Jar of Yogurt's portions, name, weight and
  empty jar go through Core's `Portions` (its `onEat` in place of the mod's own wrap of the eat action; the jar's
  texts are Core's), the heat record rides a pour through Core's `Pour` (in place of the mod's own wrap of
  `ISFluidTransferAction`), and `M.mlIn` and `M.isEmptyContainer` are Core's `Container.ml` and
  `Container.isEmptyVessel`. Save keys are unchanged. In-game step 101 of `TESTING_GUIDE.md`.
- Guide (2026-11-12): checked line by line against the code. The almanac has a Loft column; warm milk for the crock
  may come in any container at 35 to 45 C; a wrap also burns on a barbecue; Yogurt is spelled the game's way
  throughout; whole chapter numbers (When Milk Goes Off is chapter 8, the crock 9), a Credits page.
- **TP Core's loft** (2026-11-12, consistency sweep step H): `M.PLACES` has Loft. In the top storey a full pot
  sets about an hour sooner from July to September and the crock makes starter a quarter sooner in summer; raw milk
  sours a little faster there (1.2 days in July against 1.4). Season report has a Loft column; golden re-recorded.
  README, guide, Workshop text.
- Debug console (2026-11-12): `TPD.give(name, n, option)` spawns a full Jar of Yogurt (glass, clay or glazed), a
  starter or an empty cup; `TPD.milk` takes a third argument for sheep's or Animal's Milk. Test, DEVHELP, guide.
- Guide: no emojis (2026-11-12): the decorative bullets and margin-note marks are gone, warning signs read **Warning:**.
- **The cellar runs a month behind** (2026-11-12, TP Core): a basement follows the ground (the history keeps it,
  `ground`), about 5 C from January to March and 13 C from July to September. A full pot sets in a basement from May
  to December, indoors from June to November; the crock's first stage takes 4 to 5 days in a basement July to
  October. The season report starts from a long-running save's weather and reads 30-day months (each month's forecast
  also held the 10 days before it). Guide, README, Workshop text.
- **TP Core's new places** (2026-11-12, consistency sweep step C): a room is the season's mean (22 C while the grid
  is on), Covered counts as its own place (`M.PLACES`), a basement follows the season a third as far. Yogurt in an
  unheated room sets May to October; by a fire as before. The place words are Core's ("12 C (Indoors)"); the crock's
  fire catch-up is Core's `Hearth.catchUp` (same numbers). Season report, README, guide, Workshop text, sandbox tooltip.
- Debug console by the series' convention (2026-11-12, consistency sweep): `TPD.age(hours)` now moves every loaded
  incubator and crock on (it was `skip` and `culture`, both gone); the milk you carry ages with `TPD.sour(hours)`.
  Tests, DEVHELP, guide.
- **Yogurt, as the base game spells it** (2026-11-12, consistency sweep): every text the player sees, the guide,
  README and Workshop text; `TPD.kit("yogurt")`. Item, station and save names keep their spelling. *Yogurt Pot
  (Unfired)*, as vanilla's unfired clay.
- Milk taken off the heat is stamped through TP Core's `Transfer.before` (2026-11-12) instead of Dairy's own wrap of
  `transferItem`. No change in play.
- TP Core's copper is now 60 L (was 20): README, guide 5 and Workshop text updated (a full copper is twelve pots,
  about 2.75 h to the steam). Test pins `Hearth.COPPER_ML == 60000`.
- Wrap any milk carrier: Wrap / Unwrap a Pot, Jar or Bucket (crafting menu, Cooking, empty only;
  Sheet + Twine, given back on unwrap) for Base.Pot, PotForged, EmptyJar, JarCrafted, ClayJar, Bucket, BucketEmpty,
  BucketCarved. The item stays itself with its capacity; the mark is its fluid container's name (TPDWrappedPot / Jar /
  Bucket, saved by the game and shown in its name; vanilla caches the shown name and Lua can't clear it, so a tick later
  the item is swapped for a new one of its type with the same fluid, ModData, heat, condition and favourite; on the
  floor it shows after a load. The first two builds called a protected `reset()` and package-private
  `add/removeComponent`: errors in game; every Dairy and Hearth menu names a wrapped one "Wrapped <its name>" through
  `UI.nameHook`, as vanilla's display name doesn't see the wrap) and `tpdWrapped` (old name and rain factor) in ModData. No rain while wrapped. It carries milk hot as the
  Wrapped Yoghurt Pot does (`M.isWrapped`). A wrap in a container at 1.3 or hotter within 8 tiles of a player burns
  each game minute: Sheet and Twine gone; on a stove, oven or barbecue a fire starts (as burnt food), in a fireplace,
  Hearth or campfire not; a Wrapped Yoghurt Pot becomes a bare Yoghurt Pot and its milk is lost. Test `test_wrap.lua`.
- A Jar of Yoghurt as a starter: Add Starter takes one portion (250 ml, a Yoghurt cup's worth) from
  a jar with a whole portion left and not gone off; the rest stays in the jar, and the empty jar comes back with the
  last portion. Its hover says so. `M.isStarter`, `M.takeJarPortion`.
- Hearth: Empty the Copper (TP Core) is listed with the Hearth's options in the README and guide.
- The clabber crock (D9 step 2b): Load Soured Milk on an empty Starter Culture Crock takes half a litre of soured
  milk, warm or cold, with no wheat, and the crock waits for fresh milk at once (starters in about 12 hours instead of
  36). Rotten milk is listed in red, and so is less than half a litre. Soured milks of different animals now blend, as
  fresh ones do. The crock's waiting stage reads "Cultured" (was "Cultivated"). Guide: "Clabber or yoghurt?" in 7½
  (mesophilic vs thermophilic, backslopping), the crock's short way in 8, a tip and a troubleshooting line.
- Docs: the Hearth's full reference moved to TP Core's README and guide (`6_Core_Guide.md`); Dairy's keep what a
  dairymaid needs and point there.
- Docs (2026-11-11 pass against the code): README and guide gain a section on milk going off (Fresh, Scalded,
  Soured, Rotten, times by place, baking); "by a fire" is any lit fire within 2 tiles, not only the Hearth; the
  Hearth's menu lists Fill from the Copper and Bank / Stoke; Hearth Info reads "Steaming: Yes"; setting slows above
  45 C (said 50); a portion's food is its milk's (C23) everywhere; the stale caveats (30 kcal portions, milk never
  spoils) are gone; the guide's sandbox table and toolkit list the milk options and `TPD.ages` / `TPD.age`; the
  Workshop text is brought up to the 20 L copper, scalding on any stove or fire, milk going off and the changed
  vanilla recipes. The incubator's help line and build tooltip say milk scalds on a stove or fire too.
- Yoghurt without a Hearth: milk scalds on any lit stove, fireplace, barbecue or campfire at 85 C
  (vanilla's lowest stove setting gets there). The pot's Pour Scalded Milk takes any scalded milk, store milk poured
  out included; Dairy's own scalded record still counts, for when milk never goes off. Milk taken off the heat keeps
  a record of its heat: an open pot cools in minutes (85 to 45 C in about a quarter hour), a Wrapped Yoghurt Pot in
  hours, and a vanilla pour carries the heat over by volume. The Hearth keeps its 20 L copper (TP Core), its pour
  into a pot or crock within 2 tiles, and the banked fire's steady 50 C.
- "Steamed" is "scalded" throughout: the menu is Pour Scalded Milk, the refusal "Not scalded",
  `TPD.ages()` says scalded; only the copper still steams. Records from test builds that say steamed still read.
- Scalded milk (D9, step 2b): milk brought to the steam in the Hearth's copper, poured out of the incubator, or poured out
  of a store carton is "Cow's Milk (Scalded)" (sheep's, animal's), with its milk's food. It never sours and spoils to its
  milk's Rotten one; raw milk mixed in makes it plain milk again. The copper, the incubator, the crock and the yoghurt's
  food take it as milk; baking takes it, and Churn Butter and Make Mildew Cure take their milks scalded too.
- Any milk bakes, fresh or soured (D9, step 2a): vanilla Make Cake Batter, Prepare Muffins and Make Bowl of Cereal
  take cow's, sheep's or animal milk, fresh or soured (vanilla: cow's only, cereal sheep's too). Churning butter,
  mildew cure and the incubator still want fresh milk; rotten milk goes in nothing. Built on TP Core's `Recipes.addFluids`.
- Milk goes off (D9, step 1). Raw cow's, sheep's and animal milk turns Soured ("Cow's Milk (Soured)") after about a
  day and a half in a 20 C room (3 days in a basement, 8 in a powered fridge, a day at 30 C, never while frozen), then
  Rotten as long again after (mild food poisoning). Vanilla's milks now read "(Fresh)". Soured milk keeps its milk's
  food, a little unhappiness; vanilla churning and the incubator refuse it (baking takes it: below). Milk scalded in the Hearth's
  copper never sours and spoils at the same age. Sealed store milk keeps until it is poured out, then counts as
  scalded. Mixing takes the older age. Sandbox: Milk goes off (on) and Milk spoiling speed (1). Built on TP Core's
  `FluidAgeing`.
- Balance (series pass, C23): yoghurt keeps its milk's food. A 250 ml portion, from a jar or in a cup, has a quarter
  litre of the milk's food as vanilla states it: cow's milk 153.75 kcal and -12.5 hunger (was vanilla Yoghurt's 30
  and -10), sheep's milk 205.75 kcal; a mixed pot goes by its shares, so 5 L of milk is worth the same eaten as
  drunk. Each Jar of Yoghurt keeps its portion's food (modData `tpdPortion`); jars and cups made before keep vanilla
  Yoghurt's. The pot's last cup holds only the food of what it took (it was a full cup's). Vanilla Yoghurt itself
  now has a cow's milk portion's food (script `HungerChange`, `Calories`, `Carbohydrates`, `Lipids`, `Proteins`, set
  where its `ReplaceOnUse` is), so shop and homemade cow's yoghurt match; Yoghurt already in a save keeps its values.
- Fixed: Pour Out from the incubator called `next`, which the game's Lua doesn't have (a Lua error, and the milk poured
  out was lost). Found with C23, which made the same mistake at load, Collect and Fill Cups.
- Player guide `5_Dairy_Guide.md` written (was the template stub): the loop, the copper, incubator, jars and cups,
  the crock, stations, the season almanac, the Dairymaid's Notebook, tips, troubleshooting, sandbox, testers' toolkit.
- Menu icons: Pour from Hearth and the crock's Hearth row show TP Core's copper (were the Hearth and a milk carton);
  Pour Scalded Milk, Pour Out and Feed show the first container they list, drawn with its milk (an empty bucket
  when none); every container row shows its milk's colour; Add Starter and Collect Starters show the starter; Collect
  and its rows show the Jar of Yoghurt and each jar; Fill Cups rows a cup of yoghurt; Eat a Portion shows the jar
  itself, clay or glazed.
- The Hearth (TP Core) has its real art now; the README no longer calls it a placeholder. The tileset builder uses
  TP Core's shared `pzart.hard_edges`.
- Fixed: a Jar of Yoghurt collected into a Clay Jar or Glazed Clay Jar had no icon. It now shows its clay or glazed
  look everywhere, and keeps it through a save.
- The incubator and its lid have hard edges, as the crock has; only the shadows on the floor stay soft (the soft edge
  left a light ring round the pot in game).
- Balance (series pass, F4): a jar takes yoghurt to its real size, 1 L in a glass jar, 2.5 L in a Clay Jar or
  Glazed Clay Jar (every jar took 1 L), and a Jar of Yoghurt is eaten from: **Eat a Portion** eats 250 ml, a
  vanilla Yoghurt's food, and the game's Eat / Eat Half / Eat Quarter work on it too. Its name counts portions, not
  cups; cups are still filled from it a portion at a time, and the last spoonful or bite gives the empty jar back.
  Collect lists each kind of jar you carry. Jars from an older save get their cups' worth of food when first used.
- Balance (series pass, F1): the Yoghurt Pot takes 6 clay (was 4). Yoghurt Incubator needs Tailoring 1 only (the
  pot carries the Pottery gate), the Starter Culture Crock Cooking 4 only. Docs: the Hearth is Masonry 2 (TP Core).
- Fixed: the starter crock could be built or put down on an electric stove or a chest freezer. It now stands only
  on a counter, a table or the floor.
- The game's generic animal milk counts as milk, as vanilla's own milking and cheese treat it: it sets, and blends
  with cow's and sheep's. Before, a copper holding it refused any other milk.
- The README, Workshop page and mod description now describe the mod as built: the Hearth's copper, the incubator,
  jars and cups, the starter crock, places and timings. DEVHELP lists the real console commands (it named `TPD.age`
  and `TPD.batches`, which don't exist), and so does the guide's Tester's Toolkit.
- Cow's and sheep's milk mix, as a mixed herd's always did: in the Hearth's copper, in a carried container and in
  the incubator. A blend keeps its shares from the copper to the pot and back out. The "milks don't mix" refusal
  is gone.
- With the starter already in, milk that would leave the pot under 40 C is refused in red ("Too cold ..."). Before,
  the wrap went on over milk too cold to set, with no way to pour it out.
- Fixed: a part-empty Jar of Yoghurt weighed a full jar again after a reload.
- A pot left for a long time catches up at a fixed cost: the hours before the two weeks of kept weather run as one
  spell, not ten minutes at a time.
- Internal: the season report's tables have their "By banked embers" header; the crock's load looks for its wheat
  once, not on every tick; the incubator's action is a table of modes; two stale comments.
- Internal: new `tests/test_console.lua` loads the debug console (TPD) and calls its commands, and new
  `tests/test_menu.lua` builds the incubator's and the crock's right-click menus on stand-ins (status line, pouring
  from a Hearth and its refusals, a set pot, several stations under one click, the controller's probe).
- Internal: made by `tp new` from the series template, with the shared core.
- Requires the TP Core mod (`TraditionalPreservationCore`) instead of carrying its own copy of the shared core.
- Internal: the yoghurt rules. Scalded milk cools in the lidded clay pot by Newton's law towards the temperature
  where it stands, and topping up mixes temperatures. With a starter in, the pot is wrapped at 45 C. The milk sets
  at a speed that follows its own temperature. A starter won't take below 40 C, so cold milk has to be reheated.
  Collecting fills one Clay Jar per litre and carries the yoghurt's age. Batches under 2.5 L cool as if they were
  2.5 L, for balance.
- Internal: a Hearth place at 28 C, for a lit fireplace, antique oven, brazier, cooking pit or campfire within two
  tiles (never an electric or gas stove).
- Internal: the Starter Culture Crock's two weather-driven stages, with a feed of fresh milk between them.
- Internal: two weeks of hourly weather in global ModData, so an unloaded pot catches up hour by hour.
- Internal: sandbox options for the setting time, the culture time and temperature sensitivity.
- Internal: 44 tests, and a golden report of cooling and setting times by month and place.
- The Yoghurt Incubator's right-click menu shows what the pot is doing (hover for where it stands
  and the time to the next change), and offers Pour Hot Milk, Add Starter, Pour Out Milk and Collect into Clay Jar.
- Internal: the world code tracks each pot, records the hourly weather, catches the milk up and picks the stage
  sprite. The pot's state lives in movableData, so it can be picked up full. The skeleton's slots, placeholder items
  and Craft-button recipe are gone.
- Internal: debug console `TPD.help()`: weather, place, pots, skip, fast timer, hot milk, starter kit.
- Items: Yoghurt Pot (thrown at Pottery 2, fired in a kiln), Jar of Yoghurt, Active Yoghurt Starter, Empty Yoghurt
  Container. The incubator is built from a Yoghurt Pot, 2 Ripped Sheets and Twine (Pottery 2, Tailoring 1).
- Set yoghurt is collected into an empty Clay Jar, Glazed Clay Jar or glass canning jar, a litre each, and portioned
  spooned from the jar into four vanilla Yoghurts with one Empty Yoghurt Container per cup (see below). The same jar
  comes back, and the cups keep the yoghurt's age.
- Every vanilla Yoghurt leaves an Empty Yoghurt Container when eaten or stirred into oatmeal.
- The Starter Culture Crock: built from a Clay Jar or a Clay Pot, a Ripped Sheet and Twine (Pottery 4, Cooking 4).
  Its right-click menu loads 20 wheat grains and half a litre of warm milk (35 C or more), feeds half a litre of
  fresh milk once cultivated, and collects 2 Active Yoghurt Starters. Its state lives in movableData.
- Internal: placeholder crock tiles (2 and 3) until the art; `TPD.crocks()`, `TPD.culture(hours)`, `TPD.crockkit()`;
  48 tests.
- Art: the Yoghurt Incubator and the Starter Culture Crock are painted clay pots that stand straight on the floor, so
  they can be set down by a fire. The incubator shows its lid on the floor (empty, ready), on the pot (cooling) or
  under a striped cloth tied at the neck (incubating), and the set yoghurt when ready. The crock, with a slip band of
  zig-zags, shows a linen cap (cultivating, waiting), milk and wheat (developing), and the culture (ready).
- Art: icons for the Yoghurt Pot (unfired and fired), Jar of Yoghurt, Active Yoghurt Starter and Empty Yoghurt
  Container, the two build icons and the mod icon. The 3D models are still vanilla stand-ins.
- Art: milk too cold for a starter shows the incubator's lid slid half off the pot with the milk showing, so it can be seen at a glance.
- Internal: `TPD.kit(kind)` gives the things a test needs (`yoghurt`, the default, or `crock`, which replaces
  `TPD.crockkit()`); `TPD.kit("?")` lists them. Each new dairy adds a kit.
- Milk must be scalded: the menu offers Pour Scalded Milk for milk seen at 85 C or more on a stove or fire, however
  much it has cooled since. Its heat is stamped while it's in reach, because a pot loses vanilla's item heat within
  seconds of being picked up. Topping up with unscalded milk voids the stamp.
- Art: a leaning lid that draws correctly against the character, square cup icon, and clay and glazed Jar of
  Yoghurt icons (one item, its icon set by the jar it was collected into).
- Pot Info window: opened from the pot's menu or by clicking the pot. Shows the stage, contents, milk temperature,
  setting heat, place, starter, how far it has set and how fast, the time to the next change, and once ready the
  yoghurt's age, days left fresh and jars to fill. Closes when you walk away.
- The Portion Yoghurt recipe is gone. A Jar of Yoghurt now holds 4 cups (fewer for a part-full jar), shown in its
  name, and its right-click menu offers Fill a Yoghurt Cup or Fill All Cups. Each cup takes one Empty Yoghurt
  Container and is as old as the jar. The jar gets lighter as it empties, still ages and rots, and comes back empty
  with the last cup.
- Guide: the scald note (Troubleshooting, "Mind the pot").
- Internal: 65 tests.
- The Hearth: a low stone oven with a 10 L copper set into its top, built from a trowel, 12 Clay Bricks, 4 Clay and a
  Copper Sheet (Pottery 2, placeholder). It is a vanilla fireplace: fuel, lighting, the firebox, room heat and a
  glow at night. The copper holds one fluid at a time (cow's and sheep's milk don't mix), heats towards 95 C while
  the fire burns and cools when it's out. Its menu sits inside vanilla's Hearth menu: Pour into the Copper, Fill
  from the Copper and Hearth Info (fire, fuel, copper, heat, when the milk will steam). Clicking it opens the
  loot pane and Hearth Info. It can't be picked up while lit or while the copper holds anything.
- Scalding is gone. The incubator takes milk only with "Pour from the Hearth", from a copper at 85 C or more, and
  the milk goes in at the copper's heat. The crock loads warm milk (35 C or more) from the copper.
- A lit Hearth counts as "By a fire" only while its fuel lasts, also for incubators and crocks caught up after
  being away.
- The Yoghurt Incubator and the Starter Culture Crock can be built or put down anywhere (the earlier 2-tile rule
  is gone). Steamed milk reaches a far incubator in a Wrapped Yoghurt Pot (Sheet + Twine over a Yoghurt Pot), which
  holds its heat; any other container cools to room in seconds.
- A Ready incubator also fills Empty Yoghurt Containers straight away ("Fill Empty Yoghurt Containers": one or
  all), a quarter of a jar (250 ml) each, as old as the batch; the jar stays for carrying a litre.
- The crock loads milk at 35 to 45 C only (hotter kills the grain's culture), from a Hearth within 2 tiles or from
  any carried milk container ("Load Wheat and Warm Milk" lists them with litres and heat). A refused entry says
  why: too little, too cool or too hot.
- Crock Info, on the crock's menu or by clicking the crock: stage, place and its heat, the culture's best heat, progress, speed, and the
  time to the next stage (or the starters to collect). The crock's hover no longer says "Set in about" while it
  develops: it says "Starters ready in about".
- Help texts for the incubator, crock and Hearth now say milk can be carried in any container, and that only a
  Wrapped Yoghurt Pot keeps it hot on the way.
- The incubator and the crock no longer block their tile: walk past or through them, and click them from any side.
  Their floor shadow is soft-edged.
- "Pot Info" is now "Incubator Info", and the menus and notes say "incubator" for the station.
- Art: placeholder Hearth tiles (empty, full, steaming; facing S and E) and build icon.
- Guide: the scald note is replaced by a "Pour from the Hearth is greyed out" row.
- Internal: debug `TPD.hearth()`, `TPD.copper(l, c, fluid)`, `TPD.fuel(min)`, `TPD.hot()`, `TPD.tiles()`;
  `TPD.milk(l, c)` with c optional; the crock kit is wheat only. 78 checks.
- The Hearth is now TP Core's (S2a). Dairy's copper rules, fire finding, `ISDairyHearth`, the Hearth's OnCreate and
  its tracking in the World are gone; Dairy reads the copper through `TraditionalPreservationCore/Hearth` and keeps
  only milk's parts: "Pour from the Hearth", "Load from the Hearth", the steamed-milk record (now set by the core's
  `filled` hook) and the Wrapped Pot's own heat (the `heatOf` hook). Old `tpdHearth` coppers are not carried over:
  rebuild hearths in test saves.
- The Hearth's entity, art, menu and Hearth Info are TP Core's now (S2b): Dairy's tiles 20-25, `Item_DairyHearth`,
  the entity scripts and the moved strings are gone. Incubator Info and Crock Info derive from Core's `InfoWindow`.
  Hearth Info shows Dairy's milk notes through `HearthUI.addNotes`. The "Steaming" row replaces "Ready to pour".
- Not done yet: Starter Culture Crock window, final Hearth art (with a glow in the oven mouth), guide, README,
  Workshop text.
- Incubators, crocks and Wrapped Pots by a banked Hearth stand at 24 C ("by banked embers"), until the embers would
  have burnt out (three times as long as a lit fire); the season report has an Embers column.
- Internal: the Hearth's debug commands and kit moved to TP Core's console (`TPC.hearth`, `copper`, `fuel`, `hot`,
  `TPC.kit()`); `TPD.help()` points there.
- The Starter Culture Crock stands on a counter or table (built there or put down there, raised to its top) as
  well as on the floor: tile flags `IsTableTop` and `IsStackable`. Its tooltip says so.
- The crock's art sits a little back on its tile with a smaller shadow, so on a counter the shadow no longer hangs
  over the front edge.
- The crock and its stage overlays have hard edges (only its shadow stays soft): the soft edge left a ring in game
  where a wall, window or barricade behind a crock on a counter wasn't drawn.
- With more than one incubator or crock under a right-click, each gets its own menu, named with its status
  ("Yoghurt Incubator (Cooling: 2.0 L at 60 C)"). The menus answer vanilla's controller probe (review R6).
- Every timed action honours the debug cheat for instant actions.
- Internal (core consolidation, review group C): the menu helpers, the click handler, the look for new stations
  (`Station.tracker{ scan = true }`), the station lookup (`M.stationKind`), pouring times, the sensitivity scale and
  the season mean are TP Core's; console lines go through the core's `Log` (debug mode only). Timed actions are
  `TPYoghurtIncubator`, `TPStarterCrock`, `TPFillYoghurtCup` (were `IS...`). Removed `M.fireNear`, `M.copperWarm`,
  `M.fluidIn`, `M.fluidName`, `M.spriteIndex`, the aliases `M.ROOM_C`, `M.MILK_MAX_C`, `M.HEARTH_C`, `M.COPPER_ML`,
  the "no item script yet" guards, and the texts `_Hours` and `_UnderHour` (the core's are used).
