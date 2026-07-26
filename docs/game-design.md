# Civitas Chronica — Game Design Document

> **Status:** Draft. Demand system and phased turn structure (§3, §4.0) added 2026-07-25/26, replacing Citizen Approval and Migration Appeal. Historical framing revised 2026-07-26.

---

## 1. High Concept

A **card-based city-builder with rogue-lite elements**. The player acts as an ephemeral mayor guiding a single city across centuries, making decisions by playing cards drawn from a deck shaped by their choices. The city develops indirectly — the player enacts policies and invests in developments, but never directly plans streets or places buildings. Surviving to the final age with a thriving city is the win condition; city character and specialization contribute to the final score.

The setting is a **composite European provincial town**, not a specific historical location or a claim to represent every European town. It begins deliberately underdetermined; the developments the player chooses gradually establish its geography, economy, institutions, and regional role. Every resulting city should be historically plausible, but no single run is a model of all Europe. The town remains provincial throughout: it may become prosperous, specialized, or culturally important, but never a capital or one of the continent's principal metropolises.

**Genre:** Card-based strategy / city-builder hybrid with rogue-lite elements

**Inspirations:** Slay the Spire (rogue-lite structure, meta-progression), Terraforming Mars (engine building, card tableau, project cards with tags), 7 Wonders (age-scoped card pools, card chaining), Through the Ages (civilization card game, card row, age transitions, obsolescence), SimCity / Caesar (city-builder fantasy), Urban Empire (indirect mayoral control, era progression — cautionary reference for clarity of cause-and-effect)

**Board game inspirations:** Terraforming Mars, 7 Wonders

**Platform:** PC

**Save length:** ~3–5 hours per full five-age save (~30–60 min per age). Saves are persistent and played across multiple sittings.

### Unique Selling Points

- **Indirect city control** — the player enacts policies and plays development cards but never directly plans streets or places buildings. The city's character emerges from the aggregate of decisions, not from any single choice.
- **City persistence and reinterpretation** — structures built in early ages change meaning in later ones. A medieval city wall becomes a heritage tourist attraction; a 19th-century factory becomes a pollution crisis. Past decisions pay out — or punish — in unexpected ways centuries later.
- **Meta-progression via unlocks across saves** — system interactions and thresholds are discovered through play and can be used strategically in future saves.

---

## 2. Design Pillars

Guiding principles every mechanic should serve.

- **No direct planning of city.** Player has indirect control through development cards, policies, and event choices. The city's layout, character, and growth emerge from the interaction of these decisions, not from placement or spatial planning. There must always be a system between "player plays card" and "city changes."
- **Decisions are (mostly) permanent.** Past decisions are generally irreversible. Tools to "fix the mess" exist but always at a cost — reversibility is a limited, expensive affordance, not the default. Developments accumulate; tags compound; interaction thresholds, once crossed, reshape the city's trajectory.
- **You can't do everything.** Player activity is limited; no save is intended to see all content. Branching, specialization, and opportunity cost are core to the experience. Budget limits card plays per turn; policy slots force trade-offs; card paths gate content behind prior choices.
- **The player sets the pace.** Time advances only when the player acts. Between actions, the player is free to observe the city, read stats, and plan. There is no real-time pressure.
- **Emergent stories are the end goal of experience.** Adaptability is key, failing to execute precisely as planned is a norm, there is no clear-cut "right" way to play, readiness to explore is rewarded. System interactions, event consequences, and age transitions create narratives unique to each save.
- **Cards are fleeting opportunities, not something you strategize hard about.** Drawing gives you choices up until the end of an age; injected paths widen the possibility space rather than promise specific payoffs. This justifies draw-don't-draft, hand retention (opportunities accumulate but expire with the age), and accepting draw variance without mulligans or markets.
- **Score is the contest; losing is pressure, not the challenge.** This is a city-builder first: winning a save is expected, and the interesting game is the score — the character, specialization, and unique circumstances of the city you built. Lose conditions exist to force choices and prevent passive accumulation, not to gate content. Hard rule: no lose condition may ever resolve in a single turn — everything telegraphs and gives the player turns to react.

---

## 3. Core Loop

At its core the game is an engine builder. The player accumulates developments that generate resources and reshape the city's character. Choices are influenced by available card paths, current city state, active policies, and event pressure.

### Turn Structure

The turn resolves in three phases, in this order. The player only acts in phases 2 and 3; phase 1 runs to completion on its own. The UI does not have to present them as labelled phases, but the simulation resolves them in exactly this order.

**Phase 1 — Upkeep.** The city acts before the player does.

1. Budget refreshes fully; any pending event bill from last turn is deducted.
2. Population count grows by this turn's delta (§4.0). If it crosses a level boundary, population level changes.
3. Every active demand takes its growth step (§4.0).
4. Every demand at or above its threshold shuffles an emergency card into the event deck; every demand at catastrophe level shuffles a catastrophe card as well.
5. Time advances by a fixed amount.

**Phase 2 — Events.** Draw from the event deck until a card is found whose trigger conditions match the current city state. There is no draw limit; if nothing in the deck matches, no event fires this turn. Resolve it: the player chooses between options, which may move demands one-off, change population, and inject further cards into either deck. Standing developments may negate part of an event's effect or unlock an additional option (§4.4).

**Phase 3 — Play.**

1. **Draw** — draw N cards from the age deck into hand (base: 3).
2. **Play** — play cards from hand, spending budget. Development cards enter the city permanently. Action cards resolve immediately and are discarded. Unplayed cards remain in hand until end of age.
3. **Interaction check** — the system checks development tag thresholds. If a threshold is crossed, the city's character shifts: new interaction effects activate, new policies unlock, card costs may adjust.
4. **Deck injection** (invisible) — played development cards inject new cards into both the main deck and the event deck. The player knows a card "opens a path" but doesn't see exactly which cards were added or when they'll appear.
5. **Hand limit** — the turn cannot end with more than the hand limit (base 5) in hand. The player discards down to the limit; discarded cards are consumed and never return (§4.1).

**Why this order.** The player sees the city's condition and the crisis it produced *before* deciding what to build, and then responds to both in the same turn. Growth and demand pressure are never a consequence the player discovers after committing their budget.

**Event billing:** budget costs from event choices are deducted at the start of the *next* turn, from the fresh budget. The player keeps full freedom to spend this turn, but the city hands them a bill that constrains the next one. Event costs can push budget negative — overcommitting to expensive event choices is the on-ramp to the debt-spiral lose condition.

### Resources

The game tracks two resources and one meter per active demand. Nothing else.

- **Population** — city size and a major score contributor. Not spent. Tracked as a **level** (small integer, the only value rules read) over a **count** (the actual number of people, which moves every turn and drives nothing directly). Level feeds the demand growth step and may unlock card paths and trigger forced events. See §4.0.
- **Budget** — the only spendable currency. Allocated per turn, representing both money and administrative capacity. Card plays cost budget. Capacity is modified by developments, policies, and interaction effects. Refreshes fully each turn; unspent budget does not carry over.
- **Demand meters** — one integer per active demand (§4.0). Start at 0, never negative, one new demand activates each age.

