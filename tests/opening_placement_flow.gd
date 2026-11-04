extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/geometry.gd")
var city: Node3D
var editor: Node
var checks:=0
var failures: Array=[]
var output: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func capture(name_: String) -> Image:
	for i in range(4):await process_frame;RenderingServer.force_draw()
	var img:=root.get_texture().get_image();img.save_png(output+"/"+name_+".png");return img
func sample(img: Image,p: Vector3) -> Color:
	var pixel: Vector2=city.camera.unproject_position(p)*Vector2(img.get_size())/city.camera.get_viewport().get_visible_rect().size
	return img.get_pixel(int(pixel.x),int(pixel.y))
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("窗前预览兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.5).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);await create_timer(.5).timeout;editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.ui.hide();editor.grid.hide()
	var data:=L.add(L.empty(),{"type":"floor","a":[73.,5.],"b":[85.,15.]})
	for pair in [[[73.,5.],[85.,5.]],[[85.,5.],[85.,15.]],[[85.,15.],[73.,15.]],[[73.,15.],[73.,5.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	data=L.add(data,{"type":"roof","a":[73.,5.],"b":[85.,15.]});check(editor.commit(data),"A complete roof and four solid walls are committed once");editor.set_roof_visible(true);var saved:=JSON.stringify(editor.layout);var ids: Array=editor.layout.elements.filter(func(item):return item.type=="wall" and item.a[1]==15. and item.b[1]==15.).map(func(item):return item.id);var wall: Node3D=editor.room.render_cache[ids[0]].node
	var blue:=StandardMaterial3D.new();blue.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;blue.albedo_color=Color("0088ff");G.box(city,Vector3(79,2.3,13.7),Vector3(3,2.5,.04),blue,"WindowViewReference")
	city.camera.position=Vector3(79,4.2,24);city.camera.look_at(Vector3(79,2.2,15));var before:=await capture("solid-wall-before-placement")
	for family in ["window","door"]:
		for form in (["classic","arch","round"] if family=="window" else ["classic","arch","glass"]):
			editor.choose_tool(family+":"+form);var point: Variant=editor.point_at(city.camera.unproject_position(Vector3(79,2.3,15)));check(point!=null and editor.row_at(point).wall==ids[0],"Mouse ray selects the actual wall in complete view: "+family+"/"+form)
			if point==null:continue
			editor.update_ghost(point);check(is_instance_valid(editor.preview) and editor.preview.visible and not wall.visible and not editor.preview_walls.is_empty(),"Before clicking, the real model and a temporary cut wall are visible: "+family+"/"+form)
			check(editor.room.get_node("Structure/Roof").visible and JSON.stringify(editor.layout)==saved,"Preview preserves the full-roof choice and committed layout: "+family+"/"+form)
			var img:=await capture(family+"-"+form+"-before-click")
			if family=="window":
				var c:=sample(img,Vector3(79.55,2.8,15.14));var old:=sample(before,Vector3(79.55,2.8,15.14));check(c.b>c.r+.12 and absf(c.r-old.r)+absf(c.b-old.b)>.15,"The unplaced window reveals the blue interior through its real opening: "+form)
			check(editor.preview.find_children("*","CollisionObject3D",true,false).all(func(body):return body.collision_layer==0),"Temporary opening geometry never changes walk/pick collision")
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(79,2.8,18),Vector3(79,2.8,14),4);check(not city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"The original solid wall still exists physically before clicking")
			editor.choose_tool("select");check(wall.visible and editor.preview_walls.is_empty() and JSON.stringify(editor.layout)==saved,"Cancel restores the original wall without any save/undo mutation")
	for kind in ["bookshelf","forest_cabinet"]:
		editor.choose_tool("object:"+kind);editor.update_ghost(Vector2(81,14.7));check(editor.preview.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.material_overlay!=null and mesh.material_overlay.no_depth_test),"Wall-snapped furniture also retains a visible placement silhouette: "+kind)
	editor.choose_tool("window:arch");var point: Variant=editor.point_at(city.camera.unproject_position(Vector3(79,2.3,15)));editor.update_ghost(point);editor.hide_preview();check(wall.visible and editor.preview_walls.is_empty(),"Moving over the toolbar restores the original wall instead of leaving a temporary hole");editor.update_ghost(point);editor.set_roof_visible(false);check(wall.visible and editor.preview_walls.is_empty(),"Switching roof/wall view releases temporary replacement geometry");editor.set_roof_visible(true);editor.update_ghost(point)
	check(editor.place_at(point),"Click commits the same window shown in the opening preview");check(editor.layout.elements.size()==data.elements.size()+1 and editor.preview_walls.is_empty(),"Only the actual placement writes one window and releases all temporary walls")
	var existing: Dictionary=editor.layout.elements.filter(func(item):return item.type=="window")[0];var original: Node3D=editor.room.render_cache[existing.id].node
	editor.choose_tool("window:round");point=editor.point_at(city.camera.unproject_position(Vector3(79,2.3,15)));editor.update_ghost(point);check(editor.preview_walls.is_empty() and editor.room.render_cache[ids[0]].node.visible,"An overlapping invalid placement keeps the real wall and shows only the red model silhouette")
	editor.choose_tool("select");editor.selected_id=existing.id;editor.begin_move();point=editor.point_at(city.camera.unproject_position(Vector3(81.5,2.3,15)));check(point!=null,"Moving an existing opening uses the same wall picking as initial placement");editor.update_ghost(point);check(not original.visible and not editor.preview_walls.is_empty(),"Moving an existing window previews its new hole and hides the old frame");editor.choose_tool("select");check(original.visible and editor.preview_walls.is_empty(),"Cancelling a window move restores its original frame and walls")
	print("OPENING_PLACEMENT_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
