extends Node
const Grid=preload("res://scripts/building/grid_layout.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Site=preload("res://scripts/building/site.gd")
const Factory=preload("res://scripts/building/module_factory.gd")
const InputGuard=preload("res://scripts/services/gameplay_input.gd")
var city: Node3D
var active:=false
var layout: Dictionary
var room: Node3D
var ui: CanvasLayer
var tool:="select"
var structure_form:="classic"
var selected_id:=""
var moving_id:=""
var selected_unit: Dictionary={}
var moving_unit: Dictionary={}
var picked_world: Variant=null
var demolition_target_type:=""
var demolition_start: Variant=null
var demolition_mouse:=Vector2.ZERO
var demolition_pointer:=Vector2.ZERO
var demolition_pressed_id:=""
var demolition_dragging:=false
var demolition_candidate: Dictionary={}
var demolition_key:=""
var start_point: Variant=null
var rotation:=0.
var undo_stack: Array=[]
var redo_stack: Array=[]
var grid: MeshInstance3D
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var show_roof:=false
var night_preview:=false
var focus:=Site.CENTER
var yaw:=.35
var pitch:=.80
var distance_:=38.
var previous_active:=true
var ghost_key:=""
var brush_painted:=false
var npc_modes: Dictionary={}
var hovered_id:=""
var highlighted_key:=""
var highlighted: Array=[]
var part_hint_left:=0.
var selection_outline: MeshInstance3D
var preview: Node3D
var preview_key:=""
var right_origin:=Vector2.ZERO
var right_dragged:=false
var placement_support:=""
var placement_level:=0
var wall_hint: Dictionary={}
var preview_walls: Array=[]
func _ready() -> void:
	layout=Layout.normalize(city.session.state().get("build_layout",{}))
	ui=preload("res://scripts/building/editor_ui.gd").new();ui.editor=self;add_child(ui)
	var shape:=PlaneMesh.new();shape.size=Site.PLOT.size;grid=MeshInstance3D.new();grid.mesh=shape;grid.position=Site.CENTER+Vector3(0,.205,0);grid.position.z=Site.PLOT.get_center().y
	var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/build_grid.gdshader");grid.material_override=material;grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;city.add_child(grid);grid.hide()
	ghost=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3.ONE;ghost.mesh=box;ghost_material=StandardMaterial3D.new();ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ghost_material.cull_mode=BaseMaterial3D.CULL_DISABLED;ghost.material_override=ghost_material;ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;city.add_child(ghost);ghost.hide()
	selection_outline=MeshInstance3D.new();selection_outline.name="BuildSelectionOutline";selection_outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;city.add_child(selection_outline)
	rebuild();set_process(false)
func open_editor() -> Dictionary:
	if city.session.is_online() or city.map_id!="city":return {"ok":false,"message":"建造园目前只在单人城镇开放。"}
	if city.preparing or city.paused or city.sleep_active or city.nap_active or city.talking_npc!="" or not city.session.job().is_empty():return {"ok":false,"message":"请先结束当前互动，再进入建造园。"}
	active=true;previous_active=city.session.active;city.session.active=false;city.paused=true;city.bunny.can_move=false;city.bunny.velocity=Vector3.ZERO;city.hud.hide();InputGuard.release_controls()
	for npc in city.npcs:npc_modes[npc]=npc.process_mode;npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.velocity=Vector3.ZERO
	grid.show();ui.show();set_process(true);choose_tool("select");set_roof_visible(false);set_night_preview(night_preview);update_camera();ui.message("从底部分类选择物品 · 点击选中查看操作 · 双击可直接移动")
	if layout.has("recovery_message"):ui.message("旧布局需要恢复，原记录已保留，请先勿清空地块。",true)
	return {"ok":true}
func close_editor() -> void:
	if not active:return
	ui.appearance_panel.close()
	restore_moving()
	active=false;start_point=null;moving_id="";ghost.hide();grid.hide();ui.hide();clear_preview();clear_highlight();selection_outline.hide();set_process(false)
	demolition_start=null;demolition_target_type="";demolition_candidate.clear();selected_unit.clear();moving_unit.clear()
	for npc in npc_modes:
		if is_instance_valid(npc):npc.process_mode=npc_modes[npc]
	npc_modes.clear()
	if is_instance_valid(room):
		room.set_editor_view(false,false);room.set_process(true);room.get_node("Structure/Roof").show()
		for section in room.sections:
			section.alpha=1.;section.target=1.
			for material in section.materials:material.set_shader_parameter("opacity",1.)
			for visual in section.visuals:visual.show()
	city.update_lighting()
	InputGuard.release_controls();city.paused=false;city.session.active=previous_active;city.bunny.can_move=true;city.bunny.velocity=Vector3.ZERO;city.bunny.reset_physics_interpolation();city.session.set_player_position(city.bunny.position)
	city.camera_focus=city.bunny.position+Vector3.UP*1.35;city.camera.position=city.bunny.position+Vector3(5,8,13);city.hud.show();city.update_target()
	if is_instance_valid(city.navigation) and is_instance_valid(room) and room.pending_navigation.size!=Vector2.ZERO:
		var bounds: Rect2=room.pending_navigation.grow(.6);city.navigation.refresh_region(AABB(Vector3(bounds.position.x,-1,bounds.position.y),Vector3(bounds.size.x,8,bounds.size.y)));room.pending_navigation=Rect2()
	if not city.session.save_game():city.hud.notify("进度合并保存失败；建造检查点仍保留，请稍后重试。")
func rebuild() -> void:
	ghost_key="";highlighted_key="";clear_highlight();clear_preview()
	if is_instance_valid(room):Factory.sync(room,layout,city)
	else:room=Factory.make(layout,city)
	for id in city.targets.keys():
		if str(id).begins_with("build:"):city.targets.erase(id)
	if is_instance_valid(room):
		if not city.interiors.has(room):city.interiors.append(room)
		room.update_lighting(city.ambient_day)
		for door in room.get_node("Doors").get_children():
			if not door.has_method("door_action_position"):continue
			city.targets["build:"+str(door.name)]={"kind":"home_door","name":"我的小屋","node":door,"anchor":door.get_node("ActionAnchor"),"position":door.door_action_position(),"radius":3.8}
		for module in room.get_node("Furnishing").get_children():
			if module.has_node("SeatAnchor") and module.has_node("ExitAnchor"):city.targets["build:"+str(module.name)]={"kind":"bench","node":module,"position":module.global_position,"radius":1.65,"label":"坐下来休息一会"}
			if module.has_node("SleepExit"):
				city.targets["build:"+str(module.name)]={"kind":"bed","node":module,"position":module.global_position,"radius":1.65}
				if not module.has_node("BedComfort"):
					var comfort:=preload("res://scripts/building/bed_comfort.gd").new();comfort.name="BedComfort";comfort.bed=module;comfort.city=city;module.add_child(comfort)
		if active:set_roof_visible(show_roof)
	refresh_ui()
func selected_row() -> Dictionary:
	return selected_unit if not selected_unit.is_empty() else Layout.find(layout,selected_id)
func refresh_ui() -> void:ui.refresh(selected_row())
func choose_tool(id: String) -> void:
	ui.appearance_panel.close()
	restore_moving()
	var parts:=id.split(":")
	structure_form=parts[1] if parts.size()==2 and parts[0] in ["door","window","roof"] else "classic"
	if parts[0] in ["door","window","roof"]:id=parts[0]
	tool=id;start_point=null;moving_id="";moving_unit.clear();demolition_start=null;demolition_target_type="";demolition_dragging=false;demolition_candidate.clear();demolition_key="";rotation=0.;ghost_key="";ghost.hide();clear_preview()
	if id.begins_with("object:"):ui.show_category(Catalog.OBJECTS[id.trim_prefix("object:")].category)
	if id!="select":
		selected_id="";selected_unit.clear();brush_painted=false;ui.updating=true;ui.style.selected=0
		ui.color.color=Color(preload("res://scripts/building/structure_catalog.gd").default_color(id,structure_form))
		ui.updating=false
	refresh_ui();ui.message("点击选中物件查看操作" if id=="select" else "选择位置放置 · Esc 取消")
func set_night_preview(value: bool) -> void:
	night_preview=value;city.update_lighting(.92 if value else -1)
	ui.root_ui.find_child("NightPreview",true,false).set_pressed_no_signal(value)
func set_roof_visible(value: bool) -> void:
	clear_preview();ghost_key=""
	show_roof=value
	ui.root_ui.find_child("ShowRoof",true,false).set_pressed_no_signal(value)
	if not is_instance_valid(room) or not active:return
	room.set_process(false);room.get_node("Structure/Roof").visible=value
	apply_editor_cutaway()
func apply_editor_cutaway() -> void:
	if is_instance_valid(room):room.set_editor_view(true,show_roof)
func commit(candidate: Dictionary,history: bool=true) -> bool:
	var result: Dictionary=city.session.set_build_layout(candidate)
	if not result.ok:ui.message(result.message,true);return false
	if result.layout==layout:return true
	if history:undo_stack.append(layout.duplicate(true));redo_stack.clear();if_history_limit()
	layout=result.layout
	if not selected_unit.is_empty():reselect_unit(selected_unit)
	elif selected_id!="" and Layout.find(layout,selected_id).is_empty():selected_id=""
	rebuild();ui.message("已保存 · "+str(Layout.usage(layout).objects)+" 件家具与摆件")
	return true
func if_history_limit() -> void:
	if undo_stack.size()>50:undo_stack.pop_front()
func undo() -> void:
	if undo_stack.is_empty():return
	choose_tool("select")
	var next: Dictionary=undo_stack[-1];var previous:=layout.duplicate(true)
	if commit(next,false):undo_stack.pop_back();redo_stack.append(previous);selected_id="";selected_unit.clear();refresh_ui()
func redo() -> void:
	if redo_stack.is_empty():return
	choose_tool("select")
	var next: Dictionary=redo_stack[-1];var previous:=layout.duplicate(true)
	if commit(next,false):redo_stack.pop_back();undo_stack.append(previous);selected_id="";selected_unit.clear();refresh_ui()
func place_template() -> bool:
	choose_tool("template");ui.message("整栋样板房跟随鼠标 · 点击空地放置 · Esc 取消")
	return true
func clear_plot() -> void:
	if commit(Layout.empty()):selected_id="";choose_tool("select")
func paint_selected(color: Color,style: String) -> void:
	if selected_id=="":return
	if selected_row().get("type","")=="object":
		var A=preload("res://scripts/building/appearance.gd");var definition: Dictionary=A.parts(selected_row().kind)[0]
		paint_appearance(definition.id,color,style if style in A.allowed(definition) else "original");return
	var row:=selected_row().duplicate(true);var next: Dictionary
	if row.get("type","") in ["floor","wall"]:
		if selected_unit.is_empty():row=Layout.unit_at(layout,selected_id,Layout.rect(row).get_center())
		var camera:=Vector2(city.camera.global_position.x,city.camera.global_position.z)
		next=preload("res://scripts/building/surface_edit.gd").paint(layout,row,color,style,ui.batch_paint.button_pressed,ui.wall_face.selected,camera)
	else:
		row.color=color.to_html(false);row.style=style;row.painted=true;next=Layout.replace(layout,row)
	if commit(next):
		if row.type in ["floor","wall"]:reselect_unit(row)
		else:selected_id=row.id
		refresh_ui()

func paint_appearance(slot: String,color: Color,material: String,accent: Variant=null) -> void:
	var row:=selected_row().duplicate(true)
	if row.get("type","")!="object":return
	if not row.has("appearance"):row.appearance={}
	row.appearance[slot]={"color":color.to_html(false),"material":material}
	if accent is Color:row.appearance[slot].accent=accent.to_html(false)
	if commit(Layout.replace(layout,row)):selected_id=row.id;refresh_ui()
func reset_appearance(slot: String) -> void:
	var row:=selected_row().duplicate(true)
	if row.get("type","")!="object":return
	if slot=="":row.erase("appearance");row.painted=false;row.style="original"
	else:
		if not row.has("appearance"):row.appearance={}
		row.appearance[slot]={"material":"original"}
	if commit(Layout.replace(layout,row)):selected_id=row.id;refresh_ui()
func apply_appearance_preset(id: String) -> void:
	var row:=selected_row().duplicate(true)
	if row.get("type","")!="object":return
	row.appearance=preload("res://scripts/building/appearance.gd").preset(row.kind,id);row.painted=false
	if commit(Layout.replace(layout,row)):selected_id=row.id;refresh_ui()
func restore_appearance_preview() -> void:
	if not is_instance_valid(room) or not room.render_cache.has(selected_id):return
	var row:=Layout.find(layout,selected_id)
	if row.get("type","")!="object":return
	var module: Node3D=room.render_cache[selected_id].node;preload("res://scripts/building/appearance.gd").restore(module);Factory.paint(module,row)
func appearance_channels(slot: String,material: String) -> Dictionary:
	if not is_instance_valid(room) or not room.render_cache.has(selected_id):return {"enabled":false,"accent":Color("f2e5cf"),"label":"花纹色"}
	return preload("res://scripts/building/appearance.gd").channels(room.render_cache[selected_id].node,slot,material)
func preview_appearance(slot: String,color: Color,material: String,accent: Variant=null) -> void:
	restore_appearance_preview();var row:=selected_row().duplicate(true)
	if row.get("type","")!="object" or not room.render_cache.has(row.id):return
	if not row.has("appearance"):row.appearance={}
	row.appearance[slot]={"color":color.to_html(false),"material":material}
	if accent is Color:row.appearance[slot].accent=accent.to_html(false)
	Factory.paint(room.render_cache[row.id].node,row)
func highlight_appearance_part(slot: String) -> void:
	clear_highlight();selection_outline.hide()
	if not is_instance_valid(room) or not room.render_cache.has(selected_id):return
	var overlay:=StandardMaterial3D.new();overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;overlay.albedo_color=Color(1.,.94,.75,.18);part_hint_left=.35
	for mesh in room.render_cache[selected_id].node.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("appearance_part","")==slot:highlighted.append([mesh,mesh.material_overlay]);mesh.material_overlay=overlay
func delete_selected() -> void:
	ui.appearance_panel.close()
	if selected_id=="":return
	var candidate:=Layout.remove(layout,selected_id)
	if not selected_unit.is_empty():
		var r:=Layout.rect(selected_unit)
		candidate=Layout.demolish(layout,r,"floor") if selected_unit.type=="floor" else Layout.demolish(layout,r.grow(.001),"wall",Grid.edges(selected_unit)[0])
	if commit(candidate):
		selected_id="";selected_unit.clear()
		if tool=="move":choose_tool("select")
		refresh_ui()
func rotate_selected() -> void:
	if tool.begins_with("object:") or tool=="move":rotation=fposmod(rotation+90.,360.);ghost_key="";return
	var next:=layout.duplicate(true);var row:=Layout.find(next,selected_id)
	if row.get("type","")!="object":return
	row.yaw=fposmod(float(row.yaw)+90.,360.)
	var snapped:=Layout.snap_object(next,row) if Catalog.mount(row)=="floor" else Layout.attach_at(next,row,Vector2(row.position[0],row.position[1]),str(row.support),int(row.support_level));row.position=snapped.position
	commit(Layout.replace(layout,row))
func begin_move() -> void:
	ui.appearance_panel.close()
	if selected_id=="":return
	moving_unit=selected_unit.duplicate(true);moving_id=selected_id;tool="move";start_point=null;rotation=float(Layout.find(layout,selected_id).get("yaw",0));ghost_key="";refresh_ui()
	if is_instance_valid(room):
		for module in room.get_node("Furnishing").get_children():
			var row:=Layout.find(layout,str(module.name))
			if str(module.name)==moving_id or row.get("support","")==moving_id:module.hide()
func point_at(mouse: Vector2) -> Variant:
	placement_support="";placement_level=0;wall_hint.clear()
	var origin: Vector3=city.camera.project_ray_origin(mouse);var direction: Vector3=city.camera.project_ray_normal(mouse)
	var placing: String=Layout.find(layout,moving_id).get("type","") if tool=="move" else tool
	if placing in ["door","window"]:
		var nearest:=250.
		for wall in layout.elements:
			if wall.type!="wall":continue
			var a:=Vector3(wall.a[0],0,wall.a[1]);var end:=Vector3(wall.b[0],0,wall.b[1]);var along: Vector3=(end-a).normalized();var normal:=Vector3(-along.z,0,along.x)
			var hit: Variant=Plane(normal,normal.dot(a)).intersects_ray(origin,direction)
			if hit==null or hit.y<.18 or hit.y>4.58:continue
			var offset: float=(hit-a).dot(along);var distance_: float=origin.distance_to(hit)
			if offset<0. or offset>a.distance_to(end) or distance_>=nearest:continue
			var snapped_offset:=snappedf(offset,.5);var snapped_point:=a+along*snapped_offset
			nearest=distance_;wall_hint={"wall":wall.id,"offset":snapped_offset,"point":Vector2(snapped_point.x,snapped_point.z)}
		return wall_hint.get("point")
	var kind:=tool.trim_prefix("object:") if tool.begins_with("object:") else str(Layout.find(layout,moving_id).get("kind",""))
	if Catalog.OBJECTS.has(kind):
		var mount: String=Catalog.OBJECTS[kind].get("mount","floor")
		if mount=="surface":
			var best: Variant=null;var gap:=INF
			for parent in layout.elements:
				if parent.type!="object" or not Catalog.OBJECTS[parent.kind].has("surface"):continue
				var definition: Dictionary=Catalog.OBJECTS[parent.kind];var levels: Array=definition.get("surface_levels",[definition.surface_height])
				for level in range(levels.size()):
					var point: Variant=Plane(Vector3.UP,.18+float(levels[level])).intersects_ray(origin,direction)
					if point==null:continue
					var local:=Catalog.rotate_xz(Vector2(point.x-parent.position[0],point.z-parent.position[1]),-float(parent.yaw))
					if Rect2(definition.get("surface_offset",Vector2.ZERO)-definition.surface*.5,definition.surface).has_point(local) and origin.distance_to(point)<gap:best=point;gap=origin.distance_to(point);placement_support=parent.id;placement_level=level
			if best!=null:return Vector2(snappedf(best.x,.05),snappedf(best.z,.05))
		elif mount=="ceiling":
			var point: Variant=Plane(Vector3.UP,4.58).intersects_ray(origin,direction)
			if point!=null:return Vector2(snappedf(point.x,.1),snappedf(point.z,.1))
	var hit: Variant=Plane(Vector3.UP,.18).intersects_ray(origin,direction)
	if hit==null:return null
	return Vector2(snappedf(hit.x,.5),snappedf(hit.z,.5))
func closest_wall(point_: Vector2) -> Dictionary:
	if not wall_hint.is_empty() and point_.distance_to(wall_hint.point)<.01:return wall_hint
	var best: Dictionary={};var gap:=2.5
	for row in layout.elements:
		if row.type!="wall":continue
		var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);var dir: Vector2=(b-a).normalized();var offset: float=clampf((point_-a).dot(dir),0,a.distance_to(b));var distance_to: float=point_.distance_to(a+dir*offset)
		if distance_to<gap:gap=distance_to;best={"wall":row.id,"offset":snappedf(offset,.5)}
	return best
