extends SceneTree
const DB = preload("res://scripts/services/game_data.gd")
const Outfits = preload("res://scripts/appearance/resident_atelier.gd")
const Designs = preload("res://scripts/appearance/fabric_material.gd")
const Icon = preload("res://scripts/ui/item_icon.gd")
var failures: Array[String] = []
var session: Node
var output := preload("res://tests/test_support.gd").output_dir()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label_: String) -> void:
	if not ok:
		failures.append(label_)
		push_error(label_)

func count_wearers(city: Node, expected: int) -> void:
	var wearers: Array[String] = []
	for actor in city.npcs:
		var equipment: Dictionary = actor.get_meta("equipment")
		if equipment.values().any(func(id): return DB.item(id).get("collection","")=="atelier"):
			wearers.append(str(actor.name))
	print("ATELIER_RESIDENTS ",city.map_id," ",wearers," / ",city.npcs.size())
	check(wearers.size()==expected and wearers.size()*4<=city.npcs.size(),"Automatic wardrobe quota in "+city.map_id)

func run() -> void:
	session = preload("res://scripts/services/session.gd").new()
	session.name = "Session"
	root.add_child(session)
	session.create_character("试衣样衣员","bunny","bow_rose")
	session.authority.state.coins=2500
	var city := preload("res://scenes/city.tscn").instantiate()
	root.add_child(city)
	while city.preparing or not city.navigation.ready_for_paths: await physics_frame
	count_wearers(city,2)
	var anchor: Vector3 = city.targets.Merchant_clothes.node.global_position
	city.bunny.position = anchor+Vector3(0,0,1.2)
	city.bunny.reset_physics_interpolation()
	session.set_player_position(city.bunny.position)
	city.hud.shop="clothes"
	city.hud.open_panel("shop")
	for combo in Outfits.LOOKS:
		for slot in combo:
			var id: String = combo[slot]
			var item := DB.item(id)
			check(Icon.FIELD_ICONS.has(item.style),"Product portrait "+id)
			check(city.hud.shop_rows.has(id),"Store lists "+id)
			var button: Button
			for candidate in city.hud.shop_rows[id].card.find_children("*","Button",true,false):
				if candidate.get_meta("try_on_item","")==id: button=candidate
			check(button!=null,"Try-on entry "+id)
			if button: button.pressed.emit()
			check(city.hud.character_sheet.preview.equipment.get(slot)==id,"Preview "+id)
			check(session.dispatch("buy",{"shop":"clothes","item":id}).ok,"Buy "+id)
			check(session.dispatch("equip",{"slot":slot,"item":id}).ok,"Equip "+id)
			if item.pattern!="solid":
				check(Designs.texture(item.pattern).get_image().has_mipmaps(),"Mipmapped weave "+id)
	city.hud.close_panel()
	session.save_path=output+"/atelier-save.json"
	session.test_mode=false
	check(session.save_game(),"Write isolated wardrobe")
	session.test_mode=true
	var loaded:=preload("res://scripts/services/session.gd").new()
	loaded.save_path=session.save_path
	loaded.load_save()
	check(loaded.state().equipment==session.state().equipment,"Reload equipped slots")
	for combo in Outfits.LOOKS:
		for id in combo.values(): check(loaded.authority.count(id)>0,"Reload owned "+str(id))
	loaded.free()
	city.free()
	for pair in [["valley",0],["icefield",2]]:
		session.authority.state.map_id=pair[0]
		var game: Node=load("res://scenes/"+str(pair[0])+".tscn").instantiate()
		root.add_child(game)
		while game.preparing or not game.navigation.ready_for_paths: await physics_frame
		count_wearers(game,pair[1])
		if pair[0]=="icefield":
			var rack: Dictionary = game.targets.shop_clothing_rack
			game.bunny.position = rack.position+Vector3(.6,.025,0)
			game.bunny.reset_physics_interpolation()
			game.current_target = "shop_clothing_rack"
			game.interact()
			check(game.hud.mode=="tailor","Physical rack opens fitting mirror")
			if game.hud.mode=="tailor":
				var mirror: RefCounted = game.hud.tailoring
				for outfit in Outfits.LOOKS:
					for slot in outfit:
						var garment: String = outfit[slot]
						var index: int = mirror.items.find(garment)
						check(index>=0,"Rack discovers "+garment)
						if index<0: continue
						var tile: Button=mirror.garment_buttons[index]
						check(tile.text.is_empty() and tile.tooltip_text==DB.item(garment).name and tile.get_node("GarmentPicture") is TextureRect,"Garment tile shows its picture and names the item on hover")
						check(tile.get_global_rect().encloses(tile.get_child(0).get_global_rect()),"Thumbnail fits its own hit target")
						tile.pressed.emit()
						check(mirror.chosen==garment and tile.button_pressed,"Pressing the thumbnail selects the garment for dyeing")
						mirror.base_dye.color = Color("617893")
						mirror.pattern_dye.color = Color("eee5ce")
						mirror.material.select(mirror.options.find("oxford_tick"))
						mirror.repaint()
						mirror.apply.pressed.emit()
						check(session.state().clothing_designs.get(garment,{})==mirror.design(),"Rack saves both dyes and weave on "+garment)
				game.hud.close_panel()

			var id: String=game.default_atelier.keys()[0]
			var resident: Node=game.targets[id].node
			var original: Dictionary=resident.get_meta("equipment").duplicate()
			game.apply_resident_outfits({id:{"body":"duffle_frost"}})
			check(resident.get_meta("equipment").body=="duffle_frost","Saved resident choice takes priority")
			game.apply_resident_outfits({})
			check(resident.get_meta("equipment")==original,"Restore sampled outfit")
		game.free()
	await create_timer(.4).timeout
	print("HARVEST_ATELIER_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	quit(0 if failures.is_empty() else 1)
