# Changelog: Traditional Preservation (Dairy)

## 0.0.1 (in development, not released)
- Internal: made by `tp new` from the series template, with the shared core.
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
- The Yoghurt Incubator has no window: its right-click menu shows what the pot is doing (hover for where it stands
  and the time to the next change), and offers Pour Hot Milk, Add Starter, Pour Out Milk and Collect into Clay Jar.
- Internal: the world code tracks each pot, records the hourly weather, catches the milk up and picks the stage
  sprite. The pot's state lives in movableData, so it can be picked up full. The skeleton's slots, placeholder items
  and Craft-button recipe are gone.
- Internal: debug console `TPD.help()`: weather, place, pots, skip, fast timer, hot milk, starter kit.
- Not done yet: the crock's menu, items (Collect waits for the Clay Jar of Yoghurt), art and guide.
