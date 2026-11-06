extends "res://scripts/city/seabreeze_home.gd"
const Storeys=preload("res://scripts/building/storeys.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const Site=preload("res://scripts/building/site.gd")
var plans: Dictionary={}
var layout_data: Dictionary={}
var stair_rows: Array=[]
var visible_storey:=0
var editing_storey:=0
var entire_building:=false
var storey_view_key:=""
var hidden_camera_bodies: Array[RID]=[]
var other_storey_bodies: Array[RID]=[]
const Grid=preload("res://scripts/building/grid_layout.gd")
const Rooms=preload("res://scripts/building/room_plan.gd")
var plan: Dictionary={}
var wall_faces: Dictionary={}
var visibility_tick:=0
var plan_input_signature:=""
var render_cache: Dictionary={}
var module_prototypes: Dictionary={}
var mask_texture: ImageTexture
var mask_bytes:=PackedByteArray()
var mask_key:=""
var view_dirty:=true
var last_view_actor:=Vector3(INF,INF,INF)
var last_view_camera:=Vector3(INF,INF,INF)
var last_view_key:=""
var editor_active:=false
var editor_roof:=false
var editor_roof_view:=false
var current_room:=""
var last_sync: Dictionary={}
var pending_navigation:=Rect2()
var material_updates:=0
var furniture_house: Dictionary={}
var furniture_house_key:=""
const MASK_ORIGIN:=Vector2i(120,-16)
const MASK_SIZE:=Vector2i(200,72)
func _ready() -> void:pass
func configure(grid: Dictionary) -> void:
	if grid.get("signature","")!="" and grid.signature==plan_input_signature:return
	plan_input_signature=str(grid.get("signature",""));wall_faces=View.wall_faces(grid.walls)
	var next_plan:=Rooms.make(grid)
	if not plan.is_empty() and next_plan.signature==plan.signature:return
	plan=next_plan;mask_key="";mask_bytes.resize(MASK_SIZE.x*MASK_SIZE.y);mask_bytes.fill(0)
	if mask_texture==null:mask_texture=ImageTexture.create_from_image(Image.create_from_data(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_R8,mask_bytes))
func update_lighting(day: float) -> void:last_day=day
func configure_layout(data: Dictionary) -> void:
	layout_data=data;stair_rows=data.elements.filter(func(row):return row.type=="stairs")
	var signature:=str(hash(data.elements.filter(func(row):return row.type in ["wall","floor","stairs"])))
	if signature==plan_input_signature:return
	plans.clear()
	for level in range(Storeys.MAX):plans[level]=Rooms.make(Layout.walkable_grid(data,level))
	configure(Layout.walkable_grid(data,0));plan_input_signature=signature
	wall_faces.clear()
	for level in range(Storeys.MAX):wall_faces.merge(View.wall_faces(Layout.compiled(data,level).walls))
	storey_view_key="";view_dirty=true
func room_at_position(point_: Vector3) -> String:
	var level:=Storeys.at_height(point_.y)
	if not plans.has(level) or absf(point_.y-(Storeys.FLOOR+level*Storeys.HEIGHT))>3.9:return ""
	return Rooms.room_at(plans[level],Vector2(point_.x,point_.z))
func contains_position(point_: Vector3) -> bool:
	return room_at_position(point_)!="" or stair_at(point_)
func surface_at(point_: Vector3) -> bool:
	var level:=Storeys.at_height(point_.y)
	return plans.has(level) and plans[level].floors.has(Grid.cell(Vector2(point_.x,point_.z))) and absf(point_.y-(Storeys.FLOOR+level*Storeys.HEIGHT))<3.9
func stair_at(point_: Vector3) -> bool:
	for row in stair_rows:
		if point_.y>=Storeys.elevation(row)-.1 and point_.y<=Storeys.elevation(row)+Storeys.HEIGHT+.4 and Stairs.bounds(row).has_point(Vector2(point_.x,point_.z)):return true
	return false
func set_editor_view(enabled: bool,roof: bool,level: int=0,entire: bool=false,roof_view: bool=false) -> void:
	if editor_active!=enabled or editor_roof!=roof or editing_storey!=level or entire_building!=entire or editor_roof_view!=roof_view:mask_key="";view_dirty=true;storey_view_key=""
	editor_roof_view=roof_view;editor_active=enabled;editor_roof=roof;editing_storey=level;entire_building=entire
	get_node("Structure/Roof").visible=not enabled or roof_view
	if is_instance_valid(city) and is_instance_valid(city.camera):refresh_view(city.camera.global_position,city.bunny.global_position)
func apply_storey_visibility(actor: Vector3) -> void:
	var in_house:=surface_at(actor) or stair_at(actor)
	if editor_active:visible_storey=editing_storey
	elif not in_house:visible_storey=Storeys.at_height(actor.y)
	else:
		# Keep the floor stable on the flight; the camera itself follows every step.
		while visible_storey<Storeys.MAX-1 and actor.y>=(visible_storey+1)*Storeys.HEIGHT+Storeys.FLOOR-.16:visible_storey+=1
		while visible_storey>0 and actor.y<visible_storey*Storeys.HEIGHT+Storeys.FLOOR-.55:visible_storey-=1
	var mode_: int=View.mode(city)
	var show_objects: bool=city.session.settings.get("show_other_storey_objects",true) and mode_!=View.AUTO
	var actor_room:=Rooms.room_at(plans.get(visible_storey,plans[0]),Vector2(actor.x,actor.z))
	var house_key:=str([visible_storey,plan_input_signature,actor_room,Grid.cell(Vector2(actor.x,actor.z)) if actor_room=="" else Vector2i.ZERO])
	if not show_objects and not editor_active and in_house and house_key!=furniture_house_key:
		furniture_house=preload("res://scripts/building/storey_extension.gd").footprint(Layout.walkable_grid(layout_data,visible_storey),Vector2(actor.x,actor.z));furniture_house_key=house_key
	var key:=str([visible_storey,editor_active,editor_roof,editor_roof_view,entire_building,in_house,mode_,show_objects,house_key])
	if key==storey_view_key:return
	storey_view_key=key;view_dirty=true;hidden_camera_bodies.clear();other_storey_bodies.clear();occlusion_cache.clear()
	for entry in render_cache.values():
		var row: Dictionary=entry.row;var level:=Storeys.of(row);var visible_:=true
		if editor_active and not entire_building and not editor_roof_view:
			visible_=level==visible_storey or (row.type=="floor_chunk" and level<visible_storey) or (row.type=="stairs" and level+1==visible_storey) or (editor_roof and level<visible_storey and row.type in ["wall","joint","door","window","railing","stairs"])
		elif not editor_active and in_house:
			visible_=level<=visible_storey or (mode_!=View.AUTO and row.type!="object")
			# A solid upper slab hides the indoor furnishings and lamps below it.
			# Keep objects visible through a stair opening or outside on the grounds.
			if visible_ and level<visible_storey and row.type=="object" and plans.has(level) and Rooms.room_at(plans[level],Vector2(row.position[0],row.position[1]))!="" and Grid.covered(Catalog.footprint(row),plans[visible_storey].floors):visible_=false
			if row.type=="object" and (show_objects or not furniture_house.has(Grid.cell(Vector2(row.position[0],row.position[1])))):visible_=true
		# Hidden structural shells still cast shadows. Free modes keep the actual shell.
		var shadow_only: bool=not visible_ and row.type in ["floor_chunk","wall","roof","joint","door","window"] and not editor_active
		var ceiling_shadow: bool=not visible_ and row.type=="floor_chunk" and level==visible_storey+1 and editor_active
		entry.node.visible=visible_ or shadow_only or ceiling_shadow
		entry.node.set_meta("storey_cut",shadow_only)
		for visual in entry.get("visuals",[]):
			if not visual.has_meta("storey_shadow"):visual.set_meta("storey_shadow",visual.cast_shadow)
			var original: int=visual.get_meta("storey_shadow")
			visual.visible=not shadow_only or original!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if (shadow_only or ceiling_shadow) and original!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else original
		if row.type=="stairs":
			var guard: Node3D=entry.node.get_node_or_null("UpperGuard")
			if guard!=null:
				var isolate: bool=(editor_active and not entire_building) or (not editor_active and mode_==View.AUTO and in_house)
				guard.visible=not isolate or level+1<=visible_storey
		if level!=visible_storey:other_storey_bodies.append_array(entry.get("bodies",[]))
		if not visible_:hidden_camera_bodies.append_array(entry.get("bodies",[]))
	plan=plans.get(visible_storey,plans.get(0,{}));mask_key=""
func set_mask(hidden: Dictionary) -> void:
	var keys: Array=hidden.keys();keys.sort();var key:=str(keys)+":"+str(editor_active)
	if key==mask_key:return
	mask_key=key;mask_bytes.fill(0);var active_cells: Dictionary={}
	if editor_active:
		for c in plan.floors:active_cells[c]=true
	else:
		for id in hidden:
			if plan.rooms.has(id):
				for c in plan.rooms[id].cells:active_cells[c]=true
	# Extend cutaway to the overhang without extending into another enclosed room.
	for c in active_cells.keys():
		for z in range(-2,3):
			for x in range(-2,3):
				var p: Vector2i=c+Vector2i(x,z)
				if not active_cells.has(p) and plan.cell_rooms.has(p):continue
				var image_p: Vector2i=p-MASK_ORIGIN
				if image_p.x>=0 and image_p.y>=0 and image_p.x<MASK_SIZE.x and image_p.y<MASK_SIZE.y:mask_bytes[image_p.y*MASK_SIZE.x+image_p.x]=255
	mask_texture.update(Image.create_from_data(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_R8,mask_bytes))
func hidden_at(p: Vector2) -> bool:
	var c:=Grid.cell(p)-MASK_ORIGIN
	return c.x>=0 and c.y>=0 and c.x<MASK_SIZE.x and c.y<MASK_SIZE.y and mask_bytes[c.y*MASK_SIZE.x+c.x]>0
func refresh_view(camera_: Vector3,actor: Vector3) -> void:
	apply_storey_visibility(actor)
	if plan.is_empty():return
	current_room=Rooms.room_at(plan,Vector2(actor.x,actor.z));inside=contains_position(actor) or stair_at(actor)
	var hidden: Dictionary={}
	if current_room!="":hidden[current_room]=true
	var from:=actor+Vector3.UP*1.65;var ray: Variant=Plane(Vector3.UP,visible_storey*Storeys.HEIGHT+4.58).intersects_segment(from,camera_)
	if ray!=null:
		var id:=Rooms.room_at(plan,Vector2(ray.x,ray.z),false)
		if id!="":hidden[id]=true
	var mode_: int=(View.FULL if editor_roof or editor_roof_view else View.AUTO) if editor_active else View.mode(city)
	var view_key:=str(hidden)+str(editor_active)+str(editor_roof)+str(mode_)
	if mode_!=View.OCCLUSION and not view_dirty and view_key==last_view_key and camera_.distance_squared_to(last_view_camera)<.0001 and actor.distance_squared_to(last_view_actor)<.0001:return
	var force_update:=view_dirty
	last_view_key=view_key;last_view_camera=camera_;last_view_actor=actor;view_dirty=false
	set_mask(hidden if mode_==View.AUTO else {});roof_hidden=not hidden.is_empty() and mode_==View.AUTO
	var occluded:=View.sample_targets(sections,camera_,actor,occlusion_cache,force_update) if mode_==View.OCCLUSION else {}
	var now:=Time.get_ticks_usec();var delta:=clampf((now-visibility_tick)/1000000.,.001,.05);visibility_tick=now
	for section in sections:
		if not section.node.is_visible_in_tree() or section.node.get_meta("storey_cut",false):continue
		var wall: Node3D=section.get("parent_wall",section.node);var normal: Vector3=wall.get_meta("outward",Vector3.BACK)
		var center: Vector3=wall.global_position;var side: float=normal.dot(camera_-center)
		var hide_wall: bool=mode_==View.AUTO and not section.roof and (not editor_active or not editor_roof) and hidden_at(Vector2(center.x,center.z)-Vector2(normal.x,normal.z)*signf(side)*.28)
		section["editor_hidden"]=hide_wall
		if mode_==View.OCCLUSION:
			View.fade(section,occluded.has(View.face(section)),delta)
			if section.roof and section.target<.5:roof_hidden=true
		else:section.erase("occlusion_hold");section.alpha=0. if hide_wall else 1.;section.target=section.alpha
		# Shader inputs depend on camera side, not its exact position. Stable walls
		# must not dirty their material buffers every frame.
		var state_: Array=[mode_,editor_active,editor_roof,signf(side) if mode_==View.AUTO else 0.,section.alpha]
		if not force_update and section.get("render_state",[])==state_:continue
		section.render_state=state_
		material_updates+=section.materials.size()
		for material in section.materials:
			material.set_shader_parameter("building_grid_bounds",Vector4(MASK_ORIGIN.x*.5,MASK_ORIGIN.y*.5,MASK_SIZE.x*.5,MASK_SIZE.y*.5))
			material.set_shader_parameter("opacity",section.alpha if mode_==View.OCCLUSION else 1.);material.set_shader_parameter("cut_base_height",-100. if section.roof or mode_==View.OCCLUSION else global_position.y+visible_storey*Storeys.HEIGHT+floor_level+.62);material.set_shader_parameter("building_cut_mask",mask_texture);material.set_shader_parameter("building_view_position",camera_);material.set_shader_parameter("building_roof_cut",mode_==View.AUTO and section.roof and not editor_active);material.set_shader_parameter("building_wall_cut",mode_==View.AUTO and not section.roof and (not editor_active or not editor_roof));material.set_shader_parameter("building_wall_normal",Vector2(normal.x,normal.z))
		for visual in section.visuals:visual.visible=mode_!=View.OCCLUSION or section.alpha>.002
		for pane in section.glass:
			var p: Vector3=pane.global_position;pane.visible=(not hide_wall or p.y<.8) and (mode_!=View.OCCLUSION or section.alpha>.4)
func _process(delta: float) -> void:
	if assembling or not is_instance_valid(city) or not is_instance_valid(city.camera) or not is_instance_valid(city.bunny):return
	refresh_view(city.camera.global_position,city.bunny.get_global_transform_interpolated().origin)
	interior_weight=move_toward(interior_weight,1. if inside else 0.,delta*3.5)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		for prototype in module_prototypes.values():
			if is_instance_valid(prototype):prototype.free()

func has_roof_at(p: Vector2,level: int=-1) -> bool:
	if level<0:level=visible_storey
	if plans.has(level+1) and plans[level+1].floors.has(Grid.cell(p)):return true
	for entry in render_cache.values():
		var row: Dictionary=entry.get("row",{})
		if row.get("type","")=="roof" and Storeys.of(row)==level and preload("res://scripts/building/layout.gd").rect(row).grow(.6).has_point(p):return true
	return false