func row_at(point_: Vector2) -> Dictionary:
	var row:={"type":tool,"color":ui.color.color.to_html(false),"style":ui.STYLES[ui.style.selected]}
	if tool in ["door","window","roof"] and structure_form!="classic":row.form=structure_form
	if tool=="template":return {"type":"template","position":[point_.x,point_.y]}
	if tool.begins_with("object:"):row.type="object";row.kind=tool.trim_prefix("object:");row.position=[point_.x,point_.y];row.yaw=rotation;row.painted=brush_painted
	elif tool in ["floor","roof","wall"]:
		if start_point==null:return {}
		var end:=point_
		if tool=="wall":end=Vector2(point_.x,start_point.y) if absf(point_.x-start_point.x)>=absf(point_.y-start_point.y) else Vector2(start_point.x,point_.y)
		row.a=[start_point.x,start_point.y];row.b=[end.x,end.y]
	elif tool in ["door","window"]:
		var near:=closest_wall(point_)
		if near.is_empty():return {}
		row.wall=near.wall;row.offset=near.offset
	elif tool=="move":
		row=(moving_unit if not moving_unit.is_empty() else Layout.find(layout,moving_id)).duplicate(true)
		if row.is_empty():return {}
		if row.type=="object":row.position=[point_.x,point_.y];row.yaw=rotation
		elif row.type in ["door","window"]:
			var near:=closest_wall(point_)
			if near.is_empty():return {}
			row.wall=near.wall;row.offset=near.offset;row.erase("anchor")
		else:
			var area:=Layout.rect(row);var mid:=area.get_center();var delta:=point_-Vector2(snappedf(mid.x,.5),snappedf(mid.y,.5));row.a=[row.a[0]+delta.x,row.a[1]+delta.y];row.b=[row.b[0]+delta.x,row.b[1]+delta.y]
	else:return {}
	if row.type=="object" and Catalog.mount(row)!="floor":return Layout.attach_at(layout,row,point_,placement_support,placement_level)
	return Layout.snap_object(layout,row)
