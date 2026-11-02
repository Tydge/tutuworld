extends SceneTree
const Garden=preload("res://scripts/city/town_gardens.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(1).timeout
	Engine.max_fps=30;session.active=false;game.bunny.can_move=false
	var flowers: PackedVector3Array=game.scenery.get_meta("town_flower_centers",PackedVector3Array())
	var shrubs: PackedVector3Array=game.scenery.get_meta("town_shrub_centers",PackedVector3Array())
	check(flowers.size()>=80 and flowers.size()<=160,"Town gains grouped flower patches: "+str(flowers.size()))
	check(shrubs.size()>0 and shrubs.size()<=12,"Town has a small number of low shrubs: "+str(shrubs.size()))
	var clear_flowers:=true;var clear_shrubs:=true;var clear_resources:=true
	for p in flowers:
		clear_flowers=clear_flowers and Garden.off_pavement(game.scenery,p,.3)
		clear_resources=clear_resources and Garden.safe(game.scenery,p,.3)
	for p in shrubs:
		clear_shrubs=clear_shrubs and Garden.off_pavement(game.scenery,p,.8)
		clear_resources=clear_resources and Garden.safe(game.scenery,p,.8)
	check(clear_flowers,"Every flower clears all six actual road strips, curbs and plaza")
	check(clear_shrubs,"Every shrub clears actual paving including its full canopy radius")
	check(clear_resources,"New plants leave all nineteen resource interactions clear")
	var stale:=0
	for node in game.scenery.find_children("*","MultiMeshInstance3D",true,false):
		if not node.material_override is StandardMaterial3D: continue
		if not node.material_override.albedo_color.is_equal_approx(Color("e6bb9b")) and not node.material_override.albedo_color.is_equal_approx(Color("eddfa4")): continue
		for i in range(node.multimesh.instance_count):
			var point: Vector3=node.to_global(node.multimesh.get_instance_transform(i).origin)
			if absf(point.z-17.3)<.4 and absf(point.x)<4.1: stale+=1
	check(stale==0,"No old flower petals remain across the center road")
	check(game.scenery.find_children("GrassTufts","",true,false).is_empty(),"No grass seedlings reintroduced by map regeneration")
	game.set_process(false);game.hud.visible=false;game.update_lighting(.5)
	game.bunny.position=Vector3(-7,.1,17);game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	game.camera.position=Vector3(7,10,30);game.camera.look_at(Vector3(-5,1,16))
	await create_timer(.5).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/城镇-花丛与道路留白.png")
	print("TOWN_GARDENS_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
