class_name DemandDef
extends RefCounted

## One demand (GDD 4.0), defined as content in `content/rules.json` rather than
## as a code constant: the set of demands, their order of activation, their
## tolerances and their status text are all expected to move with playtesting,
## and no engine code names a specific demand.
##
## `threshold` / `catastrophe` default to the global values in RulesDef. They
## exist per demand because the GDD leaves "uniform across demands and ages"
## as an open question — uniform is expressed by simply omitting them.

const UNSET: int = -1

var id: String = ""
var display_name: String = ""
var description: String = ""
var threshold_override: int = UNSET
var catastrophe_override: int = UNSET
## Status lines in period voice, `[{"at": int, "text": String}]` ascending by
## `at` (GDD 4.0 Presentation). The band with the highest `at` <= value wins.
var bands: Array[Dictionary] = []


static func from_dict(d: Dictionary) -> DemandDef:
	var demand := DemandDef.new()
	demand.id = String(d.get("id", ""))
	demand.display_name = String(d.get("name", demand.id))
	demand.description = String(d.get("description", ""))
	demand.threshold_override = int(d.get("threshold", UNSET))
	demand.catastrophe_override = int(d.get("catastrophe", UNSET))
	for band: Variant in d.get("bands", []):
		demand.bands.append(band as Dictionary)
	demand.bands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("at", 0)) < int(b.get("at", 0)))
	return demand


## The status line for a meter value, or "" when the demand defines no bands.
func band_text(value: int) -> String:
	var text: String = ""
	for band: Dictionary in bands:
		if value >= int(band.get("at", 0)):
			text = String(band.get("text", ""))
	return text
