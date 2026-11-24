extends "res://scripts/city/city_world.gd"
const J=preload("res://scripts/jade/layout.gd")
const Residents=preload("res://scripts/jade/residents.gd")
var thanked: Dictionary={}
func conversation_line(id: String) -> String:
	var line: Array=Residents.AFTER_WORK.get(id,[])
	if not line.is_empty() and not thanked.has(id) and line[0] in session.state().jade_visits.marks:
		thanked[id]=true
		return line[1]
	return super.conversation_line(id)
func can_walk(p: Vector3) -> bool:return J.can_walk(p) and not construction_at(p)
func navigation_bounds() -> Rect2i:return J.NAVIGATION
func respawn_position() -> Vector3:return Vector3(0,2.12,203)
func player_spawn_position(pos: Array) -> Vector3:
	var p:=Vector3(pos[0],pos[1],pos[2])
	if not J.dry_footing(p) or not can_walk(p):return respawn_position()
	var floor_y:=J.foot(p.x,p.z)
	if J.by_water(p):floor_y=maxf(J.terrain_floor(p),J.crossing_height(p))
	p.y=maxf(p.y,floor_y+.03)
	return p

func along_shore_velocity(p: Vector3,velocity: Vector3,delta: float) -> Vector3:
	if not J.can_walk(p) or not J.by_water(p):return Vector3.ZERO
	var face:=J.shore_face(p)
	var normal:=Vector3(face.normal.x,0.,face.normal.z).normalized()
	var along:=Vector3(velocity.x,0.,velocity.z).slide(normal)
	var target:=J.clip_bank_step(p,p+along*delta)
	return Vector3(target.x-p.x,0.,target.z-p.z)/delta if can_walk(target) else Vector3.ZERO

func move_on_shore(actor: CharacterBody3D,delta: float,grounded: bool) -> void:
	var before:=actor.global_position
	var on_bank:=false
	if J.by_water(before) and J.can_walk(before) and not is_finite(J.crossing_height(before)):
		var face:=J.shore_face(before)
		on_bank=face.normal.y<.96 and (grounded or absf(face.distance_to(before))<1.)
	if on_bank:
		# The capsule can touch the next, steeper triangle before its centre
		# reaches that triangle. Follow the continuous bank without stair lifts.
		var angle:=actor.floor_max_angle
		var snap:=actor.floor_snap_length
		var constant_speed:=actor.floor_constant_speed
		actor.floor_max_angle=deg_to_rad(85.)
		actor.floor_snap_length=maxf(snap,.45)
		actor.floor_constant_speed=true
		actor.move_and_slide()
		actor.floor_max_angle=angle
		actor.floor_snap_length=snap
		actor.floor_constant_speed=constant_speed
	else:
		actor.move_on_ground(delta,grounded)
	if J.dry_footing(actor.global_position):return
	# Sliding, stepping and jump landings can cross the line after the input check.
	if J.dry_footing(before):
		var corrected:=J.clip_bank_step(before,actor.global_position) if on_bank else before
		actor.global_position=Vector3(corrected.x,maxf(corrected.y,actor.global_position.y),corrected.z)
		if on_bank:
			var along:=along_shore_velocity(corrected,actor.velocity,delta)
			actor.velocity=Vector3(along.x,0.,along.z)
			return
	else:
		actor.global_position=respawn_position()
	actor.velocity=Vector3.ZERO
	actor.reset_physics_interpolation()

var lantern_pools: Array[Node]=[]
var lit_materials: Array[ShaderMaterial]=[]
var horizon: ShaderMaterial
var foothills: ShaderMaterial
var applied_warmth:=-1.
var applied_ambient_day:=-1.
var applied_sun_day:=-1.
var applied_interior:=-1.
func prepare_scenery() -> void:
	# Stars and clouds are drawn to the screen. Only the broad sky gradient
	# enters the reflection cubemap, just as it does on the harbour map.
	var sky: Sky=scenery.get_node("Atmosphere").environment.sky
	sky.radiance_size=Sky.RADIANCE_SIZE_64
	register_city(true)
	var sight:=preload("res://scripts/jade/sight_geometry.gd")
	for room in interiors:sight.prepare_sections(room.sight_sections)
	for rig in scenery.find_children("CanvasRig*","Node3D",true,false):sight.prepare_sections(rig.sight_sections)
	for node in scenery.get_children():
		if node.get_script() in [preload("res://scripts/jade/gallery_view.gd"),preload("res://scripts/jade/gate_view.gd")]:node.city=self;node.set_process(true)
		if node.get_script()==preload("res://scripts/jade/gallery_view.gd"):sight.prepare_sections(node.sight_sections)
	horizon=scenery.get_node("PaintedRange").material_override
	foothills=scenery.get_node("FoldedMountains").material_override
	for mesh: MeshInstance3D in scenery.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count() if mesh.mesh!=null else 0):
			var mat:=mesh.get_active_material(i)
			if mat is ShaderMaterial and mat.shader in [preload("res://assets/shaders/jade_silk_lantern.gdshader"),preload("res://assets/shaders/jade_window.gdshader"),preload("res://assets/shaders/jade_distant_house.gdshader")] and mat not in lit_materials:lit_materials.append(mat)
	lantern_pools=scenery.find_children("*","OmniLight3D",true,false).filter(func(lamp):return lamp.has_meta("street_lamp"))
