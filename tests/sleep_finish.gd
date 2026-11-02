extends SceneTree
var session: Node
var game: Node3D
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/"+label_+".png")
func cloth_height(p: Vector3,cover: float,width_: float) -> float:
	var y:=p.z-.30
	var body:=exp(-pow(absf(p.x)/width_,4.0))*smoothstep(-.90,-.58,y)*(1-smoothstep(1.18,1.82,y))
	return .985+body*cover-.11*pow(absf(p.x)/1.24,8.0)+sin(p.x*17+y*4)*.012
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in (["panda"] if OS.get_cmdline_user_args().has("--panda-only") else ["bunny","cat_teacher"]):
		session.create_character("午睡"+load("res://scripts/characters/animal_catalog.gd").display_name(species),species,"vest_sage")
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.6).timeout
		session.state().time=1800;game.update_lighting();game.hud.toast.hide()
		var bed: Node3D=game.home.get_node("Furnishing/bed")
		game.bunny.position=bed.get_node("ActionAnchor").global_position;game.bunny.reset_physics_interpolation();session.set_player_position(game.bunny.position)
		await create_timer(.3).timeout;game.update_target();game.interact();await create_timer(1.1).timeout
		check(game.sleep_active,"Sleep starts at the actual bed: "+species)
		var cover: float=bed.get_node("Quilt").material_override.get_shader_parameter("cover_height")
		var width_: float=bed.get_node("Quilt").material_override.get_shader_parameter("cover_width")
		var penetration:=-100.0
		for arm in [game.bunny.left_arm,game.bunny.right_arm]:
			for mesh in arm.find_children("*","MeshInstance3D",true,false):
				if not mesh.is_visible_in_tree() or str(mesh.name).contains("Ink"): continue
				var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var p: Vector3=bed.to_local(mesh.to_global(vertex))
					if p.z>=-.39 and p.z<=1.95: penetration=maxf(penetration,p.y-cloth_height(p,cover,width_))
		print("ARM_COVER ",species," max_penetration=",penetration)
		check(penetration<.015,"Both arms remain beneath the quilt surface: "+species)
		game.distance_=10;game.yaw=.35;game.pitch=.46;await create_timer(.3).timeout;await capture("新版睡眠-"+species)
		game.yaw=1.4;game.pitch=.25;await create_timer(.3).timeout;await capture("新版睡眠侧面-"+species)
		game.queue_free();await process_frame;await process_frame
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout
		check(game.sleep_active and game.bunny.sleeping and not game.bunny.can_move,"Restoring the city preserves sleeping state")
		var event:=InputEventAction.new();event.action="pause";event.pressed=true;game._unhandled_input(event);await create_timer(.3).timeout
		check(not game.sleep_active and game.bunny.is_on_floor() and game.bunny.collision_layer==2,"Esc safely wakes and restores collision")
		game.queue_free();await process_frame;await process_frame
	print("SLEEP_FINISH_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
