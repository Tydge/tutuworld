extends SceneTree
const A=preload("res://scripts/building/appearance.gd")
const L=preload("res://scripts/building/layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Catalog=preload("res://scripts/appearance/material_catalog.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
var checks:=0
var failures: Array[String]=[]
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=5) -> void:
	for i in count:await process_frame;RenderingServer.force_draw()
func photo(id: String) -> void:
	await frames(7);root.get_texture().get_image().save_png(out+"/"+id+".png")
func find_button(n: Node,key: String,value: String) -> Button:
	for button in n.find_children("*","Button",true,false):
		if button.get_meta(key,"")==value:return button
	return null
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("共用布料验收兔","bunny","bow_rose")
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.7).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout;await frames(8)
	session.active=false;city.bunny.set_physics_process(false);city.set_process(false)
	city.bunny.position=Vector3(59,.2,13);city.bunny.reset_physics_interpolation()
	var editor: Node=city.build_mode;editor.open_editor();editor.focus=Vector3(79,0,10);editor.distance_=26;editor.update_camera();editor.commit(preload("res://scripts/building/templates.gd").cottage())
	var bed: Dictionary=editor.layout.elements.filter(func(row):return row.get("kind","")=="bed")[0]
	editor.choose_tool("select");editor.selected_id=bed.id;editor.refresh_ui();editor.ui.appearance_panel.open(bed)
	var panel: Control=editor.ui.appearance_panel;panel.parts.select(panel.slot_ids.find("quilt"));panel.parts.item_selected.emit(panel.parts.selected)
	var prior_pixels:=PackedByteArray()
	for id in ["stripes","dots","daisies"]:
		check(id in panel.material_ids,"The real furniture panel discovers a registered fabric: "+id)
		var before:=JSON.stringify(editor.layout)
		panel.materials.select(panel.material_ids.find(id));panel.materials.item_selected.emit(panel.materials.selected);panel.color.color=Color("789eaa");panel.color.color_changed.emit(panel.color.color);await frames()
		check(JSON.stringify(editor.layout)==before and editor.highlighted.is_empty(),"New pattern preview stays unsaved and shows its true colors: "+id)
		panel.find_child("ApplyPartAppearance",true,false).pressed.emit();await frames()
		bed=L.find(editor.layout,bed.id)
		var quilt: MeshInstance3D=editor.room.get_node("Furnishing/"+bed.id).find_child("Quilt",true,false)
		check(bed.appearance.quilt.material==id and quilt.material_override.get_shader_parameter("fabric_mask")==Fabric.texture(id) and Fabric.texture(id)!=null,"Applying the fabric updates the stored part and actual quilt mask: "+id)
		check(quilt.material_override.shader==load("res://assets/shaders/sleep_quilt.gdshader") and is_equal_approx(float(quilt.material_override.get_shader_parameter("pattern_scale")),Catalog.scale_for(id,"quilt")),"Quilt deformation and per-context pattern size are retained: "+id)
		var key: String=editor.ui.selected_thumb_key
		for i in 90:
			if editor.ui.studio.cache.has(key):break
			await frames(1)
		var thumbnail: Texture2D=editor.ui.studio.cache.get(key)
		check(thumbnail!=null and editor.ui.selected_preview.texture==thumbnail,"Saved pattern appears in the selected item thumbnail: "+id)
		if thumbnail!=null:
			var pixels:=thumbnail.get_image().get_data();check(prior_pixels.is_empty() or pixels!=prior_pixels,"Different fabrics have different rendered thumbnails: "+id);prior_pixels=pixels
		await photo("bed-"+id)
	var customized: Dictionary=editor.layout.duplicate(true);editor.undo();check(L.find(editor.layout,bed.id).appearance.quilt.material=="dots","One undo restores the previous fabric choice")
	editor.commit(customized);panel.close();editor.close_editor()
	var shop: Vector2=DB.shops().clothes;city.bunny.position=Vector3(shop.x,.18,shop.y+2.3);session.set_player_position(city.bunny.position);city.bunny.reset_physics_interpolation()
	var hud: Node=city.hud;hud.shop="clothes";hud.open_panel("shop");await frames()
	for id in ["vest_stripes_sage","apron_dots_rose","apron_daisies_sage"]:
		check(hud.shop_rows.has(id) and find_button(hud.content,"try_on_item",id)!=null,"Data-defined garment is offered by the real clothing shop: "+id)
		hud.shop_preview_overrides.clear();find_button(hud.content,"try_on_item",id).pressed.emit();await frames()
		check(hud.character_sheet.preview.equipment.body==id and session.authority.count(id)==0,"Try-on uses the new fabric without buying or changing inventory: "+id)
		var card: Control=hud.shop_rows[id].card
		var ancestor: Node=card.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer:ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(card)
		await photo("shop-"+DB.item(id).pattern)
	var preview: Control=hud.character_sheet.preview
	for species in ["bunny","cat_teacher","panda"]:
		for id in ["vest_stripes_sage","apron_dots_rose","apron_daisies_sage"]:
			preview.update_character(species,{"body":id});await frames()
			var masks: Array=[]
			for mesh in preview.actor.find_children("*","MeshInstance3D",true,false):
				var mat: Material=mesh.material_override
				if mat is ShaderMaterial and mat.get_shader_parameter("fabric_mask")==Fabric.texture(DB.item(id).pattern):masks.append(mesh)
			check(not masks.is_empty(),"Registered fabric renders on the shared species rig: "+species+"/"+id)
		await photo("daisies-"+species)
	hud.close_panel()
	session.authority.add("apron_daisies_sage",1);session.dispatch("equip",{"slot":"body","item":"apron_daisies_sage"})
	var path:=out+"/isolated-save.json";session.save_path=path;session.test_mode=false;var saved: bool=session.save_game();session.test_mode=true
	var recovered=load("res://scripts/services/session.gd").new();recovered.name="MaterialRecovered";root.add_child(recovered);recovered.save_path=path;recovered.load_save()
	check(saved and L.find(recovered.state().build_layout,bed.id).appearance.quilt.material=="daisies" and recovered.state().equipment.body=="apron_daisies_sage","A real isolated save reloads the new furniture pattern and garment IDs")
	print("MATERIAL_EXPANSION_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
