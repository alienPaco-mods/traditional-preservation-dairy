# Traditional Preservation (Dairy): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPD.help()` prints this list in the game. The Hearth's commands (the copper, its fuel and heat, a Hearth kit) are TP Core's: `TPC.help()`.

| Command | What it does |
|---|---|
| `TPD.weather()` | The temperature outdoors, under a roof, in a basement, by a fire and by banked embers, and how fast milk sets at each. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.pots()` | Every loaded incubator: position, stage, litres, milk temperature, starter, set hours, place, and what comes next and when. |
| `TPD.skip(hours)` | Moves every loaded incubator on by this many hours (1 if you leave it out), replaying the recorded weather. |
| `TPD.fast(hours)` | Test timer: milk sets in this many hours at the best temperature. `TPD.fast()` goes back to the sandbox time. |
| `TPD.milk(litres, c)` | Gives a cooking pot of cow's milk, 5 L if you leave the litres out, at `c` degrees if given. Raw, not scalded: heat it in a copper or on a stove. |
| `TPD.kit(kind)` | Gives what a test needs. `TPD.kit()` is the yogurt kit (a Yogurt, a Clay Jar, a glass jar, 4 Empty Yogurt Containers), `TPD.kit("crock")` 20 wheat grains, `TPD.kit("wrap")` a Yogurt Pot, a Sheet and Twine. `TPD.kit("?")` lists them. |
| `TPD.crocks()` | Every loaded crock: position, stage, place, progress, speed and hours left. |
| `TPD.culture(hours)` | Moves every loaded crock's current stage on by this many hours at the best temperature (a whole first stage if you leave it out). |
| `TPD.ages()` | Each container of milk you carry: fluid, stage (Fresh, Turned, Spoiled; scalded), age in hours at 20 C, hours to the next stage, the place it is counted at. Sealed store milk shows "no age". |
| `TPD.age(hours)` | Ages the milk you carry by this many hours at 20 C (36 if left out: one souring) and swaps it at once. |
| `TPD.tiles()` | Every incubator, crock and Hearth within 3 tiles: object class, sprite and the square's solid flags, for placement bugs. |

Right-click a station once to start tracking it if `TPD.pots()` or `TPD.crocks()` finds none.

**Typical check of a batch:** within 2 tiles of a Hearth, `TPC.copper(5)` and `TPC.hot()` for 5 L of steaming milk (`TPC.copper(5, 20, "SheepMilk")` for sheep's), `TPD.kit()`, then Pour from the Hearth and Add Starter on the incubator. `TPD.skip(3)` should show it wrapped and setting, `TPD.skip(7)` Ready.

**Typical check of the crock:** `TPD.kit("crock")`, `TPC.copper(1, 40)` by a Hearth within 2 tiles, Load Wheat and Warm Milk, `TPD.culture()`, Feed Fresh Milk from `TPD.milk(1)`, `TPD.culture(12)`, then Collect 2 Starters. **The clabber:** `TPD.milk(1)`, `TPD.age()` (it reads Soured), Load Soured Milk on an empty crock (Cultured at once), feed, `TPD.culture(12)`, collect.
