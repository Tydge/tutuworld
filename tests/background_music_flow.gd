extends SceneTree

const Music := preload("res://scripts/services/background_music.gd")
const Land := preload("res://scripts/building/parcels.gd")
const Routes := preload("res://scripts/services/map_routes.gd")
var failures := 0
var checks := 0
var music: Node
var session: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", label)

func wait_for_track(id: String, settled := true) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if music.current_track == id and (not settled or music.fade_elapsed == Music.FADE_SECONDS):
			return true
		await process_frame
	return false

func run() -> void:
	for row in [
		["city", ["day1","day2"], ["night1","night2"]],
		["valley", ["day1","day2"], ["night1","night2"]],
		["icefield", ["snow_day1","day1"], ["snow_day1","night1"]],
		["jade", ["jade_day1","jade_day2"], ["jade_night1"]],
	]:
		check(Music.playlist(row[0], 900.0, false) == row[1], row[0] + " dawn list")
		check(Music.playlist(row[0], 2700.0, false) == row[2], row[0] + " dusk list")
		check(Music.playlist(row[0], 2700.0, true) == ["dec1"], row[0] + " construction override")
	for id in Music.TRACKS:
		var path: String = Music.ROOT + Music.TRACKS[id][0]
		var stream := load(path) as AudioStream
		check(stream != null and stream.get_length() > 75.0, "Playable audio " + id)

	session = preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	session.create_character("听曲的兔兔", "bunny", "bow_rose")
	session.state().time = 1800.0
	var city := load(Routes.scene("city")).instantiate() as Node3D
	root.add_child(city)
	current_scene = city
	music = session.background_music
	check(await wait_for_track("day1"), "Real map starts daytime playback")
	var player: AudioStreamPlayer = music.voices[music.leading]
	check(player.playing and player.bus == "Music", "Playback is on the dedicated bus")
	var bus := AudioServer.get_bus_index("Music")
	var environment := AudioServer.get_bus_index("Environment")
	check(session.settings.music_enabled and is_equal_approx(session.settings.music_volume, 0.5), "Default music is enabled at 50 percent")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(0.5)), "Mixer applies default music gain")

	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture)
	await create_timer(0.4).timeout
	var audio := capture.get_buffer(capture.get_frames_available())
	var audible := false
	for frame in audio:
		if frame.length_squared() > 0.0000001:
			audible = true
			break
	check(audible, "Mixer decodes live stereo music samples")
	AudioServer.remove_bus_effect(bus, 0)

	city.hud.open_panel("settings")
	var toggle := city.hud.content.find_child("MusicEnabled", true, false) as CheckButton
	var slider := city.hud.content.find_child("MusicVolume", true, false) as HSlider
	check(toggle != null and slider != null and is_equal_approx(slider.value, 0.5), "Music settings are present in the world menu")
	if toggle != null and slider != null:
		toggle.button_pressed = false
		slider.value = 0.25
		check(AudioServer.is_bus_mute(bus) and not AudioServer.is_bus_mute(environment), "Music switch leaves environment audible")
		check(is_equal_approx(AudioServer.get_bus_volume_db(bus),linear_to_db(0.25)), "Music slider controls the mixer")
		toggle.button_pressed = true
		slider.value = 0
		check(AudioServer.is_bus_mute(bus), "Zero music volume is silent")
		slider.value = 0.50
		session.set_setting("sound", false)
		check(AudioServer.is_bus_mute(environment) and not AudioServer.is_bus_mute(bus), "Environment switch leaves music audible")
		session.set_setting("sound", true)
	city.hud.close_panel()

	player.play(player.stream.get_length() - 2.2)
	check(await wait_for_track("day2", false), "Playlist advances before the final sample")
	await create_timer(0.5).timeout
	var outgoing: AudioStreamPlayer = music.voices[1 - music.leading]
	var incoming: AudioStreamPlayer = music.voices[music.leading]
	check(outgoing.playing and incoming.playing and outgoing.volume_db < music.base_db[1 - music.leading] and incoming.volume_db < music.base_db[music.leading], "Both tracks overlap with complementary fades")
	check(await wait_for_track("day2"), "Rotation settles on one track")
	check(not outgoing.playing and outgoing.stream == null, "Old audio voice releases the stream")

	var center := Land.sign_position("east_nw")
	city.bunny.global_position = center
	session.set_player_position(center)
	check(session.buy_land("east_nw").ok and city.build_mode.open_editor("east_nw").ok, "Open the real construction editor")
	check(await wait_for_track("dec1"), "Construction music takes priority")
	city.build_mode.set_night_preview(true)
	check(music.current_track == "dec1", "Construction night preview keeps the construction score")
	session.state().time = 3100.0
	city.build_mode.close_editor()
	check(await wait_for_track("night1"), "Closing construction fades to the current world phase")

	var before := music.get_instance_id()
	session.state().map_id = "valley"
	session.state().player_position = Routes.arrival("valley")
	change_scene_to_file(Routes.scene("valley"))
	await scene_changed
	var valley := current_scene
	while not valley.navigation.ready_for_paths:
		await process_frame
	check(session.background_music.get_instance_id() == before and music.current_track == "night1", "Boat scene replacement keeps the shared night score")
	session.state().map_id = "jade"
	session.state().player_position = Routes.arrival("jade")
	change_scene_to_file(Routes.scene("jade"))
	await scene_changed
	check(await wait_for_track("jade_night1"), "Arrival in Jade starts its own night score")
	print("BACKGROUND_MUSIC_RESULT checks=", checks, " failures=", failures)
	quit(int(failures != 0))
