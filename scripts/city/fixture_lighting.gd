extends RefCounted
## Native fades cull distant fixture/shadow work without a script per lamp.
static func configure(light: Light3D) -> void:
	light.distance_fade_enabled=true
	light.distance_fade_begin=26.
	light.distance_fade_length=10.
	light.distance_fade_shadow=14.
