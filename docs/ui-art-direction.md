# UI art direction: the instrumented city

![Instrumented city gameplay concept](concepts/ui/gameplay-instrumented-city-v3.png)

These images are composition and interaction targets, not a promise that
generated detail or text can be used as a production asset. The shipped interface must be
assembled from reusable Godot controls, authored icons, card art, and the live
city renderer. Its reproducible generation brief is stored beside it in
[the concept prompt](concepts/ui/gameplay-instrumented-city-v3.prompt.md).

## North star

The city is the primary interaction surface. The player should feel that they
are watching a living place and reading its condition through civic
instruments, not operating a website or arranging objects on a mayor's desk.

The persistent HUD forms a quiet perimeter around a full-bleed isometric city.
Historical character comes from shallow physical construction, disciplined
materials, typography, motion, and sound. It does not come from making each
control a different literal prop.

The test for every persistent element is:

1. Does it answer a question the player asks on most turns?
2. Can the player act on it without opening another screen?
3. Is the city still the largest and most visually active object?

If not, the element belongs in a contextual view, the City Record, or a
tooltip.

## Information hierarchy

### Layer 1: always readable

- Year, turn, and age progress.
- Every active demand: name, value, signed growth, and threshold.
- Population and its expected turn delta.
- Spendable budget and any bill due next turn.
- Cards in hand.
- End Turn and unresolved-business state.

These form one predictable scan path across the top and down to the hand. They
must remain readable over every district, season, and age.

### Layer 2: visible on intent

- A card's complete immediate and standing effects.
- A selected development's name, tags, and civic contribution.
- A demand's sources, modifiers, and catastrophe boundary.
- A city's active policy or interaction associated with the current hover.
- Route, district, and related-building highlights.

Layer 2 appears because the pointer, focus, or controller selection expresses
interest. It should replace or expand a nearby surface, not create a forest of
floating panels.

### Layer 3: opened deliberately

- Chronicle and decision history.
- Active policies and interactions.
- Age timeline and discovered paths.
- Detailed demand ledgers.
- Settings and accessibility data view.

These live in the City Record drawer or dedicated overlays. None need permanent
screen space.

## Gameplay frame at 1600 x 900

| Region | Target | Behaviour |
| --- | ---: | --- |
| City world | 75-80% unobstructed | Full-bleed `SubViewport`; camera input continues unless a modal overlay is open. |
| Top rail | 72 px | One continuous enamel instrument rail, not a row of detached widgets. |
| Alert ribbon | 36-44 px | Appears below the left rail only when a decision or danger is pending. |
| City Record tab | 32-40 px wide | Closed by default; opens a 300-340 px drawer over the right edge. |
| Card hand | 210-230 px idle envelope | Five overlapping cards; hovered/focused card rises to 300-330 px and reveals rules. |
| End Turn | about 190 x 68 px | Lower right, part of the perimeter frame; compact but visually decisive. |

At 1366 x 768, the hand overlaps more aggressively and secondary rail labels
collapse before numerals or signed changes do. Below that size, the accessible
data view is preferable to shrinking rules text.

## Top rail

The rail is a single visual object divided by fine brass rules. Its segments
share baseline, padding, and depth so the result reads as an instrument panel
rather than a set of cards.

### Time

Show `YEAR · TURN`, with age progress as a fine ruled line or a small secondary
caption. Do not repeat the game title during play.

### Demand instrument

Each active demand uses the same compact grammar:

- one monochrome glyph;
- short demand name;
- current value in the largest type;
- signed per-turn growth beside it;
- a thin track showing the next threshold and catastrophe boundary;
- state colour used on the track or small marker, never as a full bright tile.

Card hover previews its consequence in this same instrument. The current value
stays anchored; an ink-coloured ghost value and signed delta appear beside it.
A worsened demand is always previewed as clearly as an improved one.

### Population and budget

Population and budget use the same rail rhythm as demands. Budget must expose a
pending bill without requiring a tooltip. Population should show the level only
as secondary information; the count and expected delta are the decisions.

## Card hand

Cards are the most tactile everyday object and may carry more skeuomorphism
than the rail.

### Idle card

Show only:

- illustration;
- title;
- effective cost;
- development/action category;
- two or three compact demand or tag glyphs;
- disabled or prerequisite state.

Do not render complete rules on all five cards at once. That makes the hand a
row of documents and consumes the city.

### Hover or controller focus

The focused card:

- rises 70-100 px;
- straightens and scales slightly;
- reveals its full immediate effects, standing effects, prerequisites, and
  path-opening note;
- previews budget and every affected demand in the top rail;
- softly outlines one representative city structure if the card has a visual
  counterpart.

Cards on either side shift just enough to prevent important text being covered.
The animation should complete in 100-140 ms and reverse more quickly.

### Play

