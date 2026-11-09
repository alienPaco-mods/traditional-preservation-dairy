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
| `TPD.weather()` | Temperature and speed by place. |
| `TPD.here()` | Which kind of place you're standing in. |
| `TPD.age(hours)` | Hours of perfect weather for every station. |
| `TPD.fast(hours)` | Test timer. `TPD.fast()` goes back to the sandbox time. |
| `TPD.batches(n)` | Spawns raw batches. |
