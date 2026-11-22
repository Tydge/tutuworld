extends SceneTree
## Sample both islands' connected ground in their baked collision worlds, using identical spacing and clearance.
const J=preload("res://scripts/jade/layout.gd")
const ICE=preload("res://scripts/icefield/icefield_layout.gd")
func _initialize() -> void:call_deferred("run")
func survey(jade: bool) -> Dictionary:
	var world: Node3D=load("res://scenes/jade_map.scn" if jade else "res://scenes/icefield_map.scn").instantiate()
	root.add_child(world)
	for i in range(3):await physics_frame
	var physics:=world.get_world_3d().direct_space_state
	var shape:=CapsuleShape3D.new();shape.height=1.48;shape.radius=.34
	var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=shape;capsule.collision_mask=5
	var ground:=PhysicsRayQueryParameters3D.new();ground.collision_mask=9
	var heights: Dictionary={};var raw:=0;var palace:=0
	for x in range(-240,241,2):
		for z in range(-214,215,2):
			var p:=Vector3(x,1.,z)
			if not (J.can_walk(p) if jade else ICE.can_walk(p)):continue
			raw+=1;palace+=int(jade and z<=-82)
			var foot: float=J.foot(x,z) if jade else ICE.walk_height(x,z)
			ground.from=Vector3(x,foot+.63,z);ground.to=Vector3(x,foot-.65,z)
			var hit:=physics.intersect_ray(ground)
			if hit.is_empty() or hit.normal.y<.68:continue
			capsule.transform=Transform3D(Basis.IDENTITY,hit.position+Vector3.UP*.86)
			if physics.intersect_shape(capsule,1).is_empty():heights[Vector2i(x,z)]=hit.position.y
	var visited: Dictionary={};var largest:=0
	for tile in heights:
		if visited.has(tile):continue
		var todo: Array[Vector2i]=[tile];visited[tile]=true
		var i:=0
		while i<todo.size():
			var current:=todo[i];i+=1
			for dir: Vector2i in [Vector2i.LEFT,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN]:
				var next:=current+dir*2
				if not visited.has(next) and heights.has(next) and absf(heights[next]-heights[current])<1.68:
					visited[next]=true;todo.append(next)
		largest=maxi(largest,todo.size())
	world.free()
	return {"boundary_m2":raw*4,"supported_m2":heights.size()*4,"connected_m2":largest*4,"palace_share":float(palace)/raw}
func run() -> void:
	var ice: Dictionary=await survey(false);var jade: Dictionary=await survey(true)
	var ratio:=float(jade.connected_m2)/maxi(1,ice.connected_m2);var ok: bool=ice.connected_m2>50000 and ratio>2. and jade.palace_share>.27 and jade.palace_share<.34
	print("JADE_AREA_RULES jade=",jade," whole_snow_and_ice=",ice," connected_ratio=",ratio," pass=",ok);quit(0 if ok else 1)