func candidate_layout(row: Dictionary) -> Dictionary:
	if row.type=="template":return Layout.merge_template(layout,preload("res://scripts/building/templates.gd").cottage(),Vector2(row.position[0],row.position[1]))
	if moving_id=="":return Layout.add(layout,row)
	return Layout.replace_unit(layout,moving_unit,row) if not moving_unit.is_empty() else Layout.replace(layout,row)
func place_at(point_: Vector2) -> bool:
	if tool in ["floor","wall","roof"] and start_point==null:start_point=point_;return true
	var row:=row_at(point_)
	if row.is_empty():ui.message("请把门窗放到足够长的墙面上。",true);return false
	if not commit(candidate_layout(row)):return false
	if moving_id!="":restore_moving();ghost.hide()
	if row.type=="template":selected_id="";selected_unit.clear();refresh_ui();return true
	selected_id=row.get("id",layout.elements[-1].id);start_point=null;clear_preview()
	if moving_id!="":
		var unit_move:=not moving_unit.is_empty();moving_id="";moving_unit.clear();selected_unit.clear();tool="select"
		if unit_move:reselect_unit(row)
	refresh_ui();return true
func element_id(node: Node) -> String:
	while node!=null and node!=city.scenery:
		if node.has_meta("build_element_id"):return node.get_meta("build_element_id")
		node=node.get_parent()
	return ""
