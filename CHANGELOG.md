# Changelog: Traditional Preservation (Dairy)

## 0.0.1 (in development, not released)
- Wrap any milk carrier (user 2026-11-11): Wrap / Unwrap a Pot, Jar or Bucket (crafting menu, Cooking, empty only;
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
- A Jar of Yoghurt as a starter (user 2026-11-11): Add Starter takes one portion (250 ml, a Yoghurt cup's worth) from
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
- Yoghurt without a Hearth (user 2026-11-11): milk scalds on any lit stove, fireplace, barbecue or campfire at 85 C
  (vanilla's lowest stove setting gets there). The pot's Pour Scalded Milk takes any scalded milk, store milk poured
  out included; Dairy's own scalded record still counts, for when milk never goes off. Milk taken off the heat keeps
  a record of its heat: an open pot cools in minutes (85 to 45 C in about a quarter hour), a Wrapped Yoghurt Pot in
  hours, and a vanilla pour carries the heat over by volume. The Hearth keeps its 20 L copper (TP Core), its pour
  into a pot or crock within 2 tiles, and the banked fire's steady 50 C.
- "Steamed" is "scalded" throughout (user 2026-11-11): the menu is Pour Scalded Milk, the refusal "Not scalded",
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
