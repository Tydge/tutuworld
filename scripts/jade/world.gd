extends "res://scripts/city/city_world.gd"
const J=preload("res://scripts/jade/layout.gd")
const Residents=preload("res://scripts/jade/residents.gd")
func can_walk(p: Vector3) -> bool:return J.can_walk(p) and not construction_at(p)
func navigation_bounds() -> Rect2i:return J.NAVIGATION
func respawn_position() -> Vector3:return Vector3(0,2.12,203)
func player_spawn_position(pos: Array) -> Vector3:
	var p:=Vector3(pos[0],pos[1],pos[2]);p.y=maxf(p.y,J.foot(p.x,p.z)+.03)
	return p if can_walk(p) else respawn_position()
var lantern_pools: Array[Node]=[]
var lit_materials: Array[ShaderMaterial]=[]
var horizon: ShaderMaterial
func prepare_scenery() -> void:
	register_city(true)
	for node in scenery.get_children():
		if node.get_script() in [preload("res://scripts/jade/gallery_view.gd"),preload("res://scripts/jade/gate_view.gd")]:node.city=self;node.set_process(true)
	horizon=scenery.get_node("PaintedRange").material_override
	for mesh: MeshInstance3D in scenery.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count() if mesh.mesh!=null else 0):
			var mat:=mesh.get_active_material(i)
			if mat is ShaderMaterial and mat.shader in [preload("res://assets/shaders/jade_silk_lantern.gdshader"),preload("res://assets/shaders/jade_window.gdshader"),preload("res://assets/shaders/jade_distant_house.gdshader")] and mat not in lit_materials:lit_materials.append(mat)
	lantern_pools=scenery.find_children("*","OmniLight3D",true,false).filter(func(lamp):return lamp.has_meta("street_lamp"))
func update_lighting(override_time: float=-1) -> void:
	super.update_lighting(override_time)
	var warmth:=1.-smoothstep(.16,.72,ambient_day)
	if horizon:horizon.set_shader_parameter("daylight_tint",Color("405879").lerp(Color("c6d7ce"),ambient_day))
	for mat in lit_materials:mat.set_shader_parameter("warmth",warmth*.97)
	for lamp in lantern_pools:
		lamp.visible=warmth>.005;lamp.light_energy=warmth*3.8
	atmosphere.fog_density=lerpf(.0014,.00105,ambient_day)
	sun.light_color=Color("a9b4c7").lerp(Color("ffebcf"),ambient_day)
	sun.light_energy=lerpf(.13,1.30,ambient_day)
	sun.directional_shadow_max_distance=lerpf(42.,63.,ambient_day)
	sun.shadow_normal_bias=.28;sun.shadow_bias=.035
	sun.shadow_opacity=lerpf(.61,.89,ambient_day);sun.shadow_blur=1.45
func update_ambient_lighting() -> void:
	var ins:=interior_weight()
	atmosphere.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_energy=lerpf(lerpf(.29,.45,ambient_day),.40,ins)
	atmosphere.ambient_light_color=Color("929aad").lerp(Color("cddde2"),ambient_day).lerp(Color("ddc5a0"),ins*.62)

func register_city(client: bool) -> void:
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
		if slot=="neck" and seed_%5==0:pool.append("bell_red")
		if not pool.is_empty():worn[slot]=pool[rng.randi_range(0,pool.size()-1)]
	return worn
func spawn_npcs() -> void:
	for shop in J.shops():
		var p: Vector2=J.shops()[shop];var id: String="JadeVendor_"+shop;var label_: String=Residents.SHOPS[shop][0]
		var npc:=spawn_npc(id,label_,J.point(p.x,p.y)+Vector3.UP*.12,attire(id.hash(),false))
		targets[id]={"kind":"shop","position":npc.position,"radius":3.3,"shop":shop,"node":npc,"name":label_}
	for i in range(Residents.PEOPLE.size()):
		var r: Array=Residents.PEOPLE[i];var p:=J.point(r[2],r[3])+Vector3.UP*.06
		var id: String="JadeCitizen_"+str(i);var npc:=spawn_npc(id,r[0],p,attire(i,i>=12),["bunny","cat_teacher","bunny","panda"][i%4])
		targets[id]={"kind":"npc","position":p,"radius":2.8,"node":npc,"name":r[0],"profile":i}
		var driver:=Driver.new();driver.name="NeighbourWalk";driver.city=self;driver.bunny=npc
		driver.route=preload("res://scripts/jade/street_life.gd").walk_stops(i,p)
		npc.add_child(driver)
	if has_method("chatting_with") or not session.is_online():
		var life_: Node=preload("res://scripts/jade/street_life.gd").new()
		life_.name="StreetLife";life_.city=self;add_child(life_)
