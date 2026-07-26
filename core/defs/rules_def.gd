class_name RulesDef
extends RefCounted

## Global tuning constants, loaded from `content/rules.json` (content-schema.md).
## Everything the demand and population systems need to be re-balanced without
## touching code lives here, including the set of demands itself.

var demands: Array[DemandDef] = []          # activation order
var demand_threshold: int = 3               # emergency cards from here up
var demand_catastrophe: int = 8             # catastrophe cards from here up
var population_levels: Array[int] = [0]     # lower bound of each level; index 0 = level 1
var population_level_hysteresis: float = 0.05
var population_variance: float = 0.15
## Multiplier on the age's base growth rate, indexed by how many active demands
## are at or above threshold; the last entry applies to that count and above.
var growth_by_demands_over_threshold: Array[float] = [1.0]

var _by_id: Dictionary = {}  # demand id -> DemandDef


static func from_dict(d: Dictionary) -> RulesDef:
	var rules := RulesDef.new()
	for demand_dict: Variant in d.get("demands", []):
		var demand: DemandDef = DemandDef.from_dict(demand_dict)
		rules.demands.append(demand)
		rules._by_id[demand.id] = demand
	rules.demand_threshold = int(d.get("demand_threshold", 3))
	rules.demand_catastrophe = int(d.get("demand_catastrophe", 8))
	if d.has("population_levels"):
		rules.population_levels.assign(d.get("population_levels"))
	rules.population_level_hysteresis = float(d.get("population_level_hysteresis", 0.05))
	rules.population_variance = float(d.get("population_variance", 0.15))
	if d.has("growth_by_demands_over_threshold"):
		rules.growth_by_demands_over_threshold.assign(d.get("growth_by_demands_over_threshold"))
	return rules


## Default rules, used when no rules.json is present (in-code test fixtures).
static func defaults() -> RulesDef:
	return RulesDef.from_dict({
		"demand_threshold": 3,
		"demand_catastrophe": 8,
		"population_levels": [0, 5000, 14000, 32000],
		"growth_by_demands_over_threshold": [1.0, 0.5, 0.0, -0.5],
	})


func has_demand(demand_id: String) -> bool:
	return _by_id.has(demand_id)


func get_demand(demand_id: String) -> DemandDef:
	return _by_id.get(demand_id, null)


func demand_ids() -> Array[String]:
	var ids: Array[String] = []
	for demand: DemandDef in demands:
		ids.append(demand.id)
	return ids


## The value at or above which this demand shuffles emergency cards.
func threshold_for(demand_id: String) -> int:
	var demand: DemandDef = get_demand(demand_id)
	if demand != null and demand.threshold_override != DemandDef.UNSET:
		return demand.threshold_override
	return demand_threshold


## The value at or above which this demand also shuffles catastrophe cards.
func catastrophe_for(demand_id: String) -> int:
	var demand: DemandDef = get_demand(demand_id)
	if demand != null and demand.catastrophe_override != DemandDef.UNSET:
		return demand.catastrophe_override
	return demand_catastrophe


## Population growth multiplier for a count of demands over threshold, with the
## last table entry applying to that count and above (content-schema.md).
func growth_multiplier(demands_over_threshold: int) -> float:
	if growth_by_demands_over_threshold.is_empty():
		return 1.0
	var index: int = clampi(demands_over_threshold, 0,
		growth_by_demands_over_threshold.size() - 1)
	return growth_by_demands_over_threshold[index]


## Lowest multiplier in the table — used when any demand is at catastrophe
## level, which forces decline regardless of the count (GDD 4.0).
func decline_multiplier() -> float:
	if growth_by_demands_over_threshold.is_empty():
		return 1.0
	return growth_by_demands_over_threshold[growth_by_demands_over_threshold.size() - 1]


## Population level (1-based) for a raw count, ignoring hysteresis.
func level_for_count(count: int) -> int:
	var level: int = 1
	for i: int in population_levels.size():
		if count >= population_levels[i]:
			level = i + 1
	return level


## Lower bound of a 1-based level, or -1 past the top of the table.
func level_lower_bound(level: int) -> int:
	if level < 1 or level > population_levels.size():
		return -1
	return population_levels[level - 1]
