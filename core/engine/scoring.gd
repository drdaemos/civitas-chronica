class_name Scoring
extends RefCounted

## MVP scoring axes (GDD 10 / 4.7): population + specialization depth +
## heritage (developments that survived ages, extra for adapted ones).


@warning_ignore("unused_parameter")
static func score(state: GameState, db: ContentDB) -> Dictionary:
	@warning_ignore("integer_division")
	var population_score: int = state.population / 10
	var specialization_score: int = 25 * state.active_interactions.size()
	var ages_survived_total: int = 0
	var adapted_count: int = 0
	for dev: DevelopmentState in state.developments:
		ages_survived_total += dev.ages_survived
		if dev.adapted:
			adapted_count += 1
	var heritage_score: int = 5 * ages_survived_total + 10 * adapted_count
	return {
		"population": population_score,
		"specialization": specialization_score,
		"heritage": heritage_score,
		"total": population_score + specialization_score + heritage_score,
	}
