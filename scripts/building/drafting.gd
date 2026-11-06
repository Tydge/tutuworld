extends Node
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const C=preload("res://scripts/building/catalog.gd")
const Edit=preload("res://scripts/building/room_edit.gd")
var editor: Node
var overlay: Control
var stage: Node3D
var halo: Node3D
var halo_material: ShaderMaterial
var halo_key:=""
var brush: Dictionary={}
var mode:=""
var dragging:=false
var origin_mouse:=Vector2.ZERO
var pointer:=Vector2.ZERO
var origin_world:=Vector2.ZERO
var drag_offset:=Vector2.ZERO
var drag_height_offset:=0.
var grabbed: Dictionary={}
var context: Dictionary={}
var cached_context: Dictionary={}
var context_key:=""
var hover: Dictionary={}
var hover_key:=""
var result: Dictionary={}
var step_key:=""
var tick_at:=0
var originals: Array=[]
var moving: Node3D
var box: MeshInstance3D
var good: StandardMaterial3D
var room_walls: Array=[]
var stationary: Node3D
var wall_valid: Variant=null
var bad: StandardMaterial3D
var pointer_key:=""
func _ready() -> void:
	stage=Node3D.new();stage.name="DraftingPreview";editor.city.add_child(stage)
	halo=Node3D.new();halo.name="BuildSelectionHalo";editor.city.add_child(halo)
	halo_material=ShaderMaterial.new();halo_material.shader=preload("res://assets/shaders/build_selection.gdshader")
	good=StandardMaterial3D.new();good.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;good.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;good.albedo_color=Color(.25,.75,.50,.18)
	bad=good.duplicate();bad.albedo_color=Color(.94,.20,.12,.25)
	for i in range(4):
		var strip:=MeshInstance3D.new();strip.mesh=BoxMesh.new();strip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;stage.add_child(strip);strip.hide();room_walls.append(strip)
	box=MeshInstance3D.new();box.mesh=BoxMesh.new();box.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;stage.add_child(box);box.hide()
	overlay=preload("res://scripts/building/draft_overlay.gd").new();overlay.editor=editor;editor.ui.root_ui.add_child(overlay)
func level() -> int:return editor.editing_storey+(1 if editor.roof_view and editor.tool=="room" else 0)
func ground(mouse: Vector2) -> Variant:return screen_point(mouse,.18+level()*S.HEIGHT)
func base() -> Dictionary:
	var key:=str(editor.layout_revision)+":"+str(level())
	if context_key!=key:cached_context=Edit.prepare(editor.layout,level());context_key=key;hover_key=""
	return cached_context
func clear_stage() -> void:
	for pair in originals:
		if is_instance_valid(pair[0]):pair[0].visible=pair[1]
	originals.clear()
	if is_instance_valid(moving):moving.free()
	moving=null
	if is_instance_valid(stationary):stationary.free()
	stationary=null;wall_valid=null
	for strip in room_walls:strip.hide()
	box.hide();overlay.area=Rect2();overlay.second=Rect2();overlay.wall=[];overlay.queue_redraw()
func cancel() -> void:
	clear_stage();mode="";dragging=false;context={};result={};step_key="";hover={};pointer_key=""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func tool_changed() -> void:
	cancel();brush.clear();halo_key=""
func screen_point(mouse: Vector2,height: float) -> Variant:
	var p: Variant=Plane(Vector3.UP,height).intersects_ray(editor.city.camera.project_ray_origin(mouse),editor.city.camera.project_ray_normal(mouse))
	return Vector2(p.x,p.z) if p!=null else null
func grid_point(p: Vector2) -> Vector2:return Vector2(snappedf(p.x,.5),snappedf(p.y,.5))
func clone_visual(node: Node3D,parent: Node3D,material: Material=null) -> void:
	for source in node.find_children("*","MeshInstance3D",true,false):
		if source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not source.is_visible_in_tree():continue
		if source.material_override is ShaderMaterial and source.material_override.shader.resource_path.get_file() in ["contact_shadow.gdshader","hearth_fire.gdshader","hearth_embers.gdshader","lamp_glow.gdshader"]:continue
		var mesh:=MeshInstance3D.new();mesh.mesh=source.mesh;mesh.material_override=material if material!=null else source.material_override;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh);mesh.global_transform=source.global_transform