Playing a development is a civic commitment, not spatial placement. There is no
construction grid and no empty-lot target. Click, drag upward, or controller
confirm all commit the same global action. The card travels toward the city,
its affected rail values roll, and a representative building or district gets
a brief warm reveal.

## City as information

The city renderer is presentation generated from simulation state; it does not
add spatial rules.

### Causal inspection

The city must answer gameplay questions, not merely illustrate that a city
exists. Its two primary inspection paths are reversible:

1. Select a demand to reveal every standing development contributing to that
   demand's growth step.
2. Select a development to reveal every demand, resource, tag, protection, and
   interaction affected by that development.

![Health contribution lens](concepts/ui/gameplay-demand-contribution-lens.png)

In a demand contribution lens:

- unrelated structures lose saturation and contrast;
- each contributing development remains in full colour with a restrained
  outline and one attached nameplate;
- the nameplate shows the development name, demand glyph, and signed printed
  value;
- a fine trace connects each contribution to the selected rail instrument;
- non-development terms remain attached to the rail rather than being
  represented by invented buildings;
- one compact equation reconciles the visible sources:
  `population level + developments + interactions + policies = growth step`.

The label treatment scales with contributor count:

- one to six contributors show their full attached nameplates;
- seven or more show compact signed glyph markers on every contributor, with a
  full nameplate only on the hovered or focused structure;
- the fixed ribbon steps through matching developments in value order;
- City Record exposes the complete reconciled source ledger for scanning,
  keyboard navigation, and accessibility.

No contributor disappears merely because its full name cannot fit in the world.

For example, the selected Health instrument might show
`Level +3 · Developments −2 · Policy +1 = +2 / turn`. Selecting the
`Developments −2` term isolates its individual contributors. This distinction
matters because the meter's current value and its growth step are different
numbers: developments move the meter once when played and also contribute their
printed value to the growth step while standing.

In reverse inspection, selecting a development opens one fixed ribbon above the
hand. The ribbon contains its printed demand values, non-demand effects, tags,
hazard protection, prerequisites or successor, and active interactions. It does
not create a floating panel beside every structure.

All contribution text comes directly from `GameState`, `CardDef`, and
`ModifierPipeline`; the renderer never infers rules from a building's visual
appearance. The accessible data view exposes the same two-way lookup as a
sortable source list.

### Durable visual grammar

- District clusters are arranged deterministically from the save seed.
- Development categories map to broad footprints and landmark silhouettes.
- Built developments add or upgrade representative structures.
- Interactions alter a small number of visible relationships: route traffic,
  smoke, lighting, crowding, greenery, water activity, or civic banners.
- Demand pressure changes ambient state before it changes the whole colour
  grade. Health may reduce pedestrians and add carts near a dispensary;
  provision may thin market traffic; security may change night activity.
- One hover shows one label. One selection may show at most three related
  structures or routes during normal inspection. An explicit contribution lens
  may show every matching development because the player requested that
  comparison.

The city should communicate pattern and consequence, not claim that the player
placed each building.

### Ambient movement budget

A convincing city does not require a full agent simulation. Pool a small cast
of readable actors on authored splines:

- one tram or train;
- two to four carts or later vehicles;
- one or two boats when water is visible;
- eight to sixteen low-detail pedestrians near focal areas;
- chimney smoke, window light, flags, and water motion.

Actors can respond to presentation state, but their paths and timing must remain
deterministic and must never feed back into `res://core/`.

### Inspection

Pointer hover, focus navigation, or a dedicated inspect input chooses the
nearest representative development. Selection uses:

- a thin warm edge or ground contact glow;
- one compact nameplate;
- a short relationship trace to an affected route or building;
- a small contextual action strip only when an action exists.

Persistent pins, district labels, and floating stat cards are not permitted.

## City Record

The closed City Record is a narrow bound volume or enamel tab attached to the
right frame. Opening it dims only the far-right portion of the world and slides
in one continuous 300-340 px surface.

Use four stable sections:

1. active policies;
2. active interactions;
3. recent chronicle entries;
4. demand ledgers and discovered paths.

The drawer may use paper for narrative entries and dark enamel for dense rule
lists, but it should not nest independent bordered widgets. Selection in the
record may highlight corresponding structures in the city.

## Focus overlays

Events, age reports, and game-over states may interrupt the perimeter because
they change the player's immediate task.

- Events arrive as one bright paper or telegram surface over a dimmed city.
- Two or three options are large physical choice strips, with costs and effects
  aligned consistently.
- Age transition is a civic report: supersessions, gained/lost interactions,
  the new demand, and growth changes form one reading sequence.
- The perimeter remains faintly visible behind overlays so the player retains
  context.

Bright paper is reserved for information that requires attention now. The
persistent interface remains dark.

## Visual system

### Three principal materials

1. **Soot enamel:** persistent rail, tabs, contextual strips, and disabled
   surfaces.
2. **Warm paper:** playable cards, events, reports, and narrative records.
3. **Subdued brass:** separators, fasteners, threshold ticks, and focus edges.