func update_lighting(override_time: float=-1) -> void:
	update_neighbour_detail()
	var previous_sky:=last_sky_colours
	super.update_lighting(override_time)
	var warmth:=1.-smoothstep(.16,.72,ambient_day)
	if horizon and (applied_warmth<0. or previous_sky!=last_sky_colours):
		for mountain: ShaderMaterial in [horizon,foothills]:
			mountain.set_shader_parameter("air_zenith",last_sky_colours[0])
			mountain.set_shader_parameter("air_horizon",last_sky_colours[1])
			mountain.set_shader_parameter("mountain_day",ambient_day)
	if foothills:foothills.set_shader_parameter("sun_direction",sun.global_basis.z.normalized())
	if absf(warmth-applied_warmth)>.0005:
		applied_warmth=warmth
		atmosphere.glow_enabled=warmth>.005
		for mat in lit_materials:mat.set_shader_parameter("warmth",warmth*.97)
		for lamp in lantern_pools:
			lamp.visible=warmth>.005;lamp.light_energy=warmth*3.8
func fog_density_for(_day: float) -> float:
	return 0.
func set_sunlight(day: float) -> void:
	if is_equal_approx(applied_sun_day,day):return
	if applied_sun_day<0.:
		# Keep a detailed near cascade and let the outer cascade span the district.
		sun.directional_shadow_max_distance=132.
		sun.directional_shadow_split_1=.15
		sun.directional_shadow_fade_start=.76
		sun.shadow_normal_bias=.28;sun.shadow_bias=.035;sun.shadow_blur=1.45
	applied_sun_day=day
	sun.light_color=Color("a9b4c7").lerp(Color("ffebcf"),day)
	sun.light_energy=lerpf(.13,1.30,day)
	sun.shadow_opacity=lerpf(.61,.89,day)
func update_ambient_lighting() -> void:
	var ins:=interior_weight()
	if absf(ins-applied_interior)<.0005 and absf(ambient_day-applied_ambient_day)<.0005:return
	applied_interior=ins;applied_ambient_day=ambient_day
	atmosphere.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_energy=lerpf(lerpf(.29,.45,ambient_day),.40,ins)
	atmosphere.ambient_light_color=Color("929aad").lerp(Color("cddde2"),ambient_day).lerp(Color("ddc5a0"),ins*.62)

func update_neighbour_detail() -> void:
	if not is_instance_valid(bunny):return
	for npc in npcs:
		var distance: float=npc.position.distance_squared_to(bunny.position)
		npc.distant_pose_interval=.14 if distance>65.*65. else (.055 if distance>35.*35. else (1./30. if distance>21.*21. else 0.))
func set_crowd_detail(actor: CharacterBody3D) -> void:
	# Keep bodies, ears, robes and hats visible across the fields. Tiny overlapping
	# face details and their shadow casters only contribute from closer cameras.
	for part: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not part.mesh:continue
		var box:=Transform3D(part.global_basis,Vector3.ZERO)*part.get_aabb()
		var size_:=box.size[box.size.max_axis_index()]
		var reach:=0.
		if part.name=="InkOutline":reach=48.
		elif size_<.27:reach=30.
		elif size_<.48:reach=43.
		if reach>0.:
			part.visibility_range_end=reach
			part.visibility_range_end_margin=3.
		if size_<.18:part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for label: Label3D in actor.find_children("*","Label3D",true,false):
		label.visibility_range_end=38.;label.visibility_range_end_margin=3.
func register_city(client: bool) -> void:
	preload("res://scripts/jade/architecture.gd").baked.merge(scenery.get_meta("occupation_meshes",{}),true)
	for fixture in scenery.get_node("Shop_spice/Front").get_children():
		if fixture.get_meta("furniture_kind","")=="jade_steam_table" and not fixture.has_meta("facility_id"):
			preload("res://scripts/jade/trades.gd").cook_station(fixture)
	for h in J.HOUSES:
		var room:=scenery.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0]) as Node3D
		room.city=self;room.set_process(client);interiors.append(room)
		for obj in room.get_node("Furnishing").get_children():
			var id: String="jade:%s:%s"%[h[0],obj.name]
			preload("res://scripts/city/room_activities.gd").register(self,id,obj)
			if obj.has_node("SeatAnchor"):
				targets[id]={"kind":"bench","position":obj.global_position,"node":obj,"radius":2.2}
			elif obj.has_node("SleepExit"):
				targets[id]={"kind":"bed","position":obj.global_position,"node":obj,"radius":1.65}
				if client:preload("res://scripts/building/bed_comfort.gd").attach(obj,self,id,true)
	for id in J.LANDMARKS:
		var landmark: Dictionary=J.LANDMARKS[id].duplicate()
		landmark.merge({"kind":"landmark","position":J.point(landmark.at.x,landmark.at.y),"radius":3.4})
		targets[id]=landmark
	for p in DB.plots("jade"):
		targets[p.id]={"kind":"plot","position":J.point(p.x,p.z),"radius":2.1}
		if client:
			var visual:=CropVisual.new();visual.position=J.point(p.x,p.z)+Vector3.UP*.17;add_child(visual);crops[p.id]=visual