func update_halo() -> void:
	if not editor.active or editor.tool not in ["select","eyedropper"] or editor.selected_id=="" or not is_instance_valid(editor.room) or not editor.room.render_cache.has(editor.selected_id):halo.hide();return
	var row: Dictionary=editor.selected_row()
	if row.get("type","") not in ["object","stairs","door","window"]:halo.hide();return
	var node: Node3D=editor.room.render_cache[editor.selected_id].node;var key:=str(node.get_instance_id())+str(editor.layout_revision)
	if key!=halo_key:
		for child in halo.get_children():child.free()
		halo.global_transform=Transform3D.IDENTITY;clone_visual(node,halo,halo_material);halo_key=key
	halo.visible=node.is_visible_in_tree() and not dragging
func show_bounds(area: Rect2,valid: bool=true) -> void:
	overlay.area=area;overlay.floor_y=.23+level()*S.HEIGHT;overlay.color=Color("5bbd96") if valid else Color("e05e48");overlay.queue_redraw()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(editor) and editor.active and mode!="":
		editor.restore_moving();cancel();editor.choose_tool("select")
func begin_wall_preview() -> void:
	moving=Node3D.new();stage.add_child(moving)
	var factory=preload("res://scripts/building/module_factory.gd");var builder=factory.builder(moving)
	for wall in G.runs(context.edges):
		var data:=factory.wall_data(editor.layout,wall,Vector2.ZERO);builder.blueprint.materials.plaster=wall.get("color","eadcc5");builder.build_wall(moving,data)
	for child in moving.get_children():
		if child is Node3D:child.position.y+=editor.editing_storey*S.HEIGHT
	var hide: Dictionary=context.follow.duplicate()
	for wall in context.edges.values():hide[wall.id]=true
	for hole in base().openings:
		if hole.axis==context.along and is_equal_approx(hole.anchor[context.axis],context.plane*.5) and hole.anchor[context.along]>=context.lo*.5 and hole.anchor[context.along]<=context.hi*.5:hide[hole.id]=true
	stationary=Node3D.new();stage.add_child(stationary)
	var remainder: Dictionary={}
	for edge in base().grid.walls:
		var wall: Dictionary=base().grid.walls[edge]
		if hide.has(wall.id) and not context.edges.has(edge):remainder[edge]=wall
	var fixed_builder=factory.builder(stationary)
	for wall in G.runs(remainder):
		fixed_builder.blueprint.materials.plaster=wall.get("color","eadcc5");fixed_builder.build_wall(stationary,factory.wall_data(editor.layout,wall,Vector2.ZERO))
	for child in stationary.get_children():
		if child is Node3D:child.position.y+=editor.editing_storey*S.HEIGHT
	for id in hide:
		if not editor.room.render_cache.has(id):continue
		var node: Node3D=editor.room.render_cache[id].node
		if not context.edges.values().any(func(wall):return wall.id==id):clone_visual(node,moving)
		originals.append([node,node.visible]);node.hide()
	for holder in [moving,stationary]:
		for body in holder.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
	for mesh in moving.find_children("*","MeshInstance3D",true,false):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func update_gesture(force: bool=false) -> void:
	if mode=="" or not dragging:return
	var p: Variant=ground(pointer)
	if p==null:return
	if mode=="object":
		p=editor.point_at(pointer)
		if p!=null:
			var point: Vector2=p
			if grabbed.get("type","") in ["object","stairs"] and C.mount(grabbed)!="wall":point+=drag_offset
			if C.mount(grabbed)=="wall" and not editor.top_down:editor.placement_height+=float(C.OBJECTS[grabbed.kind].height)*.5-drag_height_offset
			var key:=str(point)+str(editor.rotation)+str(snappedf(editor.placement_height,.05))
			if key!=step_key:step_key=key;editor.update_ghost(point)
		return
	var key: String=str(grid_point(p)) if mode=="room" else str(roundi((p[context.axis]-origin_world[context.axis])/.5))
	if key==step_key:return
	var now:=Time.get_ticks_usec()
	if not force and now-tick_at<50000:return
	step_key=key;tick_at=now
	if mode=="room":
		var finish:={"color":editor.ui.color.color.to_html(false),"style":editor.ui.STYLES[editor.ui.style.selected]}
		var end:=grid_point(p);var area:=Rect2(origin_world.min(end),(end-origin_world).abs());result=Edit.create(context,area,finish)
		box.show();box.material_override=good if result.ok else bad;box.position=Vector3(area.get_center().x,.24+level()*S.HEIGHT,area.get_center().y);box.scale=Vector3(maxf(.01,area.size.x),.08,maxf(.01,area.size.y))
		for i in range(4):
			var strip: MeshInstance3D=room_walls[i];strip.show();strip.material_override=good if result.ok else bad
			var along_x:=i<2;var center:=area.get_center();center[1 if along_x else 0]=(area.position if i%2==0 else area.end)[1 if along_x else 0]
			strip.position=Vector3(center.x,.24+level()*S.HEIGHT+(.22 if editor.top_down else 1.4),center.y);strip.scale=Vector3(maxf(.01,area.size.x) if along_x else .16,.44 if editor.top_down else 2.8,.16 if along_x else maxf(.01,area.size.y))
		show_bounds(area,result.ok)
	else:
		var delta:=int(key);result=Edit.resize(context,delta)
		if is_instance_valid(moving):
			var shift:=Vector3.ZERO;shift[context.axis*2]=delta*.5;moving.position=shift
		if is_instance_valid(moving) and wall_valid!=result.ok:
			for mesh in moving.find_children("*","MeshInstance3D",true,false):mesh.material_overlay=null if result.ok else bad
			wall_valid=result.ok
		var area: Rect2=Edit.bounds(context.rooms[context.room])
		if context.outward<0:area.position[context.axis]+=delta*.5;area.size[context.axis]-=delta*.5
		else:area.size[context.axis]+=delta*.5
		show_bounds(result.get("bounds",area.abs()),result.ok)
		var plane: float=(context.plane+delta)*.5
		overlay.wall=[Vector2(context.lo*.5,plane) if context.axis==1 else Vector2(plane,context.lo*.5),Vector2(context.hi*.5,plane) if context.axis==1 else Vector2(plane,context.hi*.5)]
		if result.ok:
			for id in result.rooms:
				if id!=context.room:overlay.second=Edit.bounds(result.rooms[id]);break
	editor.ui.message(("松开确认 · %.1f × %.1f米 · Esc取消"%[overlay.area.size.x,overlay.area.size.y]) if result.ok else result.message,not result.ok)