func pick_at(mouse: Vector2) -> String:
	var origin: Vector3=city.camera.project_ray_origin(mouse);var direction: Vector3=city.camera.project_ray_normal(mouse);var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*250,28)
	var excluded: Array[RID]=[]
	var hidden_walls: Dictionary={}
	if is_instance_valid(room) and not show_roof:
		for section in room.sections:
			if not section.roof and not section.get("editor_hidden",false):continue
			for body in section.node.find_children("*","StaticBody3D",true,false):excluded.append(body.get_rid())
			if not section.roof:hidden_walls[element_id(section.node)]=true
	if is_instance_valid(room):
		for body in room.get_node("Furnishing").find_children("*","StaticBody3D",true,false):
			if body.collision_layer!=16:excluded.append(body.get_rid())
	query.exclude=excluded;var hit: Dictionary=city.get_world_3d().direct_space_state.intersect_ray(query);var max_distance:=250.
	var picked_id:="";picked_world=null
	if not hit.is_empty():
		picked_id=element_id(hit.collider);picked_world=Vector2(hit.position.x,hit.position.z);max_distance=origin.distance_to(hit.position)
		var node: Node=hit.collider
		while node!=null and node!=city.scenery:
			if node.get_meta("build_grid_type","")=="floor":
				var floor_: Dictionary=Layout.compiled(layout).floors.get(Grid.cell(picked_world),{});picked_id=str(floor_.get("id",""));break
			node=node.get_parent()
	# A cutaway changes visibility, not physics. Pick the visible low wall without
	# letting its hidden upper collision intercept furniture selection.
	for row in layout.elements:
		if row.type!="wall":continue
		var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);var dir: Vector2=(b-a).normalized();var normal:=Vector3(-dir.y,0,dir.x)
		var point_: Variant=Plane(normal,normal.dot(Vector3(a.x,0,a.y))).intersects_ray(origin,direction)
		if point_==null:continue
		var along: float=(Vector2(point_.x,point_.z)-a).dot(dir);var top:=.80 if hidden_walls.has(row.id) else 4.58
		if along>=0 and along<=a.distance_to(b) and point_.y>=.18 and point_.y<top and origin.distance_to(point_)<max_distance+.15:picked_id=row.id;picked_world=Vector2(point_.x,point_.z);max_distance=origin.distance_to(point_)
	# Real window holes have no blocking pane collider; pick their wall-plane opening.
	for row in layout.elements:
		if row.type not in ["door","window"]:continue
		var wall:=Layout.find(layout,row.wall);var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var dir: Vector2=(b-a).normalized();var normal:=Vector3(-dir.y,0,dir.x)
		var point_: Variant=Plane(normal,normal.dot(Vector3(a.x,0,a.y))).intersects_ray(origin,direction)
		if point_==null:continue
		if hidden_walls.has(row.wall) and point_.y>.8:continue
		var along: float=(Vector2(point_.x,point_.z)-a).dot(dir);var width:=2.86 if row.type=="door" else 2.2;var bottom:=.18 if row.type=="door" else 1.28;var height:=3.5 if row.type=="door" else 2.
		if absf(along-row.offset)<width*.5+.13 and point_.y>bottom-.1 and point_.y<bottom+height+.15 and origin.distance_to(point_)<max_distance+.2:picked_id=row.id;picked_world=Vector2(point_.x,point_.z);max_distance=origin.distance_to(point_)
	for row in layout.elements:
		if row.type!="object" or not Catalog.OBJECTS[row.kind].get("overlay",false):continue
		var p: Variant=Plane(Vector3.UP,.245).intersects_ray(origin,direction)
		if p!=null and Catalog.footprint(row).has_point(Vector2(p.x,p.z)) and origin.distance_to(p)<max_distance:picked_id=row.id;picked_world=Vector2(p.x,p.z);max_distance=origin.distance_to(p)
	return picked_id
