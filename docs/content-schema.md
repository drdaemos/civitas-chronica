# Content File Schema

All game content lives under `res://content/` as **one JSON file per definition**, so cards/events/policies can be tuned and balanced by editing files directly. Loaded and cross-validated by `core/content_db.gd`; checked by `tools/validate_content.gd`.

```
content/
  ages/<age_id>.json
  cards/<age_id>/<card_id>.json
  events/<age_id>/<event_id>.json
  interactions/<interaction_id>.json
  policies/<policy_id>.json
```

**IDs** are stable snake_case strings, globally unique per type, and must equal the filename (without `.json`). Saves and the account profile reference content by ID — never rename an ID after release; add a new definition instead.

**Card uniqueness (Terraforming Mars rule):** every card exists **at most once per save**, across all zones (deck ∪ hand ∪ developments ∪ consumed actions). Base decks list each card once; injections silently skip a card that already exists anywhere in the save. The engine also refuses to play a development twice. **Events are NOT unique** — the same event may be re-injected and fire again (recurring floods are a feature).

**Canonical tags:** `trade`, `military`, `religious`, `industrial`, `cultural`, `science`, `infrastructure`.

**Canonical hazard types:** `flood`, `fire`, `disease`, `famine`, `riot`, `raid`, `pollution`, `collapse`. One per event; cancelled by developments listing them in `cancels` (GDD §4.4).

**Hand limit:** base 5, raised only by developments carrying `hand_limit_bonus`. Draw size is not the growth lever (GDD §4.1).

**Resources:** `population_level` (small int), `population_count` (people — display/score only, no rule reads it), `budget`.

**Canonical demands** (GDD §4.0), in activation order — one per age, never deactivating:

| id | Player-facing name | Activates | Meaning |
|---|---|---|---|
| `provision` | Provision | age 1 | reliable food, water, and fuel |
| `security` | Security | age 2 | defence, order, fire protection, and continuity |
| `fairness` | Legitimacy | age 3 | the gap between claimed authority and the authority inhabitants believe government deserves |
| `health` | Health | age 4 | sanitation, safe housing and work, disease and pollution control, medical access, and minimum welfare provision |
| `appeal` | Appeal | age 5 | how strongly people choose to come, live, and stay relative to other places |

Each demand is a non-negative integer starting at 0. `approval` and `migration_appeal` were removed 2026-07 — do not reintroduce them.

## Global rules (`content/rules.json`)

Tuning constants that are not per-age. Single file.

```json
{
  "demand_threshold": 5,
  "demand_catastrophe": 20,
  "population_levels": [0, 5000, 12000, 25000, 45000, 70000, 105000],
  "population_level_hysteresis": 0.05,
  "population_variance": 0.12,
  "growth_by_demands_over_threshold": [1.0, 0.65, 0.25, -0.15, -0.4, -0.65]
}
```

- `population_levels` — lower bound of the population count for each level, index 0 = level 1. Rising curve; each level takes longer than the last.
- `population_level_hysteresis` — fraction below a boundary the count must fall before the level drops, so it does not flip while sitting on a boundary.
- `population_variance` — ± fraction of random variation on the per-turn delta, drawn from the named `population` RNG stream.
- `growth_by_demands_over_threshold` — multiplier on the age's base growth rate, indexed by how many active demands are at or above `demand_threshold`; the last entry applies to that count and above. Any demand at `demand_catastrophe` forces the final (declining) entry regardless.

## Conditions

Used for event triggers, interaction thresholds, and policy unlocks. Composable:

| `type` | Fields | Meaning |
|---|---|---|
| `always` | — | Always true |
| `tag_count` | `tag`, `op`, `value` | Count of developments with tag vs value |
| `resource` | `resource`, `op`, `value` | Resource comparison (`population_level`, `population_count`, `budget`) |
| `interaction_active` | `id` | Interaction effect currently active |
| `policy_active` | `id` | Policy currently active |
| `has_development` | `id` | Card is among developments |
| `demand` | `demand`, `op`, `value` | Current demand meter vs value |
| `demand_growth` | `demand`, `op`, `value` | Demand's per-turn growth step vs value |
| `all_of` / `any_of` | `conditions: []` | Boolean combinators |
| `not` | `condition: {}` | Negation |

`op` ∈ `<`, `<=`, `>`, `>=`, `==`.

```json
{"type": "all_of", "conditions": [
  {"type": "tag_count", "tag": "industrial", "op": ">=", "value": 3},
  {"type": "tag_count", "tag": "trade", "op": ">=", "value": 1}
]}
```

## Effects

**Instant** (applied once — on card play, event option, or interaction activation):

