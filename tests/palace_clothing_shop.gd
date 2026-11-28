extends SceneTree

const Jade = preload("res://scripts/jade/layout.gd")
const OUTFIT := {"head":"peony_qitou","body":"cloud_dao_robe","neck":"ruyi_lock"}
const DYE := {"color":"785681","accent":"f3c384","pattern":"sprig"}

var session: Node
var city: Node3D
var failures := 0
var out: String

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func stand(at: Vector3) -> void:
	city.bunny.global_position = at
	city.bunny.reset_physics_interpolation()
	session.set_player_position(at)
	city.update_target()

func press_filter(slot: String) -> void:
	for button in city.hud.content.find_children("*","Button",true,false):
		if button.get_meta("category_filter","") == slot:
			button.pressed.emit()
			return

func photo(preview: Control, name_: String) -> void:
	preview.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 3:
		await process_frame
		RenderingServer.force_draw()
	var picture: Image = preview.viewport.get_texture().get_image()
	check(picture.get_used_rect().has_area() and picture.save_png(out+"/"+name_+".png")==OK, "Fitting portrait "+name_)

func run() -> void:
	# Only the fitting viewports are photographed. Keep the city physics and shop controls live.
	root.disable_3d = true
	out = preload("res://tests/test_support.gd").output_dir()
	session = preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	session.create_character("试衣客","bunny","scarf_green")
	session.state().map_id = "jade"
	session.state().player_position = Jade.arrival()
	session.state().coins = 1000
	city = load("res://scenes/jade.tscn").instantiate()
	root.add_child(city)
	current_scene = city
	while city.preparing or city.camera == null: await process_frame
	city.bunny.set_physics_process(false)
	var room := city.scenery.get_node("Shop_silk") as Node3D
	var vendor: Node3D = city.targets.JadeVendor_silk.node
	stand(vendor.global_position + room.global_basis.z * .95)
	check(city.current_target == "JadeVendor_silk", "E reaches the palace clothier on the ground floor")
	city.interact()
	city.interact()
	if city.hud.mode != "shop" or city.hud.shop != "silk":
		check(false,"Open the palace counter")
		quit(1)
		return
	check(city.hud.shop_rows.size() == 5, "Palace shelf contains both hats, both robes and the pendant")
	var starting_outfit: Dictionary = session.state().equipment.duplicate()
	for slot: String in OUTFIT:
		var id: String = OUTFIT[slot]
		press_filter(slot)
		check(city.hud.shop_rows.has(id) and city.hud.shop_rows.size()==(1 if slot=="neck" else 2), "Slot filter "+slot)
		city.hud.try_on_clothing(id)
		check(city.hud.character_sheet.preview.equipment[slot] == id and session.state().equipment == starting_outfit,"Preview before purchase "+id)
		city.hud.shop_rows[id].buy.pressed.emit()
		check(session.authority.count(id)==1 and city.hud.shop_rows[id].buy.disabled,"Purchased once "+id)
	press_filter("body")
	check(city.hud.shop_rows.imperial_dragon_robe.buy.disabled and not session.dispatch("buy",{"shop":"silk","item":"imperial_dragon_robe"}).ok,"An unaffordable dragon robe cannot be bought")
	session.state().coins+=8888
	city.hud.rebuild()
	var coins: int=session.state().coins
	city.hud.shop_rows.imperial_dragon_robe.buy.pressed.emit()
	check(coins-session.state().coins==8888 and session.authority.count("imperial_dragon_robe")==1,"The palace charges 8888 coins for the dragon robe")
	press_filter("head")
	city.hud.try_on_clothing("imperial_mian")
	city.hud.shop_rows.imperial_mian.buy.pressed.emit()
	check(session.authority.count("imperial_mian")==1,"Buy the rabbit emperor's crown at the palace counter")
	press_filter("all")
	var preview: Control = city.hud.character_sheet.preview
	for species in ["bunny","cat_teacher","panda"]:
		preview.update_character(species,OUTFIT)
		preview.actor.visual.rotation.y = .23
		check(preview.actor.find_children("Wardrobe_body_sleeve","Node3D",true,false).size()==2,"Separate articulated sleeves for "+species)
		await photo(preview,species)
		preview.update_character(species,{"head":"imperial_mian","body":"imperial_dragon_robe","neck":""})
		await photo(preview,"crown-"+species)
	preview.actor.visual.rotation.y = PI + .20
	await photo(preview,"robe_back")
	city.hud.close_panel()
	for slot: String in OUTFIT:
		check(session.dispatch("equip",{"slot":slot,"item":OUTFIT[slot]}).ok,"Equip "+slot)
	var station_id := "jade:silk:Gallery_jade_dress_0"
	stand(city.targets[station_id].position)
	check(city.current_target == station_id,"Upstairs fitting rack is reachable")
	city.interact()
	if city.hud.mode != "tailor":
		check(false,"Open the upstairs fitting mirror")
		quit(1)
		return
	var tailor: RefCounted = city.hud.tailoring
	for id: String in OUTFIT.values():
		tailor.select_item(tailor.items.find(id))
		tailor.material.select(tailor.options.find(DYE.pattern))
		tailor.base_dye.color = Color(DYE.color)
		tailor.pattern_dye.color = Color(DYE.accent)
		tailor.repaint()
		tailor.apply.pressed.emit()
		check(session.state().clothing_designs.get(id,{})==DYE,"Save both dye channels and cloth pattern "+id)
	await photo(tailor.preview,"dyed")
	for id in ["imperial_mian","imperial_dragon_robe"]:
		tailor.select_item(tailor.items.find(id))
		tailor.material.select(tailor.options.find(DYE.pattern))
		tailor.base_dye.color=Color(DYE.color)
		tailor.pattern_dye.color=Color(DYE.accent)
		tailor.repaint()
		tailor.apply.pressed.emit()
		check(session.state().clothing_designs.get(id,{})==DYE,"Save both imperial garment dyes and pattern "+id)
		await photo(tailor.preview,id+"-dyed")
	var restored: Dictionary = session.restore_state(session.snapshot()).state
	check(restored.equipment==OUTFIT and restored.clothing_designs==session.state().clothing_designs,"Equipment and all five dyes survive save loading")
	tailor.reset.pressed.emit()
	check(not session.state().clothing_designs.has(tailor.chosen) and session.state().clothing_designs.size()==4,"Restore only the selected piece")
	city.hud.close_panel()
	var court=city.get_node("StreetLife").imperial_court
	var throne: Node3D=city.targets[court.THRONE].node
	var emperor: CharacterBody3D=city.targets[court.EMPEROR].node
	var resident: CharacterBody3D=city.targets.JadeCitizen_12.node
	check(emperor.rig_profile.species_id=="bunny" and emperor.get_meta("equipment").head=="imperial_mian" and emperor.get_meta("equipment").body=="imperial_dragon_robe" and resident.get_meta("equipment").head!="imperial_mian","Jingzhao is a crowned rabbit and Wenyu remains the bell keeper")
	city.get_node("StreetLife").set_physics_process(false)
	court.update(city,false)
	stand(throne.to_global(Vector3(0,.04,1.7)))
	city.current_target=court.THRONE
	city.interact()
	check(city.nap_active and is_inf(city.bunny.action_length),"Player occupies the throne before the audience")
	court.update(city,true)
	check(city.bunny.seated and not emperor.seated and city.hud.bubble_text.text==court.REQUEST and city.hud.bubble_target==emperor,"The emperor asks the seated player to rise")
	city.hud.hide_dialogue()
	court.update(city,true)
	check(not city.hud.bubble.visible and city.bunny.seated,"The same occupant is not interrupted twice")
	city.interact()
	var initial_phase: float=emperor.step_phase
	var walked:=false
	for i in 220:
		await physics_frame
		if i%12==0:court.update(city,true)
		court.walk(city,1./60.)
		walked=walked or (emperor.is_on_floor() and emperor.step_phase>initial_phase)
		if emperor.seated:break
	check(walked and emperor.seated and emperor.action=="hold_court","Emperor walks to the free throne and holds court")
	stand(throne.to_global(Vector3(0,.04,1.7)))
	city.current_target=court.THRONE
	city.interact()
	check(not city.bunny.seated and emperor.seated,"A player cannot take the occupied throne")
	stand(throne.to_global(Vector3(-3.,.04,3.0)))
	root.disable_3d=false
	city.set_process(false)
	city.hud.hide()
	city.update_lighting(.40)
	var room_art: Node3D=throne.get_parent().get_parent()
	var focus:=throne.global_position+Vector3.UP*1.75
	for camera_side: float in [-.26,1.10]:
		city.camera.global_position=focus+Vector3(camera_side*3.3,.55,5.25)
		city.camera.look_at(focus)
		room_art._process(1.)
		for frame in 4:await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_png(out+("/court-front.png" if camera_side<0. else "/court-side.png"))
	court.update(city,false)
	check(not emperor.seated and not throne.has_meta("resident_occupant"),"After court the throne is released")
	# Ignore calendar drift during photography and start a fresh morning.
	city.hud.show()
	session.state().time=4800.
	emperor.position=emperor.get_meta("court_post")
	stand(throne.to_global(Vector3(0,.04,1.7)))
	city.current_target=court.THRONE
	city.interact()
	court.update(city,true,.01)
	check(city.hud.bubble_name.text=="景昭" and city.hud.bubble_text.text==court.REQUEST,"The emperor speaks under his personal name")
	court.update(city,true,10.1)
	var second_line: String=city.hud.bubble_text.text
	check(emperor.emote=="angry" and city.hud.bubble.visible and second_line!=court.REQUEST,"The second reminder changes the line and plays anger")
	city.hud.hide_dialogue()
	court.update(city,true,14.)
	check(not city.hud.bubble.visible,"Repeated ticks do not reopen the second reminder")
	court.update(city,true,1.1)
	check(city.hud.bubble.visible and city.hud.bubble_text.text not in [court.REQUEST,second_line] and city.bunny.seated,"The final dismissal is visible and leaves the player seated")
	session.sync_current()
	check(int(session.world.get("jade_court_dismissed_day",-2))==1 and not session.characters[session.active_character_id].has("jade_court_dismissed_day"),"The local dismissal is shared across character slots")
	var saved: Dictionary=session.restore_state(session.snapshot()).state
	check(int(saved.get("jade_court_dismissed_day",-2))==1,"Loading the local save keeps the dismissed date")
	city.interact()
	emperor.position=throne.to_global(Vector3(2.08,.03,1.04))
	court.update(city,true,.4)
	check(not emperor.seated,"Rising after the final line does not restart the audience")
	session.state().time+=3600.
	court.update(city,true,.4)
	check(emperor.seated,"The local emperor attends again the next morning")
	while not city.navigation.ready_for_paths or not city.navigation.sampling_ready:
		await physics_frame
	city.free()
	session.free()
	await process_frame
	await process_frame
	print("PALACE_SHOP failures=",failures)
	quit(int(failures>0))