func finish(mouse: Vector2) -> void:
	pointer=mouse
	if not dragging:cancel();return
	update_gesture(true)
	var action:=mode;var context_: Dictionary=context.base if action=="wall" else context;var planned:=result;var row:=grabbed;var point: Variant=editor.point_at(mouse) if action=="object" else null
	if action=="object":
		if point!=null:
			if row.get("type","") in ["object","stairs"] and C.mount(row)!="wall":point+=drag_offset
			if C.mount(row)=="wall" and not editor.top_down:editor.placement_height+=float(C.OBJECTS[row.kind].height)*.5-drag_height_offset
			var ok: bool=editor.place_at(point);var message: String=editor.ui.status.text;editor.choose_tool("select")
			if not ok:editor.ui.message(message,true)
		cancel();return
	var unit: Dictionary=editor.selected_unit.duplicate(true)
	if action=="wall" and planned.get("ok",false) and not unit.is_empty():
		for field in ["a","b"]:unit[field][0]+=planned.delta.x;unit[field][1]+=planned.delta.y
	clear_stage();mode="";dragging=false
	if planned.get("ok",false):
		if editor.commit(Edit.materialize(context_,planned)):
			if action=="wall" and not unit.is_empty():editor.reselect_unit(unit)
			editor.refresh_ui();editor.ui.message("房间调整已保存 · 可一步撤销" if action=="wall" else "房间已建好 · 可继续拖建下一间")
	else:editor.ui.message(planned.get("message","按住左键拖出房间"),true)
	cancel()
