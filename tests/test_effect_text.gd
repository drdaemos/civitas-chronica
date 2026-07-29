extends RefCounted

## Player-facing effect copy describes unmet demand in words, never as an
## ambiguous signed number. Policies remain deliberately absent from the UI.


func run(t: TestContext) -> bool:
	var db: ContentDB = Fixtures.build_db()

	t.label("instant demand changes say whether they increase or satisfy a need")
	var satisfy := EffectDef.from_dict({
		"type": "demand_delta", "demand": "supply", "amount": -2,
	})
	var increase := EffectDef.from_dict({
		"type": "demand_delta", "demand": "supply", "amount": 3,
	})
	var unchanged := EffectDef.from_dict({
		"type": "demand_delta", "demand": "supply", "amount": 0,
	})
	t.eq(EffectText.describe(satisfy, db), "Satisfies Supply by 2",
		"negative demand delta is a satisfied need")
	t.eq(EffectText.describe(increase, db), "Increases Supply by 3",
		"positive demand delta is increased unmet need")
	t.eq(EffectText.describe(unchanged, db), "",
		"zero demand delta does not create a meaningless consequence line")

	t.label("printed development values explain both halves of the rule")
	t.eq(EffectText.describe_printed_demand("supply", -1, db),
		"Satisfies Supply by 1 · reduces growth by 1/turn",
		"mitigation describes immediate and standing effects")
	t.eq(EffectText.describe_printed_demand("supply", 2, db),
		"Increases Supply by 2 · increases growth by 2/turn",
		"aggravation describes immediate and standing effects")

	t.label("policy effects are suppressed while policies are disabled")
	var unlock := EffectDef.from_dict({
		"type": "unlock_policy", "id": "trade_council",
	})
	t.eq(EffectText.describe(unlock, db), "", "unlock_policy has no player-facing line")
	t.eq(EventLogFormatter.describe(
		{"type": "policy_unlocked", "id": "trade_council"}, db), "",
		"policy discovery has no chronicle line")
	return true
