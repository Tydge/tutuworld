extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var game: Node3D
var session: Node
var failures: Array[String]=[]
var checks:=0
var output:=preload("res://tests/test_support.gd").output_dir()
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func capture(label_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label_+".png")
func press_f() -> void:
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_F
	key.keycode=KEY_F
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	key=InputEventKey.new()
	key.physical_keycode=KEY_F
	key.keycode=KEY_F
	key.pressed=false
	Input.parse_input_event(key)
	await process_frame
func travel(position_: Vector3) -> void:
	game.bunny.position=position_
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	session.set_player_position(position_)
	await create_timer(.4).timeout
func run() -> void:
	root.size=Vector2i(1440,900)
	session=load("res://scripts/services/session.gd").new()
	session.name="Session"
	root.add_child(session)
	game=load("res://scenes/city.tscn").instantiate()
	root.add_child(game)
	await create_timer(.8).timeout
	session.active=false
	var neck_count:=0
	for id in DB.catalog().items:
		if DB.item(id).get("slot","")=="neck": neck_count+=1
	check(neck_count==6,"Three plaid scarves and three colored-band bells are sold")
	var cat: CharacterBody3D=game.get_node("CatTeacher")
	check(cat.get_meta("equipment").get("neck","")=="bell_red","Cat NPC wears a red-band bell via shared equipment")
	var dressed:=0
	for npc in game.npcs:
		if npc!=cat and npc.get_meta("equipment").has("neck"): dressed+=1
	check(dressed==2,"Exactly two other randomly selected NPCs wear neck accessories")
	var base:=Animals.create("cat_teacher")
	check(base.find_children("InnerEar*","Node",true,false).is_empty(),"No contrasting inner ear patch")
	check(base.find_children("Wardrobe*","Node",true,false).is_empty(),"Cat base model has no baked accessories")
	check(base.get_node("Visual/Head/RoundCatHead").mesh is ArrayMesh,"Cat ears and head are one continuous surface")
	base.free()
	session.authority.state.coins=2000
	await travel(Vector3(6,.1,-20))
	for id in DB.catalog().items:
		if DB.item(id).get("slot","")!="neck": continue
		check(session.dispatch("buy",{"shop":"clothes","item":id}).ok,"Buy "+id)
		check(session.dispatch("equip",{"slot":"neck","item":id}).ok,"Equip "+id)
		for actor in [game.bunny,cat]:
			Outfit.apply(actor,{"neck":id})
			check(actor.has_node("Visual/Wardrobe_neck"),"One shared neck wearable fits "+actor.rig_profile.species_id+": "+id)
	check(not session.dispatch("equip",{"slot":"head","item":"bell_red"}).ok,"Neck accessory cannot occupy head slot")
	session.authority.add("bow_rose",1)
	session.authority.add("vest_sage",1)
	session.dispatch("equip",{"slot":"head","item":"bow_rose"})
	session.dispatch("equip",{"slot":"body","item":"vest_sage"})
	session.dispatch("equip",{"slot":"neck","item":"bell_red"})
	check(session.state().equipment.head=="bow_rose" and session.state().equipment.body=="vest_sage" and session.state().equipment.neck=="bell_red","Three independent slots coexist")
	check(game.bunny.get_node("Visual/Head/Wardrobe_head").position.x<-.3 and cat.rig_profile.bow_offset.x<-.3,"Bows sit below one ear for both species")
	check(game.bunny.has_node("Visual/Wardrobe_neck/GoldenBell"),"Bell is an independent yellow mesh")
	for style in ["bell_red","bell_blue","bell_green"]:
		Outfit.apply(cat,{"neck":style})
		check(cat.get_node("Visual/Wardrobe_neck/GoldenBell").material_override.albedo_color.is_equal_approx(Color("efc34d")),"Bell stays gold with "+style)
	# New and old two-slot saves use the same loader without touching the real save.
	session.test_mode=false
	session.save_path="user://qa_neck_%d.json"%Time.get_ticks_usec()
	check(session.save_game(),"Save all three slots")
	var restored=load("res://scripts/services/session.gd").new()
	restored.save_path=session.save_path
	restored.load_save()
	check(restored.state().equipment==session.state().equipment,"Neck slot survives reload")
	restored.free()
	var raw={"schema":2,"saved_at":Time.get_unix_time_from_system(),"state":session.snapshot(),"settings":session.settings.duplicate()}
	raw.state.equipment.erase("neck")
	var file:=FileAccess.open(session.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	restored=load("res://scripts/services/session.gd").new()
	restored.save_path=session.save_path
	restored.load_save()
	check(restored.state().equipment.neck=="" and restored.state().equipment.head=="bow_rose","Legacy two-slot save loads with empty neck slot")
	restored.free()
	DirAccess.remove_absolute(session.save_path)
	DirAccess.remove_absolute(session.save_path+".bak")
	session.test_mode=true
	game.hud.open_panel("wardrobe")
	await create_timer(.3).timeout
	await capture("更新-三位置换装界面")
	game.hud.close_panel()
	# Test all butterfly wing pivots, not just the first butterfly's position.
	game.life.daylight=1
	var wing_min: Array[float]=[]
	var wing_max: Array[float]=[]
	for butterfly in game.life.butterflies:
		wing_min.append(100)
		wing_max.append(-100)
	for i in range(15):
		await create_timer(.025).timeout
		for j in range(game.life.butterflies.size()):
			var b: Dictionary=game.life.butterflies[j]
			wing_min[j]=minf(wing_min[j],b.wings[0].rotation.z)
			wing_max[j]=maxf(wing_max[j],b.wings[0].rotation.z)
	var flapping:=true
	var above_ground:=true
	for i in range(wing_min.size()):
		flapping=flapping and wing_max[i]-wing_min[i]>.8
		above_ground=above_ground and game.life.butterflies[i].node.position.y>1.5
	check(flapping and above_ground,"All eight butterflies flap and stay comfortably above ground")
	session.authority.state.time=3300
	game.update_lighting()
	await create_timer(.1).timeout
	var hidden:=true
	for b in game.life.butterflies: hidden=hidden and not b.node.visible
	check(hidden and game.life.motes.visible,"Night hides every butterfly and leaves fireflies")
	session.authority.state.time=1700
	game.update_lighting()
	await create_timer(.1).timeout
	var returned:=true
	for b in game.life.butterflies: returned=returned and b.node.visible
	check(returned,"Butterflies return in daylight")
	# Empty nearest bed must not hide a nearby crop's shortcut.
	session.authority.state.plots.plot_00={"crop":"carrot","growth":0.0,"water_stage":-1,"weed_stage":0}
	game.refresh_world()
	session.authority.add("watering_can",1)
	session.authority.add("herbicide",2)
	await travel(Vector3(23.5,.1,-5.4))
	game.yaw=.30
	game.pitch=.48
	game.distance_=10
	game.update_target()
	check(game.current_target=="plot_01" and game.quick_action.is_empty(),"F never affects a different crop when the selected bed is empty")
	await travel(Vector3(22.4,.1,-6.2))
	game.update_target()
	check(game.current_target=="plot_00" and game.quick_action.target==game.current_target,"E, F and the floating marker share the selected crop")
	check(game.hud.prompt.text.contains("F   快捷互动"),"HUD advertises the F shortcut")
	await create_timer(.5).timeout
	game.hud.toast.hide()
	await capture("更新-F快捷互动提示")
	session.active=true
	await press_f()
	check(session.job().get("verb","")=="water" and not game.hud.overlay.visible,"Actual F key begins watering without opening a panel")
	await create_timer(.55).timeout
	check(game.hud.ring.visible and game.tools.verb=="water","Shortcut uses existing progress ring, animation and held tool")
	await capture("更新-F快捷浇水")
	await create_timer(1.6).timeout
	check(session.authority.count("watering_can")==1 and not session.authority.needs(session.state().plots.plot_00).water,"Water finishes after two seconds without consuming the can")
	session.active=false
	var plot: Dictionary=session.state().plots.plot_00
	plot.growth=1200
	plot.water_stage=0
	plot.weed_stage=0
	await press_f()
	check(session.job().get("verb","")=="water","When both care needs exist, shortcut starts watering first")
	game.cancel_action()
	plot.water_stage=1
	await press_f()
	check(session.job().get("verb","")=="weed","Next required care can be selected with the same key")
	session.active=true
	await create_timer(2.15).timeout
	check(session.authority.count("herbicide")==1 and not session.authority.needs(plot).weed,"Shortcut consumes exactly one herbicide on completion")
	session.active=false
	plot.growth=3600
	await press_f()
	check(session.job().get("verb","")=="harvest","Ripe crops offer shortcut harvesting")
	session.active=true
	await create_timer(2.15).timeout
	check(session.authority.count("carrot")==3 and session.state().plots.plot_00.crop=="","Shortcut harvest delivers crops")
	await travel(Vector3(0,.1,9))
	check(not game.quick_interact().ok and session.job().is_empty(),"Shortcut cannot affect distant crops")
	game.hud.open_panel("bag")
	check(not game.quick_interact().ok,"Shortcut does not run behind an open panel")
	game.hud.close_panel()
	check(game.hud.root_ui.find_children("*","Label",true,false).all(func(label_): return label_.text!="兔兔的世界" and label_.text!="今天，慢慢做点小事"),"Both top-left cards have been removed")
	await capture("更新-清爽游戏界面")
	print("NECK_QUICK_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
