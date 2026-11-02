extends SceneTree
func _initialize() -> void:
	Engine.max_fps=30
	Engine.physics_ticks_per_second=30
	var server=load("res://server/world_server.gd").new()
	root.add_child.call_deferred(server)