func select_at(mouse: Vector2) -> void:
	selected_id=pick_at(mouse);selected_unit.clear()
	if picked_world!=null and Layout.find(layout,selected_id).get("type","") in ["floor","wall"]:selected_unit=Layout.unit_at(layout,selected_id,picked_world)
	refresh_ui();update_highlight(selected_id)
	ui.message("已选中 · "+Catalog.name_for(Layout.find(layout,selected_id)) if selected_id!="" else "点击物件选中 · 从底部目录选择新物品")
func update_ghost(point_: Vector2) -> void:
	var row:=row_at(point_);ghost.visible=not row.is_empty()
	if not ghost.visible:
		clear_preview();return
	var result:=Layout.validate(candidate_layout(row))
	if row.type=="template":
		update_template_preview(Vector2(row.position[0],row.position[1]),result.ok)
		if not result.ok:ui.message(result.message,true)
		else:ui.message("点击空地放置整栋房子 · 可连续放置 · Esc 取消")
		return
	ghost_material.albedo_color=Color(.30,.80,.48,.30) if result.ok else Color(.88,.29,.21,.35)
	var mid:=point_;var size_:=Vector3.ONE;ghost.rotation=Vector3.ZERO
	if row.type=="object":
		var rect_:=Catalog.footprint(row);mid=rect_.get_center();size_=Vector3(rect_.size.x,.035,rect_.size.y)
		update_preview(row,result.ok)
	elif row.type in ["floor","roof","wall"]:
		var rect_:=Layout.rect(row);mid=rect_.get_center();size_=Vector3(maxf(.16,rect_.size.x),.10 if row.type=="floor" else (1.8 if row.type=="roof" else 4.4),maxf(.16,rect_.size.y))
	else:
		var wall:=Layout.find(layout,row.wall);var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var dir: Vector2=(b-a).normalized();mid=a+dir*row.offset;size_=Vector3(2.86 if row.type=="door" else 2.2,3.5 if row.type=="door" else 2.,.30);ghost.rotation.y=-atan2(dir.y,dir.x)
	ghost.scale=size_;ghost.position=Vector3(mid.x,.18+(Layout.base_height(layout,row) if row.type=="object" else 0.)+size_.y*.5+(4.4 if row.type=="roof" else (1.1 if row.type=="window" else 0.)),mid.y)
	if row.type!="object":update_structure_preview(row,result.ok)
	if not result.ok:ui.message(result.message,true)
	else:ui.message("点击放置 · "+Catalog.name_for(row))
func update_camera() -> void:
	city.camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance_;city.camera.look_at(focus)
	# Center the working plot in the visible area above the bottom catalog.
	var shift:=distance_*tan(deg_to_rad(city.camera.fov)*.5)*minf(.38,326./get_viewport().get_visible_rect().size.y)
	city.camera.look_at(focus-city.camera.global_basis.y*shift)
	if active:apply_editor_cutaway()
func pan_camera(local_offset: Vector2) -> void:
	focus+=Vector3(local_offset.x,0,local_offset.y).rotated(Vector3.UP,yaw)
	focus.x=clampf(focus.x,60,98);focus.z=clampf(focus.z,-7,28)
func clear_preview() -> void:
	for entry in preview_walls:
		if is_instance_valid(entry[0]):entry[0].visible=entry[1]
	preview_walls.clear()
	preview_key=""
	if is_instance_valid(preview):preview.get_parent().remove_child(preview);preview.free()
func hide_preview() -> void:
	if not preview_walls.is_empty():clear_preview();ghost_key=""
	elif is_instance_valid(preview):preview.hide()
func restore_moving() -> void:
	if is_instance_valid(room):
		for module in room.get_node("Furnishing").get_children():module.show()
