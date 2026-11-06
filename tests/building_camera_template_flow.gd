extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
var checks:=0
var failures: Array=[]
var output: String
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func bounds(node: Node3D) -> AABB:
	var box:=AABB();var first:=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		var part: AABB=mesh.global_transform*mesh.get_aabb()
		box=part if first else box.merge(part);first=false
	return box
func faces(node: Node3D,side_only: bool=false) -> Array:
	var result: Array=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		for s in range(mesh.mesh.get_surface_count()):
			var a: Array=mesh.mesh.surface_get_arrays(s);var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count: int=indices.size() if not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size()
			for i in range(0,count,3):
				var idx: int=indices[i] if not indices.is_empty() else i;var normal: Vector3=mesh.global_basis*a[Mesh.ARRAY_NORMAL][idx]
				var axis:=normal.abs().max_axis_index()
				if absf(normal[axis])<.9999 or (side_only and axis==1):continue
				var points: Array=[]
				for j in range(3):points.append(mesh.to_global(a[Mesh.ARRAY_VERTEX][indices[i+j] if not indices.is_empty() else i+j]))
				var u: int=(axis+1)%3;var v: int=(axis+2)%3;var polygon:=PackedVector2Array()
				for p in points:polygon.append(Vector2(p[u],p[v]))
				result.append({"axis":axis,"sign":signf(normal[axis]),"plane":points[0][axis],"polygon":polygon})
	return result
func overlap_area(first: Array,second: Array) -> float:
	var total:=0.
	for a in first:
		for b in second:
			if a.axis!=b.axis or a.sign!=b.sign or absf(a.plane-b.plane)>.00001:continue
			# Work near zero to keep clipping/area calculations stable at world x=140.
			var origin: Vector2=a.polygon[0];var pa:=PackedVector2Array();var pb:=PackedVector2Array()
			for p in a.polygon:pa.append(p-origin)
			for p in b.polygon:pb.append(p-origin)
			for polygon in Geometry2D.intersect_polygons(pa,pb):
				var area:=0.
				for i in range(polygon.size()):area+=polygon[i].cross(polygon[(i+1)%polygon.size()])*.5
				total+=absf(area)
	return total
func capture(name_: String) -> Image:
	await process_frame;RenderingServer.force_draw()
	var frame:=root.get_texture().get_image();frame.save_png(output+"/"+name_+".png");return frame
