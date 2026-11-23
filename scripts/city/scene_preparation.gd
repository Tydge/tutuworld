extends RefCounted
const UI=preload("res://scripts/ui/ui_kit.gd")
static func run(city: Node3D) -> void:
	var start:=Time.get_ticks_msec()
	city.preparing=true
	city.paused=true
	city.bunny.can_move=false
	city.session.active=false
	var cover:=CanvasLayer.new()
	cover.layer=90
	city.add_child(cover)
	var background:=ColorRect.new()
	background.color=Color("f5efdf")
	cover.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new()
	background.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column:=UI.column(18)
	column.theme=UI.theme()
	column.custom_minimum_size=Vector2(430,0)
	center.add_child(column)
	var logo:=TextureRect.new()
	logo.texture=load("res://icon.svg")
	logo.custom_minimum_size=Vector2(110,110)
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(logo)
	var title:=UI.label("海风正在穿过街道…",25)
	if city.map_id=="valley": title.text="溪水正在唤醒山谷…"
	if city.map_id=="jade":title.text="南津灯市正在开张…"
	if city.map_id=="icefield":title.text="雪山与冰原正在迎接你…"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var progress:=ProgressBar.new()
	progress.custom_minimum_size=Vector2(430,14)
	progress.show_percentage=false
	column.add_child(progress)
	var tip:=UI.label("小岛很快就准备好啦",16,UI.MUTED)
	tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tip)
	var focuses: Array[Vector3]=[Vector3(0,1.4,7),Vector3(-5,1.4,-18),Vector3(29,1.4,4),Vector3(-33,1.4,12),Vector3(8,1.4,36),Vector3(15,1.4,33),Vector3(-34,1.5,-1.4)]
	if city.map_id=="valley":
		focuses=[]
		for point in [Vector2(-20,88),Vector2(-24,55),Vector2(0,10),Vector2(-42,-24),Vector2(44,-50),Vector2(24,-68),Vector2(-65,-61)]:
			focuses.append(Vector3(point.x,preload("res://scripts/valley/valley_layout.gd").walk_height(point.x,point.y)+1.4,point.y))
	if city.map_id=="jade":
		focuses=[]
		for p in [Vector2(0,199),Vector2(4,131),Vector2(0,4),Vector2(106,-25),Vector2(0,-63),Vector2(0,-146)]:
			focuses.append(preload("res://scripts/jade/layout.gd").point(p.x,p.y)+Vector3.UP*1.4)
	var view_steps:=0
	if city.map_id=="icefield":
		focuses=[]
		for point in [Vector2(-104,116),Vector2(-64,25),Vector2(-80,-12),Vector2(-80,-70),Vector2(12,16),Vector2(80,-40),Vector2(100,60)]:
			focuses.append(Vector3(point.x,preload("res://scripts/icefield/icefield_layout.gd").walk_height(point.x,point.y)+1.4,point.y))
	for focus in focuses: view_steps+=8 if focus.z>=30 else 4
	var step:=0
	for time_ in [.5,.92]:
		city.update_lighting(time_)
		for focus in focuses:
			var angles:=8 if focus.z>=30 else 4
			for i in range(angles):
				var angle: float=i*TAU/angles
				city.camera.position=focus+Vector3(sin(angle)*13,6,cos(angle)*13)
				city.camera.look_at(focus)
				step+=1
				progress.value=float(step)/(view_steps*2)*100
				await city.get_tree().process_frame
				await RenderingServer.frame_post_draw
		# Prime the actual avatar + cutaway room + local shadow-light variants.
		if is_instance_valid(city.home):
			var original: Vector3=city.bunny.position
			var velocity: Vector3=city.bunny.velocity
			for building in city.interiors:
				city.bunny.position=building.to_global(Vector3(0,building.floor_level,.3))
				city.bunny.velocity=Vector3.ZERO
				city.bunny.reset_physics_interpolation()
				var room_focus: Vector3=city.bunny.position+Vector3(0,1.35,0)
				var views: int=8 if building==city.home else 4
				for i in range(views):
					var angle: float=i*TAU/views
					city.camera.position=room_focus+Vector3(sin(angle)*10.8,8.2,cos(angle)*10.8)
					city.camera.look_at(room_focus)
					building._process(.5)
					await city.get_tree().process_frame
					await RenderingServer.frame_post_draw
			city.bunny.position=original
			city.bunny.velocity=velocity
			city.bunny.reset_physics_interpolation()
			for building in city.interiors: building._process(.5)
	# Warm the portrait's independent render world behind the loading cover;
	# the HUD retains it while other menus are shown.
	city.hud.open_panel("profile")
	for frame in range(4):
		await city.get_tree().process_frame
		await RenderingServer.frame_post_draw
	city.hud.close_panel()
	city.paused=true
	city.update_lighting()
	city.camera_focus=city.bunny.get_global_transform_interpolated().origin+Vector3(0,1.35,0)
	city.camera.position=city.camera_focus+Vector3(sin(city.yaw)*cos(city.pitch),sin(city.pitch),cos(city.yaw)*cos(city.pitch))*city.distance_
	city.camera.look_at(city.camera_focus)
	if is_instance_valid(city.culinary):await city.culinary.warm_models()
	await city.tools.warm_variants()
	await city.get_tree().process_frame
	await RenderingServer.frame_post_draw
	cover.queue_free()
	city.preparing=false
	city.paused=false
	city.bunny.can_move=not city.sleep_active
	city.session.active=true
	print("SCENE_PREPARED ms=",Time.get_ticks_msec()-start)
