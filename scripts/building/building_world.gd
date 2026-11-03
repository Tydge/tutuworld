extends "res://scripts/city/seabreeze_home.gd"
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
var current_room:=""
var last_sync: Dictionary={}
var pending_navigation:=Rect2()
const MASK_ORIGIN:=Vector2i(120,-16)
const MASK_SIZE:=Vector2i(76,72)
func _ready() -> void:pass
func configure(grid: Dictionary) -> void:
	if grid.get("signature","")!="" and grid.signature==plan_input_signature:return
	plan_input_signature=str(grid.get("signature",""));wall_faces=View.wall_faces(grid.walls)
	var next_plan:=Rooms.make(grid)
	if not plan.is_empty() and next_plan.signature==plan.signature:return
	plan=next_plan;mask_key="";mask_bytes.resize(MASK_SIZE.x*MASK_SIZE.y);mask_bytes.fill(0)
	if mask_texture==null:mask_texture=ImageTexture.create_from_image(Image.create_from_data(MASK_SIZE.x,MASK_SIZE.y,false,Image.FORMAT_R8,mask_bytes))
func update_lighting(day: float) -> void:last_day=day
func contains_position(point_: Vector3) -> bool:
	return not plan.is_empty() and point_.y>-.1 and point_.y<4.38 and Rooms.room_at(plan,Vector2(point_.x,point_.z))!=""
func set_editor_view(enabled: bool,roof: bool) -> void:
	if editor_active!=enabled or editor_roof!=roof:mask_key="";view_dirty=true
	editor_active=enabled;editor_roof=roof;get_node("Structure/Roof").visible=not enabled or roof
	if is_instance_valid(city) and is_instance_valid(city.camera):refresh_view(city.camera.global_position,city.bunny.global_position)
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
	if plan.is_empty():return
	current_room=Rooms.room_at(plan,Vector2(actor.x,actor.z)) if actor.y<4.38 else "";inside=current_room!=""
	var hidden: Dictionary={}
	if current_room!="":hidden[current_room]=true
	var from:=actor+Vector3.UP*1.65;var ray: Variant=Plane(Vector3.UP,4.58).intersects_segment(from,camera_)
	if ray!=null:
		var id:=Rooms.room_at(plan,Vector2(ray.x,ray.z),false)
		if id!="":hidden[id]=true
	var mode_: int=View.AUTO if editor_active else View.mode(city)
	var view_key:=str(hidden)+str(editor_active)+str(editor_roof)+str(mode_)
	if mode_!=View.OCCLUSION and not view_dirty and view_key==last_view_key and camera_.distance_squared_to(last_view_camera)<.0001 and actor.distance_squared_to(last_view_actor)<.0001:return
	last_view_key=view_key;last_view_camera=camera_;last_view_actor=actor;view_dirty=false
	set_mask(hidden if mode_==View.AUTO else {});roof_hidden=not hidden.is_empty() and mode_==View.AUTO
	var occluded:=View.targets(sections,camera_,actor) if mode_==View.OCCLUSION else {}
	var now:=Time.get_ticks_usec();var delta:=clampf((now-visibility_tick)/1000000.,.001,.05);visibility_tick=now
	for section in sections:
		var wall: Node3D=section.get("parent_wall",section.node);var normal: Vector3=wall.get_meta("outward",Vector3.BACK)
		var center: Vector3=wall.global_position;var side: float=normal.dot(camera_-center)
		var hide_wall: bool=mode_==View.AUTO and not section.roof and (not editor_active or not editor_roof) and hidden_at(Vector2(center.x,center.z)-Vector2(normal.x,normal.z)*signf(side)*.28)
		section["editor_hidden"]=hide_wall
		if mode_==View.OCCLUSION:
			View.fade(section,occluded.has(View.face(section)),delta)
			if section.roof and section.target<.5:roof_hidden=true
		else:section.erase("occlusion_hold");section.alpha=0. if hide_wall else 1.;section.target=section.alpha
		for material in section.materials:
			material.set_shader_parameter("opacity",section.alpha if mode_==View.OCCLUSION else 1.);material.set_shader_parameter("cut_base_height",-100. if section.roof or mode_==View.OCCLUSION else global_position.y+floor_level+.62);material.set_shader_parameter("building_cut_mask",mask_texture);material.set_shader_parameter("building_view_position",camera_);material.set_shader_parameter("building_roof_cut",mode_==View.AUTO and section.roof and not editor_active);material.set_shader_parameter("building_wall_cut",mode_==View.AUTO and not section.roof and (not editor_active or not editor_roof));material.set_shader_parameter("building_wall_normal",Vector2(normal.x,normal.z))
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

func has_roof_at(p: Vector2) -> bool:
	for entry in render_cache.values():
		var row: Dictionary=entry.get("row",{})
		if row.get("type","")=="roof" and preload("res://scripts/building/layout.gd").rect(row).grow(.6).has_point(p):return true
	return false