func update_preview(row: Dictionary,valid: bool) -> void:
	var key: String=str(row.get("kind",row.type))+":"+moving_id+":"+str(row.get("painted",false))+":"+str(row.get("color",""))+":"+str(row.get("style",""))+JSON.stringify(row.get("appearance",{}))
	if key!=preview_key:
		clear_preview();preview_key=key;preview=Node3D.new();preview.name="BuildObjectPreview";city.add_child(preview)
		var b:=Factory.builder(preview);b.build_item(preview,row.kind);Factory.paint(preview,row)
		if moving_id!="":
			var old:=Layout.find(layout,moving_id)
			for item in layout.elements:
				if item.get("support","")!=moving_id:continue
				var child:=Node3D.new();preview.add_child(child);var local:=Catalog.rotate_xz(Vector2(item.position[0]-old.position[0],item.position[1]-old.position[1]),-float(old.yaw))
				child.position=Vector3(local.x,Layout.base_height(layout,item)-Layout.base_height(layout,old),local.y);child.rotation.y=deg_to_rad(float(item.yaw)-float(old.yaw));b.build_item(child,item.kind);Factory.paint(child,item)
		for body in preview.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
		for light in preview.find_children("*","Light3D",true,false):light.hide()
	preview.position=Vector3(row.position[0],.18+Layout.base_height(layout,row),row.position[1]);preview.rotation.y=deg_to_rad(row.yaw);preview.show()
	var overlay:=StandardMaterial3D.new();overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;overlay.albedo_color=Color(.24,.75,.48,.20) if valid else Color(.95,.22,.15,.45)
	overlay.no_depth_test=Catalog.OBJECTS[row.kind].has("wall_size")
	for mesh in preview.find_children("*","MeshInstance3D",true,false):mesh.material_overlay=overlay;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func update_template_preview(p: Vector2,valid: bool) -> void:
	if preview_key!="template":
		clear_preview();preview_key="template";preview=Factory.make(preload("res://scripts/building/templates.gd").cottage(),city);preview.name="TemplatePlacementPreview";preview.set_process(false)
		for body in preview.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
		for light in preview.find_children("*","Light3D",true,false):light.hide()
	preview.position=Vector3(p.x,0,p.y);preview.show();ghost.hide()
	var overlay: StandardMaterial3D=null
	if not valid:overlay=StandardMaterial3D.new();overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;overlay.albedo_color=Color(.95,.22,.15,.48)
	for mesh in preview.find_children("*","MeshInstance3D",true,false):mesh.material_overlay=overlay
func update_structure_preview(row: Dictionary,valid: bool) -> void:
	var key:=JSON.stringify(row)+str(valid)+str(show_roof)
	if key!=preview_key:
		clear_preview();preview_key=key;preview=Node3D.new();preview.name="BuildStructurePreview";city.add_child(preview)
		var b:=Factory.builder(preview);var area:=Rect2();var mid:=Vector2.ZERO
		if row.type in ["floor","roof","wall"]:
			area=Layout.rect(row);mid=area.get_center();preview.position=Vector3(mid.x,0,mid.y)
		match row.type:
			"floor":
				if minf(area.size.x,area.size.y)<.01:return
				var m:=Factory.floor_material(row)
				var slab:=BoxMesh.new();slab.size=Vector3(area.size.x,.30,area.size.y);var visual:=MeshInstance3D.new();visual.mesh=slab;visual.material_override=m;visual.position.y=.03;preview.add_child(visual)
			"wall":
				if area.size.length()<.01:return
				b.blueprint.materials.plaster=row.color;b.build_wall(preview,{"id":"WallPreview","a":[row.a[0]-mid.x,row.a[1]-mid.y],"b":[row.b[0]-mid.x,row.b[1]-mid.y],"openings":[],"color":row.color,"style":row.style,"faces":row.get("faces",{})})
			"roof":
				if minf(area.size.x,area.size.y)<.01:return
				b.roof_form=row.get("form","classic");b.blueprint.size=[area.size.x,area.size.y];b.blueprint.materials.roof=row.color;b.build_roof(preview)
			"door","window":
				var wall:=Layout.find(layout,row.wall);var a:=Vector2(wall.a[0],wall.a[1]);var end:=Vector2(wall.b[0],wall.b[1]);var dir: Vector2=(end-a).normalized();var p:=a+dir*float(row.offset)
				preview.position=Vector3(p.x,0,p.y);var holder:=Node3D.new();preview.add_child(holder);holder.rotation.y=-atan2(dir.y,dir.x)
				var opening:={"id":"opening","type":row.type,"offset":2.5,"width":2.86 if row.type=="door" else 2.2,"height":3.5 if row.type=="door" else 2.,"bottom":0. if row.type=="door" else 1.1,"color":row.color,"style":row.style,"form":row.get("form","classic")}
				b.build_opening(holder,0,opening)
				if row.type=="door":
					var leaf:=Node3D.new();leaf.set_script(preload("res://scripts/building/room_door.gd"));holder.add_child(leaf);b.root=leaf;b.blueprint.walls=[{"a":[-2.5,0],"b":[2.5,0],"openings":[opening]}];b.build_door(leaf)
					if row.get("form","classic")=="classic" or row.get("painted",false):Factory.paint(leaf,row,true)
				if moving_id!="" and room.render_cache.has(moving_id):
					var original: Node3D=room.render_cache[moving_id].node;preview_walls.append([original,original.visible]);original.hide()
				if show_roof and valid:preview_opening_wall(b,row,p)
		for body in preview.find_children("*","CollisionObject3D",true,false):body.collision_layer=0;body.collision_mask=0
		for mesh in preview.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for wall in preview.get_children():
				if wall.has_meta("preview_wall") and wall.is_ancestor_of(mesh):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;break
	preview.show();ghost.hide()
	var overlay:=StandardMaterial3D.new();overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;overlay.albedo_color=Color(.2,.75,.48,.08) if valid else Color(.95,.22,.15,.48)
	overlay.no_depth_test=row.type in ["door","window"]
	for mesh in preview.find_children("*","MeshInstance3D",true,false):
		var wall_mesh:=false
		for wall in preview.get_children():
			if wall.has_meta("preview_wall") and wall.is_ancestor_of(mesh):wall_mesh=true;break
		mesh.material_overlay=null if wall_mesh else overlay