> **Removed 2026-07:** *Citizen Approval* and *Migration Appeal* were previously separate resources. Trust in government is now covered by the **Legitimacy** demand from Age 3 onward. Political interests, customary rights, and negotiation exist earlier, but Legitimacy becomes a continuous city-wide demand only when political authority becomes an object of broader public argument. Migration Appeal was a separate growth dial; **Appeal** is now an unmet demand and population growth is driven by overall demand balance (§4.0).

### One Age (target time: 30–60 min)

An age contains many turns and events. The age ends when in-game time reaches the age boundary.

**Turn count per age is derived from content, not chosen abstractly.** The floor is implied by the age's own design: the deepest prerequisite chain (e.g., Town Market → Merchant Guild → Trade Company needs 3+ turns minimum), plus injection lag (a path opened mid-age needs several turns to plausibly surface in draws), plus interaction threshold counts. Write the age's content first, then set the turn count so the deepest intended arc is completable with room to spare. A slightly dynamic turn count per age is acceptable.

Card decks, most developments, and policies are age-specific. Developments carry into subsequent ages and some are replaced by successor cards at the boundary (see §4.6). At age end, unplayed cards are discarded — unless the player has used a rare preservation mechanic (e.g., Legacy Archive) to carry specific cards forward.

### Full Save (~3–5 hours, across multiple sittings)

A save spans 5 ages, each activating one new demand (§4.0):

| Age | Years | Setting | Demand activated | Positive character | Negative character |
|---|---|---|---|---|---|
| 1 | 1500–1600 | Charter and Consolidation | **Provision** | growth | scarcity |
| 2 | 1600–1750 | Confession, State, and Exchange | **Security** | learning | war and sickness |
| 3 | 1750–1850 | Agrarian and Commercial Transformation | **Legitimacy** | improvement | upheaval |
| 4 | 1850–1950 | Urbanization and Civic Provision | **Health** | invention | overcrowding |
| 5 | 1950–2030 (present day) | Mobility, Services, and Competition | **Appeal** | connection | decline and competition |

The positive and negative characters set the tone and content of each age — which cards, events, and situations belong to it. They are authoring guidance, not separate mechanics.

**Ages describe transformations as experienced locally.** The town need not lead the Scientific Revolution, industrialization, political revolution, or modernization. History usually reaches it through new laws, taxes, prices, military demands, migration, transport connections, administrative standards, circulating publications, and technologies developed elsewhere.

**Demands do not represent the invention of human needs.** People cared about food, safety, justice, health, and the desirability of their home in every period. A demand activates when that concern becomes a persistent, city-wide municipal responsibility that can no longer be handled only through households, guilds, parishes, estates, customary institutions, or occasional emergency measures.

Age 3 remains predominantly agrarian and commercial for a typical run; factory industrialization is an optional specialization supported by prior choices. Legitimacy becomes continuous as knowledge, administration, political organization, and changing ideas of citizenship make government increasingly contestable. Age 4 brings denser urban life and dependence on civic systems whether or not the town becomes a heavy-industry center. Age 5 makes Appeal comparative as greater mobility and communication cause provincial towns to compete with other places for residents and relevance.

Detailed historical briefs, content boundaries, and examples for all five Ages are maintained in [content-authoring.md](content-authoring.md).

The city persists across ages — it's one continuous city, growing and changing. Each age has a distinct card pool reflecting era-appropriate developments. At age transitions, development tags carry forward and may trigger new interaction effects under the new age's rules.

Saves are persistent. The player can close the game mid-age and return later. The whole state before the start of the turn is persistent.

**Win condition:** reach the end of the final age without triggering a lose condition.

**Lose conditions:** *(open — see §4.0)*

The demand system does not kill the player directly; it loads the event deck. Loss therefore has to arrive through an event. The leading candidate is the **catastrophe card** (§4.0): drawing one for a demand that is still far above its threshold ends the save. Reaching that state requires having been deep in the red long enough for catastrophe cards to have entered the deck at all, and pulling the meter back down at any point removes the danger.

Retained from the earlier draft:

- Debt spiral — budget capacity below 0 for multiple consecutive turns.
- City destruction — specific unmitigated event chains.

**Design intent:** all lose conditions are slow and grace-period-based — *consecutive* debt turns, *unmitigated* event chains, demands left in the red for many turns. Nothing kills the city suddenly; every path to loss telegraphs and leaves turns to react. Losing exists to create pressure to choose and accept consequences, not to be the contest. When a save is lost mid-way, the city is done, but account-level discoveries persist — the player walks away with more options for the next run. Survival as a genuine threat is reserved for harder starts (a New Game+ concern, not an MVP one).

**Score:** see §4.7 Scoring.

### Account-Level Meta-Progression

> **Deprioritized for now.** Will be designed after in-save mechanics are solid.

Achievements and milestones across saves unlock new cards (and possibly advisors, starting bonuses, etc.) for future saves. Purely account-wide; does not affect any active save.

Critically, interaction thresholds discovered during play are remembered at the account level. On a first save, the player may discover that a sufficiently deep Trade tableau triggers Trade Hub status. On subsequent saves, the player can see and plan toward its exact threshold from the start.

---

## 4. Mechanics

### 4.0 Demands

Demands are the counterweight to the card engine. Drawing cards, building developments, and growing the city all push demands up. Bringing them back down costs budget and card plays the player would rather spend on specialization. This is the system that forces the player to build specific things and that punishes leaning too hard in any one direction.

**One demand activates per age and never deactivates.** By the final age all five are live simultaneously, which is where the game's complexity comes from — not from any demand becoming individually harder.

Each demand measures an **unmet municipal responsibility**, not the existence of a human concern:

- **Provision** — unmet need for reliable food, water, and fuel.
- **Security** — unmet need for defence, public order, fire protection, and the basic continuity of the town.
- **Legitimacy** — the gap between the authority claimed by the mayor and council and the authority inhabitants believe the government deserves. It covers trust in government, acceptance of rules and burdens, demands for representation and liberty, and expectations of fairer treatment. A value of 0 means the current political settlement is broadly accepted, not necessarily democratic or equal. A high value means expectations have outgrown that settlement: residents question who rules, whose interests government serves, and whether they could govern themselves better. The internal content ID remains `fairness`; **Legitimacy** is the player-facing name.
- **Health** — unmet requirements of healthy urban life: clean water, sanitation, waste removal, safe housing, disease control, workplace safety, pollution control, medical access, and the minimum welfare provision needed to keep concentrated hardship from becoming a public crisis. Welfare choices may also affect Legitimacy when inhabitants contest who receives help and on what terms.
- **Appeal** — the gap between the town people want to choose and the one they experience. It covers housing, employment, services, mobility, environmental quality, comfort, culture, belonging, and confidence in the town's future, judged against other towns and cities. Appeal does not directly generate or spend population; unmet Appeal contributes to the overall demand balance that governs growth.

#### The meter

