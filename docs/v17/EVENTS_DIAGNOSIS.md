# Why the rewritten events still feel thin (2026-11-14)

The user, after playing GPT's rewrite: more interesting than before, but still thin; "bland to
consume, wasteful to discard" (鸡肋), and the cause is hard to pin down. This note measures the
events (`game/data/v17/events.json`, 106 definitions) and how the game presents them.

## The short answer

The rewrite made the stories 4.4 times longer and the bills 12 times bigger. It left what a choice
gives you exactly where it was: most choices still end in a ±10% nudge to one production line for
about 90 days, which the player never sees. The costs became real, but the payoffs stayed small and
invisible. Events cost attention and money, and give back a number that fades.

| | Before GPT (86 events) | GPT rewrite (106 events) |
|---|---:|---:|
| Text per node, median | 60 characters | 264 (×4.4) |
| Typical cost, median | 0.6 days of income | 7.0 days (×12) |
| Endings that change nothing | 20% | 22% |
| Endings that leave something lasting (people, technology, deposit…) | 13% | 12% |
| A typical effect | ±10% for 90 days | ±10% for 90 days |

## Five causes, with the evidence

**1. The payoff never grew.** Of 440 endings:
- 22% change nothing;
- 66% move only money, goods or a temporary multiplier;
- 12% leave anything lasting.

Even that 12% is mostly research points. Five endings reveal a deposit and three give a
technology; none builds anything. Of 373 effects:
- the median is ±10% for 90 days;
- 11 are permanent;
- 109 act on 吸引力 (a town's appeal to migrants), a number the player does not watch.

The rarest story pays like the commonest. The ten-step 「钻孔深处有一片星空」 (an ancient
window found underground) ends with four options:
- ¥12,000 and goods for +8% power;
- a research boost for 240 days;
- ¥24,000;
- +20% appeal for 240 days, the default.

**2. You never see what happened.**
- **No resolution:** an ending is a 4–6-character tag (「通风改造」) with no text, so the story
  stops at the click.
- **Unseen effects:** the effect then runs inside production, shown only as a muted line on the
  event page (「仍生效的影响」). Nothing at the mine, the town or on the map says that this
  event is why the mine runs 25% slow.
- **Nothing left in the world:** no building, mark or place is added.

**3. The choice screen read as an invoice.** Options listed costs and multipliers. They did not say
which of the 33 risky nodes' options were gambles, with what odds, or whether the story went on.
Choices became arithmetic, not decisions. *Fixed on 2026-11-14 (`ce1d903`): every option now
names its ending, or the next step and when, or both outcomes with their odds.* The page still reads
like a form: each option is a line of small text over an identical 「选择此方案」 button, so the
eye finds the buttons, not the choices.

**4. It can all be ignored.**
- 58 of 106 events are notices, which never pause and resolve to a free default.
- 91 of 106 never pause at all.
- Even the star map's last step is a non-pausing decision: a player who does not open the event
  page in time gets the default, the appeal bonus.

The game teaches that events are optional, but the costs make them not quite optional.

**5. Chains are slow and fragmented.**
- 27 chains, with steps 15 days apart (median, up to 90).
- No reminder of what came before.
- 10% of all nodes are "pay to go on, or stop for nothing".

The story arrives in pieces, each a fresh decision that weighs about as much as the last.

## What would fix it (proposal, for the user to choose)

**Engine and interface (Claude):**

1. **Option course:** done (`ce1d903`).
2. **Outcome scenes.**
   - An optional `outcome` text per option (60–150 characters), shown as a result card when the
     choice resolves and kept in the history.
   - Without one, the card states the ending and what changed, in words.
3. **Consequences where they act.**
   - Active event effects are shown on the settlement they touch and in the economy page's
     production lines, with the event's name and the days left.
   - A marker on the map while a chain runs at a place.
4. **Climaxes that pause.** A node-level `critical` (GPT's requests 6 and 10), so a chain's
   deciding step waits for the player and a ten-step story is never closed by a default unseen.
5. **Hooks for lasting rewards.**
   - **Landmarks:** an ending leaves a named feature at the place, drawn in the town view, with a
     small permanent effect.
   - **Permanent site traits.**
   - **More gift technologies** (the engine has them).
   - Named specialists who join the colony, later.

**Content (GPT, a new sheet once 2–5 exist):**

6. **Pay off what the story promises.** Every chain's main endings leave something lasting and
   visible: a landmark, a permanent trait, a technology, people, a deposit or a route. The rare
   discoveries change how the colony plays.
7. **Fewer, larger effects.**
   - Retire "appeal ±10% for 90 days" as the default currency.
   - Use two sizes only, big and lasting or small and brief, and drop the ±3% dust.
8. **No empty choices.**
   - Endings that change nothing become real trade-offs, or at least end with a short outcome.
   - Notices either cost nothing and leave a mark, or become decisions; merge the weakest.
9. **An outcome text for each option.**

**Status (2026-11-14):** the user approved all five steps. Steps 1–4 are built (`ce1d903`,
`08f7600`, `af03574`, `b3ca230`): option course, ending scenes, nodes that pause, effects and
landmarks shown where they act, and gift effects in words. Step 5, the content, is GPT's:
`docs/superpowers/plans/2026-11-14-v19-events-payoff-sheet.md`.

**Recommended order:** 2 and 4 first (the story gets an ending, and the big moments wait for the
player), then 3, then 5. Then the sheet for GPT, so its rewrite can use the new hooks.
