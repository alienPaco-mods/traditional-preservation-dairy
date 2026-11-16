# Traditional Preservation (Dairy): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPD.help()` prints this list in the game. The Stone Hearth's commands (the cauldron, its fuel and heat, its kit) are TP Core's: `TPC.help()`.

| Command | What it does |
|---|---|
| `TPD.weather()` | The temperature in each place (open air, under an open roof, indoors, a basement, by a fire, by banked embers), and how fast milk sets at each. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.pots()` | Every loaded incubator: position, stage, litres, milk temperature, starter, set hours, place, and what comes next and when; a kefir pot: its grains, what they count for, speed, fermented and hours to ready. |
| `TPD.age(hours)` | Moves every loaded incubator and crock on by this many hours (1 if left out): an incubator replays the recorded weather, a crock's stage takes them as hours at the best temperature. A kefir pot gets the hours at its place's temperature now (its ferment runs on the ledger, which can't be set back). |
| `TPD.fast(hours)` | Test timer: milk sets in this many hours at the best temperature. `TPD.fast()` goes back to the sandbox time. |
| `TPD.milk(litres, c, fluid)` | Gives a cooking pot of milk, 5 L if you leave the litres out, at `c` degrees if given; cow's unless `fluid` is `"SheepMilk"` or `"AnimalMilk"`, or a kefir (`"CowKefir"` or `"SheepKefir"`: both read Kefir; animal's milk makes the cow's). Raw, not scalded: heat it in a cauldron or on a stove. At `c` of 85 or more it counts as having had its 20-minute hold, so it reads Scalded at the next look; to watch the hold count, heat a cold pot on a stove instead. |
| `TPD.give(name, n, option)` | Spawns `n` of: `jar` (a full, new Jar of Yogurt of cow's milk; glass, or option `"clay"` or `"glazed"`), `starter` (an Active Yogurt Starter), `cup` (an Empty Yogurt Container), `butter`, `salted`, `clarified`, `packet` (a Packet of Kefir Grains), `dried` (a Dried Kefir Grain) or `grains` (a live Kefir Grain, its record made). `TPD.give()` lists them. |
| `TPD.kit(kind)` | Gives what a test needs. `TPD.kit()` is the yogurt kit (a Yogurt, a Clay Jar, a glass jar, 4 Empty Yogurt Containers), `TPD.kit("crock")` 20 wheat grains, `TPD.kit("wrap")` a Yogurt Pot, a Sheet and Twine, `TPD.kit("butter")` nine Butter, a Salt, a cooking pot, a saucepan, a Ripped Sheet and a burnt Pot of Butter, `TPD.kit("kefir")` a Packet of Kefir Grains, 25 live Kefir Grains, a pot of 2 L of cow's milk kefir, a pot of 1 L of cow's milk (the full ratio for the 25 grains), a Strainer and a Ripped Sheet. `TPD.kit("?")` lists them. |
| `TPD.crocks()` | Every loaded crock: position, stage, place, progress, speed and hours left. |
| `TPD.ages()` | Each container of milk you carry: fluid, stage (Fresh, Turned, Spoiled; scalded), age in hours at 20 C, hours to the next stage, the place it is counted at. Sealed store milk shows "no age". |
| `TPD.sour(hours)` | Ages the milk and kefir you carry by this many hours at 20 C (36 if left out: milk's souring) and swaps it at once. Kefir separates at 72 and rots at 240. |
| `TPD.butter()` | Each Butter and Salted Butter you carry or in containers within 4 tiles on your floor (a fridge, a freezer, a crate): place, rate (days of age a day), age, and the days to stale and rotten there. |
| `TPD.rancid(days)` | Ages that butter (carried or within 4 tiles) by this many days (10 if left out) at its place. |
| `TPD.tiles()` | Every incubator, crock and Stone Hearth within 3 tiles: object class, sprite and the square's solid flags, for placement bugs. |

Right-click a station once to start tracking it if `TPD.pots()` or `TPD.crocks()` finds none.

**Typical check of a batch:** within 2 tiles of a Stone Hearth with the cauldron fitted (`TPC.kit()`, `TPC.fit()`), `TPC.cauldron(5)` and `TPC.hot()` for 5 L of steaming milk (`TPC.cauldron(5, 20, "SheepMilk")` for sheep's), `TPD.kit()`, then Pour from the Cauldron and Add Starter on the incubator. `TPD.age(3)` should show it wrapped and setting, `TPD.age(7)` Ready.

**Typical check of the crock:** `TPD.kit("crock")`, `TPC.cauldron(1, 40)` by a Stone Hearth within 2 tiles, Load Wheat and Warm Milk, `TPD.age(24)`, Feed Fresh Milk from `TPD.milk(1)`, `TPD.age(12)`, then Collect 2 Starters. **The clabber:** `TPD.milk(1)`, `TPD.sour()` (it reads Soured), Load Soured Milk on an empty crock (Cultured at once), feed, `TPD.age(12)`, collect.

**Typical check of kefir (fluids, grains, the cure, the incubator):** `TPD.kit("kefir")`; `TPD.ages()` shows the pot's kefir Fresh; `TPD.sour(72)` Separated, `TPD.sour(168)` Rotten. Drink a cup with some food sickness (debug: set Food Sickness): it eases 10 a litre, and a second cup within 3 game hours does not; a cup drunk healthy starts no cooldown. Double-click the packet: 10 Dried Kefir Grains. In the incubator: Add Kefir Grains (All 25), Pour Milk from the 1 L pot, `TPD.pots()` says 100% speed and about 24 h; `TPD.age(24)`, Strain Kefir into the emptied pot with the Strainer: Kefir, and 27 grains back.

**Typical check of butter:** `TPD.kit("butter")`, `TPD.butter()` (each Butter 30 days fresh in a cellar; carried indoors it reads the room), `TPD.rancid(25)` and it reads Stale, again and Rotten. Salt Butter on a fresh one: `TPD.butter()` shows 90 / 120 days. Put Butter in a Pot, Add Butter to the Pot, cook it on a stove, Pour Off Clarified Butter (the sheet is kept): two Clarified Butter and the pot. Every step needs Cooking 2 (debug: set the perk). **In the cauldron:** `TPC.kit()`, `TPC.fit()`, Put Butter in the Cauldron, `TPC.hot()` and an hour's steaming (Stone Hearth Info says when), Fill from the Cauldron into a pot, Strain Clarified Butter.
