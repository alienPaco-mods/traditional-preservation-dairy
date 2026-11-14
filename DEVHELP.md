# Traditional Preservation (Dairy): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPD.help()` prints this list in the game. The Stone Hearth's commands (the cauldron, its fuel and heat, its kit) are TP Core's: `TPC.help()`.

| Command | What it does |
|---|---|
| `TPD.weather()` | The temperature in each place (open air, under an open roof, indoors, a basement, by a fire, by banked embers), and how fast milk sets at each. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.pots()` | Every loaded incubator: position, stage, litres, milk temperature, starter, set hours, place, and what comes next and when. |
| `TPD.age(hours)` | Moves every loaded incubator and crock on by this many hours (1 if left out): an incubator replays the recorded weather, a crock's stage takes them as hours at the best temperature. |
| `TPD.fast(hours)` | Test timer: milk sets in this many hours at the best temperature. `TPD.fast()` goes back to the sandbox time. |
| `TPD.milk(litres, c, fluid)` | Gives a cooking pot of milk, 5 L if you leave the litres out, at `c` degrees if given; cow's unless `fluid` is `"SheepMilk"` or `"AnimalMilk"`. Raw, not scalded: heat it in a cauldron or on a stove. At `c` of 85 or more it counts as having had its 20-minute hold, so it reads Scalded at the next look; to watch the hold count, heat a cold pot on a stove instead. |
| `TPD.give(name, n, option)` | Spawns `n` of: `jar` (a full, new Jar of Yogurt of cow's milk; glass, or option `"clay"` or `"glazed"`), `starter` (an Active Yogurt Starter) or `cup` (an Empty Yogurt Container). `TPD.give()` lists them. |
| `TPD.kit(kind)` | Gives what a test needs. `TPD.kit()` is the yogurt kit (a Yogurt, a Clay Jar, a glass jar, 4 Empty Yogurt Containers), `TPD.kit("crock")` 20 wheat grains, `TPD.kit("wrap")` a Yogurt Pot, a Sheet and Twine. `TPD.kit("?")` lists them. |
| `TPD.crocks()` | Every loaded crock: position, stage, place, progress, speed and hours left. |
| `TPD.ages()` | Each container of milk you carry: fluid, stage (Fresh, Turned, Spoiled; scalded), age in hours at 20 C, hours to the next stage, the place it is counted at. Sealed store milk shows "no age". |
| `TPD.sour(hours)` | Ages the milk you carry by this many hours at 20 C (36 if left out: one souring) and swaps it at once. |
| `TPD.tiles()` | Every incubator, crock and Stone Hearth within 3 tiles: object class, sprite and the square's solid flags, for placement bugs. |

Right-click a station once to start tracking it if `TPD.pots()` or `TPD.crocks()` finds none.

**Typical check of a batch:** within 2 tiles of a Stone Hearth with the cauldron fitted (`TPC.kit()`, `TPC.fit()`), `TPC.cauldron(5)` and `TPC.hot()` for 5 L of steaming milk (`TPC.cauldron(5, 20, "SheepMilk")` for sheep's), `TPD.kit()`, then Pour from the Hearth and Add Starter on the incubator. `TPD.age(3)` should show it wrapped and setting, `TPD.age(7)` Ready.

**Typical check of the crock:** `TPD.kit("crock")`, `TPC.cauldron(1, 40)` by a Stone Hearth within 2 tiles, Load Wheat and Warm Milk, `TPD.age(24)`, Feed Fresh Milk from `TPD.milk(1)`, `TPD.age(12)`, then Collect 2 Starters. **The clabber:** `TPD.milk(1)`, `TPD.sour()` (it reads Soured), Load Soured Milk on an empty crock (Cultured at once), feed, `TPD.age(12)`, collect.
