extends RefCounted
## Clear game input at text-entry/focus boundaries, including keys swallowed by an IME.
const ACTIONS:=["move_up","move_down","move_left","move_right","jump","sprint","interact","quick_interact","daydream"]
static func release_controls() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):continue
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey:
				var release: InputEventKey=binding.duplicate();release.pressed=false;release.echo=false
				if release.keycode==0:release.keycode=release.physical_keycode
				if release.physical_keycode==0:release.physical_keycode=release.keycode
				Input.parse_input_event(release)
		Input.action_release(action)
