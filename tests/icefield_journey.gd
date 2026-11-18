extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
var session: Node
var game: Node3D
var output: String
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func wait_map(id: String) -> bool:
	var deadline:=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		if is_instance_valid(current_scene) and current_scene.get("map_id")==id and current_scene.camera!=null and current_scene.navigation.ready_for_paths and not current_scene.preparing:game=current_scene;return true
		await process_frame
	return false
func place(p: Vector3) -> void:
	game.bunny.position=p;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation()
	for i in range(8):await physics_frame
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.settings.background_throttle=false
	session.create_character("冰原行走测试","bunny","scarf_red");session.state().time=1800.;session.state().player_position=[13,.2,40.5]
	game=load("res://scenes/city.tscn").instantiate();root.add_child(game);current_scene=game
	if not await wait_map("city"):check(false,"City loads");quit(1);return
	game.bunny.position=Vector3(13,.2,41.5);game.bunny.velocity=Vector3.ZERO
	preload("res://scripts/valley/boat_travel.gd").go(game)
	var ice_button: Button=game.hud.modal.find_child("Travel_icefield",true,false)
	check(is_instance_valid(ice_button) and is_instance_valid(game.hud.modal.find_child("Travel_valley",true,false)),"City ferry opens both destination choices")
	await process_frame;RenderingServer.force_draw();root.get_texture().get_image().save_png(output+"/01-ferry-menu.png")
	var coins: int=session.state().coins
	ice_button.pressed.emit()
	if not await wait_map("icefield"):check(false,"Ferry loads icefield");quit(1);return
	check(session.state().coins==coins-10 and game.bunny.position.distance_to(game.respawn_position())<1.,"Menu travels to correct harbor and charges once")
	check(game.npcs.size()==9,"Three merchants plus exactly six new roaming residents")
	game.set_process(false);session.active=false;game.hud.hide()
	var starts: Dictionary={}
	for d in game.RESIDENTS:starts[d.id]=game.targets[d.id].node.position
	await create_timer(7.).timeout
	for id in starts:check(game.targets[id].node.position.distance_to(starts[id])>.5,"Resident walks with real collision: "+id)
	check(is_equal_approx(game.bunny.move_speed,3.5) and is_equal_approx(game.bunny.move_speed*game.bunny.SPRINT_MULTIPLIER,5.95),"Player walking and running base speeds are both increased by 25 percent")
	game.bunny.stamina_fraction=0.;game.bunny.toggle_run();check(game.bunny.run_enabled,"Running can be enabled at zero stamina");game.bunny.run_enabled=false
	game.bunny.network_controlled=true;game.bunny.network_direction=Vector3.ZERO
	await place(Vector3(50,.84,25));game.bunny.network_direction=Vector3.RIGHT
	await create_timer(.3).timeout;var start_speed:=Vector2(game.bunny.velocity.x,game.bunny.velocity.z).length()
	check(start_speed>.2 and start_speed<1.2,"Ice takes time to accelerate")
	check(game.bunny.walking and is_equal_approx(game.bunny.animation_speed,3.5) and game.bunny.gait_blend>.9,"Ice startup uses the normal input gait while translation accelerates")
	await create_timer(1.2).timeout;game.bunny.network_direction=Vector3.ZERO;var released: Vector3=game.bunny.position
	await create_timer(.7).timeout
	check(game.bunny.position.distance_to(released)>1.2 and game.bunny.velocity.x>1.5,"Releasing input produces a genuine ice glide")
	check(not game.bunny.walking and game.bunny.gait_blend<.01,"Releasing input stops limbs while the body coasts")
	var air_speed: float=game.bunny.velocity.x
	game.bunny.network_jump=true;await physics_frame;await physics_frame
	await create_timer(.25).timeout
	check(not game.bunny.is_on_floor() and game.bunny.velocity.x>air_speed-.15,"A jump preserves the current ice momentum without input")
	var airborne_state: Dictionary=game.bunny.movement_state()
	game.bunny.ice_inertia=false;game.bunny.restore_movement_state(airborne_state)
	check(game.bunny.ice_inertia,"Prediction restore preserves airborne ice inertia")
	await create_timer(6.).timeout;check(absf(game.bunny.velocity.x)<.05,"Ice glide naturally stops")
	await place(Vector3(-79,L.height_at(-79,40)+.035,40));var emitted: int=game.footprints.emitted
	game.bunny.network_direction=Vector3.BACK;await create_timer(3.5).timeout;game.bunny.network_direction=Vector3.ZERO
	await create_timer(.3).timeout
	check(absf(game.bunny.velocity.z)<.05,"Packed snow keeps normal braking")
	check(game.footprints.emitted>emitted+5 and game.footprints.marks.instance_count==192,"Actual walking leaves pooled temporary snow footprints")
	game.bunny.can_move=false
	for npc in game.npcs:
		for child in npc.get_children():
			if child.get_script()==load("res://scripts/city/npc_driver.gd"):child.set_physics_process(false)
	game.camera.position=game.bunny.position+Vector3(5,8,12);game.camera.look_at(game.bunny.position+Vector3(0,-.2,-4));game.update_lighting(.5)
	await create_timer(.4).timeout;RenderingServer.force_draw();root.get_texture().get_image().save_png(output+"/02-snow-footprints.png")
	game.footprints._process(23.)
	await create_timer(.2).timeout;RenderingServer.force_draw();root.get_texture().get_image().save_png(output+"/03-footprints-faded.png")
	check(game.footprints.elapsed>23.,"Footprints advance beyond their fade lifetime")
	for d in [["farm","seed_carrot"],["tools","pickaxe"],["clothes","bow_rose"]]:
		var merchant: Node3D=game.targets["FrostMerchant_"+d[0]].node
		game.bunny.position=merchant.position+Vector3(0,0,2.05);game.bunny.velocity=Vector3.ZERO
		for i in range(5):await physics_frame
		check(game.trade_access(d[0]),"Walk-in merchant is physically reachable "+d[0])
	var raw: Dictionary=session.snapshot();raw.map_id="icefield";raw.player_position=[50.,.84,25.]
	var restored=session.restore_state(raw);check(restored.state.map_id=="icefield" and restored.state.player_position==raw.player_position,"Resume remains on icefield")
	await place(Vector3(L.DOCK.x,L.DOCK_HEIGHT+.035,L.DOCK.y));game.bunny.can_move=true
	preload("res://scripts/valley/boat_travel.gd").go(game)
	check(await wait_map("city") and session.state().coins==coins-10,"Icefield ferry returns to city for free")
	print("ICEFIELD_JOURNEY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
