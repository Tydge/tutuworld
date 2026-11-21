extends RefCounted
## Read imported, named meshes without instantiating a scene full of unused variants.
static var libraries: Dictionary = {}

static func from_scene(scene: PackedScene) -> Dictionary:
	if not libraries.has(scene):
		var meshes := {}
		var state := scene.get_state()
		for node in state.get_node_count():
			for property in state.get_node_property_count(node):
				if state.get_node_property_name(node, property) == &"mesh":
					meshes[String(state.get_node_name(node))] = state.get_node_property_value(node, property)
		libraries[scene] = meshes
	return libraries[scene]
