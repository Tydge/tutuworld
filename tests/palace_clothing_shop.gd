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
	check(city.hud.shop_rows.size() == 3, "Palace shelf contains exactly three garments")
	var starting_outfit: Dictionary = session.state().equipment.duplicate()
	for slot: String in OUTFIT:
		var id: String = OUTFIT[slot]
		press_filter(slot)
		check(city.hud.shop_rows.keys() == [id], "Slot filter "+slot)
		city.hud.try_on_clothing(id)
		check(city.hud.character_sheet.preview.equipment[slot] == id and session.state().equipment == starting_outfit,"Preview before purchase "+id)
		city.hud.shop_rows[id].buy.pressed.emit()
		check(session.authority.count(id)==1 and city.hud.shop_rows[id].buy.disabled,"Purchased once "+id)
	press_filter("all")
	var preview: Control = city.hud.character_sheet.preview
	for species in ["bunny","cat_teacher","panda"]:
		preview.update_character(species,OUTFIT)
		preview.actor.visual.rotation.y = .23
		check(preview.actor.find_children("Wardrobe_body_sleeve","Node3D",true,false).size()==2,"Separate articulated sleeves for "+species)
		await photo(preview,species)
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
	var restored: Dictionary = session.restore_state(session.snapshot()).state
	check(restored.equipment==OUTFIT and restored.clothing_designs==session.state().clothing_designs,"Equipment and all three dyes survive save loading")
	tailor.reset.pressed.emit()
	check(not session.state().clothing_designs.has(tailor.chosen) and session.state().clothing_designs.size()==2,"Restore only the selected piece")
	city.hud.close_panel()
	print("PALACE_SHOP failures=",failures)
	city.free()
	session.free()
	quit(int(failures>0))