func sample(mouse: Vector2) -> void:
	var id: String=editor.pick_at(mouse);var row:=L.find(editor.layout,id)
	if row.is_empty():editor.ui.message("点击家具或墙地表面吸取同款");return
	var copied:=row.duplicate(true);var type: String=row.type
	if type=="wall":
		var side: String="positive" if (Vector2(editor.city.camera.position.x,editor.city.camera.position.z)-L.rect(row).get_center()).dot(preload("res://scripts/building/structure_catalog.gd").normal(row))>=0. else "negative"
		copied.merge(preload("res://scripts/building/structure_catalog.gd").surface(row,side),true)
	var tool: String="object:"+row.kind if type=="object" else type+(":"+row.get("form","classic") if type in ["door","window","roof","stairs"] else "")
	editor.choose_tool(tool);brush=copied;editor.rotation=float(row.get("yaw",0.));editor.brush_painted=bool(copied.get("painted",true));editor.ui.color.color=Color(copied.color);editor.ui.style.selected=maxi(0,editor.ui.STYLES.find(copied.style))
	editor.ui.message("已吸取 · "+C.name_for(row)+(" · 点击同类表面刷样式" if type in ["floor","wall"] else " · 点击放置同款"))
func apply_brush(row: Dictionary) -> Dictionary:
	if brush.is_empty() or row.get("type","")!=brush.get("type",""):return row
	if row.type=="object" and row.kind==brush.kind:
		if brush.has("mount_height"):row.mount_height=brush.mount_height
		for field in ["appearance","painted","color","style"]:
			if brush.has(field):row[field]=brush[field].duplicate(true) if brush[field] is Dictionary else brush[field]
	elif row.type=="roof":row.yaw=editor.rotation
	return row
func paint(mouse: Vector2) -> bool:
	if brush.get("type","") not in ["floor","wall"] or editor.tool!=brush.type or editor.start_point!=null:return false
	var id: String=editor.pick_at(mouse);var row:=L.find(editor.layout,id)
	if row.get("type","")!=brush.type or editor.picked_world==null:return false
	var unit:=L.unit_at(editor.layout,id,editor.picked_world);var face_mode:=0
	if row.type=="wall":
		var edit=preload("res://scripts/building/surface_edit.gd");var camera:=Vector2(editor.city.camera.position.x,editor.city.camera.position.z);var inside: String=edit.inside_side(base().plan,unit,camera);var side: String="positive" if (camera-L.rect(unit).get_center()).dot(preload("res://scripts/building/structure_catalog.gd").normal(unit))>=0 else "negative";face_mode=0 if side==inside else 1
	if editor.commit(preload("res://scripts/building/surface_edit.gd").paint(editor.layout,unit,editor.ui.color.color,editor.ui.STYLES[editor.ui.style.selected],editor.ui.batch_paint.button_pressed,face_mode,Vector2(editor.city.camera.position.x,editor.city.camera.position.z))):editor.reselect_unit(unit);editor.refresh_ui()
	return true