Each active demand is a single integer. It starts at 0 and never goes below 0.

- **0** = the demand is satisfied.
- **Any positive value** = unmet need. Small values are tolerable; large ones generate crises.

There is no surplus, no buffer, and no reward for a demand being at 0 beyond it not causing problems. Overshooting is wasted effort by design — the player is not meant to bank safety against future ages.

#### Growth step

Every turn, during the upkeep phase (§3), each active demand increases by its **growth step**:

```
population level + aggravators − mitigators        (minimum 0)
```

- **Population level** — a small integer, currently 1 for a town up to 3–4 at maximum size (see Population below).
- **Aggravators / mitigators** — the sum of printed demand values on the developments standing in the city (see below).

Every term is a count of something visible on the table. The whole calculation is small-integer addition and is intended to be doable by hand.

**A well-managed demand sits at a growth step of 0 and does not move.** That is the equilibrium the player is aiming for, and reaching it means nothing happens on that row for many turns at a stretch. The system is quiet by default.

**A population level-up is what breaks equilibrium.** Gaining a level adds 1 to every active demand's growth step at once. A city that was holding five demands at 0 is suddenly creeping upward on all five, every turn, until it rebuilds mitigation. This produces the intended rhythm: long calm stretches punctuated by a level-up that forces a scramble.

**Demand growth is fully predictable.** The step is computed from things the player can count, and the result is shown on every demand row. The only unpredictable movement comes from events.

#### Population

Population is tracked as two numbers with different jobs.

- **Population level (X)** — a small integer. This is the only population number any rule reads: it feeds the demand growth step, gates card paths, and contributes to the score.
- **Population count (Y)** — the actual number of people. It moves every turn and exists to make the city feel alive. **No rule calculates against Y directly.**

Y grows each turn during the upkeep phase and is collapsed into X by a fixed table of level boundaries, spaced on a rising curve so that each level takes longer to reach than the last. When Y crosses a boundary, X changes and the engine feels it.

**Growth rate is governed by demand balance**, counted off the demand rows rather than summed:

| Active demands at or above threshold | Growth |
|---|---|
| none | full rate for the age |
| one | reduced |
| two | stalled |
| three or more | decline |
| any demand at catastrophe level | decline regardless |

*(Exact multipliers are balancing placeholders. The per-age base rate is set by the age definition.)*

The per-turn delta carries a small random variation of roughly ±15% so the numbers look alive; it is drawn from the named `population` RNG stream and never large enough to make level timing unpredictable in practice. The player is shown the delta as part of the upkeep phase, at the same moment the demand growth steps resolve.

**Levels can be lost.** If Y falls below a level boundary — through Age 5 decline, or through an event such as a plague or a levy — X drops, and with it every demand's growth step. A disaster that costs the city a level genuinely relieves demand pressure. This is not exploitable, because population is a major score contributor. A hysteresis margin prevents X from flipping back and forth while Y sits on a boundary.

**Growth is a cost that cannot be switched off, only slowed.** Neglecting demands does not protect the player: it stalls growth, which means fewer level-ups but also a smaller city, a worse score, and a steadily more crowded event deck. Managing demands well is rewarded with growth, and growth is what makes the next stretch harder.

Some events change Y directly as a one-off, in either direction.

#### How cards move demands

Development cards print a value for each demand they touch — for example *Tannery: Provision −1, Health +1*; *Aqueduct: Health −2*; *Foundry: Health +2, Provision −1*.

A printed value does two things at once, and they are always the same number:

1. **On play**, the demand's current value changes by that amount immediately (clamped at 0).
2. **Permanently**, the value is added to that demand's growth step for as long as the development stands in the city.

The immediate half being clamped at 0 is what prevents buffering. Playing an Aqueduct while Health is at 0 wastes the immediate reduction; the player still gets the permanent growth reduction, so it is not a dead play, but it is an inefficient one. This pushes the player to address problems that exist rather than pre-build against problems that do not.

Because aggravators enter the growth step rather than costing a flat amount once, the cost of specializing compounds every turn. Six factories at population level 2 grow Health by 8 per turn, and holding it at 0 needs roughly six health developments — budget and card plays the player wanted elsewhere. No special rule is needed for this; it falls out of the counting.

**Events move demands one-time only.** An event may bump a demand's current value up or down, but never changes its growth step. Events exist to force movement when the player's standing system is not good enough, not to permanently rewrite it.

#### Consequences

A single tolerance threshold, the same for every demand and every age (current tuned value: **5**).

- **Below the threshold** — nothing happens at all. No penalty, no bleed, no cost.
- **At or above the threshold** — one **emergency event card** for that demand is shuffled into the event deck each turn. Duplicates are allowed and expected.
- **Far above the threshold** (current tuned value: **20**) — a **catastrophe card** for that demand also enters the deck each turn.

Two severity levels total. No third tier.

Bringing a demand back below the threshold stops new cards entering the deck but does not remove cards already added. A demand ignored for ten turns has stuffed ten emergency cards into the deck, and they will surface at a time the player does not control. This is the entire punishment mechanism — demands never apply direct damage, ongoing bleed, or hidden penalties. All consequences arrive through the event system, which already presents choices and already telegraphs.

#### Age activation

When an age activates a demand, the meter does not start at 0 unless the city happens to be clean. The printed values of all standing developments for that demand are counted and applied, exactly as if the cards had just been played.

A city that spent two hundred years building tanneries, a foundry, and dense housing starts Health well above the threshold in 1850, with emergency cards entering the deck from the first turn of the age. The city is measured against a concern that has become institutionalized as a continuous municipal responsibility, even though the underlying human need always existed. This is the primary mechanical expression of the "past decisions pay out or punish centuries later" premise.

Supersession (§4.6) handles obsolescence: an early granary may eventually be replaced by a warehouse or a heritage structure whose Provision value, tags, and effects reflect its new role.

#### Visibility

**Demands are never hidden.** Interaction thresholds, event triggers, and deck injections are discovery-based; the demand system is fully transparent at all times. The player can always see every meter, its current value, and its growth step. The hidden systems provide surprise; the demand system provides the pressure that gives those surprises weight. Hiding both would make cause and effect unreadable.

#### Presentation

One row per active demand. Each row shows the current value, its growth step, and the threshold. A row at or above the threshold is clearly marked as generating emergency cards. Population level and count sit alongside, with the count's per-turn delta shown at upkeep.

Hovering a card previews its effect on every demand row, including the demands it worsens. Cross-demand costs must be visible before the card is played, not discovered afterward.

Rows carry a short status line in period voice derived from the value band — "bread prices are climbing", "the lower ward is sick". On the mayor's desk (§6) demands live on a petitions board; each age transition physically adds a sheet.

#### Open questions

- **The growth rate function.** The table above is the shape, not the numbers. Not a sum of demand values — a step function on how many demands are over threshold.
- **Level boundary spacing.** How many levels exist across a full save, and how steeply the boundaries rise. Roughly one level per age is the current assumption.
- Whether the threshold should stay uniform across demands and ages permanently, or diverge once content exists to justify it. Uniform for now.
- Whether the catastrophe card is the loss condition, or merely the thing that makes a save unrecoverable. Undecided — see Lose conditions in §3.