func preview_opening_wall(builder: RefCounted,row: Dictionary,point_: Vector2) -> void:
	var candidate:=layout.duplicate(true)
	if moving_id!="":candidate.elements=candidate.elements.filter(func(item):return item.id!=moving_id)
	var pending:=row.duplicate(true);pending.id="__placement_opening";pending.anchor=[point_.x,point_.y]
	var supporting:=Layout.find(layout,row.wall);pending.axis=0 if is_equal_approx(supporting.a[1],supporting.b[1]) else 1;candidate.elements.append(pending)
	for wall in layout.elements:
		if wall.type!="wall":continue
		var data:=Factory.wall_data(candidate,wall,point_)
		if not data.openings.any(func(opening):return opening.id==pending.id):continue
		var original: Node3D=room.render_cache[wall.id].node;preview_walls.append([original,original.visible]);original.hide()
		builder.build_wall(preview,data)
		var temporary: Node3D=preview.get_node(NodePath(wall.id));temporary.set_meta("preview_wall",true);builder.bake_section(temporary)
		for mesh in temporary.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is ShaderMaterial:mesh.material_override.set_shader_parameter("building_world_pattern",true)
func clear_highlight() -> void:
	part_hint_left=0.
	for entry in highlighted:
		if is_instance_valid(entry[0]):entry[0].material_overlay=entry[1]
	highlighted.clear();highlighted_key=""
func update_highlight(id: String) -> void:
	var row:=selected_unit if id==selected_id and not selected_unit.is_empty() else Layout.find(layout,id)
	if row.get("type","") in ["floor","wall"] and picked_world!=null and id==hovered_id:row=Layout.unit_at(layout,id,picked_world)
	var key:=id+":"+tool+str(row.get("a",[]))+str(row.get("b",[]))
	if key==highlighted_key:return
	clear_highlight();highlighted_key=key;selection_outline.hide()
	if row.is_empty() or not is_instance_valid(room):return
	var area:=Catalog.footprint(row) if row.type=="object" else (Layout.rect(row) if row.type in ["floor","roof","wall"] else Rect2())
	var color_:=Color(.95,.27,.16,.32) if tool=="delete" else Color(.28,.78,.56,.17)
	if row.type=="wall":
		var bounds:=area
		if bounds.size.x<.001:bounds.position.x-=.19;bounds.size.x=.38
		if bounds.size.y<.001:bounds.position.y-=.19;bounds.size.y=.38
		var overlay:=ShaderMaterial.new();overlay.shader=preload("res://assets/shaders/build_area_highlight.gdshader");overlay.set_shader_parameter("area",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y));overlay.set_shader_parameter("tint",color_)
		if room.render_cache.has(id):
			for mesh in room.render_cache[id].node.find_children("*","MeshInstance3D",true,false):
				if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
				highlighted.append([mesh,mesh.material_overlay]);mesh.material_overlay=overlay
	elif row.type!="floor":
		var overlay:=StandardMaterial3D.new();overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;overlay.albedo_color=color_
		for mesh in room.find_children("*","MeshInstance3D",true,false):
			var mesh_id:=element_id(mesh);var item:=Layout.find(layout,mesh_id)
			if mesh_id!=id and not (tool=="delete" and (item.get("support","")==id or item.get("wall","")==id)):continue
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
			highlighted.append([mesh,mesh.material_overlay]);mesh.material_overlay=overlay
	if area.size==Vector2.ZERO:return
	var y:=.23+(Layout.base_height(layout,row) if row.type=="object" else 0.);var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners: Array=[Vector3(area.position.x,y,area.position.y),Vector3(area.end.x,y,area.position.y),Vector3(area.end.x,y,area.end.y),Vector3(area.position.x,y,area.end.y)]
	for i in range(4):mesh.surface_add_vertex(corners[i]);mesh.surface_add_vertex(corners[(i+1)%4])
	mesh.surface_end();var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color("df6245") if tool=="delete" else Color("4fba8a");selection_outline.mesh=mesh;selection_outline.material_override=m;selection_outline.show()

func _process(delta: float) -> void:
	if not active:return
	if part_hint_left>0.:
		part_hint_left-=delta
		if part_hint_left<=0.:clear_highlight()
	var input_focus:=get_viewport().gui_get_focus_owner()
	if not (input_focus is LineEdit or input_focus is TextEdit):
		var move:=Input.get_vector("move_left","move_right","move_up","move_down");pan_camera(move*delta*12.)
	update_camera()
	if ui.appearance_panel.visible:return
	var point_: Variant=point_at(get_viewport().get_mouse_position())
	if demolition_start!=null:
		if demolition_dragging:preview_demolition(demolition_pointer)
		return
	if get_viewport().gui_get_hovered_control()!=null:
		ghost.hide()
		hide_preview()
		update_highlight(selected_id);return
	if tool in ["select","delete"]:
		hovered_id=pick_at(get_viewport().get_mouse_position());update_highlight(hovered_id if hovered_id!="" else selected_id)
	if point_!=null and tool not in ["select","delete"]:
		var key: String=tool+str(point_)+str(start_point)+str(rotation)+ui.color.color.to_html()+str(ui.style.selected)
		if key!=ghost_key:ghost_key=key;update_ghost(point_)
		if is_instance_valid(preview):preview.show()
		if tool.begins_with("object:") or (tool=="move" and Layout.find(layout,moving_id).get("type","")=="object"):ghost.show()
	else:
		ghost.hide()
		hide_preview()
