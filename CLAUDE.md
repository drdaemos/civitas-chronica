# Civitas Chronica

Card-based city-builder with rogue-lite elements, built on Godot 4.7 (GDScript).

- Game design: [docs/game-design.md](docs/game-design.md)
- Technical design: [docs/technical-design.md](docs/technical-design.md)
- Content file schema: [docs/content-schema.md](docs/content-schema.md)

## Project constitution

These rules are binding for all work on this repo (human or agent):

1. **Verify currency of solutions.** Before adopting or upgrading any engine version, addon, library, or external solution, confirm its latest stable release and Godot 4.7 compatibility from its release page or a web search — never from memory. Record the version and check date where the dependency is introduced.
2. **Typed GDScript only.** Every variable, parameter, and return value is explicitly typed. `untyped_declaration` warnings are errors (enforced in project.godot).
3. **`res://core/` is headless.** Nothing under `core/` may reference `Node`, scenes, autoloads, or anything requiring a scene tree. Pure logic, constructible directly in tests. UI talks to the sim via `game/` autoloads; the sim never reaches upward.
4. **Content is data.** Every card, event, interaction, policy, and age lives as its own human-readable JSON file under `res://content/` — one file per definition, stable string IDs, no content defined in code. (Tests may build in-code fixtures.)
5. **Determinism.** All randomness flows through `RngService` named streams. Never call `randi()`/`randf()`/`shuffle()` directly anywhere else.
6. **Verify headless before calling anything done.** Any sim or content change must pass the test suite and content validator via the console binary (commands below).

## Environment

- Godot 4.7 console binary (Windows):
  `E:\Apps\Godot\Godot_v4.7-stable_win64_console.exe`
- Run tests: `& "<godot_console>" --headless --path . --script res://tools/run_tests.gd`
- Validate content: `& "<godot_console>" --headless --path . --script res://tools/validate_content.gd`
- Balance simulation: `& "<godot_console>" --headless --path . --script res://tools/simulate.gd`

## Architecture map

```
core/state/    GameState, DevelopmentState, RngService   (pure data + RNG)
core/defs/     CardDef, EventDef, InteractionDef,
               PolicyDef, AgeDef, ConditionDef, EffectDef (typed views over JSON)
core/          ContentDB (loads/validates res://content)
core/engine/   TurnEngine, DeckManager, ModifierPipeline,
               InteractionEngine, EventMatcher, Scoring, GameSetup
content/       ages/ cards/ events/ interactions/ policies/  (JSON, one file per def)
game/          autoloads: GameController, SaveManager, ProfileManager, SignalBus
ui/            data_view (MVP UI), later: desk, city_view
tools/         run_tests.gd, validate_content.gd, simulate.gd (headless)
tests/         test scripts run by tools/run_tests.gd
```

GDScript style: tabs for indentation, `class_name` on every core class, snake_case files.
