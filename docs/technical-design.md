# Civitas Chronica — Technical Design Document

> **Status:** Draft v2 — companion to [game-design.md](game-design.md). Updated 2026-07-26 for the demand system and the phased turn order. Covers architecture, technology choices, and reuse strategy. Sections map to GDD mechanics by § reference.

---

## 1. Guiding Technical Principles

Derived from the game's actual shape — a turn-based, single-player, systems-driven card game with no real-time pressure, no networking, no physics, and modest content scale (hundreds of cards, dozens of events/interactions per age):

1. **The simulation is a pure, headless library.** All game rules (turn resolution, decks, interactions, events, scoring) live in plain script classes with zero dependency on Nodes, scenes, or rendering. The UI is a replaceable skin over it. This is the single most important decision in this document — it makes the game testable, balanceable by bot simulation, and immune to UI rewrites.
2. **Determinism by default.** Same seed + same player inputs = same game. All randomness flows through named, seeded RNG streams stored in the save. Required for reproducing bugs, testing, and (later, for free) seeded challenge runs.
3. **Content is data, not code.** Cards, events, interactions, policies, and age definitions are data files authored in the Godot inspector. Adding a card must never require touching engine code. The GDD's content lists (Appendix C) become data-entry work, not programming.
4. **Scale honesty.** GDD §9 worries about interaction-check efficiency and deck insertion performance. At this game's scale (a save holds perhaps 100–200 developments, decks of under 100 cards, one check per turn) every sim operation is trivially cheap. No performance architecture is needed; correctness and authoring ergonomics are the real problems. The one genuine §9 concern — age transitions with no load time — is met automatically because the transition is pure in-memory data transformation.

---

## 2. Engine, Language & Project Baseline

| Decision | Choice | Rationale |
|---|---|---|
| Engine | **Godot 4.x** (project currently on 4.6; 4.7 stable released 2026-07) | Already chosen; ideal fit for 2D UI-heavy games. Track the latest stable minor; upgrades within 4.x are low-risk for a project this young. |
| Language | **GDScript with static typing everywhere** (`--warnings-as-errors` for untyped code) | Fastest iteration for a small team; best addon compatibility; the sim is far too small to need C# performance. Typed GDScript catches most of what C# would. C# remains a fallback if the balance simulator (§8) ever needs 100× throughput — unlikely. |
| Renderer | **Forward Plus (keep current)** | The envisioned city view is a 3D-ish isometric world under a 2D UI. On a PC-only target, Forward+ gives the better lighting/GI toolbox for a stylized 3D city at no practical cost. (If the city view ever becomes pure 2D illustration, downgrade to Mobile then — a one-line change.) |
| Project cleanup | Remove `3d/physics_engine="Jolt Physics"` and the `d3d12` driver override from [project.godot](../project.godot) | Leftovers from the default scaffold; no physics in this game, and the default Vulkan driver is the better-tested path. |
| Platform | PC (Windows/Linux/macOS export templates) | Per GDD. Nothing in this design blocks a later Steam Deck / mobile port, but don't spend effort on it. |

### Engine choice — alternatives considered

Godot was picked for simplicity; it was re-examined against the criteria that actually matter for this project — fit for a UI-heavy turn-based game, a 3D-ish isometric city view under a 2D UI, desktop shipping, and **agent-friendliness** (how well AI-assisted development works: everything-as-text, headless verifiability, LLM fluency with the stack, fast feedback loops).