| `type` | Fields | Meaning |
|---|---|---|
| `resource_delta` | `resource`, `amount` | One-time change |
| `demand_delta` | `demand`, `amount` | One-time demand change, clamped at 0. Used by action cards and events — **never changes a growth step** |
| `unlock_policy` | `id` | Policy becomes selectable |
| `inject_main` | `cards: []` | Shuffle card IDs into main deck |
| `inject_events` | `events: []` | Shuffle event IDs into event deck |
| `remove_events` | `events: []` | Remove all copies from event deck |

**Passive** (live while their source — development, interaction, policy — is active):

| `type` | Fields | Meaning |
|---|---|---|
| `income` | `amount` | Budget capacity per turn |
| `demand_modifier` | `demand`, `amount` | Adds to that demand's growth step while active. Used by interactions and policies |
| `demand_modifier_per_tag` | `demand`, `tag`, `amount` | Adds `amount` to the growth step for each standing development with `tag` (e.g. Poor Relief: every `[civic]` counts as another −1 provision) |
| `cost_modifier` | `tag` (optional; omit = all cards), `amount`, `min_cost` (optional) | Card cost change |
| `draw_bonus` | `amount` | Extra cards drawn per turn |
| `pop_growth_mult` | `amount` (float) | Multiplier on the population growth rate |

## Card (`cards/<age>/<id>.json`)

```json
{
  "id": "harbor_expansion",
  "name": "Harbor Expansion",
  "category": "development",            // or "action"
  "cost": 5,
  "tags": ["trade", "infrastructure"],  // developments only
  "demands": {"provision": -1, "security": 1},  // developments only; see below
  "prerequisites": ["river_docks"],     // card IDs, optional
  "superseded_by": {"age4": "harbor_ruins"},  // optional; developments only
  "cancels": ["flood"],                 // optional; hazard types this development negates
  "effects": [
    {"type": "income", "amount": 2}
  ],
  "inject_main": ["merchant_fleet"],    // optional; shown as "opens paths"
  "inject_events": ["plague_ship", "trade_dispute"],
  "flavor": "The city turns its face to the sea.",
  "hand_limit_bonus": 0                 // optional; rare developments raise the hand limit
}
```

Action cards: `category: "action"`, no tags, no `demands` field, only instant effects, discarded on play. To move a demand from an action card use a `demand_delta` effect — one-time only.

### The `demands` field (developments only)

A printed value does **two things with the same number** (GDD §4.0):

1. **On play** — the demand's current meter changes by that amount immediately, clamped at 0.
2. **While the development stands** — the value is added to that demand's per-turn growth step.

Negative values mitigate, positive values aggravate. A development may carry values for demands that are not active yet; they are inert until that demand activates, at which point they are counted retroactively along with every other standing development.

Demolishing a development removes **both** halves of the standing value — tearing down a granary gives back its `provision: -2` growth reduction.

### `superseded_by` (developments only)

Maps an age ID to the card ID that **replaces** this development when that age begins (GDD §4.6). Automatic — the player is not asked. The old development leaves the city (taking both halves of its `demands` values with it) and the successor is placed in its stead with its own tags, demands, effects and injections. Successors may themselves define `superseded_by`, so a structure can pass through several forms across a save.

The successor is a normal card definition and lives in the `cards/<age>/` folder of the age it appears in. It is exempt from the reachability check — it is reached by supersession, not by draw — but it must not appear in any `base_deck`, since it is never drawn or played. The validator rejects supersession cycles.

*Removed 2026-07-26:* `age_variants` and the Preserve/Adapt/Demolish parameters. Age transitions no longer take player input on inherited developments; supersession replaces that system entirely. Demolition remains available mid-age through action cards.

## Event (`events/<age>/<id>.json`)

```json
{
  "id": "trade_dispute",
  "title": "Trade Dispute",
  "text": "Foreign merchants accuse local traders of unfair tariffs.",
  "trigger": {"type": "has_development", "id": "river_docks"},
  "hazard": "famine",                   // optional; cancelled by a development listing it in `cancels`
  "options": [
    {"text": "Side with local traders", "cost": 0,
     "effects": [{"type": "demand_delta", "demand": "provision", "amount": 2}]},
    {"text": "Mediate", "cost": 3,
     "effects": [{"type": "unlock_policy", "id": "trade_council"}]},
    {"text": "Call in the merchant guild", "cost": 0,
     "requires_development": "merchant_guild",   // optional; extra option, only if standing
     "effects": [{"type": "income", "amount": 1}]}
  ]
}
```

Option `cost` is **billed at the start of the next turn** (event billing, GDD §3). Forced events omit `trigger` from matching; they are scheduled in the age file.

Events move demands **one-time only** — an event option may use `demand_delta` but never `demand_modifier`.

**Triggers should be permissive** (GDD §4.4). A trigger exists to stop narratively impossible situations, not to gate content — a flood needs a river, a plague needs nothing. Most events should be able to fire in most cities. There is **no draw limit** on event matching: the engine draws until something matches or the deck is exhausted.

Historical framing, eligibility guidance, and examples are maintained in [content-authoring.md](content-authoring.md). The guide uses the existing trigger, required-development, injection, and age-scheduling fields; it does not introduce additional schema.

