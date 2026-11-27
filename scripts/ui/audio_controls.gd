extends RefCounted
const UI := preload("res://scripts/ui/ui_kit.gd")

static func add_to(parent: VBoxContainer, session: Node) -> void:
	add_group(parent, session, "环境声音", "环境音量", "sound", "volume", "Environment")
	add_group(parent, session, "背景音乐", "音乐音量", "music_enabled", "music_volume", "Music")

static func add_group(parent: VBoxContainer, session: Node, title: String, volume_title: String,
		enabled_key: String, volume_key: String, name_prefix: String) -> void:
	var group := UI.column(6)
	parent.add_child(group)
	var toggle := CheckButton.new()
	toggle.name = name_prefix + "Enabled"
	toggle.text = title
	toggle.button_pressed = bool(session.settings[enabled_key])
	toggle.toggled.connect(func(value): session.set_setting(enabled_key, value))
	group.add_child(toggle)
	var label := UI.label("", 17)
	group.add_child(label)
	var slider := HSlider.new()
	slider.name = name_prefix + "Volume"
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(session.settings[volume_key])
	label.text = "%s  %d%%" % [volume_title, roundi(slider.value * 100.0)]
	slider.value_changed.connect(func(value):
		label.text = "%s  %d%%" % [volume_title, roundi(value * 100.0)]
		session.set_setting(volume_key, value))
	group.add_child(slider)