### 4.1 Cards

Cards are the primary means of city development. Most cards are played once and persist as permanent additions to the city (developments) or resolve immediately (action cards). There is no rolling discard pile or deck cycling.

**Card uniqueness (Terraforming Mars rule, added 2026-07 after first playtest):** every card exists at most once per save, across deck, hand, city, and consumed actions. A development can never be built twice; a played action card never returns. Injections silently skip cards that already exist anywhere in the save. Events are deliberately NOT unique — a recurring flood is a consequence, not a bug.

**Card categories:**

#### Development Cards

Permanent city additions. The core of the engine. Once played, a development stays in the city for the rest of the save (though its meaning may change across ages — see §4.6).

Each development has three layers of effect:

- **Demand values** (visible on card): printed values for the demands the development touches, e.g. *Health +2, Provision −1*. Each applies immediately on play and permanently to that demand's growth step (§4.0). Most developments touch one or two demands; some touch none.
- **Primary effect** (visible on card): the immediate, predictable outcome beyond demands. Examples: "+1 Budget/turn," "reduces disease event severity," "+1 draw."
- **Interaction tags** (visible on card): categories that define the development's domain. Tags include `[Trade]`, `[Military]`, `[Religious]`, `[Industrial]`, `[Cultural]`, `[Science]`, `[Infrastructure]`, etc. Tags don't do anything individually — they matter when developments combine (see §4.2 Interaction System).
- **Deck injection** (hidden on first encounter): playing the card adds specific new cards into the age deck and/or the event deck. The first time a card is played in any save, the player only knows "this opens a path" — they don't see exactly which cards were added or when they'll appear in the draw. After that first play, the injection contents are remembered at the account level and shown on the card in future saves — the same learning contract as interaction thresholds and event triggers (see §4.2). This is the primary mechanism for path-dependent content gating — playing a River Docks development injects maritime card paths into the main deck and flood/trade events into the event deck.

Developments accumulate without limit. This accumulation is the goal, but it also compounds the city's character, triggers new interaction effects, and increases the city's exposure to related events.

Some developments require prerequisites: prior developments of the same path must have been played. The prerequisite chain is visible on the card. Example: "Requires: Town Market" → unlocks Merchant Guild → unlocks Trade Company. This creates branching specialization within an age.

#### Action Cards

Immediate, tactical plays. They don't permanently alter the city's engine but let the player respond to situations, convert between resources, or perform one-time adjustments.

Examples: grain purchase (one-time Provision reduction), emergency repairs (mitigate event damage), militia muster (one-time Security reduction), eminent domain (remove a development — expensive, and removes its mitigation as well as its aggravation).

Action cards move demand meters **one time only** — they never change a demand's growth step. They are how the player buys time against a backlog their standing system cannot handle, which makes them the natural answer to a demand that has spiked from an event.

Action cards are the primary means of handling event consequences. This creates a hand management tension: spending all budget on developments leaves the player vulnerable to events with no action cards to respond.

Action cards are discarded after play.

**Card attributes:**

- Budget cost
- Age availability (which ages it can appear in)
- Card category (Development / Action)
- Demand values (Development cards: permanent; Action cards: one-time only)
- Interaction tags (Development cards only)
- Prerequisites (some Development cards)
- Superseding card (optional, Development cards — see §4.6)
- Primary effect description
- Path hint: "Opens new paths" indicator (Development cards that inject into the deck)

**Deck construction:**

- **Deck is age-scoped.** Each age, the player plays with a deck specific to that era. Cards from previous ages do not carry forward (with rare exceptions via preservation mechanics).
- **Deck is generated, not manually drafted.** At the start of each age, the deck is composed automatically based on: (a) current city state (developments in play, active tags, population level, demand meters, economy), (b) accumulated decisions across prior ages (which paths were opened, which events were resolved and how), and (c) the age-appropriate base card pool.
- **Deck grows during play.** As the player plays development cards, new cards are injected into the deck mid-age. The deck is not a fixed size — it expands based on the player's choices.
- **Draw, don't draft.** Each turn, the player draws N cards from the top of the shuffled deck. There is no card row or market. The player's influence over what cards appear is indirect — through which developments they play (which inject new cards) and which paths they've opened.
- **Hand retention, with a limit.** Unplayed cards stay in hand across turns, but the hand has a **maximum size, starting at 5**. Every turn must end with the hand at or below the limit; if the player is over, they choose which cards to discard. Discarded cards are consumed and do not return (card uniqueness).
- **The limit expands, the draw does not.** Hand size is increased by rare developments. Increasing the *draw* is deliberately not the growth lever — a bigger draw floods the player with cards they must immediately discard, while a bigger hand lets them hold more opportunities open. Growth in card capacity should feel like more room to manoeuvre, not more forced decisions per turn.
- At end of age, all remaining hand cards are discarded unless specifically preserved.

### 4.2 The Interaction System

The interaction system is the core mechanism for indirect city control. It sits between the player's individual card decisions and the city's emergent character.

**Concept:** the player controls individual decisions (which cards to play). The city responds to the *aggregate* of those decisions. When the total number of developments with a given tag crosses a threshold, an interaction effect activates, changing the rules of the game.

**How it works:**

Each interaction effect has one or more substantial state thresholds (for example, a deep concentration of `[Trade]` developments) and a set of consequences that activate when the threshold is reached. Consequences may include:

- Passive resource changes (budget bonuses, demand growth-step modifiers)
- Cost modifications for future card plays (cards of certain tags become cheaper or more expensive)
- Policy unlocks (new policy options become available — see §4.3)
- Card path unlocks or restrictions (certain card paths become available or are locked out)
- Event deck changes (new event types enter the event pool; others are removed)
- City view changes (visual transformation of the city to reflect its character)

**Current interaction examples:**

| Threshold | Effect Name | Consequences |
|-----------|-------------|--------------|
| 12+ `[Trade]` | Trade Hub | +2 Budget/turn. Security growth +1 as traffic and valuable goods increase exposure. |
| 14+ `[Industrial]` + 10+ `[Trade]` | Export Economy | +3 Budget/turn. Health growth +2 from intensive production. |
| 5+ `[Religious]` + 10+ `[Cultural]` | Religious Cultural Centre | Legitimacy growth −1 and Appeal growth −1 through shared institutions and identity. |
| 12+ `[Military]` | Garrison Town | Security growth −2, but Legitimacy growth +1 from permanent military influence. |
| 15+ `[Science]` | Learned City | Science developments cost −1; Legitimacy growth +1 as civic expectations rise. |
| 15+ `[Infrastructure]` | Well-Connected City | Development costs −1 (minimum 1); Provision growth +1 as dependence on networks grows. |

**Multi-tag interactions** create the most interesting emergent situations: the player may not have intended to create an Export Economy, but by pursuing both trade and industrial paths for their individual benefits, they crossed the threshold and now face the consequences.

