# Traditional Preservation (Dairy) — Build 42 prototype (v0.0.1)

**Status: experimental.** The yogurt loop, from the Hearth's copper to a cup of yogurt, and the starter crock have been played in the game with test timers. The latest changes (mixed milks, the cold-milk refusal, the jar weight after a reload) have only been checked offline so far (see the test plan). Back up your save before enabling.

Set your own yogurt the old way: milk brought to the steam in a Hearth's copper, cooled in a lidded clay pot, then wrapped in cloth to set overnight. It ends in the same vanilla Yogurt you find in fridges, and every Yogurt eaten leaves its cup behind to fill again. When the last yogurt is gone, a crock of wheat and warm milk grows a new starter.

## History

Yogurt is milk soured by lactic bacteria that like it warm. Herders across the Balkans, Anatolia and the steppe kept it going for thousands of years without a thermometer: the milk was heated until it steamed, which kills what else is in it and thickens the result, then left to cool until a finger could stand it for a count of ten, about 45 C. A spoonful of yesterday's yogurt went in, and the pot was wrapped in a blanket or set by the hearth's embers overnight. By morning it had set.

A household that lost its starter borrowed one from a neighbour, or grew a new one. Old recipes from the Balkans start it from grain, a few wheat kernels or a crust of bread in warm milk, as the bacteria that sour milk also live on cereal. Cow's, sheep's and goat's milk from a mixed herd went into the same pot.

## Install

