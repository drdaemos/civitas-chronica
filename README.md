# Civitas Chronica

A card-based city-builder with rogue-lite elements. You are the ephemeral mayor of a single
city across centuries — enacting policies and playing development cards, never placing
buildings. The city's character emerges from the aggregate of your decisions.

Built with Godot 4.7 (typed GDScript).

- [Game design](docs/game-design.md) · [Content authoring](docs/content-authoring.md) · [Technical design](docs/technical-design.md) · [Content schema](docs/content-schema.md)
- Project rules for contributors and agents: [CLAUDE.md](CLAUDE.md)

## Running

Open the project in Godot 4.7 and press Play, or headless from the repo root:

```powershell
$godot = "<path-to>\Godot_v4.7-stable_win64_console.exe"

& $godot --path .                                                # run the game
& $godot --headless --path . --script res://tools/check_compile.gd    # compile check
& $godot --headless --path . --script res://tools/validate_content.gd # content validation
& $godot --headless --path . --script res://tools/run_tests.gd        # test suite
& $godot --headless --path . --script res://tools/simulate.gd -- --runs=50 --bot=random  # balance sim
```

## Layout

```
core/      pure headless simulation (state, defs, engines) — no Node dependencies
content/   all cards/events/interactions/policies/ages as one JSON file each
game/      autoloads gluing sim to UI (controller, saves, profile)
ui/        presentation (MVP: data view)
tools/     headless scripts (tests, validation, balance simulation)
tests/     test suites run by tools/run_tests.gd
```

Balancing happens by editing the JSON files under `content/` and re-running the
validator + simulator — no code changes required.
