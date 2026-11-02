extends Node
const Trust=preload("res://scripts/services/update_trust.gd")
func _ready() -> void:
	var splash:=CanvasLayer.new()
	add_child(splash)
	var background:=ColorRect.new()
	background.color=Color("fff9e9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text:=Label.new()
	text.text="兔兔的世界\n海风正在把小岛吹醒…"
	text.add_theme_color_override("font_color",Color("557c65"))
	text.add_theme_font_size_override("font_size",26)
	text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	background.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().process_frame
	# Keep bootstrap independent of release.gd so patched gameplay is first loaded after mounting.
	var build:=3
	if not OS.get_cmdline_user_args().has("--test"):
		for file in ["pending.json","active.json"]:
			var path: String="user://updates/"+file
			if not FileAccess.file_exists(path): continue
			var data=JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data is Dictionary: continue
			var payload:=Trust.verify_envelope(data.get("envelope",{}))
			if payload.is_empty() or int(payload.get("min_launcher",1))>Trust.LAUNCHER or int(payload.build)<build: continue
			var filename:="build-%d.pck"%int(payload.build)
			if data.get("file","")!=filename: continue
			var pack_path:="user://updates/"+filename
			if FileAccess.get_sha256(pack_path)!=str(payload.pack.sha256): continue
			if ProjectSettings.load_resource_pack(pack_path,true):
				build=int(payload.build)
				if file=="pending.json":
					if FileAccess.file_exists("user://updates/active.json"): DirAccess.copy_absolute("user://updates/active.json","user://updates/previous.json")
					DirAccess.rename_absolute(path,"user://updates/active.json")
				break
	var session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	session.installed_build=build
	get_tree().root.add_child.call_deferred(session)
	await get_tree().process_frame
	var release=load("res://scripts/services/release.gd")
	print("TUTU_CLIENT_READY version=",release.VERSION," build=",build)
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