func sweep(city: Node3D,label_: String,pivot: Vector3,offset: Vector3) -> void:
	var max_error:=0.;var max_changed:=0.
	for i in range(8):
		city.camera.position=pivot+offset.rotated(Vector3.UP,(i-3.5)*.035);city.camera.look_at(pivot)
		var moving: Image=await capture(label_+"-move-%d"%i)
		for j in range(5):await process_frame;RenderingServer.force_draw()
		var stable:=root.get_texture().get_image();var error:=0.;var changed:=0;var samples:=0
		var center:=Vector2i(moving.get_width()/2,moving.get_height()/2)
		for y in range(center.y-90,center.y+90,3):
			for x in range(center.x-130,center.x+130,3):
				var a:=moving.get_pixel(x,y);var b:=stable.get_pixel(x,y);var difference:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				error+=difference;samples+=1
				if difference>.08:changed+=1
		max_error=maxf(max_error,error/samples);max_changed=maxf(max_changed,float(changed)/samples)
	print("JOIN_MOTION ",label_," max_mean_error=",max_error," max_changed_fraction=",max_changed)
	check(max_error<.015 and max_changed<.03,"Moving-to-rest material region has no settling flash: "+label_)
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("镜头样板验证兔","bunny","bow_rose");session.state().time=.4*3600.
	var city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1440,900);await create_timer(.7).timeout
	city.distance_=12.;var pan:=InputEventPanGesture.new();pan.position=root.get_final_transform()*Vector2(700,300);pan.delta=root.get_final_transform().basis_xform(Vector2(0,.25))
	var motion:=InputEventMouseMotion.new();motion.position=pan.position;Input.parse_input_event(motion);await process_frame
	Input.parse_input_event(pan);await process_frame
	print("ZOOM_TEST play=",city.distance_," transform=",root.get_final_transform())
	check(city.distance_>12. and city.distance_<13.,"Actual dispatched trackpad gesture zooms play camera")
	var play_distance: float=city.distance_
	city.paused=true;city._unhandled_input(pan);check(is_equal_approx(city.distance_,play_distance),"Paused game ignores camera gestures");city.paused=false
	var editor=city.build_mode;editor.open_editor();editor.set_process(false);editor.distance_=38.
	# Showing the dock recalculates GUI hover; establish the scene pointer again
	# before dispatching the gesture (also robust to macOS Retina window resize).
	await process_frame;motion.position=root.get_final_transform()*Vector2(200,180);Input.parse_input_event(motion);await process_frame;pan.position=motion.position
	Input.parse_input_event(pan);await process_frame
	print("ZOOM_TEST build=",editor.distance_)
	check(editor.distance_>38. and editor.distance_<42.,"Actual dispatched trackpad gesture zooms build camera")
	var build_distance: float=editor.distance_
	var field:=LineEdit.new();editor.ui.root_ui.add_child(field);field.grab_focus();editor._unhandled_input(pan)
	check(is_equal_approx(editor.distance_,build_distance),"Typing in an editor field blocks camera gestures");field.release_focus();field.queue_free()
	var pinch:=InputEventMagnifyGesture.new();pinch.factor=1.25;editor._unhandled_input(pinch)
	check(is_equal_approx(editor.distance_,build_distance/1.25),"Build camera also supports pinch zoom")
	for kind in ["single_one","two_storey"]:
		check(editor.commit(L.empty()),"Reset isolated layout for "+kind);editor.ui.choose_card("template:"+kind)
		check(not editor.ui.rotate_button.disabled,"Template exposes rotation button")
		var source: Dictionary=editor.template_source();var preview_id:=0
		for i in range(4):
			editor.update_ghost(Vector2(100,10))
			if preview_id==0:preview_id=editor.preview.get_instance_id()
			check(editor.preview.get_instance_id()==preview_id,"Rotation reuses complete template preview")
			editor.ui.rotate_button.pressed.emit()
		check(editor.rotation==0.,"Four turns return to original orientation")
		for turn in [0.,90.,180.,270.]:
			editor.ui.choose_card("template:"+kind)
			for i in range(roundi(turn/90.)):editor.ui.rotate_button.pressed.emit()
			editor.update_ghost(Vector2(100,10))
			var expected: Dictionary={};var candidate: Dictionary=editor.candidate_layout(editor.row_at(Vector2(100,10)))
			for i in range(source.elements.size()):
				if source.elements[i].type in ["object","stairs","roof","door","window"]:expected[candidate.elements[i].id]=bounds(editor.preview.render_cache[source.elements[i].id].node)
			check(editor.place_at(Vector2(100,10)),"Rotated whole house places: %s/%d"%[kind,turn])
			var mismatch:=0
			for id in expected:
				var actual:=bounds(editor.room.render_cache[id].node);var box: AABB=expected[id]
				if actual.position.distance_to(box.position)>.003 or actual.size.distance_to(box.size)>.003:mismatch+=1;print("PREVIEW_MISMATCH ",kind," ",turn," ",id," actual=",actual," preview=",box)
			check(mismatch==0,"Rendered placement matches rotated preview including roof and attachments")
			editor.undo();check(editor.layout.elements.is_empty(),"Undo removes the complete rotated sample")
			editor.redo();check(not editor.layout.elements.is_empty(),"Redo restores the rotated sample")
			if kind=="two_storey" and turn==90.:
				editor.set_storey(2);editor.focus=Vector3(100,3,10);editor.update_camera();editor.ui.hide();editor.grid.hide();await capture("rotated-two-storey");editor.ui.show()
			editor.undo()
	check(editor.commit(T.player_sample("two_storey")),"Actual player sample for material joins")
	editor.set_storey(1);editor.set_roof_visible(true);editor.ui.hide();editor.grid.hide();city.set_process(false);city.bunny.set_physics_process(false);city.bunny.hide();editor.room.set_process(false)
	var floor_faces:=faces(editor.room.get_node("Structure/Floor"),true);var walls:=faces(editor.room.get_node("Structure/Walls"),true)
	check(overlap_area(floor_faces,walls)<.000001,"Real slab side faces never share a facing plane with wall fascia")
	var journal: Node3D
	for entry in editor.room.render_cache.values():
		if entry.row.get("kind","")=="field_journal":journal=entry.node;break
	check(journal!=null,"Actual journal found")
	if journal!=null:
		check(overlap_area(faces(journal.get_node("Part_cover")),faces(journal.get_node("Part_pages")))<.000001,"Real book cover and pages have no coincident visible faces")
		await sweep(city,"journal",journal.global_position+Vector3(0,.055,0),Vector3(.65,.28,.85))
	await sweep(city,"wall-floor-seam",Vector3(140.5,4.75,17.5),Vector3(3,.8,5))
	print("BUILDING_CAMERA_TEMPLATE_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
