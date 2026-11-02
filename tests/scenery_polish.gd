extends SceneTree
var game: Node3D
var session: Node
var output:=preload("res://tests/test_support.gd").output_dir()
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,text_: String) -> void:
	print("PASS " if ok else "FAIL ",text_)
	if not ok: failures.append(text_)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
	print("CAPTURE ",label_)
func travel(p: Vector3,yaw_: float,pitch_: float,distance_: float) -> void:
	game.bunny.position=p
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	game.yaw=yaw_
	game.pitch=pitch_
	game.distance_=distance_
	await create_timer(1.3).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	session.active=false
	session.authority.state.time=1700
	await travel(Vector3(0,.1,6),.25,.44,11)
	game.hud.visible=false
	await capture("场景细化-喷泉白天")
	check(game.life.butterflies.size()==8,"Eight original-style butterflies restored")
	var butterfly_start: Vector3=game.life.butterflies[0].node.position
	await create_timer(.3).timeout
	check(game.life.butterflies[0].node.position.distance_to(butterfly_start)>.01,"Butterflies fly and flap")
	session.authority.state.time=3300
	await create_timer(.7).timeout
	var ids: Array[int]=[]
	var distant:=0
	for lamp_ in game.lamps:
		if lamp_.get_node("NightLight").visible:
			ids.append(lamp_.get_instance_id())
			if lamp_.position.distance_to(game.bunny.position)>30: distant+=1
	check(ids.size()==game.lamps.size() and distant>0,"Distant streets are lit independently of player position")
	await capture("场景细化-喷泉夜晚")
	await travel(Vector3(-30,.1,14),-.6,.22,17)
	var same:=true
	for lamp_ in game.lamps:
		if not lamp_.get_node("NightLight").visible or not ids.has(lamp_.get_instance_id()): same=false
	check(same,"Walking across city preserves every active street light")
	await capture("场景细化-远处街灯")
	session.authority.state.time=1700
	await travel(Vector3(5,.1,36),-.45,.50,17)
	await capture("场景细化-海滩白天")
	await travel(Vector3(13,.1,42),PI+.2,.26,16)
	await capture("场景细化-海岸浪花")
	session.authority.state.time=2750
	await travel(Vector3(4,.1,34),-.6,.32,17)
	await capture("场景细化-海滩黄昏")
	session.authority.state.time=1700
	await travel(Vector3(0,.1,9),.12,.35,12)
	var teacher: CharacterBody3D=game.get_node("CatTeacher")
	teacher.position=Vector3(1.8,.1,7.4)
	teacher.reset_physics_interpolation()
	game.current_target="CatTeacher"
	game.interact()
	game.hud.visible=true
	await create_timer(.5).timeout
	await capture("猫咪老师-小岛NPC")
	print("SCENERY_POLISH_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
