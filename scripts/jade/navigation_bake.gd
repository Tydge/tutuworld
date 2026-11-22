extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const Nav=preload("res://scripts/city/wander_navigation.gd")
class Survey extends Node3D:
	var map_id:="jade"
	func navigation_bounds() -> Rect2i:return J.NAVIGATION
	func can_navigate(p: Vector3) -> bool:return J.can_walk(p)
static func bake(tree: SceneTree,world: Node3D) -> bool:
	var sample:=Survey.new();tree.root.add_child(sample)
	var nav:=Nav.new();nav.set_meta("survey_only",true);sample.add_child(nav)
	await tree.physics_frame;await tree.physics_frame
	var space:=world.get_world_3d().direct_space_state
	var count:=J.NAVIGATION.get_area();var h:=PackedFloat32Array();var groups:=PackedInt32Array()
	h.resize(count);h.fill(-INF);groups.resize(count);groups.fill(-1)
	var i:=0
	for z in range(J.NAVIGATION.position.y,J.NAVIGATION.end.y):
		for x in range(J.NAVIGATION.position.x,J.NAVIGATION.end.x):
			var cell:=Vector2i(x,z);var solid:=nav.blocked(space,x,z)
			nav.grid.set_point_solid(cell,solid)
			if not solid:h[i]=nav.floor_heights[cell]
			i+=1
	await nav.rebuild_destinations()
	for cell: Vector2i in nav.component_of:
		var local:=cell-J.NAVIGATION.position;groups[local.y*J.NAVIGATION.size.x+local.x]=nav.component_of[cell]
	var valid:=nav.component_of.size()>count/2
	if valid:
		world.set_meta("navigation_heights",h);world.set_meta("navigation_components",groups)
	sample.free();return valid
