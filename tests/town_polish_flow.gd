extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var game: Node3D
var checks:=0
var failures: Array=[]
var OUT=preload("res://tests/test_support.gd").output_dir()+"/"
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	check(session.settings.fps_limit_enabled and session.settings.fps_limit==60 and session.settings.background_throttle,"Power defaults")
	preload("res://scripts/city/frame_pacer.gd").ensure(session);await process_frame
	var pacer:=root.get_node("FramePacer")
	for rate in [60,90,120]:
		session.set_setting("fps_limit",rate);check(pacer.desired_fps()==rate and Engine.max_fps==rate,"Foreground cap "+str(rate))
		pacer.set_background(true);check(pacer.desired_fps()==20 and Engine.max_fps==20,"Background 20 FPS "+str(rate));pacer.set_background(false)
	session.set_setting("fps_limit_enabled",false);check(pacer.desired_fps()==0,"Unlimited foreground")
	pacer.set_background(true);check(pacer.desired_fps()==20,"Background throttle with unlimited foreground")
	session.set_setting("background_throttle",false);check(pacer.desired_fps()==0,"Optional background throttle")
	session.set_setting("fps_limit_enabled",true);session.set_setting("fps_limit",60);session.set_setting("background_throttle",true);pacer.set_background(false)
	for species in ["bunny","cat_teacher","panda"]:
		check(session.create_character("摘橘子"+species.left(3),species,"vest_sage").ok,"Create "+species)
		session.state().resources.city_orange_3.available=true
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.7).timeout
		session.active=false;game.bunny.can_move=false
		var fruit:=DB.resource("city_orange_3");game.bunny.position=Vector3(fruit.x,0,fruit.z+2.5);game.bunny.velocity=Vector3.ZERO;session.set_player_position(game.bunny.position)
		game.bunny.reset_physics_interpolation();game.update_target()
		check(game.current_target==fruit.id and game.hud.prompt.text.contains("采摘"),"Fruit E target and hint "+species)
		check(game.begin_action("gather",fruit.id).ok and game.bunny.action=="harvest_tree","Shared picking animation "+species)
		await create_timer(.3).timeout
		check((game.bunny.left_arm.basis*Vector3.DOWN).y>.4,"Hands reach fruit "+species)
		game.session.authority.tick(2);game.refresh_world();game.finish_action()
		check(not game.resources[fruit.id].visible,"Fruit disappears when picked "+species)
		check(session.authority.count("orange")>=3,"Fruit reaches backpack "+species)
		if species=="bunny":
			var trees: Array=[];var closest:=999.0
			for child in game.scenery.get_children():
				if str(child.name).begins_with("Tree"): trees.append(child)
			for i in range(trees.size()):
				for j in range(i+1,trees.size()): closest=minf(closest,trees[i].position.distance_to(trees[j].position))
			var stale_fruit:=0
			for tree_ in trees:
				for mesh_ in tree_.find_children("*","GeometryInstance3D",true,false):
					if mesh_.material_override is StandardMaterial3D:
						for color in ["eaa34a","dc6655","c8cb6b"]:
							if mesh_.material_override.albedo_color.is_equal_approx(Color(color)): stale_fruit+=1
			check(stale_fruit==0,"No residual decorative fruit after harvest")
			check(closest>=5.39,"Spaced tree trunks: "+str(closest))
			var space:=game.get_world_3d().direct_space_state
			var footprint:=SphereShape3D.new();footprint.radius=.35
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=footprint;query.collision_mask=5
			for r in DB.resources():
				if r.item=="orange": continue
				query.transform=Transform3D(Basis.IDENTITY,Vector3(r.x,.8,r.z))
				check(space.intersect_shape(query,1).is_empty(),"Unobstructed resource "+r.id)
			game.hud.open_panel("profile");await process_frame
			var sheet: Control=game.hud.character_sheet
			check(sheet.pages.has_theme_stylebox_override("tab_hovered") and sheet.pages.get_theme_color("font_hovered_color")==preload("res://scripts/ui/ui_kit.gd").INK,"Themed hover tabs")
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"城镇更新-属性页签.png")
			game.hud.close_panel();game.hud.open_panel("settings");await process_frame
			check(game.hud.content.find_child("FrameLimitEnabled",true,false)!=null and game.hud.content.find_child("BackgroundThrottle",true,false)!=null,"In-game frame settings")
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"城镇更新-帧率设置.png");game.hud.close_panel()
			game.set_process(false)
			for interior in game.interiors:
				var center: Vector3=interior.global_position
				game.bunny.position=center+Vector3(0,.2,1);game.bunny.velocity=Vector3.ZERO
				game.camera.position=center+Vector3(11,12,18);game.camera.look_at(center+Vector3(0,1.5,0))
				await create_timer(.5).timeout
				var flashes:=0
				for i in range(24):
					game.camera.position.x=center.x+11+sin(i*1.8)*.018
					await process_frame
					if interior.sections[0].alpha>.001: flashes+=1
				check(flashes==0,"Roof remains hidden under small camera motion "+str(interior.name))
			game.bunny.position=Vector3(14,.1,28);game.camera.position=Vector3(27,12,45);game.camera.look_at(Vector3(10,0,35))
			await create_timer(.5).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"城镇更新-海岸.png")
			game.camera.position=Vector3(7,6,33);game.camera.look_at(Vector3(15,-.5,56));await create_timer(.2).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"城镇更新-海水远岛.png")
			game.bunny.position=Vector3(12,.1,9);game.camera.position=Vector3(21,9,22);game.camera.look_at(Vector3(10,2,5));session.state().resources.city_orange_2.available=true;game.refresh_world()
			await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"城镇更新-橘子树.png")
		game.queue_free();await process_frame;await process_frame
	print("TOWN_POLISH_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
