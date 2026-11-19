# PeltTrade

Trades bear, cat and wolf pelts up a quality step with **Dar Forager Lumun** in the Rathe
Mountains. Three of one kind become one of the next quality up, and the script keeps going
until nothing is left to trade.

- Three Low Quality become one Medium Quality
- Three Medium Quality become one High Quality

High quality is the end of the line, so it is counted but never handed over.

## Requirements

- **A froglok**, or a **Guktan illusion**. A plain *Froglok* illusion will not do — he refuses
  those. The script checks before you set out, and checks again after you zone, since zoning
  drops an illusion for anyone without the AA that carries one across. If it lapses it waits
  for you to recast rather than giving up.
- **MQ2Nav** for walking to him, and **MQ2EasyFind** if you want the trip from the Plane of
  Knowledge. The script loads either one if it is missing, without changing your auto-load
  settings.

## Use

Start in the **Plane of Knowledge** and it travels for you, or start in the **Rathe
Mountains** and it walks straight to him.

```
/lua run pelttrade
```

It checks your bags first and stops before travelling if there is nothing worth trading.

## What it trades

| Kind | Qualities traded |
|---|---|
| Bear Skin | Low, Medium |
| Cat Pelt | Low, Medium |
| Wolf Skin | Low, Medium |

Lion, cougar, tundra kodiak, horse, coyote, snake and cragbeast pelts use the same naming
but he does not accept them, so they are left alone.

## Notes

- Lows are traded before Mediums, so the Mediums made during a run get upgraded in the
  same pass.
- Pelts go over **one at a time, unstacked**, three per hand-in. He discards the remainder
  of an over-sized hand-in, so the script refuses to put a whole stack in the trade window.
- Every hand-in is confirmed by your inventory count actually dropping, not by the button
  press. If he hands something back, the script says so and stops rather than looping.
- He is not always up. If he is missing, the script reports the Norrath time and exits.