func _unhandled_input(event: InputEvent) -> void:
	if not active:return
	var input_focus:=get_viewport().gui_get_focus_owner()
	if input_focus is LineEdit or input_focus is TextEdit:return
	if ui.appearance_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:ui.appearance_panel.close();get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F6:close_editor()
		elif event.keycode==KEY_ESCAPE:
			if tool!="select" or start_point!=null:choose_tool("select")
			else:close_editor()
		elif event.is_command_or_control_pressed() and event.keycode==KEY_Z:
			if event.shift_pressed:redo()
			else:undo()
		elif event.is_command_or_control_pressed() and event.keycode==KEY_Y:redo()
		elif event.keycode==KEY_R:rotate_selected()
		elif event.keycode==KEY_B:choose_tool("delete")
		elif event.keycode==KEY_H:choose_tool("select")
		elif event.keycode in [KEY_DELETE,KEY_BACKSPACE]:delete_selected()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
		if event.pressed:right_origin=event.position;right_dragged=false
		elif not right_dragged and tool!="select":choose_tool("select")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and tool=="delete":
		finish_demolition(event.position);get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and demolition_start!=null:
		if demolition_target_type in ["wall","floor","object"] and event.position.distance_to(demolition_mouse)>7.:demolition_dragging=true;preview_demolition(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if event.position.distance_to(right_origin)>4. or event.relative.length()>4.:right_dragged=true
		if event.shift_pressed:pan_camera(-event.relative*distance_*.0015)
		else:yaw-=event.relative.x*.006;pitch=clampf(pitch+event.relative.y*.004,.30,1.4)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance_=maxf(10,distance_-2)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance_=minf(58,distance_+2)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if tool=="select":
				select_at(event.position)
				if event.double_click and selected_id!="":begin_move()
			elif tool=="delete":begin_demolition(event.position)
			else:
				var point_: Variant=point_at(event.position)
				if point_!=null:place_at(point_)
		get_viewport().set_input_as_handled()

func ground_at(mouse: Vector2) -> Variant:
	var p: Variant=Plane(Vector3.UP,.18).intersects_ray(city.camera.project_ray_origin(mouse),city.camera.project_ray_normal(mouse))
	return Vector2(p.x,p.z) if p!=null else null
func begin_demolition(mouse: Vector2) -> void:
	demolition_pressed_id=pick_at(mouse);demolition_mouse=mouse;demolition_pointer=mouse;demolition_start=ground_at(mouse);demolition_dragging=false;demolition_candidate.clear();demolition_key=""
	var type: String=Layout.find(layout,demolition_pressed_id).get("type","")
	# Keep the initial type for the entire gesture, including releases over the dock.
	demolition_target_type=type if type in ["wall","floor","object"] else "single"
	if type=="":
		demolition_start=null;ui.message("请从想拆除的墙、地板或物件上开始拖动");return
	if picked_world!=null and type=="wall":demolition_start=picked_world

func demolition_area(mouse: Vector2) -> Rect2:
	var p: Variant=ground_at(mouse)
	if p==null or demolition_start==null:return Rect2()
	var a:=Grid.cell(demolition_start);var b:=Grid.cell(p);var first:=a.min(b);var last:=a.max(b)+Vector2i.ONE
	return Rect2(Grid.point(first),Grid.point(last-first))
func preview_demolition(mouse: Vector2) -> void:
	demolition_pointer=mouse
	var bounds:=demolition_area(mouse);var key:=str(bounds)+demolition_target_type
	if key==demolition_key:return
	demolition_key=key;demolition_candidate=Layout.demolish(layout,bounds,demolition_target_type);clear_highlight();selection_outline.hide()
	var changed:=0;var ids: Dictionary={}
	for row in demolition_candidate.elements:ids[row.id]=row
	var red:=StandardMaterial3D.new();red.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;red.albedo_color=Color(.95,.18,.10,.35)
	var clipped_red:=ShaderMaterial.new();clipped_red.shader=preload("res://assets/shaders/build_area_highlight.gdshader");clipped_red.set_shader_parameter("area",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
	if is_instance_valid(room):
		for mesh in room.find_children("*","MeshInstance3D",true,false):
			var id:=element_id(mesh)
			if id=="" or ids.get(id,{})==Layout.find(layout,id):continue
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
			highlighted.append([mesh,mesh.material_overlay]);mesh.material_overlay=clipped_red if Layout.find(layout,id).get("type","")=="wall" else red;changed+=1
	ghost.show();ghost_material.albedo_color=Color(.94,.22,.13,.24);ghost.rotation=Vector3.ZERO;ghost.scale=Vector3(maxf(.01,bounds.size.x),.04,maxf(.01,bounds.size.y));var center:=bounds.get_center();ghost.position=Vector3(center.x,.23,center.y)
	var before:=Layout.usage(layout);var after:=Layout.usage(demolition_candidate)
	var openings_before: int=layout.elements.filter(func(row):return row.type in ["door","window"]).size();var openings_after: int=demolition_candidate.elements.filter(func(row):return row.type in ["door","window"]).size()
	ui.message("松开拆除 %.2f㎡地面、%.1f米墙、%d件物品、%d处门窗、%d块屋顶（含失去支撑者） · Esc取消"%[maxf(0,before.floor_area-after.floor_area),maxf(0,before.wall_length-after.wall_length),maxi(0,before.objects-after.objects),maxi(0,openings_before-openings_after),maxi(0,before.roofs-after.roofs)])
func finish_demolition(mouse: Vector2) -> void:
	if demolition_start==null:return
	if demolition_dragging:
		preview_demolition(mouse)
		if not demolition_candidate.is_empty():commit(demolition_candidate)
	else:
		select_at(demolition_mouse)
		var row:=selected_row()
		if not row.is_empty() and (demolition_target_type=="single" or row.type==demolition_target_type):delete_selected()
	demolition_start=null;demolition_target_type="";demolition_dragging=false;demolition_candidate.clear();demolition_key="";clear_highlight();ghost.hide();selected_unit.clear();selected_id="";refresh_ui()

func reselect_unit(row: Dictionary) -> void:
	var index:=Layout.compiled(layout);var source: Dictionary={}
	if row.type=="floor":source=index.floors.get(Grid.coordinates(row)[0],{})
	elif row.type=="wall":source=index.walls.get(Grid.edges(row)[0],{})
	selected_id=str(source.get("id",""));selected_unit=Layout.unit_at(layout,selected_id,Layout.rect(row).get_center()) if not source.is_empty() else {}
func _input(event: InputEvent) -> void:
	if active and demolition_start!=null and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		finish_demolition(event.position);get_viewport().set_input_as_handled()
