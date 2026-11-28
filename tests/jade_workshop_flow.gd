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
func draw(editor: Node, card: String, a: Vector2, b: Vector2) -> void:
	editor.ui.choose_card(card)
	var camera: Camera3D=editor.city.camera
	var down:=InputEventMouseButton.new();down.pressed=true;down.button_index=MOUSE_BUTTON_LEFT
	down.position=camera.unproject_position(Vector3(a.x,editor.build_base()+.18,a.y))
	editor._unhandled_input(down)
	var motion:=InputEventMouseMotion.new()
	motion.position=camera.unproject_position(Vector3(b.x,editor.build_base()+.18,b.y))
	motion.relative=motion.position-down.position
	editor._unhandled_input(motion)
	var up:=InputEventMouseButton.new();up.pressed=false;up.button_index=MOUSE_BUTTON_LEFT;up.position=motion.position
	editor._input(up)
	await process_frame

func run() -> void:
	var out:=preload("res://tests/test_support.gd").output_dir()
	var s:=preload("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s)
	check(s.create_character("檐下织工","bunny","scarf_green").ok,"Create a workshop visitor with a legacy green scarf")
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
	var vendor: Node3D=city.targets.JadeVendor_clothes.node
	city.bunny.position=vendor.position+Vector3(0,0,1.1);s.set_player_position(city.bunny.position)
	city.update_target();city.interact();city.interact()
	var shelf: Array=city.hud.shop_rows.keys()
	var jade_styles:=DB.Clothes.items().keys().filter(func(id):return DB.item(id).get("rank","") in ["folk","court"])
	check(city.hud.mode=="shop" and shelf.size()==12 and jade_styles.all(func(id):return id in shelf),"Yunjin merchant stocks exactly the twelve Jade garments")
	check(authority.count("scarf_green")==1 and city.hud.character_sheet.preview.equipment.neck=="scarf_green" and s.state().equipment.neck=="scarf_green","A previously owned island scarf stays worn in the Jade fitting room")
	city.hud.close_panel()
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
	check(not editor.ui.tabs.has("玉京"), "No city-specific catalogue tab")
	for kind in preload("res://scripts/jade/room_furniture.gd").SIZES:
		var furnished:=home.duplicate(true)
		furnished.elements[1].kind=kind
		if kind in ["jade_censer","jade_blossom"]:
			furnished.elements[1].kind="jade_altar_table"
			var decoration: Dictionary={"id":"build_402","type":"object","kind":kind,"yaw":0,"storey":0}
			var mounted:=Layout.attach_at(furnished,decoration,Vector2(82,94),"build_401")
			check(mounted.support=="build_401","Mount "+kind+" on Chinese altar table")
			furnished.elements.append(mounted)
		editor.ui.show_category(preload("res://scripts/building/catalog.gd").OBJECTS[kind].category)
		check(editor.ui.cards["object:"+kind].visible and Layout.validate(furnished,"jade").ok,"Build catalogue and cottage placement "+kind)
	editor.undo()
	editor.ui.show_templates()
	check(editor.ui.cards["template:jade_cottage"].visible and not editor.ui.cards.has("object:jade_cottage"), "Cottage is only listed as a house plan")
	editor.ui.choose_card("template:jade_cottage")
	check(editor.place_at(Vector2(82,94)),"Set up a cottage through the construction editor · "+editor.ui.status.text)
	editor.choose_tool("object:jade_alcove_bed")
	check(editor.place_at(Vector2(82,94)),"Furnish the new cottage with its canopy bed · "+editor.ui.status.text)
	home.elements[1].kind="jade_altar_table"
	var dining=preload("res://scripts/building/dining.gd")
	var slot: Dictionary=dining.slots(home.elements[1])[0]
	home.elements.append({"id":"build_402","type":"object","kind":"jade_moon_chair","position":[slot.position.x,slot.position.y],"yaw":slot.yaw,"storey":0})
	check(dining.links(home).get("build_402","")=="build_401","Chinese table and chair form a dining place")
	editor.clear_plot()
	editor.ui.show_templates()
	editor.ui.choose_card("template:jade_palace")
	var center := Land.bounds(J.LOTS[0]).get_center()
	check(editor.place_at(center) and editor.tool=="select", "Palace placement immediately returns to editing")
	check(not editor.room.get_node("Structure/Roof").is_visible_in_tree(), "Palace roof automatically lifts on the interior storey")
	editor.focus=Vector3(center.x,0,center.y);editor.distance_=42.;editor.pitch=.43
	editor.set_storey(1);editor.update_camera()
	editor.ui.show_category("结构")
	while editor.ui.studio.busy or not editor.ui.studio.pending.is_empty():await process_frame
	for frame in range(4): await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_jpg(out+"/palace-exterior.jpg",.92)
	editor.ui.choose_card("object:jade_throne")
	check(not editor.roof_view and not editor.room.get_node("Structure/Roof").is_visible_in_tree(), "Choosing a chair from the exterior view uncovers the editing floor")
	check(editor.place_at(center), "Place an independent throne inside the palace")
	editor.choose_tool("select")
	var original_cells: int = Layout.usage(editor.layout).floor_cells
	var side: Dictionary = editor.layout.elements.filter(func(row):return row.type=="wall" and row.a[0]==row.b[0] and row.a[0]>center.x)[0]
	var x: float = side.a[0]
	# Aim at solid timber between openings, using the viewport coordinates of a real drag.
	if not editor.top_down: editor.toggle_top_down()
	editor.focus=Vector3(x,0,center.y+2.5);editor.update_camera()
	await process_frame;await physics_frame
	var from := Vector3(x, editor.build_base()+.18, center.y+2.5)
	for i in range(6):
		var mouse: Vector2=city.camera.unproject_position(from+Vector3.RIGHT*i*.2)
		var motion:=InputEventMouseMotion.new();motion.position=mouse;editor.drafting.input(motion)
		var button:=InputEventMouseButton.new();button.position=mouse;button.button_index=MOUSE_BUTTON_LEFT
		if i==0: button.pressed=true;editor.drafting.input(button)
		elif i==5: editor.drafting.release(button)
		await process_frame
	check(Layout.usage(editor.layout).floor_cells>original_cells,"Dragging the palace wall expands its floor and roof: "+editor.ui.status.text)
	check(editor.selected_row().get("type","")=="wall","Wall remains selected after the drag")
	editor.ui.batch_paint.button_pressed=false
	editor.ui.wall_face.select(2)
	editor.paint_selected(Color("498777"),"jade_frame")
	check(editor.selected_row().get("color","")=="498777","Repaint the selected half-metre wall section")
	editor.focus=Vector3(center.x,0,center.y);editor.update_camera()
	for frame in range(4): await process_frame;RenderingServer.force_draw()
	root.get_texture().get_image().save_jpg(out+"/palace-interior.jpg",.92)
	editor.clear_plot()
	var a:=center-Vector2(4.5,3.);var b:=center+Vector2(4.5,3.)
	editor.focus=Vector3(center.x,0,center.y);editor.distance_=34.;editor.update_camera()
	var tile:=a+Vector2(.24,.24)
	await draw(editor,"floor:jade_paving",tile,tile)
	check(Layout.usage(editor.layout).floor_cells==1,"One click lays exactly one half-metre tile")
	await draw(editor,"floor:jade_paving",a,b)
	check(Layout.usage(editor.layout).floor_cells==216,"Drag paving across an existing tile without duplicate floors")
	check(editor.layout.elements.any(func(row):return row.type=="floor" and row.style=="jade_paving"),"Drag to lay a native Jade floor by hand")
	for edge in [[a,Vector2(b.x,a.y)],[Vector2(b.x,a.y),b],[b,Vector2(a.x,b.y)],[Vector2(a.x,b.y),a]]:
		await draw(editor,"wall:jade_red",edge[0],edge[1])
	check(editor.layout.elements.filter(func(row):return row.type=="wall" and row.get("form","")=="jade_frame").size()==4,"Draw four lacquer walls using the regular wall tool")
	editor.ui.choose_card("door:jade_panel")
	check(editor.place_at(Vector2(center.x,b.y)),"Fit a studded double door to a hand-drawn wall")
	editor.ui.choose_card("window:jade_lattice")
	check(editor.place_at(Vector2(center.x,a.y)),"Fit a lattice window to a hand-drawn wall")
	await draw(editor,"roof:jade_double",a,b)
	check(editor.layout.elements.any(func(row):return row.get("form","")=="jade_double"),"Drag a double-eave roof onto the hand-built hall")
	editor.set_storey(1);editor.ui.choose_card("object:jade_altar_table")
	check(editor.place_at(center) and not editor.roof_view,"Furnish the hand-built hall after looking at its exterior")
	var saved:=Layout.normalize(s.state().jade_build_layout,"jade")
	check(saved==editor.layout, "Edited manual construction is in the parcel save")
	editor.clear_plot()
	var legacy:=Layout.add(editor.layout,{"type":"object","kind":"jade_cottage","position":[center.x,center.y],"yaw":90.})
	legacy=Layout.add(legacy,{"type":"object","kind":"chair","position":[center.x,center.y],"yaw":0.})
	check(editor.commit(legacy), "Load an existing furnished one-piece cottage")
	var old_id: String=legacy.elements[0].id;var chair_id: String=legacy.elements[1].id
	await process_frame;await physics_frame
	var old_model: Node3D=editor.room.render_cache[old_id].node.get_node("Carpentry")
	check(not old_model.get_node("Exterior").is_visible_in_tree(),"Legacy cottage roof hides while editing")
	var mouse: Vector2=city.camera.unproject_position(Vector3(center.x,editor.build_base()+.8,center.y))
	editor.select_at(mouse)
	check(editor.selected_id==chair_id,"Select the chair through the old cottage roof")
	editor.selected_id=old_id;editor.selected_unit.clear();editor.refresh_ui()
	check(editor.ui.convert_house_button.visible,"Conversion action is offered for an old house")
	editor.ui.convert_house_button.pressed.emit()
	check(Layout.find(editor.layout,old_id).is_empty() and not Layout.find(editor.layout,chair_id).is_empty() and editor.layout.elements.any(func(row):return row.type=="wall"),"Convert in place while retaining the independent chair")
	editor.undo()
	check(Layout.find(editor.layout,old_id).get("kind","")=="jade_cottage","One undo restores the original cottage")
	editor.redo()
	check(Layout.find(editor.layout,old_id).is_empty() and Layout.find(editor.layout,chair_id).get("kind","")=="chair","Redo restores the editable cottage and chair")
	for kind in ["jade_pavilion","jade_theatre","jade_clocktower","jade_street_gallery"]:
		editor.clear_plot();editor.ui.show_templates();editor.ui.choose_card("template:"+kind)
		check(editor.place_at(center),"Place "+kind+" on the working parcel")
		editor.set_storey(3);editor.ui.show_category("结构")
		if editor.top_down:editor.toggle_top_down()
		editor.focus=Vector3(center.x,8 if kind in ["jade_clocktower","jade_theatre"] else 4,center.y);editor.pitch=.40;editor.distance_=48.;editor.update_camera()
		for frame in range(3):await process_frame;RenderingServer.force_draw()
		root.get_texture().get_image().save_jpg(out+"/"+kind+".jpg",.90)
		if kind=="jade_pavilion":
			check(editor.room.find_children("PierCollision","StaticBody3D",true,false).size()==8,"Four editable wall runs produce the eight pavilion piers")
		if kind=="jade_street_gallery":
			check(editor.room.get_node("Structure/Stairs").get_child_count()==2,"Both walkable stair flights surround the bridge")
	print("JADE_WORKSHOP_FLOW failures=",failures)
	city.free();s.free();quit(1 if failures else 0)
