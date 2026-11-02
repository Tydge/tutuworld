extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()+"/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func travel(point: Vector3) -> void:
	game.bunny.position=point;game.bunny.velocity=Vector3.ZERO;game.bunny.reset_physics_interpolation();session.set_player_position(point)
	await create_timer(.35).timeout
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label_+".png")
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	for species in (["panda"] if OS.get_cmdline_user_args().has("--panda-only") else ["bunny","cat_teacher"]):
		session.create_character("园丁"+load("res://scripts/characters/animal_catalog.gd").display_name(species),species,"vest_sage")
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(1).timeout
		session.state().time=1800;game.update_lighting();game.hud.toast.hide();game.yaw=.70;game.pitch=.42;game.distance_=8.8
		for item in ["watering_can","pickaxe","stone_hammer"]: session.authority.add(item,1)
		session.authority.add("herbicide",4)
		session.state().plots.plot_00={"crop":"carrot","growth":0.0,"water_stage":-1,"weed_stage":0};game.refresh_world()
		for kind in ["water","weed"]:
			if kind=="weed": session.state().plots.plot_00.weed_stage=-1
			var target: Vector3=game.target_position("plot_00")
			await travel(target+Vector3(0,.2,-1.65))
			game.update_target();await create_timer(.1).timeout
			check(game.hud.prompt_card.visible and root.get_visible_rect().encloses(game.hud.prompt_card.get_global_rect()) and game.hud.prompt.text.contains("F "),"Both E/F instructions stay on-screen: "+species)
			var before: float=session.state().stamina
			check(game.begin_action(kind,"plot_00").ok,"Start "+kind+" "+species)
			check(session.state().stamina==before-1,"Production costs exactly one point at start")
			await create_timer(.9).timeout
			check(game.tools.effects.visible and game.tools.spray.visible,"Visible continuous work effect")
			var nozzle: Vector3=game.tools.prop.get_node("Outlet").get_global_transform_interpolated().origin
			var start: Vector3=game.tools.spray.material_override.get_shader_parameter("start")
			var end: Vector3=game.tools.spray.material_override.get_shader_parameter("finish")
			check(start.distance_to(nozzle)<.035 and end.distance_to(target+Vector3(0,.18,0))<.001,"Effect starts at the real nozzle and lands on the selected plot")
			await capture("新版作业-"+species+"-"+kind)
			await create_timer(1.3).timeout
			check(session.job().is_empty() and not game.tools.effects.visible,"Effect stops on completion")
		check(session.authority.count("watering_can")==1 and session.authority.count("herbicide")==3,"Tool retained; herbicide consumed")
		for item in ["limestone","copper"]:
			game.yaw=PI-.70
			var resource: Dictionary={}
			for candidate in DB.resources():
				if candidate.item==item and session.state().resources[candidate.id].available and (item!="limestone" or candidate.x>-41): resource=candidate;break
			await travel(Vector3(resource.x,.2,resource.z+1.75))
			var result: Dictionary=game.begin_action("gather",resource.id)
			check(result.ok,"Start two-handed "+item+" "+species+" "+result.get("message",""))
			if not result.ok: continue
			await create_timer(.46).timeout
			await capture("新版双手-"+species+"-"+item+"-抬起")
			await create_timer(.30).timeout
			var grip: Vector3=game.bunny.rig_profile.grip_offset
			var right_error: float=game.bunny.right_arm.to_global(grip).distance_to(game.tools.prop.get_node("GripR").global_position)
			grip.x=-grip.x
			var left_error: float=game.bunny.left_arm.to_global(grip).distance_to(game.tools.prop.get_node("GripL").global_position)
			print("TWO_HAND_GRIP ",species," ",item," right=",right_error," left=",left_error," hit=",game.tools.prop.get_node("Impact").global_position.distance_to(game.tools.target_point))
			check(right_error<.04 and left_error<.04,"Both hands actually meet the tool grips")
			check(game.tools.prop.get_node("Impact").global_position.distance_to(game.tools.target_point)<.08,"Strike contacts the resource")
			await capture("新版双手-"+species+"-"+item+"-击中")
			await create_timer(1.5).timeout
			check(session.job().is_empty() and session.authority.count(item)>0,"Shared production finishes with resources")
		game.queue_free();await process_frame;await process_frame
	print("WORK_EFFECTS_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
