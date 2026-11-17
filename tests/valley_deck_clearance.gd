extends SceneTree
## Measure the saved, rendered boards against the saved terrain mesh, not just its height formula.
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func capture(label_: String,eye: Vector3,target: Vector3,time_: float) -> void:
	var query:=PhysicsShapeQueryParameters3D.new();var sphere:=SphereShape3D.new();sphere.radius=.24;query.shape=sphere;query.collision_mask=9;query.transform=Transform3D(Basis.IDENTITY,eye)
	check(game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Screenshot camera clears physical scenery: "+label_)
	game.camera.position=eye;game.camera.look_at(target);game.update_lighting(time_)
	for i in range(12):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.create_character("木栈道检查","bunny","bow_sage");session.state().map_id="valley";session.state().player_position=[-24,0,94.4];session.state().time=1800
	game=load("res://scenes/valley.tscn").instantiate();root.add_child(game);current_scene=game
	while game.camera==null or not game.navigation.ready_for_paths:await process_frame
	session.active=false;game.set_process(false);game.bunny.can_move=false;game.bunny.hide();game.hud.hide()
	for npc in game.npcs:npc.hide();npc.set_physics_process(false)
	var terrain: Node3D=game.scenery.get_node("ForestTerrain")
	var query:=PhysicsRayQueryParameters3D.new();query.collision_mask=8
	var excluded: Array[RID]=[]
	for body: StaticBody3D in game.scenery.find_children("*","StaticBody3D",true,false):
		if body.collision_layer&8 and not terrain.is_ancestor_of(body):excluded.append(body.get_rid())
	query.exclude=excluded
	var stats: Dictionary={"harbor":{"boards":0,"samples":0,"minimum":INF},"creek":{"boards":0,"samples":0,"minimum":INF}}
	for node: MultiMeshInstance3D in game.scenery.find_children("*","MultiMeshInstance3D",true,false):
		var mm:=node.multimesh
		if not mm.mesh is BoxMesh:continue
		for i in range(mm.instance_count):
			var transform_: Transform3D=node.global_transform*mm.get_instance_transform(i)
			var size_: Vector3=Vector3(transform_.basis.x.length(),transform_.basis.y.length(),transform_.basis.z.length())*(mm.mesh as BoxMesh).size
			var kind:=""
			if absf(size_.x-.37)<.001 and absf(size_.y-.18)<.001 and absf(size_.z-3.7)<.001:kind="harbor"
			if absf(size_.x-.37)<.001 and absf(size_.y-.15)<.001 and absf(size_.z-3.9)<.001:kind="creek"
			if kind=="":continue
			stats[kind].boards+=1
			var top: float=transform_.origin.y+size_.y*.5
			for u in [-.46,0.,.46]:
				for v in [-.47,-.23,0.,.23,.47]:
					var p:=transform_.origin+Vector3(size_.x*u,0,size_.z*v)
					query.from=Vector3(p.x,top+2.,p.z);query.to=Vector3(p.x,top-12.,p.z)
					var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.is_empty():continue
					stats[kind].samples+=1;stats[kind].minimum=minf(stats[kind].minimum,top-hit.position.y)
	for kind in stats:
		var value: Dictionary=stats[kind]
		print("DECK_CLEARANCE ",kind," boards=",value.boards," samples=",value.samples," minimum_m=",value.minimum)
		check(value.boards==(28 if kind=="harbor" else 61),"All saved boards located: "+kind)
		check(value.samples==value.boards*15,"Ground measured beneath every board: "+kind)
		check(value.minimum>=.075,"Terrain stays visibly below the complete board tops: "+kind)
	await capture("pier-day-west",Vector3(-25,1.9,99),Vector3(-17.4,.18,94.1),.5)
	await capture("pier-day-north",Vector3(-23.8,1.4,88),Vector3(-17.8,.18,94.3),.5)
	await capture("pier-night-west",Vector3(-25,1.9,99),Vector3(-17.4,.18,94.1),.92)
	var base: float=preload("res://scripts/valley/valley_layout.gd").bridge_height(-12)
	await capture("creek-west-end",Vector3(-17,base+4.,15),Vector3(-10,base,10),.5)
	print("VALLEY_DECK_CLEARANCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