func setup_targets() -> void:
	setup_resources()
	preload("res://scripts/city/production_facilities.gd").register(self)
	preload("res://scripts/city/production_facilities.gd").refresh(self,session.authority)
func attire(seed_: int,royal: bool) -> Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=seed_+85013
	var worn: Dictionary={}
	for slot in ["head","body","neck"]:
		var pool: Array=[]
		for id in DB.Clothes.items():
			var item:=DB.item(id)
			if item.get("rank","")==("court" if royal else "folk") and item.slot==slot:pool.append(id)
		if not pool.is_empty():worn[slot]=pool[rng.randi_range(0,pool.size()-1)]
	return worn
func spawn_npcs() -> void:
	for shop in J.shops():
		var p: Vector2=J.shops()[shop];var id: String="JadeVendor_"+shop;var label_: String=Residents.SHOPS[shop][0]
		var npc:=spawn_npc(id,label_,J.point(p.x,p.y)+Vector3.UP*.12,attire(id.hash(),false))
		targets[id]={"kind":"shop","position":npc.position,"radius":3.3,"shop":shop,"node":npc,"name":label_}
	for i in range(Residents.PEOPLE.size()):
		var r: Array=Residents.PEOPLE[i];var p:=J.point(r[2],r[3])+Vector3.UP*.06
		var id: String="JadeCitizen_"+str(i);var npc:=spawn_npc(id,r[0],p,attire(i,r[3] < -82 and absf(r[2]) < 80),["bunny","cat_teacher","bunny","panda"][i%4])
		npc.distant_pose_elapsed=(i%8)*.016
		if i in [0,3]:
			preload("res://scripts/jade/handwork.gd").carry(npc,i==0)
		targets[id]={"kind":"npc","position":p,"radius":2.8,"node":npc,"name":r[0],"profile":i}
		var driver:=Driver.new();driver.name="NeighbourWalk";driver.city=self;driver.bunny=npc
		driver.route=preload("res://scripts/jade/street_life.gd").walk_stops(i,p)
		npc.add_child(driver)
	if not has_method("chatting_with"):
		for actor in npcs:set_crowd_detail(actor)
	if has_method("chatting_with") or not session.is_online():
		var life_: Node=preload("res://scripts/jade/street_life.gd").new()
		life_.name="StreetLife";life_.city=self;add_child(life_)


# At the palace door a passing courtier can fill the lens while the player
# is still several metres away. Only cut a nearby figure on that sightline.
var lens_courtiers: Array[Node3D]=[]
func clear_palace_lens() -> void:
	var covered: Array[Node3D]=[]
	if absf(bunny.position.x)<14. and bunny.position.z< -143. and bunny.position.z> -178. and preload("res://scripts/city/interior_view.gd").mode(self)!=1:
		var focus:=bunny.global_position+Vector3.UP*1.35
		for npc in npcs:
			var head: Vector3=npc.global_position+npc.rig_profile.head_center
			if head.distance_squared_to(camera.position)>6.25:continue
			var nearest:=Geometry3D.get_closest_point_to_segment(head,camera.position,focus)
			if head.distance_squared_to(nearest)<pow(npc.rig_profile.head_radii.x+.18,2):
				covered.append(npc.visual)
				npc.visual.visible=false
	for visual in lens_courtiers:
		if is_instance_valid(visual) and visual not in covered:visual.visible=true
	lens_courtiers=covered

func update_camera(delta: float) -> void:
	if not is_instance_valid(hud) or hud.mode!="jade_game" or not targets.has(hud.activity_target):
		super.update_camera(delta)
		clear_palace_lens()
		return
	var prop: Node3D=targets[hud.activity_target].node
	var focus:=prop.global_position.lerp(bunny.global_position,.29)+Vector3.UP*1.03
	var eye:=prop.global_basis*Vector3(4.8,2.7,-1.7)
	var point:=camera_safe_position(focus,focus+eye)
	var shift: float=1.22 if get_viewport().get_visible_rect().size.x>=1120 else 0.
	var right:=Vector3.UP.cross(eye.normalized()).normalized()
	camera_focus=camera_focus.lerp(focus+right*shift,1.-exp(-delta*12.))
	camera.position=camera.position.lerp(point,1.-exp(-delta*12.))
	if not camera.position.is_equal_approx(camera_focus):camera.look_at(camera_focus)
	clear_palace_lens()
