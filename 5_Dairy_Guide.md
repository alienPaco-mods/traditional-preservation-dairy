# Traditional Preservation: DAIRY
### The Official Player's Guide

> *"TEMPLATE: an epigraph."*

---

## Contents
1. What This Mod Does
2. Quick Start
3. Walkthrough
4. The Yoghurt Incubator
5. Secrets & Hidden Features
6. Tips
7. Troubleshooting
8. Sandbox Settings
9. Appendix: The Tester's Toolkit

---

## 1. What This Mod Does

TEMPLATE: the problem in vanilla, and the real technique this mod brings back.

---

## 2. Quick Start

| Step | You need | You get |
|---|---|---|
| Build a **Yoghurt Incubator** | 4 planks, 8 nails, hammer (kept). Carpentry 2 | The station |
| Load it, press **Craft** | Up to 4 Raw Dairy Batches | |
| Wait **3 in-game days** (at the best temperature) | | Finished Dairy Batches |

---

## 3. Walkthrough

TEMPLATE

---

## 4. The Yoghurt Incubator

- **Each press of Craft starts its own timer.**
- **Temperature matters.** Outdoors it follows the day's weather; under a roof the average of the last ten days
  plus 10 C (never above 28 C); in a basement 15 C all year.

> **Margin note:** TEMPLATE: a real-world note.

> **Mind the pot.** Milk is only marked **scalded** while you're within reach of it, so stand by the stove until it
> steams. Once scalded it stays scalded however cold it gets, and goes into the incubator at whatever heat it
> has left. If it's below 40 C by then, the starter won't take until you reheat it.

---

## 5. Secrets & Hidden Features

TEMPLATE

---

## 6. Tips

TEMPLATE

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| The station or recipes don't appear | Check `~/Zomboid/console.txt`. |
| "Scald your milk first", though you heated it | Milk only counts as scalded if you're within reach of it while it's at 85 C or hotter. Heat it, walk off, and come back cold, and nobody saw it steam. Stay by the stove until it's hot, or heat it again. |
| Added a splash of fresh milk and now it won't pour | Fresh milk unscalds the whole pot. Bring it back to the steam. |

---

## 8. Sandbox Settings

| Setting | Default | What it does |
|---|---|---|
| Processing time (days) | 3 | Days a batch takes at the best temperature. |
| Temperature sensitivity | Normal | Off, Forgiving, Normal, Harsh. Off ignores the weather. |

---

## 9. Appendix: The Tester's Toolkit

Copied from `DEVHELP.md`; change both together.

| Command | What it does |
|---|---|
| `TPD.weather()` | Temperature and speed by place. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.age(hours)` | Hours of perfect weather for every station. |
| `TPD.fast(hours)` | Test timer. `TPD.fast()` goes back to the sandbox time. |
| `TPD.batches(n)` | Spawns raw batches. |