func input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and mode!="":editor.restore_moving();cancel();editor.choose_tool("select");return true
		if event.keycode==KEY_T:editor.toggle_top_down();return true
		if event.keycode==KEY_E:editor.choose_tool("eyedropper");return true
		if event.keycode==KEY_G:cancel();editor.begin_move();return true
		if mode=="wall" and event.keycode==KEY_R:return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and mode!="":editor.restore_moving();cancel();return true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if editor.tool=="eyedropper":sample(event.position);return true
		if paint(event.position):return true
		if editor.tool not in ["room","select"]:return false
		var p: Variant=ground(event.position)
		if p==null:return false
		origin_mouse=event.position;pointer=event.position;origin_world=grid_point(p);step_key="";dragging=false
		if editor.tool=="room":mode="room";context=base();return true
		editor.select_at(event.position);grabbed=editor.selected_row().duplicate(true)
		if event.double_click and not grabbed.is_empty():editor.begin_move();return true
		if grabbed.get("type","")=="wall":
			context=Edit.wall_context(base(),grabbed,Vector2(editor.city.camera.position.x,editor.city.camera.position.z));mode="wall" if not context.is_empty() else "";origin_world=p
		elif grabbed.get("type","") in ["object","stairs","door","window","roof"]:
			mode="object";var height: float=.18+(L.base_height(editor.layout,grabbed) if grabbed.type=="object" else S.elevation(grabbed));var at: Variant=screen_point(event.position,height)
			if C.mount(grabbed)=="wall":
				var normal: Vector2=preload("res://scripts/building/wall_mount.gd").normal(grabbed);var plane:=Plane(Vector3(normal.x,0,normal.y),Vector3(normal.x,0,normal.y).dot(Vector3(grabbed.position[0],0,grabbed.position[1])))
				var hit: Variant=plane.intersects_ray(editor.city.camera.project_ray_origin(event.position),editor.city.camera.project_ray_normal(event.position))
				drag_height_offset=hit.y-height if hit!=null else float(C.OBJECTS[grabbed.kind].height)*.5
			drag_offset=Vector2(grabbed.get("position",[0.,0.])[0],grabbed.get("position",[0.,0.])[1])-at if at!=null else Vector2.ZERO
		return true
	if event is InputEventMouseMotion and mode!="":
		pointer=event.position
		if not dragging and pointer.distance_to(origin_mouse)>7.:
			dragging=true
			if mode=="object":editor.begin_move()
			elif mode=="wall":begin_wall_preview()
		update_gesture();return true
	return false
func release(event: InputEvent) -> bool:
	if mode!="" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:finish(event.position);return true
	return false
func tick() -> bool:
	update_halo()
	if mode!="":update_gesture();overlay.queue_redraw();return dragging or mode=="room"
	var mouse: Vector2=get_viewport().get_mouse_position();var key: String=str(mouse)+str(editor.city.camera.global_transform)+str(editor.city.camera.size)+str(editor.selected_id)+str(editor.layout_revision)+editor.tool
	if key==pointer_key:return editor.tool in ["room","eyedropper"]
	pointer_key=key;overlay.area=Rect2();overlay.wall=[];overlay.second=Rect2()
	if get_viewport().gui_get_hovered_control()!=null:overlay.queue_redraw();return editor.tool in ["room","eyedropper"]
	if editor.tool=="select":
		var id: String=editor.pick_at(mouse);var row:=L.find(editor.layout,id)
		if row.get("type","")=="wall" and editor.picked_world!=null:
			var unit:=L.unit_at(editor.layout,id,editor.picked_world);var hkey:=id+str(unit.get("a"))+str(editor.layout_revision)+str(editor.editing_storey)+str(editor.city.camera.position)
			if hkey!=hover_key:hover=Edit.wall_context(base(),unit,Vector2(editor.city.camera.position.x,editor.city.camera.position.z));hover_key=hkey
			if not hover.is_empty():
				show_bounds(Edit.bounds(hover.rooms[hover.room]));overlay.wall=[Vector2(hover.lo*.5,hover.plane*.5) if hover.axis==1 else Vector2(hover.plane*.5,hover.lo*.5),Vector2(hover.hi*.5,hover.plane*.5) if hover.axis==1 else Vector2(hover.plane*.5,hover.hi*.5)];Input.set_default_cursor_shape(Input.CURSOR_VSIZE if hover.axis==1 else Input.CURSOR_HSIZE)
		else:Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if editor.start_point!=null and editor.tool in ["floor","roof","wall","railing"]:
		var point: Variant=editor.point_at(mouse)
		if point!=null:
			var row: Dictionary=editor.row_at(point)
			if row.has("a"):show_bounds(L.rect(row))
	overlay.queue_redraw();return editor.tool in ["room","eyedropper"]
