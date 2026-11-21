extends RefCounted
## Sample without replacement. The same map seed gives clients and hosts matching defaults.
const LOOKS := [
	{"head":"cowboy_hat_saddle", "body":"oxford_shirt_tide", "neck":"gold_chain_cable"},
	{"head":"top_hat_midnight", "body":"day_dress_cornflower", "neck":"silk_bowtie_claret"}
]

static func sample(ids: Array, population: int, map: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("atelier-2026/"+map).hash()
	var pool := ids.duplicate()
	var result := {}
	for i in mini(mini(floori(population * .25), pool.size()), LOOKS.size()):
		var index := rng.randi_range(0, pool.size()-1)
		var worn: Dictionary = LOOKS[i].duplicate()
		if map == "icefield":
			worn.erase("body") # Keep the residents’ insulated coats in the snow.
		result[pool.pop_at(index)] = worn
	return result
