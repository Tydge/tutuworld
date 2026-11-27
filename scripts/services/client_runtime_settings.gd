extends RefCounted
## Mounted updates replace resources. The original executable keeps its startup project settings.

const SHORTCUTS := {"photo": KEY_F2, "build_mode": KEY_F6, "screenshot": KEY_F12}
static var initialized := false

static func apply() -> void:
	if initialized:
		return
	initialized = true
	for action in SHORTCUTS:
		ensure_shift_shortcut(action, SHORTCUTS[action])

	if DisplayServer.get_name() == "headless":
		return
	add_missing_global("canopy_focus", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	add_missing_global("canopy_eye", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	add_missing_global("sky_lattice", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, "res://assets/terrain/sky_lattice.png")

static func ensure_shift_shortcut(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var already_bound := false
	for event in InputMap.action_get_events(action):
		if not event is InputEventKey or event.physical_keycode != key or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
			continue
		if event.shift_pressed:
			already_bound = true
		else:
			InputMap.action_erase_event(action, event)
	if not already_bound:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.shift_pressed = true
		InputMap.action_add_event(action, event)

static func add_missing_global(name: StringName, type: RenderingServer.GlobalShaderParameterType, value: Variant) -> void:
	if not ProjectSettings.has_setting("shader_globals/" + name):
		RenderingServer.global_shader_parameter_add(name, type, load(value) if value is String else value)