**Discovery model:** interaction thresholds are NOT shown to the player before they are first activated in any save. The first time a threshold is crossed, the effect is revealed with a notification explaining what happened and why. This serves the "emergent stories" pillar — the player discovers their city's character rather than planning it from a menu.

At the **account level**, discovered interactions are remembered. On subsequent saves, the player can see known thresholds and plan toward or away from them. This is the primary rogue-lite discovery mechanic and a major driver of replayability.

**Unified learning contract:** all three hidden systems — interaction thresholds, event triggers, and deck injections — obey the same rule: *hidden the first time, remembered at the account level forever after.* Nothing changes between saves, so remembering is the skill. Learning how the systems respond is precisely what makes a player good at the game.

**Visibility:**

- Active interaction effects are displayed in the city view dashboard: "Trade Hub (active): +2 budget, +1 industrial costs."
- On repeat saves, upcoming thresholds for known interactions are shown: "Trade Hub: 10/12 [Trade] developments."
- Unknown interactions are never hinted at.

### 4.3 Policies

Policies are a separate mechanic from the card system. They represent the city's governing philosophy and modify the rules of the game.

**Slots:** the player has 3 active policy slots. Early in Age 1, only 1 slot may be available, with additional slots unlocking through development thresholds or age transitions.

**Unlocking:** policies are unlocked by reaching specific development tag thresholds or interaction effects. Example: reaching Trade Hub status unlocks the "Free Trade" and "Mercantile Regulation" policy options. Some policies are age-specific; others persist across ages but may evolve into new variants.

**Changing:** swapping a policy costs budget and raises the Legitimacy demand (if active) and takes effect at the start of the next turn. The cost reflects the disruption of changing governing philosophy mid-stream. This makes policy changes meaningful rather than trivial.

**Mechanical effects:** policies modify game rules rather than providing flat bonuses. Examples:

- **Free Trade:** `[Trade]` developments produce +1 budget each. Trade-related events have increased severity. Provision growth −1 (imported grain), Security growth +1.
- **Conscription:** `[Military]` developments cost 1 less budget. Legitimacy growth +1. Military events are less severe.
- **Patronage of Arts:** `[Cultural]` developments inject 2 extra cards into the deck instead of 1. Budget capacity reduced by 2. Appeal growth −1.
- **Isolationism:** Foreign trade events cannot fire. Security growth −1, Appeal growth +2. `[Trade]` developments produce −1 budget.
- **Poor Relief:** All `[Civic]` developments count as an additional −1 mitigator for Provision. Budget −2/turn.

**Age evolution:** when an age transitions, active policies present the player with evolution choices. A "Patronage of Arts" policy in Age 1 might branch into "State-Sponsored Culture" (more control, more budget cost, specific card unlocks) or "Free Artistic Expression" (less control, Legitimacy growth −1, different card paths). This is one of the key decision points at age transitions.

### 4.4 Events

Events are the city's voice — they present consequences of the player's decisions and force reactive choices.

**Event Deck:** separate from the main card deck. Composed at age start from a base set of era-appropriate events, then expanded during play as development cards inject associated events.

Example: playing "River Docks" injects "Plague Ship," "Spring Flood," and "Trade Dispute" events into the event deck. The player knows the docks "open paths" but doesn't see which specific events were added.

**Drawing:** the event phase runs *before* the player draws or plays cards (§3). Draw from the event deck until a card is found whose trigger conditions match the current city state. There is **no draw limit** — if nothing in the entire deck matches, no event fires this turn. Unmatched events return to the bottom of the deck.

**Trigger conditions are permissive.** An event's trigger exists to prevent narratively nonsensical situations, not to gate content. A flood needs a river; a dock strike needs docks; a plague does not need anything in particular. Most events should fire in most cities most of the time — the interesting variation comes from *how* an event resolves, not whether it fires. This is a content and balancing guideline rather than a hard rule.

Examples:

- "Provision ≥ 3"
- "3+ `[Industrial]` developments"
- "Health growth step ≥ 4"
- "Population level ≥ 2 AND no `[Infrastructure]` interaction active"

**Emergency and catastrophe events** (§4.0) are ordinary events with a trigger tied to their demand being at or above the relevant threshold. They enter the deck through demand pressure rather than through card injection, but they resolve like any other event. Their trigger re-checks the demand, so copies left in the deck from an earlier crisis quietly fail to match once the player has recovered.

**Discovery of triggers:** the first time an event of a given type fires, the player sees the event and its consequences but NOT what triggered it. After that first occurrence, future events of the same type display their trigger conditions on the card. This parallels the interaction discovery model — the player builds understanding of their city's vulnerabilities through experience.

**Resolution:** events present a choice, preferring dilemmas (genuine trade-offs) over pure fortune/misfortune. Choices should have asymmetric timescales:

- Option A: good now, bad later (e.g., "Ignore the flooding — save budget now, but flood events become more severe")
- Option B: painful now, good later (e.g., "Build emergency levees — spend 3 budget, but remove flood events from the deck and add Flood Control development to main deck")
- Option C (rare): lateral move with unexpected consequences (e.g., "Relocate the docks upstream — lose Trade Hub status but gain access to a new card path")

**Developments change how an event resolves.** Rather than restricting which events can fire, developments alter what happens when they do. Two mechanisms:

- **Protection, by hazard type.** Each event has one **hazard type** — `flood`, `fire`, `disease`, `famine`, `riot`, `raid`, `pollution`, `collapse`. A development may carry a `cancels` list naming the hazard types it protects against. If any standing development cancels the event's hazard type, the event's negative effects do not apply. A levee cancels `flood`; a fire watch cancels `fire`; a quarantine house cancels `disease`.

  **Few developments cancel anything, and most cancel exactly one type.** It must never be possible to assemble a city immune to everything.

  Because the protection is a printed hazard type rather than a link to specific events, **the player can read it off the card and plan around it**. Building a levee is a legible decision to buy down flood risk in general, without knowing which flood events exist.

- **Extra options.** Having a specific development standing unlocks an additional choice on the event screen, over and above the default options. Depending on the event this may be an opportunity (turn the crisis into a gain) or simply a less punishing exit. The default options remain available; the extra option is strictly additional.

  Unlike protection, extra options are authored as a reference to a *specific card*, not a hazard type. This asymmetry is intentional: protection is a general category of preparedness, while an extra option is a particular narrative move that only makes sense with a particular institution behind it.

**Event-to-deck feedback loop:** event choices inject new cards into either deck. This makes events part of the engine builder, not interruptions to it.

- Choosing to quarantine during a plague might add "Public Health Office" to the development deck and reduce severity of future disease events.
- Choosing to ignore the plague might add "Mass Grave" (a development with Health +1 and Legitimacy +1) and "Physician Shortage" events.
- Some event choices add action cards to the deck — reactive tools the player might draw in future turns.