Oxblood red is an accent for danger, irreversible commitment, and unresolved
business. Green, amber, and red semantic colours are used in small areas and
always paired with glyph, sign, or pattern.

Nine-slice assets should carry the shallow bevel, inner highlight, wear, and
contact shadow. Normal layout remains Godot `Control` composition; avoid unique
pre-rendered frames for each panel.

### Typography

- Sturdy, compact serif: card titles, event titles, report headings.
- Condensed humanist sans: instruments, numerals, tooltips, rules, and buttons.
- Tabular figures for every changing value.
- Minimum shipped rules text: 16 px at 1600 x 900.
- All-caps is limited to short instrument names and physical control labels.

Decorative historical display faces must not be used for changing numbers or
small rules.

### Icon detail

- Abstract concepts, tags, and demands: flat single-colour glyphs with strong
  silhouettes.
- Concrete buildings and objects: illustrated or rendered thumbnails when the
  surface is large enough.
- Never shrink a detailed painted object into a 16 px rules icon.

## Motion and sound

Physicality should be felt more often than it is seen.

| Interaction | Motion | Sound |
| --- | --- | --- |
| Card hover | lift, straighten, neighbour shift | paper slide |
| Card commit | short forward travel, ink preview resolves | paper snap + restrained civic chime |
| Value change | 450-700 ms counter roll, threshold tick reacts | soft mechanical count |
| City Record | bound-edge slide, no bounce | cover/rail movement |
| Event | paper surface enters, city desaturates slightly | telegram, bell, or age-appropriate signal |
| End Turn | 70-90 ms depression and oxblood stamp flash | weighty stamp/relay impact |

Animations should confirm cause and effect without delaying the next input.
Reduced-motion mode replaces travel and parallax with short fades and immediate
counter updates.

## Evolution through the ages

The layout and information grammar remain fixed. Each age changes a limited
skin layer:

- trim geometry and fastener motif;
- paper stock and printing treatment;
- one accent colour;
- the notification sound/object metaphor;
- city architecture, transport, lighting, and ambient actors.

This makes historical progression visible without producing five incompatible
interfaces or forcing the player to relearn locations.

## Accessibility and input

- Every colour change is paired with a sign, glyph, line style, or text.
- Keyboard/controller focus follows the same order as the visual scan line.
- Card focus produces the same preview as pointer hover.
- The City Record and event choices never require precise world clicking.
- A high-contrast data view presents identical state with restrained plain
  controls; it is an accessibility skin, not a separate rule path.
- Tooltips have a short delay, can be pinned, and never cover the value they
  explain.
- UI scale supports at least 90%, 100%, 115%, and 130%.

## Production kit

The first shippable kit should contain:

- one scalable top rail and one narrow side-tab family;
- one dark contextual strip and one warm paper surface family;
- one card frame with idle, hover, selected, disabled, and discard states;
- demand, tag, hazard, population, budget, time, and action glyphs;
- contribution nameplates, source traces, and the development-detail ribbon;
- normal, hover, pressed, disabled, warning, and commitment button states;
- edge glow, route glow, and district tint materials;
- paper, enamel, and brass audio interactions;
- accessible high-contrast variants.

Build and validate the kit against a worst-case state: four active demands,
negative budget, a pending bill, five long-title cards, a warning, and an open
City Record at 1366 x 768.

## Explicit non-goals

- A literal desk with loose documents or one-off props.
- Placement grids or city tiles implying spatial simulation.
- Permanent building labels or a minimap.
- Detached rounded widgets, bright dashboard cards, or glass panels.
- Large circular gauges.
- Five different HUD layouts for five ages.
- Detailed animated citizens whose behaviour becomes simulation state.

## Reference observations

These references are for hierarchy and interaction principles, not for copying
their art:

- [Anno 1800 UI development](https://www.anno-union.com/devblog-user-interface-2/):
  persistent UI is dark and restrained; brighter surfaces demand attention;
  function and low interaction cost come first.
- [SimCity UI design](https://www.chichanart.com/simcity-2-1): the world itself
  participates in the information system, with neutral chrome preserving
  accent colours for contextual feedback.
- [Against the Storm interface update](https://www.indiedb.com/games/against-the-storm/news/interface-update-is-here):
  reduced ornament improved readability, rendering cost, and the ability to
  extend the interface.
- [Civilization VI art direction](https://www.gamedeveloper.com/art/making-i-civilization-vi-i-both-playable-and-beautiful):
  distant strategy-game objects need distinctive silhouettes and readable
  forms more than architectural photorealism.
- [Anno icon production](https://www.anno-union.com/devblog-our-icon-production-process/):
  icon detail should match the concept and its display size.
- [Frostpunk interface gallery](https://interfaceingame.com/games/frostpunk/):
  a useful tonal reference for high-stakes civic alerts, but too mechanically
  dense to define the everyday HUD.
