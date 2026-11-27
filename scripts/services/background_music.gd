extends Node
## Two persistent voices keep the score continuous while map scenes are replaced.
const DAY_SECONDS := preload("res://scripts/services/local_authority.gd").DAY_SECONDS
const ROOT := "res://assets/audio/music/"
const TRACKS := {
	"day1": ["day1.mp3", -2.17],
	"day2": ["day2.mp3", -1.71],
	"night1": ["night1.mp3", -1.39],
	"night2": ["night2.mp3", -1.23],
	"snow_day1": ["snow_day1.mp3", -2.36],
	"jade_day1": ["jade_day1.res", 0.0],
	"jade_day2": ["jade_day2.res", 0.0],
	"jade_night1": ["jade_night1.mp3", -1.12],
	"dec1": ["dec1.mp3", -2.01],
}
const ISLAND_DAY := ["day1", "day2"]
const ISLAND_NIGHT := ["night1", "night2"]
const FADE_SECONDS := 2.6
const LOAD_AHEAD_SECONDS := 8.0
const LOAD_GRACE_SECONDS := 0.5
const MIX_DB := -8.0

var world: Node
var voices: Array[AudioStreamPlayer] = []
var leading := 0
var current_track := ""
var fade_elapsed := FADE_SECONDS
var base_db: Array[float] = [0.0, 0.0]
var missing_world_time := 0.0
var requested: Dictionary = {}
var unavailable: Dictionary = {}

static func playlist(map_id: String, world_time: float, building: bool) -> Array:
	if building:
		return ["dec1"]
	var hour := fposmod(world_time, DAY_SECONDS) * 24.0 / DAY_SECONDS
	var day := hour >= 6.0 and hour < 18.0
	match map_id:
		"city", "valley": return ISLAND_DAY if day else ISLAND_NIGHT
		"icefield": return ["snow_day1", "day1"] if day else ["snow_day1", "night1"]
		"jade": return ["jade_day1", "jade_day2"] if day else ["jade_night1"]
	return []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicVoice%d" % (index + 1)
		player.bus = "Music"
		add_child(player)
		voices.append(player)

func _process(delta: float) -> void:
	if fade_elapsed < FADE_SECONDS:
		update_fade(delta)
		return

	var tracks: Array = []
	if is_instance_valid(world) and world.is_inside_tree():
		missing_world_time = 0.0
		var building: bool = is_instance_valid(world.build_mode) and world.build_mode.active
		tracks = playlist(world.map_id, float(world.session.state().time), building)
		if not unavailable.is_empty():
			tracks = tracks.filter(func(id): return not unavailable.has(id))
	else:
		missing_world_time += delta
		if missing_world_time < LOAD_GRACE_SECONDS:
			return

	if tracks.is_empty():
		discard_unused_requests("")
		if not current_track.is_empty():
			start_fade("", null)
		return

	var player := voices[leading]
	var index := tracks.find(current_track)
	var next: String = tracks[(index + 1) % tracks.size()]
	var remaining := player.stream.get_length() - player.get_playback_position() if player.playing else 0.0
	discard_unused_requests(next)
	if index >= 0 and remaining > LOAD_AHEAD_SECONDS:
		return
	var stream := prepare_track(next, index < 0 or remaining <= FADE_SECONDS)
	if stream != null:
		start_fade(next, stream)

func prepare_track(id: String, can_start: bool) -> AudioStream:
	var path: String = ROOT + TRACKS[id][0]
	if not requested.has(id):
		var error := ResourceLoader.load_threaded_request(path)
		if error != OK:
			mark_unavailable(id)
			return null
		requested[id] = path
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_LOADED:
			if can_start:
				requested.erase(id)
				var stream := ResourceLoader.load_threaded_get(path) as AudioStream
				if stream == null:
					mark_unavailable(id)
				return stream
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			mark_unavailable(id)
	return null

func discard_unused_requests(keep: String) -> void:
	for id in requested.keys():
		if id == keep:
			continue
		var path: String = requested[id]
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		ResourceLoader.load_threaded_get(path)
		requested.erase(id)

func mark_unavailable(id: String) -> void:
	if requested.has(id):
		ResourceLoader.load_threaded_get(requested[id])
		requested.erase(id)
	unavailable[id] = true
	push_warning("Could not load background music: " + id)

func start_fade(id: String, stream: AudioStream) -> void:
	leading = 1 - leading
	current_track = id
	fade_elapsed = 0.0
	var player := voices[leading]
	if stream != null:
		base_db[leading] = MIX_DB + float(TRACKS[id][1])
		player.stream = stream
		player.volume_db = -80.0
		player.play()

func update_fade(delta: float) -> void:
	fade_elapsed = minf(fade_elapsed + delta, FADE_SECONDS)
	var angle := fade_elapsed / FADE_SECONDS * PI * 0.5
	var outgoing := 1 - leading
	voices[leading].volume_db = base_db[leading] + linear_to_db(maxf(0.0001, sin(angle)))
	voices[outgoing].volume_db = base_db[outgoing] + linear_to_db(maxf(0.0001, cos(angle)))
	if fade_elapsed == FADE_SECONDS:
		voices[outgoing].stop()
		voices[outgoing].stream = null