**Event frequency:** one event per turn maximum. Because triggers are permissive and there is no draw limit, a turn usually produces an event. The difference between a stable and an unstable city is therefore not *how often* events fire but *what kind* — a well-run city draws ordinary historical situations, while a city with demands in the red has been steadily stuffing emergency and catastrophe cards into the same deck and keeps drawing those instead.

**Forced events are historical pressures experienced locally.** They are age-gated and fire regardless of city state, but describe how a wider transformation reaches this town rather than placing it at the center of continental history. Specific framing rules and examples are in [content-authoring.md](content-authoring.md).

A forced event must still offer locally meaningful choices. Wider history may be unavoidable, but the player's response and the consequences for this town are not predetermined.

Forced events are also **capability checks** — the anti-turtling mechanism. Regular events key off player-generated risk, so a small, stable city rarely triggers them; forced events arrive regardless of what was built and are absorbed comfortably only by a city that developed *some* engine. History happens to you whether or not you invited it: a turtle doesn't die of the events it avoided, it struggles with the exam it didn't study for. Expect 2–4 forced events per age doing this work. Turtling doesn't need to be punished hard — it's punished softly by forced events and creeping lose conditions, and mostly it's just boring; the stronger lever is presenting options too shiny to pass up.

### 4.5 The City View

The player can view the city but does not directly control its construction. The city develops according to cards played and interaction effects active.

**Purpose:** admire progress, read current state, monitor interaction effects, anticipate emerging problems.

**Information surfaced:**

- Current interaction effects and their consequences (as a readable dashboard overlay)
- Active policies and their effects
- Development tags composition (how many of each tag)
- On repeat saves: known interaction thresholds and progress toward them
- Event trigger conditions for previously-seen event types
- Resource trends (budget trajectory, demand meters and their growth steps, population level and distance to the next boundary)

**TODO:** art/representation style — map-based, isometric, abstract? The city view does not need to be spatially accurate but should convey character and change visibly when interaction effects activate or ages transition.

**TODO:** accessibility — ensure info density is readable alongside the aesthetic presentation. Consider a "data view" toggle that strips the visual presentation to pure stats for players who prefer clarity over atmosphere.

### 4.6 City Persistence & Era Reinterpretation

The city is the single most persistent element of a save. Developments, interaction effects, population, specialization, and accumulated history all carry forward across ages.

**Visual evolution.** Structures upgrade visually as the city modernizes — a wooden fire station becomes brick, then modern, then a historical marker. The underlying development persists; its presentation evolves with the era.

**Functional reinterpretation by supersession.** A development can mean something different in a later age. This is expressed by one card **superseding** another: a development card may optionally name a successor card and the age in which the swap happens. At that age transition, the original development is removed from the city and the successor is placed in its stead.

The two cards are fully distinct definitions with their own name, tags, demand values, effects, injections, and artwork. Nothing is patched or overridden — the old card leaves and the new one arrives, and any card may in turn name its own successor, so a structure can pass through several forms across a save.

Examples:

- **City Walls** (`[Military]`, Security −2) → in 1850, superseded by **Wall Ruins** (`[Cultural]`, Security 0, Appeal −1) → in 1950, superseded by **Old Town Heritage Site** (`[Cultural]`, Appeal −2, +1 budget).
- **Foundry** (`[Industrial]`, Health +2) → in 1950, superseded by **Derelict Works** (`[Industrial]`, Health +3, Appeal +2) or, if the city has enough `[Cultural]` developments, by **Converted Lofts** (`[Cultural]`, Appeal −2).
- **Stone Church** (`[Religious]`, `[Cultural]`) → in 1950, superseded by **Civic Landmark** (`[Cultural]`, Appeal −2), which injects heritage tourism cards into the new age's deck.

Supersession is not always an upgrade. A wall becoming ruins is a loss of Security mitigation the player has to replace; a foundry becoming derelict works actively makes Health worse. Which successor arrives may itself depend on city state, which is how the same building ends up as either a liability or an asset depending on what was built around it.

**No player decision is involved.** Supersession is automatic and defined by content, not chosen at the transition (see §4.8). The player's agency was exercised when they built the original card — and, crucially, they may not have known what it would become. Demolition remains available *during* an age through action cards such as eminent domain, which is the expensive, deliberate way to get rid of something.

**Supersession and deck generation:** the post-supersession tags of inherited developments feed directly into the new age's deck generation. A city whose old quarter survived into `[Cultural]` forms generates heritage and tourism card paths; one whose industrial stock decayed generates renewal and remediation paths. This is the primary connective tissue between ages.

### 4.7 Scoring

Scoring reflects city character, not just city size. Multiple scoring axes ensure that different city specializations are viable high-scoring strategies.

> **No end-score function is designed yet.** The axes below are candidates only.
>
> A *Stability* axis (turns spent with all demands below threshold) was cut on 2026-07-26: population growth is already gated on demand management, so Population rewards that behaviour and a second axis would double-count it. The remaining axes should each reward something Population does not.

**Scoring axes (candidates — to be balanced):**

- **Population** — base score component. Larger cities score more, but this alone is not sufficient for a high score.
- **Specialization depth** — bonus points for reaching high-tier interaction effects. A city that deeply commits to a specialization (e.g., reaching "Maritime Empire" at 6+ `[Trade]` developments) scores more than a city that spreads across many tags without crossing higher thresholds.
- **Heritage** — bonus points for developments that have persisted across multiple ages, particularly those that survived supersession into a still-useful later form rather than decaying into liabilities. Rewards building things with a future.
- **Narrative milestones** — bonus for specific event chain completions (e.g., successfully navigating a plague, resolving a reformation, managing an industrial revolution without a Health catastrophe).

A small, culturally rich city and a large industrial metropolis should both be viable high-scoring outcomes, achieved through different development paths and policy choices.

### 4.8 Age Transitions

**The age transition asks the player for nothing.** It resolves automatically and is presented as a report, not a decision screen. The player's choices were made during the age that just ended; the transition is where those choices are settled up. The one exception is policy evolution, which remains a choice (§4.3).

When in-game time reaches an age boundary, the following sequence occurs:

1. **Hand discard** — all remaining cards in hand are discarded (unless preserved via a Legacy Archive or similar mechanic).
2. **Supersession** — every development whose card names a successor for this age is replaced by that successor (§4.6). Automatic; no player input.
3. **Policy evolution** — active policies present evolution choices. Each policy branches into 2–3 age-appropriate variants (§4.3). This is the only decision in the transition.
4. **Interaction recalculation** — development tags are recalculated after supersession and all interaction effects are re-evaluated. An interaction can be lost if supersession changes the city's tags or removes a required development.
5. **Deck generation** — the new age's main deck and event deck are generated based on current city state, including superseded developments and new policy selections.
6. **Demand activation** — the age's new demand becomes active, and its starting value is calculated from the printed values of all standing developments *after* supersession (§4.0). Existing demands carry their current values forward; their growth steps are recalculated.
7. **Resource adjustment** — budget capacity may shift based on age transition rules. Population carries forward directly.
8. **New age begins** — first turn of the new age.