| Option | Verdict | Reasoning |
|---|---|---|
| **Godot 4** | **Keep** | Scenes, resources, and scripts are all diffable text — agents can read and write the entire project. `--headless` runs tests, tools, and the balance simulator from the CLI. "2D UI over a 3D world" is a first-class pattern (a `SubViewport` with a 3D camera embedded in the Control-based UI), which is exactly the envisioned presentation. Weakest point: GDScript has less LLM training data than TypeScript/C#, and models occasionally emit Godot-3-era idioms — mitigated by typed GDScript, tests, and CI catching drift. |
| TypeScript + Three.js/PixiJS (Electron/Tauri for desktop) | Rejected, honorable mention | The strongest *pure agentic* option: TS is the most LLM-fluent ecosystem, HTML/CSS is superb for card UI, and Playwright gives agents screenshot-verified UI testing. Rejected because you'd hand-build engine services Godot provides free (input, audio, asset pipeline, GLTF/3D scene tooling, packaging), the isometric 3D city is much more work without an editor, and Electron+Steam packaging adds a permanent tax. Viable, but a worse trade for a solo/small project with a 3D view. |
| Unity (C#) | Rejected | Best LLM fluency for game dev and a huge asset store, but scene/prefab files are GUID-laden YAML that agents edit poorly, much workflow is editor-locked, domain reloads make feedback slow, and licensing remains a background risk. Its advantages (3D at scale, mobile, asset store) target problems this game doesn't have. |
| Unreal | Rejected | Blueprints are binary (agent-opaque), C++ iteration is slow, and the engine's strengths are irrelevant to a turn-based card game. |
| MonoGame / Bevy / Love2D | Rejected | Full-code and agent-friendly, but no editor and weak-to-no 3D+UI tooling — everything Godot gives for the isometric view would be hand-rolled. |

The deciding argument: **this codebase's agent-friendliness comes more from its own architecture than from the engine** — a pure headless sim core (§4), text-resource content (§5), CLI validation and simulation (§8) mean an agent can implement and *verify* most changes without ever opening an editor. Godot supports that architecture fully; switching stacks would buy marginal language fluency at the cost of rebuilding engine services.

---

## 3. Architecture Overview

Three strictly layered parts. Dependencies point downward only.

```
┌────────────────────────────────────────────────────────────┐
│  PRESENTATION  res://ui/                                    │
│  Instrumented city, card hand, City Record, event screen,   │
│  age-transition screen. Listens to sim signals;             │
│  calls sim API. Contains no game rules.                     │
├────────────────────────────────────────────────────────────┤
│  APPLICATION   res://game/  (autoloads)                     │
│  GameController (owns the running sim), SaveManager,        │
│  ProfileManager (account-level discoveries), Settings,      │
│  SignalBus. Glue only.                                      │
├────────────────────────────────────────────────────────────┤
│  SIMULATION    res://core/   (pure GDScript, no Nodes)      │
│  GameState · TurnEngine · DeckManager · InteractionEngine   │
│  EventMatcher · ModifierPipeline · AgeTransition · Scoring  │
│  Reads content definitions; emits domain events.            │
├────────────────────────────────────────────────────────────┤
│  CONTENT       res://content/  (.tres custom Resources)     │
│  CardDef · EventDef · InteractionDef · PolicyDef · AgeDef   │
│  Pure data. Validated by tooling (§7).                      │
└────────────────────────────────────────────────────────────┘
```

**Communication contract:** UI → sim through explicit method calls (`play_card(id)`, `resolve_event(option)`, `end_turn()`), each returning a typed result. Sim → UI through domain events (`threshold_crossed`, `event_fired`, `resources_recalculated`, `age_ended`) relayed over a `SignalBus` autoload. The sim never reaches upward.

---

## 4. Simulation Core (`res://core/`)

All classes here extend `RefCounted` (or are plain `Resource` data holders) — instantiable without a scene tree, which is what makes headless testing and the balance simulator possible.

### 4.1 GameState

One plain data object holding the entire save-relevant state: resources (population level, population count, budget capacity), **demand meters** (one non-negative int per active demand, GDD §4.0), the set of active demands, developments in play (with their *current-age* tags and demand values — reinterpretation mutates both), active policies, active interaction effects, pending event bill (GDD §3 event billing), main deck, event deck, hand, turn/age counters, lose-condition counters (consecutive debt turns), per-save discovery flags, and the RNG stream states.

*Amended 2026-07-26:* `approval` and `migration_appeal` are removed. Approval's role is taken by the `fairness` demand from age 3 (**Legitimacy** in the player-facing design); the old migration-growth dial is replaced by the `appeal` demand plus demand-balance-driven population growth. Population is stored as both level and count; **only the level is read by any rule** — the count is display and score data. No logic beyond invariant checks. Serializes to/from a `Dictionary` (§6).

### 4.2 TurnEngine — the phase state machine

Implements GDD §3 turn structure literally as an explicit state machine:

```
UPKEEP  (apply event bill, refresh budget, grow population count,
         recompute population level, apply demand growth steps,
         shuffle emergency/catastrophe cards, advance time)
  → EVENT_DRAW → [EVENT_CHOICE (blocks on player)]
  → DRAW → PLAY (repeatable: play_card × N)
  → INTERACTION_CHECK → DECK_INJECTION
  → UPKEEP …
```

*Reordered 2026-07-26 to match GDD §3.* The city acts before the player does: growth and demand pressure resolve first, the resulting crisis is drawn second, and the player commits budget last, having seen both. Nothing the player cannot see happens after they spend.

Each phase is a pure function `(GameState, input) → (GameState changes, [DomainEvent])`. The engine pauses in `PLAY` and `EVENT_CHOICE` awaiting player input; everything else runs to completion instantly. The UI animates by consuming the emitted `DomainEvent` list at its own pace — the sim never waits on animation. This cleanly enforces the GDD pillar "the player sets the pace."

The GDD rule *"the whole state before the start of the turn is persistent"* becomes an implementation rule: **SaveManager snapshots GameState exactly once, at the start of UPKEEP.** Mid-turn quits replay from that snapshot; no mid-phase serialization is ever needed.

### 4.3 DeckManager

Ordered card-ID arrays with seeded shuffling. Supports the GDD's dynamic **injection**: `inject(cards, deck, placement)` where placement is a weighting policy (uniform, or top-N-biased if the design later wants opened paths to surface sooner — the mechanism costs nothing to have). No discard-pile cycling exists, matching the GDD.

Hand is a plain unordered set with a **capacity** (base 5, raised by rare developments). The turn cannot be ended over capacity: `end_turn()` returns a `DiscardRequired` result listing the overflow count rather than advancing the phase, and the UI blocks on it exactly as it blocks on `EVENT_CHOICE`. Discarded cards go to the uniqueness ledger and never return.

### 4.4 Conditions & Effects — structured data, not a string DSL

Event triggers ("Population > 800 AND no [Infrastructure] interaction active"), interaction thresholds ("14+ [Industrial] + 10+ [Trade]"), and card/policy effects are all expressed as **composable Resource types**, not parsed strings:

- `Condition` (abstract) → `ResourceCompare`, `TagCount`, `DemandCompare`, `DemandGrowthCompare`, `InteractionActive`, `PolicyActive`, `AgeIs`, `AllOf`, `AnyOf`, `Not`
- `Effect` (abstract) → `ResourceDelta`, `DemandDelta` (one-time), `DemandModifier` / `DemandModifierPerTag` (passive, feeds the growth step), `CostModifier`, `Income`, `InjectCards`, `InjectEvents`, `UnlockPolicy`, `AddTag` / `RemoveTag`, `SetFlag`

Development cards do not express their demand contribution as an `Effect`. They carry a `demands` map whose values apply twice — once immediately on play (clamped at 0) and permanently to the growth step while the development stands (GDD §4.0). Keeping this off the `Effect` hierarchy matters: the same number has to be reversible on demolition and re-readable at age activation, which a fire-and-forget effect cannot do.

Rationale: inspector-friendly authoring with dropdowns instead of syntax, impossible-to-typo references (they're object links), and machine-checkable by the validator (§7). Godot's built-in `Expression` class is the escape hatch if authoring ever demands free-form formulas — deliberately not used at the start.

The same two vocabularies serve cards, events, interactions, and policies. One evaluator, one applier, no per-system special cases.

### 4.5 ModifierPipeline

Interactions and policies both modify rules ("[Industrial] costs +1", "all developments −1, min 1", "[Trade] produce +1 budget"). Rather than scattering these through the code, one pipeline collects all active modifiers and answers queries: `cost_of(card)`, `income_per_turn()`, `event_severity(event)`, and **`demand_growth_step(demand)`** — `population_level + sum(standing demand values) + modifiers`, floored at 0. Stacking order is fixed and documented: **additive modifiers first, then multiplicative, then floors/caps** (`min 1` last). This makes GDD Appendix B's arithmetic reproducible and gives balance work a single place to reason about.

### 4.6 InteractionEngine, EventMatcher, AgeTransition, Scoring

- **InteractionEngine** — after each play and age transition, evaluates all `InteractionDef` conditions against GameState (a few dozen boolean checks; trivial). Emits `threshold_crossed` with first-discovery flag (checks ProfileManager).
- **EventMatcher** — draws until a trigger matches, with **no draw limit** (amended 2026-07-26); unmatched cards return to deck bottom, and a full pass with no match means no event this turn. Because triggers are deliberately permissive (GDD §4.4), the common case is a match within a few draws; the unbounded loop is still bounded by deck size and is trivially cheap at this scale. Also resolves **hazard cancellation** and **conditional options**. Cancellation is type-based: an event declares one `hazard` from a fixed vocabulary (`flood`, `fire`, `disease`, `famine`, `riot`, `raid`, `pollution`, `collapse`), developments carry a `cancels` list, and if any standing development cancels that hazard the event's negative effects are dropped before application. Conditional options are card-ID references checked against standing developments at resolution time. Forced events are `EventDef`s with an `AgeTime` condition and a `forced` flag that bypasses the draw.
- **DemandEngine** — owns the demand meters. During UPKEEP it applies each active demand's growth step, then shuffles one emergency event per demand at or above threshold and one catastrophe event per demand at or above the catastrophe value. At age transition it activates the age's new demand by summing the printed `demands` values of every standing development. Thresholds and catastrophe values come from `content/rules.json`.
- **PopulationEngine** — grows the population *count* each turn by `age.population_growth_base × growth_multiplier(demands over threshold) × (1 ± variance)` from the named `population` RNG stream, then recomputes the population *level* from the boundary table with a hysteresis margin so the level does not oscillate. Level changes are the only population output any other system reads.
- **AgeTransition** — a pure transformation implementing GDD §4.8. **Amended 2026-07-26:** Preserve/Adapt/Demolish is removed. The transition takes no player input except policy evolution, so it is a single function `(GameState, age) → (GameState, TransitionReport)`: discard hand → apply **supersession** (each development whose `CardDef.superseded_by` names a successor for this age is swapped for it) → recalc interactions under new-age tables → activate the new demand by summing standing `demands` values → regenerate both decks → adjust resources. The `TransitionReport` is the data the UI renders: supersessions applied, interactions gained/lost, new demand and its starting value, resulting growth steps. Runs in one frame.
- **Scoring** — pure function `GameState → ScoreBreakdown` over the GDD §4.7 axes. Computable at any time (useful for a live "trajectory" display later, and for the balance simulator's fitness function).

### 4.7 Determinism

`RngService` owns named `RandomNumberGenerator` streams — `deck`, `events`, `population` (per-turn growth variance and emergency-event selection) — seeded from a save-level master seed and serialized (state included) with the save. Player input is the only other source of variation. A recorded input log + seed replays a full save; this is the debugging story for "my city died and I don't know why" reports.

---

## 5. Content Pipeline (`res://content/`)

**Format: one JSON file per definition** (amended from the original `.tres` plan, 2026-07): balancing is expected to happen by hand-editing and diffing content files, and plain JSON with string-ID references is far friendlier for that (and for agent-driven editing) than `.tres` sub-resource syntax. The cost — no inspector dropdowns, references checked by the validator instead of the loader — is covered by `tools/validate_content.gd` running in CI and before every headless test run. Full schema: [content-schema.md](content-schema.md). Historical framing and writing guidance: [content-authoring.md](content-authoring.md).

Definition types (all data-only Resources):

| Type | Key fields (per GDD) |
|---|---|
| `CardDef` | id, name, category (Development/Action), budget_cost, ages_available, tags[], **demands{}** (Development only), **cancels[] (hazard types)**, **hand_limit_bonus**, prerequisites[] (CardDef refs), effects[], injections {main_deck: CardDef[], event_deck: EventDef[]}, opens_paths flag, **superseded_by{age → CardDef ref}** (optional, GDD §4.6) |
| `EventDef` | id, trigger: Condition, forced flag, weight, **hazard**, **demand + severity** (emergency/catastrophe events only), options[] {text, budget_cost (billed next turn), **requires_development (optional CardDef ref)**, effects[], injections} |
| `InteractionDef` | id, name, description, threshold: Condition, consequences: Effect[] |
| `PolicyDef` | id, ages, unlock: Condition, rule_modifiers: Effect[], swap_cost (budget + demand penalty), evolution_branches: PolicyDef[] |
| `AgeDef` | id, year range, turn_count, **activates_demand**, **population_growth_base**, base card pool, base event pool, forced-event schedule, interaction table overrides, deck-generation rules |
| `RulesDef` | single `content/rules.json`: demand threshold and catastrophe values, population level boundaries, hysteresis, variance, growth multiplier table |

Content IDs are stable strings (`card_town_market`), never array indices — saves and the account profile reference content by ID and must survive content reordering between game versions.

**Authoring aids (build when data entry begins, not before):** a `tools/validate_content.gd` headless script that checks every definition — dangling refs, unreachable cards (nothing injects them and they're not in a base pool), prerequisite cycles, events whose triggers can never fire in their age. Runs locally and in CI. This validator is cheap and will catch the majority of content bugs before anyone plays a turn.

The validator also enforces authored-pool budgets: at least 50 cards per Age, 5 action cards, 10 ordinary events, 2 forced historical pressures, bounded base-deck size, and both mitigating and aggravating developments for the Age's newly activated demand. `tools/verify.ps1` is the canonical full loop: content validation, all headless tests, then a deterministic multi-bot balance matrix over the complete five-Age chain. The matrix checks that demand-aware play usually survives while random, reckless, and passive play do not.

---

## 6. Persistence

Two fully separate stores, per GDD §9:

**Per-save state** — `user://saves/<slot>/save.json`. A versioned JSON document produced by `GameState.to_dict()`: `{schema_version, master_seed, rng_states, state:{...}}`. Written at the start of UPKEEP only (§4.2). JSON over serialized Resources deliberately: no script-injection risk from tampered files, human-inspectable for debugging, and schema migration is explicit — a `migrations/` chain of `Dictionary → Dictionary` functions keyed by version, applied on load. Content is referenced by ID only; a save never embeds card data.

**Account profile** — `user://profile.json`. The unified learning contract's memory (GDD §4.2): sets of discovered interaction IDs, event-trigger IDs, and card-injection IDs, plus meta-unlocks (deprioritized) and settings. Written on every first-discovery event, independent of save writes — a lost save still pays out discoveries, exactly as the GDD promises.

Both writes are atomic (write temp file, then rename). Save files are small (tens of KB); no compression or async needed.

---

## 7. Presentation Layer (`res://ui/`)

- **Instrumented city scene** (GDD §6) — one full-bleed `SubViewport`
  containing the 3D city renderer under a Control-based perimeter HUD. The top
  rail, hand, City Record tab, alert ribbon, and End Turn control bind to sim
  queries and commands; decorative presentation never becomes simulation state.
- **Card hand** — reuse **[chun92/card-framework](https://github.com/chun92/card-framework)** (MIT, Godot 4.x, actively maintained through 2026) for drag-and-drop, hand fanning, and pile containers. It's UI-only, which fits perfectly: our rules stay in `core/`, the addon just moves sprites. If its behavior fights the skeuomorphic desk aesthetic, hand-rolling a hand container is a contained ~2-week fallback, and the sim doesn't change either way.
- **City view** — a **3D isometric world under the 2D UI**. A `SubViewport`
  contains an orthographic 3D city scene and fills the gameplay frame. Since
  the simulation is non-spatial (GDD pillar: no placement), the city is
  *generated presentation*: developments and active interactions map to
  representative structures, district clusters, routes, and ambient state
  placed by a deterministic layout algorithm seeded per save. The same city
  can be rendered at lower detail for menus or reports, but there is no separate
  desk mockup. Everything stays behind
  `CityViewRenderer.update(state, presentation_context)`; the MVP can ship a
  simple procedural renderer and replace its assets without changing the sim or
  HUD.
- **Demand rows** — the primary always-visible readout: one row per active demand showing current value, growth step, and threshold, plus population level and the count's per-turn delta. Card hover must preview the delta on **every** demand row including worsened ones (GDD §4.0), so `ModifierPipeline` needs a dry-run `preview_play(card) → demand deltas` query.
- **Data view toggle** (GDD accessibility TODO) — cheap by construction: every UI element binds to sim data, so a plain-Control stats screen is just a second skin over the same signals. Build it *first*, in fact — it doubles as the developer debug UI.
- **Animations** — built-in `Tween`; sim domain events queue into an animation player that the user can click through (sets the pace, never blocks the sim).
- **Localization** — Godot's built-in translation system from day one: all content `name`/`text` fields are translation keys. Retrofitting i18n into hundreds of authored cards later is miserable; starting with it costs nothing.

---

## 8. Testing & Balance Tooling

This game's risk is systemic balance, not code volume — the tooling reflects that.

- **Unit tests: [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4)** (v5, actively maintained, GDScript + C#, CI-friendly; preferred over GUT for cleaner headless/CI integration). Because `core/` is Node-free, tests construct GameStates directly and assert on turn resolution — no scene loading.
  *MVP amendment (2026-07):* the MVP ships with a ~60-line custom runner (`tools/run_tests.gd` + `tests/test_context.gd`) instead — zero addon dependency, same headless CLI workflow. Migrate to gdUnit4 when the suite outgrows it (parameterized tests, mocking, per-test isolation); re-verify the latest gdUnit4 release at that point per constitution rule 1.
- **Property tests for the GDD's hard rules.** The design intent statements are executable: *no lose condition may resolve in a single turn* (assert every lose path requires ≥2 turns from healthy state), *event bills can push budget negative but nothing else can end the game that turn*, *age transition preserves population exactly*, *demand meters never go below 0*, *a demand growth step of 0 leaves the meter unchanged indefinitely*, *demolishing a development exactly reverses its standing demand contribution*, and *no rule reads the population count* (only the level). These run over thousands of randomized states.
- **The balance simulator** — `tools/simulate.gd` plays complete five-age saves with deterministic random, greedy, steward, reckless, and turtle strategies. Its `--suite` mode reports win rate, final-age reach, transitions, turns, score, and interactions, then enforces a difficulty envelope: competent stewardship should usually win, random play should rarely win, and reckless or inactive play should fail. Use multiple seed bands during tuning; every anomalous run remains reproducible.
- **CI** — GitHub Actions using the standard godot-ci Docker images: content validation (§5) + gdUnit4 suite on every push; export builds on tags.

---

## 9. Reuse Summary

| Need | Use | Notes |
|---|---|---|
| Unit testing | [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | Active (v5, 2026); headless CI support |
| Card drag/drop & hand UI | [chun92/card-framework](https://github.com/chun92/card-framework) | MIT, Godot 4.x, maintained; UI-only — no rules coupling |
| Card game *rules* engine | **None — build `core/` ourselves** | [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework) was evaluated and rejected: it's a full rules-enforcement engine whose model (scripted per-card behaviors, board zones) doesn't match this game's sim (thresholds, injection, reinterpretation). Our core loop *is* the game; owning it is the point. |
| CI/exports | godot-ci Docker images + GitHub Actions | De-facto standard for headless Godot CI |
| Placeholder art | Kenney asset packs (CC0) | Cards, icons, desk props for the vertical slice |
| Tweening, i18n, expressions, save I/O | Godot built-ins (`Tween`, `TranslationServer`, `Expression`, `FileAccess`/`JSON`) | No addons needed |

General policy: reuse at the **UI and tooling** layers, never inside `core/`. The simulation is small, bespoke, and the product's identity — dependencies there cost more than they save.

---

## 10. Directory Layout

```
res://
  core/                  # pure simulation — no Node, no preload of scenes
    state/               #   GameState, RngService
    engine/              #   TurnEngine, DeckManager, InteractionEngine,
    │                    #   EventMatcher, ModifierPipeline, AgeTransition, Scoring
    defs/                #   CardDef, EventDef, ... (Resource scripts)
    conditions/          #   Condition & Effect type hierarchy
  content/
    ages/  cards/age1/  events/age1/  interactions/  policies/
  game/                  # autoloads: GameController, SaveManager,
                         #   ProfileManager, SignalBus, Settings
  ui/
    desk/  city_view/  event_screen/  transition/  data_view/  menu/
  tools/                 # validate_content.gd, simulate.gd (headless)
  tests/                 # gdUnit4 suites, mirrors core/ structure
  addons/                # card-framework, gdUnit4
```

---

## 11. Build Order (maps to GDD §10)

A walking skeleton, sim-first — each step is playable/testable before the next:

1. **Core state + turn engine, headless** — GameState, TurnEngine, DeckManager, ModifierPipeline, DemandEngine, PopulationEngine with ~10 hand-written stub cards defined in code. Verified entirely by gdUnit4 tests reproducing GDD Appendix B turn-by-turn.
2. **Content pipeline** — Def resources + validator; port stub cards to `.tres`; add interactions and events. EventMatcher + InteractionEngine complete the turn loop.
3. **Balance simulator** — bots + CSV output. From here on, every content change gets measured.
4. **Data-view UI** — the plain-stats skin as the first playable human interface (doubles as debug UI forever).
5. **Save/profile persistence** — snapshot-at-turn-start, discovery recording, schema v1.
6. **Desk UI** — skeuomorphic scene over the same signals; card-framework integration; event screen; lose/score screens.
7. **Full authored content chain** per GDD §10, tuned through deterministic multi-strategy balance suites and human playtesting.

The five-age transition chain is covered headlessly. The remaining transition work is presentation: policy-evolution choices and a clear report screen showing supersessions, interaction changes, demand activation, and the rebuilt pools.

---

## 12. Open Technical Questions

- Art pipeline for the isometric city awaits GDD §8 (art direction): modeled low-poly (GLTF from Blender/asset packs) vs pre-rendered sprites on billboards. Decision isolated behind `CityViewRenderer`.
- City layout algorithm (how developments map to visual districts/props) — presentation-only, seeded, but needs design once art direction lands.
- Steam integration (achievements mapping to meta-progression unlocks) — defer; keep ProfileManager as the single integration point.
- Godot 4.6 → 4.7 upgrade timing — do it before serious content work starts (trivial now, annoying later).
