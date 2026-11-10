# Changelog: Traditional Preservation (Dairy)

## 0.0.1 (in development, not released)
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
- Not done yet: Starter Culture Crock window, final Hearth art (with a glow in the oven mouth), guide, README,
  Workshop text.