Copy this folder to `~/Zomboid/mods/TraditionalPreservationDairy`, as a real copy rather than a symlink. It needs the **TP Core** mod (`TraditionalPreservationCore`, the series' shared mod) installed and enabled the same way, and no other mods. The Hearth is part of TP Core.

## Getting started

1. **Keep a cow or sheep in milk.** Cow's and sheep's milk both work, and mix.
2. **Build a Hearth** (TP Core) and keep wood for it. 10 L take about 1.5 hours to steam, 20 L about 2, a full 60 L about 2.75. (No Hearth yet: a pot of milk on any lit stove or fire scalds too; see Filling the incubator.)
3. **Throw a Yogurt Pot** on the wheel and fire it, then build it into a Yogurt Incubator within 2 tiles of the Hearth.
4. **Keep one yogurt back.** Each batch takes one vanilla Yogurt, one portion of a Jar of Yogurt, or one Active Yogurt Starter. With none left, build a Starter Culture Crock.
5. **Save your Empty Yogurt Containers and jars.** Each cup of yogurt needs a container; a glass jar holds a litre, a clay jar 2.5 L, and you eat from the jar itself.
6. **Set it by the fire in winter.** A lit fire within 2 tiles (the Hearth, a fireplace, an antique stove or a campfire) keeps the pot at 28 C: it sets in about 6 hours in any month.
7. **Mind the milk.** Raw milk sours in about a day and a half in a warm room; scald it or keep it cold (see Milk goes off).

## The loop at a glance

| # | Step | Where | In | Out | Time |
|---|---|---|---|---|---|
| 1 | Pour into the Copper | Hearth's right-click menu | milk, from any container | up to 60 L in the copper | a moment |
| 2 | Bring to the steam | Lit Hearth | | milk at 85 C | about 1.5 hours for 10 L, 2 for 20 L, 2.75 for 60 L |
| 3 | Pour from the Hearth | Incubator's menu, Hearth within 2 tiles | steaming milk | up to 5 L in the pot | a moment |
| 4 | Add Starter | Incubator's menu | 1 Yogurt, a jar's portion, or an Active Yogurt Starter | | a moment |
| 5 | Cool | Incubator, lid on | | milk at 45 C, the wrap goes on | about 2 hours* |
| 6 | Set | Incubator, wrapped | | 5 L of yogurt | 6 hours at 40 to 45 C* |
| 7 | Collect | Incubator's menu | empty jars, or Empty Yogurt Containers | Jars of Yogurt (glass 1 L, clay 2.5 L), or Yoghurts | a moment |
| 8 | Eat a Portion | Jar's menu | Jar of Yogurt | 250 ml eaten, a quarter litre of its milk's food | as eating |
| 9 | Fill a Yogurt Cup | Jar's menu | Jar of Yogurt, Empty Yogurt Container | 1 vanilla Yogurt | a moment |

\* In a 20 C room, or by a fire. Colder places take longer; see Temperature and places.

| One full pot | |
|---|---|
| Milk | 5 L, cow's, sheep's or both |
| Starter | 1 Yogurt, 1 portion of a Jar of Yogurt, or 1 Active Yogurt Starter |
| Wood | about 1.5 hours of fire to steam 10 L (two pots), 2 hours for 20 L (four), 2.75 for 60 L (twelve) |
| Yogurt | 5 L: 5 glass jars, 2 clay jars, or 20 cups (250 ml portions) |
| Cooking XP | 2 per litre collected |

## Stations

| Station | Where | Skill | Materials |
|---|---|---|---|
| **Hearth** (TP Core) | Build menu, Masonry | Masonry 2 | 12 Clay Bricks, 4 Clay, 1 Copper Sheet, a trowel (kept) |
| **Yogurt Incubator** | Build menu, Pottery; floor | Tailoring 1 | 1 Yogurt Pot, 2 Ripped Sheets, 1 Twine |
| **Starter Culture Crock** | Build menu, Pottery; floor, counter or table | Cooking 4 | 1 Clay Jar, Glazed Clay Jar or Clay Pot, 1 Ripped Sheet, 1 Twine |

The **Yogurt Pot** is thrown on the pottery wheel (Pottery 2, 6 Clay, a little water) and fired in a kiln. Wrapped in a Sheet and tied with Twine (crafting menu, Cooking) it becomes a **Wrapped Yogurt Pot**, which carries 5 L of hot milk and loses only about 15 C an hour. Unwrap it when empty to get the pot, sheet and twine back.

Any **cooking pot, forged pot, jar, clay jar or bucket** wraps the same way (**Wrap a Pot, Jar or Bucket**, crafting menu, Cooking, empty only) and keeps its own capacity: it shows as a "Wrapped Pot", "Wrapped Jar" or "Wrapped Bucket", catches no rain, and keeps milk hot as the Wrapped Yogurt Pot does, a small jar for less long (about 2.3 hours' time constant for 1 L against 4 for 5 L) and a full bucket longer (about 5). **Unwrap a Pot, Jar or Bucket** gives the sheet and twine back. The mark is the item's own fluid-container name (saved by the game) plus `tpdWrapped` in its ModData.

**Keep the cloth off the heat.** A wrapped pot, jar or bucket (or a Wrapped Yogurt Pot) in a hot stove, oven, barbecue, fireplace, Hearth firebox or campfire burns its wrap within a game minute: the sheet and twine are gone. On a stove, oven or barbecue that sets the kitchen alight, as burnt food does; in an open fire it burns away in the flames. A Wrapped Yogurt Pot burns down to a bare Yogurt Pot, which holds no fluid, so its milk is lost.

You can walk through the incubator and the crock. Both work anywhere, but pouring straight from the copper needs the Hearth within 2 tiles.

## How it works

### 1. The Hearth's copper

The Hearth is TP Core's station, documented in full in TP Core's `README.md` and guide (`6_Core_Guide.md`): a vanilla fireplace (Add Fuel, Light, a firebox that cooks, room heat) with a 60 L copper set in its top. Right-click it for **Pour into the Copper**, **Fill from the Copper** (into your own containers), **Empty the Copper**, **Bank the Fire** / **Stoke the Fire** and **Hearth Info**.

- The copper holds one fluid at a time. Cow's and sheep's milk count as one: they mix freely, and a blend keeps its shares in the copper, a container and the pot. Any other mix is refused, shown in red with the reason.
- Poured milk mixes its temperature with what's already in the copper, by volume.
- While the fire burns, the copper heats towards 95 C: 10 L go from 20 C to 85 C in about 1.5 hours, 20 L in about 2, a full 60 L in about 2.75, less milk faster. With the fire out it cools towards the room over a few hours, as the stone holds heat.
- **Bank the Fire** burns a third of the wood, holds the copper at about 50 C and cooks a third as fast in the firebox. **Stoke the Fire** brings it back.
- At 85 C the copper steams, in its sprite and in Hearth Info ("Steaming: Yes"), and its milk reads Scalded.

### 2. Filling the incubator

Right-click the incubator:
- **Pour from the Hearth** draws steaming milk from a Hearth within 2 tiles, up to the pot's 5 L.
- **Pour Scalded Milk** takes scalded milk from any container: milk that has been at 85 C or more in the copper, or in a pot on a lit stove, fireplace, barbecue or campfire (vanilla's lowest stove setting already gets there), or store milk poured out of its carton. It goes in at the heat it has now: off the heat an open pot or bucket cools in minutes (85 to 45 C in about a quarter hour), a Wrapped Yogurt Pot in hours, and a pour between containers carries the heat over. Milk that isn't scalded is refused as "Not scalded".
- **Add Starter** takes one vanilla Yogurt, one portion (250 ml) of a Jar of Yogurt with a whole portion left (the rest stays; the empty jar comes back with the last), or one Active Yogurt Starter, before or after the milk. None gone off. One per batch.

Once the starter is in, milk that would leave the pot under 40 C is refused as too cold, so a set batch is never spoiled by a cold top-up.

### 3. Cooling, wrapping, setting

1. **Cooling** (lid on): the milk cools towards the temperature where the incubator stands, about 85 to 45 C in 2 hours at 20 C. Less than 2.5 L cools as slowly as 2.5 L, so a litre still sets.
2. **The wrap goes on by itself** at 45 C if a starter is in.
3. **Setting** (striped cloth on): wrapped, it loses only about 10 C overnight in a 20 C room. It sets in 6 hours at 40 to 45 C, slower when cooler, and stalls below about 18 C. Above 45 C it slows again, and stops at 55 C.

If the milk falls under 40 C with no starter in, it is **Too cold** (the lid slides half off). **Pour Out Milk** into a container and reheat it, in the copper or on a stove or fire, or top the pot up with steaming milk.

### 4. Collecting

When the status line reads **Ready**:
- **Collect into a Jar**: each empty jar is filled to its size, 1 L in a glass jar, 2.5 L in a Clay Jar or Glazed Clay Jar; the last one takes what is left. A **Jar of Yogurt** holds a 250 ml portion per quarter litre (4 in glass, 10 in clay), keeps the yogurt's age, stays fresh 10 days and is rotten at 15.
- **Fill Empty Yogurt Containers**: 250 ml each, straight into a vanilla Yogurt the same age as the batch.

Eat from the jar: **Eat a Portion** in its right-click menu eats 250 ml, a quarter litre of its milk's food: 153.75 kcal and -12.5 hunger from cow's milk, 205.75 kcal from sheep's, a mixed pot by its shares. A cup filled from the pot or the jar has the same, and vanilla Yogurt found from now on has the cow's figures (it had 30 kcal and -10 hunger); jars, cups and Yogurt from before keep theirs. The game's own Eat, Eat Half and Eat Quarter work too (they eat that share of a full jar). Or **Fill a Yogurt Cup** / **Fill All Cups** spoons portions into Empty Yogurt Containers. The jar gets lighter, its name shows the portions left (a part-portion after Eat Quarter makes a cup with that much food), and the last spoonful gives the empty jar back.

Every vanilla Yogurt eaten, or stirred into oatmeal, leaves an **Empty Yogurt Container**, so the cups go round.

### 5. The Starter Culture Crock

No yogurt left to start from? Grow a starter.

1. **Load Wheat and Warm Milk**: 20 wheat grains and 0.5 L of milk at 35 to 45 C, from a Hearth within 2 tiles or a carried container (in practice a Wrapped Yogurt Pot, or a copper cooling with the fire out). Hotter milk kills the grain's culture; the menu says why it refuses.
2. **Cultivating**: 24 hours at its best (25 to 35 C), slower outside that. Keep it by the fire in winter.
   *Or* **Load Soured Milk** instead of steps 1 and 2: 0.5 L of soured milk, any warmth, no wheat (a clabber). It already holds lactic bacteria, so the crock goes straight to step 3. Rotten milk is refused.
3. **Feed Fresh Milk**: 0.5 L of any milk, fresh or scalded, warm or cold, from any container. Soured and rotten milk are refused.
4. **Developing**: 12 hours at its best.
5. **Collect 2 Starters**: two **Active Yogurt Starters**, fresh 5 days and rotten at 10. Each sets one batch.

The crock is small enough to stand on a kitchen counter or a table, as long as nothing else stands on it, or on the floor.

### 6. Milk goes off

Vanilla milk keeps for ever. Here it doesn't (TP Core's `FluidAgeing`; sandbox **Milk goes off**, on by default).

| Milk reads | When | Good for |
|---|---|---|
| Cow's Milk (Fresh) | Raw, young | Everything |
| Cow's Milk (Scalded) | Has been at 85 C or more (the copper, or a pot on a lit stove or fire), poured out of the incubator, or poured out of a store carton | Everything. It never sours |
| Cow's Milk (Soured) | Raw milk after 36 hours' worth of 20 C | Drinking (its milk's food, a little unhappiness), Make Cake Batter, Prepare Muffins, Make Bowl of Cereal, and Load Soured Milk on an empty crock. The incubator, the crock's feed, Churn Butter and Make Mildew Cure refuse it |
| Cow's Milk (Rotten) | Any milk after 72 hours' worth of 20 C | Nothing: food poisoning. Pour it away |

Sheep's and the game's generic animal milk go the same way under their own names.

| Kept at | Raw milk sours | Any milk is rotten |
|---|---|---|
| 30 C | 1 day | 2 days |
| 20 C, a room in July | 1.5 to 2 days | 3 days |
| A basement in summer, about 13 C | 3½ days | 7 days |
| A basement in winter, about 5 C | 6 to 7 days | about 2 weeks |
| A powered fridge, 4 C | about 8 days | about 16 days |
| A powered freezer | never | never |

- Milk ages by the place it was last seen in (open air, under an open roof, indoors, a loft, a basement, by a fire, a fridge or freezer), also while you are away.
- Pouring never makes milk young: the older age wins, and raw milk mixed into scalded makes the whole lot raw again. Milking into a container emptied of its old milk starts afresh.
- Sealed store milk (carton, bottle, personal size) doesn't age until it is poured out; then it counts as scalded.
- Milk left in the copper ages there too. A steaming copper scalds what is in it.
- Any milk bakes: vanilla Make Cake Batter, Prepare Muffins and Make Bowl of Cereal take cow's, sheep's or animal milk, fresh, scalded or soured (vanilla took cow's only, cereal sheep's too). Churn Butter and Make Mildew Cure take their milks scalded as well as fresh.

## What the stations show

| Incubator | When | What you see |
|---|---|---|
| Empty | Nothing in it | The open pot, its lid leaning against it |
| Cooling | Milk in, lid on | The lid on the pot |
| Too cold | Under 40 C with no starter | The lid slid half off, milk showing in the gap |
| Setting | Starter in, wrapped | A striped cloth over the pot, tied at the neck |
| Ready | Set | The lid off again, white yogurt in the pot |

| Crock | When | What you see |
|---|---|---|
| Empty | Nothing in it | The open clay crock |
| Cultivating | Wheat and warm milk in | A linen cap tied over the mouth |
| Developing | Fed fresh milk | Milk with plenty of wheat in it |
| Ready | Starters to collect | The thickened culture, a few grains left |

**Incubator Info** and **Crock Info** (in the menu, or just click the station) open a small window with the stage, contents, temperature, place, progress, working speed and the time to the next change. With several stations under one click, the menu shows one entry for each, named with its status.

## Temperature and places

Time counts by the game clock, at any Day Length, and keeps counting while the area is unloaded. The milk's temperature follows where the station stands, recorded every 10 in-game minutes.

| | Stalls | Slow | Best | Slowing again |
|---|---|---|---|---|
| Setting (incubator) | below 18 C | 18–40 C | 40–45 C | above 45 C, stops at 55 C |
| Culture (crock) | | below 25 C | 25–35 C | above 35 C, 10% at 45 C |

Seven kinds of place (TP Core's):

- **Open air**: the day's weather.
- **Under an open roof** (a porch, an open shed) or **indoors** (a room): the average outdoor temperature of the last 10 days or so. A room is 22 C while the power grid is on.
- **In a loft** (the top storey: a room upstairs with no room over it): as indoors, plus three tenths of whatever the 10-day average is above 10 C: the sun on the roof (about 24 C in a 21 C July, no warmer than a room from October to April); 22 C while the power grid is on.
- **In a basement**: the ground, a month behind the season, two fifths as far from 10 C: about 5 C from January to March, 13 C from July to September.
- **By a fire**: any lit fire within 2 tiles (the Hearth, a fireplace, an antique stove or a campfire; never an electric or gas stove) holds a station at 28 C. While you're away it counts only until its fuel would have run out, then the room counts.
- **By banked embers**: a banked Hearth or Firebox within 2 tiles, 24 C.

Hours for 5 L poured at 85 C at 18:00 with the starter in, cooling then setting, the grid off (`tools/season_report.lua`); "never" means it hadn't set after 72 hours:

| Month | Open air | Indoors | Loft | Basement | By a fire | By banked embers |
|---|---|---|---|---|---|---|
| Jan | never | never | never | never | 2.5 + 6.2 | 2.2 + 6.3 |
| Mar | never | never | never | never | 2.5 + 6.2 | 2.2 + 6.3 |
| May | never | never | never | 1.5 + 13.7 | 2.5 + 6.2 | 2.2 + 6.3 |
| Jul | 1.8 + 8.8 | 2.0 + 7.7 | 2.0 + 6.5 | 1.7 + 9.5 | 2.5 + 6.2 | 2.2 + 6.3 |
| Sep | 1.7 + 14.8 | 1.8 + 7.8 | 1.8 + 6.8 | 1.7 + 8.2 | 2.5 + 6.2 | 2.2 + 6.3 |
| Nov | never | 1.5 + 14.5 | 1.5 + 14.5 | 1.7 + 13.7 | 2.5 + 6.2 | 2.2 + 6.3 |

While the grid is on a room or a loft is 22 C in every month: 2.2 + 7.0 hours.

The crock's first stage takes 24 hours by a fire in any month, about 32 hours in a powered room, about 2 days indoors in summer, 4 to 5 in a basement from July to October (9 in November), and weeks anywhere else in winter.

## Skills

| Step | XP |
|---|---|
| Build a Hearth (TP Core) | Masonry 10 |
| Throw a Yogurt Pot | Pottery 20 |
| Build a Yogurt Incubator | Tailoring 5 |
| Build a Starter Culture Crock | Cooking 10 |
| Each litre of yogurt collected | Cooking 2 (a cup earns a quarter) |
| Collect the crock's starters | Cooking 2 |

## Sandbox options

Under Traditional Preservation (Dairy):

| Option | Default | What it does |
|---|---|---|
| Yogurt setting time (hours) | 6 | Hours wrapped milk takes to set at its best (40 to 45 C) |
| Starter culture time (hours) | 24 | The crock's first stage at its best; the second takes half as long |
| Temperature sensitivity | Normal | Off, Forgiving, Normal or Harsh. Off runs at full speed in any weather; the milk still has to cool before the wrap goes on |
| Milk goes off | On | Raw milk sours, then spoils; scalded milk spoils without souring |
| Milk spoiling speed | 1 | 2 goes off twice as fast, 0.5 keeps twice as long |

## Tuning

Volumes, temperatures, cooling times, the setting and culture curves, the crock's amounts and XP are at the top of `42/media/lua/shared/TraditionalPreservationDairy.lua`. The pottery and wrapping recipes are in `42/media/scripts/TraditionalPreservationDairy.txt`, the items in `..._items.txt`, the stations' build recipes in `42/media/scripts/entities/`. The Hearth's copper and fire rules are TP Core's (`Hearth.lua`).

`python3 tools/build_tileset.py` (needs Pillow) paints the incubator, the crock and their stage overlays and writes `42/media/traditionalpreservationdairy.tiles`, `42/media/texturepacks/traditionalpreservationdairy.pack`, the icons and the generated `42/media/lua/shared/TraditionalPreservationDairy/Tiles.lua` (don't edit it by hand). `luajit tests/test_tiles.lua` checks the entity scripts against it.

`luajit tests/test_incubator.lua` checks the rules (cooling, setting, mixing, refusals, the crock, catching up), `tests/test_menu.lua` the right-click menus on stand-ins for the engine, `tests/test_jar.lua` the Jar of Yogurt (portions, food, weight, the empty jar back), `tests/test_baking.lua` the milks added to vanilla's recipes, `tests/test_console.lua` the debug console, and `luajit tools/season_report.lua` prints the season tables (golden-checked by `tp test Dairy`).

## Realism notes for review

**Claims taken as real practice**
1. Milk for yogurt is heated to about 85 C first: it kills competing bacteria and changes the whey proteins, so the yogurt sets thicker.
2. The starter goes in at about 40 to 45 C; much hotter kills it, much cooler and it sets slowly or not at all.
3. A wrapped pot, or one set by the embers, holds that warmth long enough to set overnight, in roughly 4 to 8 hours.
4. A spoonful of the last batch starts the next. Lost starters were regrown from grain or bread in warm milk.
5. Cow's and sheep's milk were freely mixed in the same pot.
6. A cellar takes the edge off the seasons and runs a month or two behind them, cool in summer and above frost in winter.

**Simplifications made for play**
- One yogurt or starter sets a whole pot, whatever its size (real practice is 3 to 5% of the milk).
- The copper's heating and the pot's cooling are simple exponential curves; the steam takes no holding time at 85 C.
- Temperature during setting slows it but never spoils a batch.
- A room or an open roof is the 10-day mean (22 C while the grid is on); a basement follows the ground (the 10-day mean's own 30-day mean) two fifths as far from 10 C; room heating isn't modelled beyond a fire within 2 tiles.
- Milk goes off (TP Core's `FluidAgeing`): raw milk turns to its Soured twin at 36 hours' worth of 20 C and to its Rotten one at
  72; scalded milk (85 C or more) skips souring and goes by its Scalded twin (`SCALDED_MILKS`, "Cow's Milk (Scalded)") until raw milk
  is mixed in; it spoils to its milk's Rotten one. The curve (`MILK_CURVE`) and the hours are at the top of the main Lua file. Its age
  lives in the container's ModData (`tpFluidAge`, TP Core's key) and on Dairy's weather ledger (`milkOpen` and so on).
- Any milk bakes, fresh, scalded or soured: vanilla Make Cake Batter, Prepare Muffins and Make Bowl of Cereal take all
  three milks and their scalded and soured twins (`SOUR_BAKING`, `bakingMilks`; TP Core's `Recipes.addFluids` widens
  their fluid line at `OnInitWorld`). Vanilla took cow's only (cereal sheep's too). Churn Butter and Make Mildew Cure
  take their milks scalded too, never soured (`SCALDED_ONLY`, `scaldedMilks`): store milk poured out is scalded.

## Engineering notes

- The pot's milk, temperature, starter, stage and set hours live in the station's ModData (`tpdIncubator`), the crock's in `tpdCrock`, and hot milk carried in a container in `tpdCarry` (`ml`, `c`, `hour`, `scalded`; `steamed` from test builds is still read). Never rename them once the mod is out.
- Weather is TP Core's shared ledger; a pot catches up hour by hour over the two weeks of kept weather, and the hours before that as one spell.
- A Jar of Yogurt keeps its jar type and litres in its ModData (`tpdJar`, `tpdMl`); its portions are its own food values (hunger, calories and so on, which the engine saves), and `tpdFood` marks a jar that has them. `tpdPortion` holds one portion's food, a quarter litre of the batch's milk by its shares (C23); a jar without it is in old vanilla Yogurt's portions (30 kcal). Vanilla Yogurt's script food is set to a cow's milk portion at load, beside its `ReplaceOnUse`. A jar from before that (only `tpdCups`) gets its cups' worth the first time it is touched. Its weight is a custom weight the engine saves. Vanilla's eat action is wrapped (`complete`, `serverStop`) to relabel the jar and give the empty jar back.
- Every vanilla Yogurt gets `ReplaceOnUse` = Empty Yogurt Container at load, so eating or oatmeal leaves the cup.
- The shared core (Weather, Station, UI, Hearth) is the required TP Core mod (`~/MODS/TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there. Dairy names cow's and sheep's milk as a blend with `Hearth.blend`.

## Debug commands

In debug mode, `TPD.help()` in the Lua console lists commands for testing this mod, and `TPC.help()` the Hearth's. See `DEVHELP.md`.

## Known prototype caveats

- **Empty Yogurt Containers can't be made yet**: they come only from eating looted or home-made Yogurt.
- Vanilla is changed in four places: Yogurt (leaves its cup, and has a cow's milk portion's food), the milk fluids' names ("Cow's Milk (Fresh)"), milk going off, and the milk line of five vanilla recipes (Make Cake Batter, Prepare Muffins, Make Bowl of Cereal, Churn Butter, Make Mildew Cure). Another mod that changes the same things may conflict.
- Several vanilla UI functions are wrapped (the station's right-click entry and the click on a station), so compare them with vanilla after a game update.
- The tiledef number 5172 must be unique among your active mods.
- Multiplayer is not supported. This mod is singleplayer only for now.

## Test plan

Already passed in the game: building the Hearth, incubator and crock; the copper heating and cooling, Hearth Info; pouring from the Hearth, the starter, cooling, wrapping, setting and collecting into jars and cups; Incubator Info and Crock Info; the crock's load, feed and starters; banked and lit fire.

Still to check in the game:

1. The crock on a kitchen counter and a table: built, put down, saved and reloaded, refused on a fridge or stove (test C).
2. Cow's and sheep's milk mixing in the copper, a container and the pot; the Hearth's menu and Hearth Info naming both.
3. Milk that would leave a started pot under 40 C refused, in red.
4. A part-empty Jar of Yogurt keeps its weight and portions after a reload.
5. Jars at their real size: a glass jar 4 portions, a clay jar 10; Eat a Portion, vanilla Eat Quarter, a cup from a part-portion, and the empty jar back.
6. A pot left for weeks catches up and reads right on return.
7. The incubator's and crock's menus with a controller.
8. `console.txt` shows no repeating Lua errors after an hour of play, with the other Traditional Preservation mods on.