### Hazard types and cancellation

An event may declare one `hazard`. If any standing development lists that hazard in its `cancels` array, the event's negative effects do not apply.

Keep `cancels` rare, and usually a single type per development. Full coverage of all eight types must never be affordable.

An option with `requires_development` is hidden unless that card is standing in the city. It is **additional** — the unconditional options remain available — and may be either an opportunity or a softer exit.

### Emergency and catastrophe events

Events that exist to be shuffled in by demand pressure (GDD §4.0) carry two extra fields:

```json
{
  "id": "bread_riot",
  "demand": "provision",
  "severity": "emergency",   // or "catastrophe"
  "trigger": {"type": "demand", "demand": "provision", "op": ">=", "value": 3},
  ...
}
```

During upkeep, each active demand at or above `demand_threshold` shuffles one **random** `emergency` event for that demand into the event deck; a demand at or above `demand_catastrophe` shuffles a `catastrophe` event as well. Duplicates are expected and allowed — the uniqueness rule does not apply to events. These are not listed in `base_events`; the validator requires every demand to have at least one event of each severity available in every age where the demand is active.

Their triggers should re-check the demand, so cards already sitting in the deck from an earlier crisis simply fail to match once the player has recovered.

## Interaction (`interactions/<id>.json`)

```json
{
  "id": "trade_hub",
  "name": "Trade Hub",
  "description": "+2 budget/turn. Industrial developments cost +1.",
  "threshold": {"type": "tag_count", "tag": "trade", "op": ">=", "value": 3},
  "effects": [
    {"type": "income", "amount": 2},
    {"type": "cost_modifier", "tag": "industrial", "amount": 1},
    {"type": "demand_modifier", "demand": "security", "amount": 1},
    {"type": "inject_events", "events": ["smuggling_ring"]}
  ]
}
```

Instant effects fire once on activation; passive effects persist while active. Once activated, an interaction stays active for the save (MVP simplification; deactivation is a post-MVP question).

## Policy (`policies/<id>.json`)

```json
{
  "id": "free_trade",
  "name": "Free Trade",
  "description": "Trade produces more; the world flows in.",
  "unlock": {"type": "interaction_active", "id": "trade_hub"},
  "swap_cost_budget": 3,
  "swap_cost_demands": {"fairness": 3},
  "effects": [
    {"type": "income", "amount": 2},
    {"type": "demand_modifier", "demand": "provision", "amount": -1},
    {"type": "demand_modifier", "demand": "security", "amount": 1}
  ]
}
```

Policies with `"unlock": {"type": "always"}` are available from age start.

## Age (`ages/<id>.json`)

```json
{
  "id": "age1",
  "name": "Charter and Consolidation",
  "year_start": 1500,
  "year_end": 1600,
  "years_per_turn": 10,
  "base_draw": 3,
  "base_budget": 8,
  "policy_slots": 1,
  "next_age": "age2",
  "activates_demand": "provision",
  "population_growth_base": 200,
  "start": {"population_count": 4000},
  "base_deck": ["town_market", "river_docks", "festival_of_saints"],
  "base_events": ["harvest_failure", "spring_flood"],
  "forced_events": [{"event": "religious_reformation", "turn": 15}]
}
```

`activates_demand` names the demand that becomes active when this age begins (GDD §4.0); its starting meter value is calculated from the printed `demands` values of all standing developments. `population_growth_base` is the per-turn population count delta before the demand-balance multiplier and random variance are applied.

Age boundaries and framing per GDD §3: age1 1500–1600 (**Charter and Consolidation**), age2 1600–1750 (**Confession, State, and Exchange**), age3 1750–1850 (**Agrarian and Commercial Transformation**), age4 1850–1950 (**Urbanization and Civic Provision**), age5 1950–2030/present (**Mobility, Services, and Competition**).

`base_deck` is a **flat array of unique card IDs** (no copies — uniqueness rule above; the validator rejects duplicates). `next_age` names the following age's ID; omit or `""` on the final age — completing it wins the save. `start` resource values apply only to the save's first age; later ages inherit the running city and only `base_budget`, `policy_slots`, and deck pools take effect.

Cards reachable only via injection do **not** appear in `base_deck`; the validator confirms every card is reachable (base deck, injection, or event effect) and every referenced ID exists — per age: a card in `cards/age2/` must be reachable within age 2's pools.

Additional demand-related validator checks:
- every `demands` key and every `demand` field names a canonical demand
- every age names an `activates_demand`, and no demand is activated twice
- every demand has at least one `emergency` and one `catastrophe` event available in every age from its activation onward
- `population_levels` is strictly increasing
- `superseded_by` targets exist, contain no cycles, and never appear in a `base_deck`
- every `cancels` entry and every event `hazard` names a canonical hazard type
- `requires_development` references an existing card ID