**The transition report.** Although the player decides nothing, they must be shown clearly what changed, because their engine can look substantially different on the other side. The report covers: which developments were superseded and by what, which interaction effects were gained or lost as a result, the new demand and its starting value, and the resulting growth step for every active demand. This screen is where a player learns that their walls became ruins and their Security demand just jumped.

**What carries forward:** developments (superseded where defined), population, accumulated account-level discoveries. **What resets or adjusts:** budget capacity (recalculated for new age), policy slots (new options, old policies evolved), card paths (new age pool), event deck (rebuilt), hand (discarded).

### 4.9 Advisors

> **Deprioritized.** Not in minimal variant.

Advisors grant passive abilities that modify card play. Examples: peek at next draw, draw extra cards, reduce cost of a card type. Advisors would be acquired at age start or as event rewards and would stack with policies to create deeper strategic customization.

---

## 5. Narrative & Tone

Historically grounded, inspired by the real dilemmas and pitfalls of city development and management. The tone balances between the optimism of building something lasting and the pragmatic reality that every decision has consequences. Not satirical (unlike Tropico), not dry (unlike a pure simulation) — more akin to a thoughtful historical documentary narrated from the perspective of someone who cares about the city.

Events should feel like plausible historical situations, not fantasy scenarios. The "emergent stories" pillar means that the narrative emerges from the interplay of systems, not from scripted storylines.

Detailed historical writing rules and examples are kept in [content-authoring.md](content-authoring.md). This document retains the governing design intent; the authoring guide applies it to individual cards, events, policies, interactions, and Age pools.

---

## 6. UI / UX

### The Mayor's Desk

The primary interaction surface is a skeuomorphic rendering of the mayor's desk. Every object on the desk maps to a core loop action — no subsidiary systems or decorative distractions.

**Desk objects (mapped to core actions):**

- **City mockup** — a dynamic, animated miniature of the city. Represents city state and active interaction effects in simplified visual form. Clicking opens the full city view with stat overlays and interaction dashboard.
- **Card hand** — the drawn cards for this turn. The player drags cards to play them, spending budget. Unplayed cards remain visible in hand.
- **Stamp / seal** — ends the turn. Triggers event draw and resource recalculation. Shows a summary of played cards before confirming.
- **Bell / telephone / pigeon** — notification mechanism. Lights up when an event fires. Opens the event screen with choices.
- **Calendar** — shows flow of time, age progress, and turn count. Indicates proximity to age boundary.

**Design rule:** if an object on the desk doesn't correspond to a core loop action (draw, play, end turn, view city, respond to event), it should not be on the desk. The desk should feel focused, not cluttered.

**Opened screens (skeuomorphic, contextual):**

- **City view** (from mockup) — detailed, explorable, with stat overlays and interaction effect dashboard.
- **Event screen** (from bell) — presents the event situation, choices, and consequences.
- **Calendar detail** (from calendar) — age timeline, upcoming forced events (if any are known), historical record of past events and decisions.

**Non-desk screens:**

- Main menu / save selection
- Save summary / end-of-save screen (with scoring breakdown)
- Account-level meta-progression / unlocks screen (deprioritized)
- Age transition report (supersession results, interaction changes, new demand) with the policy evolution choice

**TODO:** how does the desk evolve across ages? Candidate: the desk itself changes visually each age (quill → typewriter → computer; oil lamp → electric lamp; pigeon → telephone → smartphone). This reinforces the passage of time without adding mechanical complexity.

**TODO:** accessibility — the skeuomorphic approach can hurt readability. Plan for a clear "data view" toggle and ensure all information surfaced by the city view is also accessible in text/stat form. Font sizes, contrast, and color-blind considerations need attention.

---

## 7. Narrative & Tone

See §5 above. This section reserved for expanded narrative design if needed (event writing guidelines, tone reference material, historical research notes).

---

## 8. Art & Audio Direction

**TODO** — visual references, palette, 2D vs 3D, illustrated cards vs icon-based, etc.

**TODO** — audio style; music should shift per age to reinforce era transitions. Sound design for desk interactions (stamp sound, bell ring, card shuffle).

---

## 9. Technical

**TODO** — engine, platforms, save/load architecture (per-save persistence for city state + account-level persistence for discovered interactions and unlocks), etc.

Key technical considerations flagged by the design:

- Deck injection during play requires a data structure that supports dynamic insertion and reshuffling.
- Interaction threshold checking needs to be efficient since it runs every turn.
- Account-level discovery persistence needs to be separate from save data.
- Age transition involves significant state transformation (supersession, deck regeneration) — this should not have noticeable load time.

---

## 10. Scope & Milestones

**Current authored-systems milestone:**

- All five ages are playable as one continuous save, including automatic supersession and demand activation at every transition.
- 302 cards, including at least 50 cards, 5 actions, 6 demand mitigators, and 3 demand aggravators per age.
- 100 events, including ordinary dilemmas, historical pressures received locally, emergencies, and catastrophes.
- 25 interaction effects and 20 policies spanning economic, political, infrastructural, cultural, welfare, and environmental identities.
- Every demand is supported from its activation through the final age.
- Content validation enforces pool size, reachability, authoring budgets, references, historical windows, and transition integrity.
- The automated verification loop covers the complete five-age chain and compares multiple deterministic player strategies.

**Next milestone:** human playtesting and UI integration. Validate comprehension, decision time, city-history recall, transition reports, scoring identities, and whether the automated difficulty envelope feels fair to real players.

---

## Appendix A: System Interaction Summary

Turn order is canonical in §3: the city acts, then the crisis lands, then the player responds.

```
┌───────────────────────────────────────────────────────┐
│                          TURN FLOW                                │
│                                                                  │
│  PHASE 1 — UPKEEP                                                │
│  ┌──────────┐   ┌───────────┐   ┌───────────────────────┐   │
│  │ budget   │──▶│ population │──▶│ demand growth steps      │   │
│  │ + bill   │   │ count/level│   │ (level + agg − mit)      │   │
│  └──────────┘   └───────────┘   └──────────────┬─────────┘   │
│                                            │ demands over    │
│                                            │ threshold       │
│                                            ▼                 │
│  PHASE 2 — EVENTS                  ┌───────────────┐        │
│  ┌─────────────────────────┐      │  EVENT DECK   │        │
│  │ draw until trigger matches │◀─────│  (grows)      │        │
│  │ (no draw limit)            │      └───────▲───────┘        │
│  └─────────────┬────────────┘              │                │
│                │ player choice                │ inject         │
│                ▼                              │                │
│  PHASE 3 — PLAY                              │                │
│  ┌────────┐   ┌────────┐   ┌─────────────────┐    │                │
│  │ DRAW   │──▶│ PLAY   │──▶│ INTERACTION     │    │                │
│  │ (hand  │   │ cards  │   │ CHECK           │    │                │
│  │ limit) │   └────┬───┘   └─────────────────┘    │                │
│  └────────┘        │ inject                  │                │
│       ▲             └────────────────────────────────────┘                │
│       │             │                                          │
│  ┌────┴────────┐    │                                          │
│  │  MAIN DECK   │◀───┘                                          │
│  │  (grows)     │                                             │
│  └──────────────┘                          ▶ next turn         │
└───────────────────────────────────────────────────────┘
```

