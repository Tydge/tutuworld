extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Layout=preload("res://scripts/building/layout.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var out:=preload("res://tests/test_support.gd").output_dir()

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func photo(label_: String) -> void:
	for i in range(4):await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_png(out+"/"+label_+".png")

func run() -> void:
	session=preload("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
	session.settings.background_throttle=false
	check(session.create_character("雪镇试衣","cat_teacher","scarf_red").ok,"Cat character created")
	session.state().map_id="icefield";session.state().player_position=L.arrival();session.state().time=1800.
	game=preload("res://scenes/icefield.tscn").instantiate();root.add_child(game);current_scene=game
	while not game.camera or not game.navigation.ready_for_paths or game.preparing:await process_frame
	session.active=false
	var actor: CharacterBody3D=game.bunny
	actor.network_controlled=true;actor.run_enabled=true
	game.hud.hide()
	for b in L.BUILDINGS:
		var shop: bool=b.kind=="shop"
		var room: Node3D=game.scenery.get_node(("Shop_" if shop else "Room_")+b.id)
		check(room in game.interiors,"Indoor view registered "+b.id)
		actor.position=room.to_global(Vector3(0,.26,7.))
		actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
		actor.network_direction=Vector3.FORWARD
		for tick in range(74):await physics_frame
		check(room.contains_position(actor.position) and actor.is_on_floor(),"Walk in through doorway "+b.id)
		if not shop:
			check(room.cutaway and room.get_node("Furnishing").visible and room.get_node("Furnishing").get_children().all(func(n):return n is Light3D or Catalog.OBJECTS.has(n.get_meta("furniture_kind",""))),"Interior uses placeable furniture "+b.id)
		if b.id in ["bakery","home_a"]:
			actor.network_direction=Vector3.ZERO
			game.set_process(false)
			game.camera.position=room.to_global(Vector3(1.8,7.3,10.8));game.camera.look_at(room.to_global(Vector3(0,.6,-.3)))
			await photo(b.id)
			game.set_process(true)
		actor.network_direction=Vector3.BACK
		for tick in range(92):await physics_frame
		check(not room.contains_position(actor.position) and room.to_local(actor.position).z>5.2,"Walk back to street "+b.id)
	actor.network_direction=Vector3.ZERO
	var chair_id:="winter_seat:home_a:petal_armchair_3"
	var chair: Node3D=game.targets[chair_id].node
	actor.position=chair.get_node("ExitAnchor").global_position
	actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();await physics_frame
	game.current_target=chair_id;game.interact()
	check(game.nap_active,"Use the library armchair through the normal interaction")
	game.interact()
	check(not game.nap_active and game.scenery.get_node("Room_home_a").contains_position(actor.position),"Stand up inside the library")
	var baker: Dictionary=game.targets.SnowBaker
	actor.position=baker.node.position+Vector3(1.65,0,0);actor.velocity=Vector3.ZERO
	actor.reset_physics_interpolation();await physics_frame
	check(preload("res://scripts/city/conversation_access.gd").can_talk(game,actor,baker),"Baker is within conversation reach")
	game.current_target="SnowBaker";game.interact()
	check(game.talking_npc=="SnowBaker" and ("面包" in game.dialogue_text or "奶香" in game.dialogue_text),"Baker speaks bakery dialogue")
	game.end_dialogue()
	var tailor: Node3D=game.targets.FrostMerchant_clothes.node
	actor.position=tailor.position+Vector3(0,0,2.05);actor.reset_physics_interpolation();actor.velocity=Vector3.ZERO
	session.set_player_position(actor.position);session.state().coins=99999
	game.hud.show();game.hud.shop="clothes";game.hud.open_panel("shop")
	var styles: Dictionary={};var slots: Dictionary={}
	for id in DB.catalog().items:
		var item:=DB.item(id)
		if item.get("shop_map","")!="icefield":continue
		var button: Array=game.hud.content.find_children("*","Button",true,false).filter(func(n):return n.get_meta("buy_item","")==id)
		check(button.size()==1,"Winter variant is listed in tailor "+id)
		if not button.is_empty():button[0].pressed.emit()
		check(session.authority.count(id)==1 and session.dispatch("equip",{"slot":item.slot,"item":id}).ok,"Buy and wear "+id)
		if not styles.has(item.style):
			styles[item.style]=[];slots[item.slot]=slots.get(item.slot,0)+1
		styles[item.style].append(item.pattern)
	check(slots=={"head":2,"neck":2,"body":2} and styles.values().all(func(v):return v.size()==3 and v.has("snowstar") and v.has("herringbone") and v.has("argyle")),"Six winter cuts, each in three distinct prints")
	var chooser: OptionButton=game.hud.content.find_child("FittingSubject",true,false)
	for i in range(chooser.item_count):
		if chooser.get_item_metadata(i)=="SnowPanda":chooser.item_selected.emit(i);break
	for id in ["pompom_cap_pine","kerchief_frost","duffle_berry"]:game.hud.try_on_clothing(id)
	var player_worn: Dictionary=session.state().equipment.duplicate()
	check(game.hud.character_sheet.preview.species=="panda","Tailor previews the chosen neighbor species")
	game.hud.content.find_child("DressResident",true,false).pressed.emit()
	check(game.targets.SnowPanda.node.get_meta("equipment")=={"head":"pompom_cap_pine","neck":"kerchief_frost","body":"duffle_berry"} and session.state().equipment==player_worn,"Resident wears the requested outfit independently")
	check(session.restore_state(session.snapshot()).state.winter_outfits==session.state().winter_outfits,"Resident outfit survives save conversion")
	await photo("tailor")
	var reset: Array=game.hud.content.find_children("*","Button",true,false).filter(func(b):return b.text=="恢复原装")
	reset[0].pressed.emit()
	var original: Dictionary=game.targets.SnowPanda.node.get_meta("winter_default")
	check(game.targets.SnowPanda.node.get_meta("equipment")==original and game.hud.character_sheet.preview.equipment==original,"Restore the resident and their fitting preview together")
	game.hud.close_panel()
	var data:=Layout.add(Layout.empty(),{"type":"floor","a":[70.,1.],"b":[82.,13.]})
	for i in range(3):
		var kind: String=["bread_case","tile_stove","atlas_stand"][i]
		data=Layout.add(data,{"type":"object","kind":kind,"position":[73.+i*3.,7.],"yaw":90.})
	var saved:=Layout.validate(data)
	check(saved.ok and Layout.normalize(JSON.parse_string(JSON.stringify(data)))==Layout.normalize(data),"New room objects rotate, place and round-trip through building mode")
	check(game.interiors.size()==16,"All sixteen buildings registered once")
	print("WINTER_ROOMS_AND_TAILOR_RESULT ","PASS" if failures.is_empty() else "FAIL"," failures=",failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
