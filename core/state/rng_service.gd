class_name RngService
extends RefCounted

## Deterministic named RNG streams (constitution rule 5).
## All game randomness must flow through one of these streams so that
## master_seed + player inputs fully determine a save.

const STREAM_NAMES: Array[String] = ["deck", "events", "population"]

var master_seed: int = 0
var _streams: Dictionary = {}


func _init(seed_value: int = 0) -> void:
	master_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	for stream_name: String in STREAM_NAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [master_seed, stream_name])
		_streams[stream_name] = rng


func rand_int(stream: String, from_value: int, to_value: int) -> int:
	return _get_stream(stream).randi_range(from_value, to_value)


func rand_float(stream: String) -> float:
	return _get_stream(stream).randf()


## Fisher-Yates shuffle in place, using the named stream.
func shuffle(stream: String, arr: Array) -> void:
	var rng: RandomNumberGenerator = _get_stream(stream)
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func to_dict() -> Dictionary:
	var streams: Dictionary = {}
	for stream_name: String in STREAM_NAMES:
		var rng: RandomNumberGenerator = _streams[stream_name]
		# Stored as strings: RNG state is int64 and JSON numbers are doubles.
		streams[stream_name] = {"seed": str(rng.seed), "state": str(rng.state)}
	return {"master_seed": str(master_seed), "streams": streams}


static func from_dict(d: Dictionary) -> RngService:
	var service := RngService.new(String(d.get("master_seed", "1")).to_int())
	var streams: Dictionary = d.get("streams", {})
	for stream_name: String in STREAM_NAMES:
		if streams.has(stream_name):
			var s: Dictionary = streams[stream_name]
			var rng: RandomNumberGenerator = service._streams[stream_name]
			rng.seed = String(s.get("seed", "0")).to_int()
			rng.state = String(s.get("state", "0")).to_int()
	return service


func _get_stream(stream: String) -> RandomNumberGenerator:
	assert(_streams.has(stream), "Unknown RNG stream: " + stream)
	return _streams[stream]
