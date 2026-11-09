# Traditional Preservation (Dairy): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPD.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `TPD.weather()` | The temperature outdoors, under a roof and in a basement, how fast a batch works in each, and how many days it takes there. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.age(hours)` | Gives every station this many hours of perfect weather. `TPD.age(72)` finishes a batch. |
| `TPD.fast(hours)` | Test timer: a batch takes this many hours. `TPD.fast()` goes back to the sandbox time. |
| `TPD.batches(n)` | Spawns raw batches. |

**Typical check:** `TPD.batches(4)`, load the station and press Craft, then `TPD.age(72)`.
