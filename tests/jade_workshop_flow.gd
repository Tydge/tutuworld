extends SceneTree
const DB=preload("res://scripts/services/game_data.gd")
const J=preload("res://scripts/jade/layout.gd")
const Land=preload("res://scripts/building/parcels.gd")
const Stock=preload("res://scripts/building/warehouse.gd")
const Layout=preload("res://scripts/building/layout.gd")
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var out:=preload("res://tests/test_support.gd").output_dir()
	var s:=preload("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("檐下织工","bunny","bell_red")
	s.state().map_id="jade";s.state().player_position=J.arrival()
	var city=load("res://scenes/jade.tscn").instantiate();root.add_child(city);current_scene=city
	while city.preparing or city.camera==null:await process_frame
	city.bunny.set_physics_process(false);var authority: RefCounted=s.authority
	for slot in ["head","body","neck"]:
		for rank in ["folk","court","loom"]:
			var group: Array=DB.Clothes.items().keys().filter(func(id):return DB.item(id).slot==slot and DB.item(id).get("rank","")==rank)
			check(group.size()==2,slot+" "+rank+" has two distinct styles")
			for id in group:
				if rank=="loom":check(not DB.Clothes.data().shop_stock.has(DB.item(id).style) and not DB.item(id).has("price") and DB.recipe(id).get("output","")==id,"Workshop-only "+id)
	for npc in city.npcs:
		var outfit: Dictionary=npc.get_meta("equipment")
		check(outfit.has("head") and outfit.has("body") and outfit.has("neck") and not npc.find_children("Wardrobe_body*","Node3D",true,false).is_empty(),"Worn outfit "+str(npc.name))
	var p:=Land.sign_position(J.LOTS[0]);city.bunny.position=p;s.set_player_position(p)
	check(s.buy_land(J.LOTS[0]).ok,"Purchase first residential parcel")
	var editor: Node=city.build_mode
	check(editor.open_editor(J.LOTS[0]).ok,"Open build mode at the land sign")
	editor.ui.show_category("仓库");check(editor.ui.empty_warehouse.visible,"Empty warehouse guidance")
	for id in Stock.RECIPES:
		for mat in Stock.RECIPES[id]:authority.add(mat,Stock.RECIPES[id][mat])
	editor.ui.show_category("制作")
	for id in Stock.RECIPES:await editor.ui.choose_card("make:"+id)
	editor.ui.show_category("仓库")
	for i in range(80):
		await process_frame;RenderingServer.force_draw()
		if Stock.RECIPES.keys().all(func(id):return editor.ui.card_images["object:"+id].texture!=null):break
	for id in Stock.RECIPES:check(authority.count(id)==1 and editor.ui.cards["object:"+id].visible and editor.ui.card_images["object:"+id].texture!=null,"Finished warehouse icon "+id)
	check(not editor.ui.empty_warehouse.visible,"Finished furniture replaces empty message")
	root.get_texture().get_image().save_jpg(out+"/warehouse.jpg",.90)
	editor.choose_tool("object:jade_chime")
	check(editor.place_at(Vector2(78,91)) and authority.count("jade_chime")==0,"Place chime from warehouse")
	check(not editor.ui.cards["object:jade_chime"].visible,"Depleted stock leaves the warehouse")
	editor.undo();check(authority.count("jade_chime")==1,"Undo restores one finished chime")
	editor.redo();check(authority.count("jade_chime")==0,"Redo consumes the same piece")
	var trades: Dictionary={"spice":"jade_steam_table","almond":"jade_pastry_board","tools":"jade_smith_rack","farm":"jade_seed_bins"}
	for trade in trades:
		var facade: Node=city.scenery.get_node("Shop_"+trade+"/Front")
		var kinds: Array=facade.get_children().map(func(child):return child.get_meta("furniture_kind",""))
		check(not kinds.has("jade_goods"),"Dedicated shop display has clear counter space "+trade)
		check(kinds.has(trades[trade]) and preload("res://scripts/building/catalog.gd").OBJECTS.has(trades[trade]),"Placeable trade display "+trade)
	var home: Dictionary=editor.layout.duplicate(true);home.elements.clear()
	home.elements.append({"id":"build_400","type":"object","kind":"jade_cottage","position":[82,94],"yaw":0,"storey":0})
	home.elements.append({"id":"build_401","type":"object","kind":"chair","position":[82,94],"yaw":0,"storey":0})
	check(Layout.validate(home,"jade").ok,"Place a chair inside the buildable cottage")
	print("JADE_WORKSHOP_FLOW failures=",failures)
	city.free();s.free();quit(1 if failures else 0)