**Key feedback loops:**

- Developments → inject cards → more development options → more developments (growth loop)
- Developments → interaction thresholds → policy unlocks → modified development costs (specialization loop)
- Demands satisfied → population grows → population level rises → every demand's growth step rises (pressure loop — success makes the next stretch harder)
- Demands neglected → emergency cards accumulate in the event deck → crises crowd out ordinary events → budget spent reacting instead of building (consequence loop)
- Developments → inject events → event choices → inject more cards into both decks (feedback loop)
- Developments standing at the moment an event fires → protection or extra options → different resolution (preparedness loop)

---

## Appendix B: Example Turn Sequence (Age 1)

**City state entering turn:** Population level 1 (4,180 people) | Budget 10/turn | **Provision 2** (threshold 5) | Hand: 2 cards (limit 5)

**Active developments:** Town Market `[Trade]` (Provision −1), River Docks `[Trade]`, Cobblestone Roads `[Infrastructure]`, Stone Church `[Religious]` `[Cultural]`, Grain Storehouse `[Infrastructure]` (Provision −1)

**Provision growth step:** 1 (level) + 0 (aggravators) − 2 (Market, Storehouse) = −1 → **0**. The demand is at equilibrium and will not move on its own.

**Active interactions:** None yet (2 `[Trade]`, 2 `[Infrastructure]` — below thresholds)

**Active policies:** Tax Levy (+2 Budget/turn)

---

### Phase 1 — Upkeep

Budget refreshes to 10. No pending bill.

Provision is below its threshold, so growth is at full rate for the age. Population count grows +214 (base rate with the turn's small variation) to 4,394. The level-2 boundary is at 5,000, so the level does not change.

Provision takes its growth step of 0 and stays at 2. Nothing is below threshold, so no emergency cards enter the deck.

### Phase 2 — Events

Draw from the event deck. First card: "Spring Flood" — trigger requires a river development, which the city has, so it matches on the first draw. But the city built a **Levee** two ages ago, and the event names it as a protection: the flood's Provision +3 is negated entirely and the event resolves as a near-miss with no options to choose.

*(Had the Levee not been standing, the player would have been choosing which part of the damage to absorb — with the budget they have not yet spent this turn, because Phase 3 has not happened.)*

The turn allows one event only, so no further cards are drawn. For the sake of the example, assume instead that the next card was "Trade Dispute" (trigger: 2+ `[Trade]` developments) and it fires:

*"Foreign merchants accuse local traders of unfair tariffs. Tension rises."*

- Choice A: "Side with local traders" — Provision +2, "Protectionist Backlash" event added to deck.
- Choice B: "Open the markets" — Provision −1, "Foreign Quarter" development card added to main deck.
- Choice C: "Mediate" — costs 3 Budget, no demand change, "Trade Council" policy unlocked.

Player picks C. The 3-budget cost is billed at the start of next turn (event billing — see §3).

### Phase 3 — Play

**Draw:** 3 cards — `Artisan Guild [Trade] [Cultural] (Dev, cost 3)`, `Harbor Expansion [Trade] [Infrastructure] (Dev, cost 5, Provision −1, Security +1)`, `Grain Purchase (Action, cost 1, Provision −2)`. Hand is now 5, at the limit.

**Play:** Harbor Expansion (5) and Grain Purchase (1). Total 6/10 spent. Artisan Guild kept in hand.

Harbor Expansion: Provision 2 → 1, and the growth step drops further to −2 (still floored at 0 when applied). Its **Security +1 does nothing yet** — Security is not an active demand until Age 2 — but the value is recorded and will be counted the moment the demand activates. +2 Budget/turn. Injects maritime cards into the main deck and "Plague Ship" / "Trade Dispute" into the event deck.

Grain Purchase: Provision 1 → 0. One-time only, no change to the growth step. Discarded.

**Interaction check:** 3 `[Trade]` (Market, Docks, Harbor) and 3 `[Infrastructure]` (Roads, Storehouse, Harbor). Two thresholds cross at once:

- **Trade Hub:** +2 Budget/turn. `[Industrial]` developments cost +1. Maritime events enter the event pool.
- **Well-Connected City:** all development costs −1 (min 1).

Both are first discoveries — the player did not see them coming.

**Hand limit:** two cards were played, so the hand is at 3 of 5. No discard needed. Had the player held everything, they would have had to consume a card permanently to end the turn.

---

**End state:** Population level 1 (4,394) | Budget 14/turn, 11 spendable next turn after the 3-budget bill | Provision 0, growth step 0 | Hand 3/5 | Two interaction effects active | New policy option available

**What the player actually bought:** Provision is fully handled and generating no events, but three of the five standing developments are working on it and doing little else. Harbor Expansion has quietly recorded a Security +1 that will be counted the instant Age 2 begins. And because Provision is at 0, growth runs at full rate — which brings the level-2 boundary closer, and with it a +1 to the growth step of every demand the city has.

---

## Appendix C: Open Questions (Running List)

- Balancing: the growth-rate function — exact multipliers per count of demands over threshold (§4.0).
- Balancing: population level boundaries, how many levels exist across a full save, and the hysteresis margin for losing a level.
- Balancing: end-score function — not designed yet (§4.7).
- Balancing: revisit the current demand threshold (5) and catastrophe value (20) after human playtests.
- Balancing: typical printed demand values on cards — is the useful range −1..−3 / +1..+3?
- Balancing: budget growth curve across an age — diminishing returns or hard cap needed?
- Balancing: card draw scaling — should draw bonuses be capped?
- Balancing: interaction threshold numbers for each tag combination
- Balancing: time-per-turn (fixed or variable?) — related decision made: turn count per age is derived from content depth (see §3 One Age), and a slightly dynamic count is acceptable
- Balancing: hand limit starting value (currently 5) and how much rare developments should raise it.
- Design: should the transition report ever let the player act on what it shows, or stay purely informational?
- Design: should some interaction effects be negative-only (liabilities that activate when you over-specialize)?
- Design: should demand meters carry across an age boundary at their current value, or be recalculated purely from standing developments? (Currently: newly activated demands are calculated from developments; existing demands carry their value.)
- Design: how many interaction effects per age? Per full save?
- Design: should the event deck be visible (player can see remaining events) or hidden? Now that emergency cards accumulate visibly through demand neglect, partial visibility may be the honest option.
- Content: which developments grant event protection or extra event options, and how rare protection should be (§4.4).
- Design: how do interaction thresholds change between ages? (e.g., Trade Hub = 3 [Trade] in Age 1, 4 [Trade] in Age 2?)
- Content: full interaction effect table for Age 1
- Content: full card list for Age 1 MVP
- Content: full event list for Age 1 MVP
- Content: policy list for Age 1 MVP
- Production: art style decision
- Production: engine / platform decision
- Production: save architecture design
