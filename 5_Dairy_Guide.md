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
| Pour from the Hearth is greyed out | The Hearth must stand within 2 tiles of the pot, and the milk in its copper must steam (85 C). Keep the fire lit; Hearth Info says when it will be ready. |

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
| `TPD.weather()` | Temperature by place, and how fast milk sets at each. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.pots()` | Every loaded incubator: stage, litres, milk temperature, what's next. |
| `TPD.skip(hours)` | Moves every loaded incubator on by this many hours. |
| `TPD.fast(hours)` | Test timer for setting. `TPD.fast()` goes back to the sandbox time. |
| `TPD.milk(litres, c)` | A cooking pot of cow's milk (default 5 L), at c degrees if given. |
| `TPD.kit(kind)` | What a test needs: yoghurt (default), `"crock"` or `"wrap"`; `"?"` lists them. |
| `TPD.crocks()` | Every loaded crock: stage, progress, place. |
| `TPD.culture(hours)` | Moves every loaded crock's current stage on by this many hours. |
| `TPD.tiles()` | Every station within 3 tiles: object class, sprite, solid flags. |

The Hearth's commands are TP Core's: `TPC.help()`.
