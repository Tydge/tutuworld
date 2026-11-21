extends "res://scripts/city/city_world.gd"
const IceLayout=preload("res://scripts/icefield/icefield_layout.gd")
var current_outfits: Dictionary={}
var footprints: Node3D
var sun_target:=Quaternion.IDENTITY
var sun_ready:=false
const RESIDENTS=[
	{"id":"SnowBunny0","name":"雪芽","species":"bunny","p":Vector2(-75,39),"head":"pompom_cap_frost","neck":"kerchief_pine","body":"duffle_frost"},
	{"id":"SnowBunny1","name":"霜铃","species":"bunny","p":Vector2(-48,15),"head":"winter_rosette_berry","neck":"loop_cowl_frost","body":"capelet_berry"},
	{"id":"SnowBunny2","name":"松露","species":"bunny","p":Vector2(-87,-45),"head":"pompom_cap_pine","neck":"loop_cowl_berry","body":"duffle_pine"},
	{"id":"SnowBunny3","name":"小絮","species":"bunny","p":Vector2(16,21),"head":"winter_rosette_frost","neck":"kerchief_berry","body":"capelet_pine"},
	{"id":"SnowCat","name":"米霜","species":"cat_teacher","p":Vector2(-43,52),"head":"winter_rosette_pine","neck":"bell_red","body":"duffle_berry"},
	{"id":"SnowPanda","name":"团雪","species":"panda","p":Vector2(-85,61),"head":"pompom_cap_berry","neck":"kerchief_frost","body":"capelet_frost"}
]
func _ready() -> void:
	await super._ready()
	camera.far=2000.
	footprints=preload("res://scripts/icefield/snow_footprints.gd").new();footprints.name="SnowFootprints";footprints.city=self;add_child(footprints)
	var weather=preload("res://scripts/icefield/winter_atmosphere.gd").new();weather.name="WinterAtmosphere";weather.city=self;add_child(weather)
	life.hide();ambience.volume_db=-31
func prepare_scenery() -> void:
	register_winter_rooms(true)
	var reflection=preload("res://scripts/icefield/ice_reflections.gd").new();reflection.name="LakeReflection";reflection.city=self;add_child(reflection)
func register_winter_rooms(render_rooms: bool) -> void:
	preload("res://scripts/icefield/snow_trail.gd").place(self)
	for b in IceLayout.BUILDINGS:
		if b.kind=="shop":continue
		var room:=scenery.get_node("Room_"+b.id) as Node3D
		room.city=self
		room.set_process(render_rooms)
		interiors.append(room)
		for obj in room.get_node("Furnishing").get_children():
			preload("res://scripts/city/room_activities.gd").register(self,"winter:%s:%s"%[b.id,obj.name],obj)
			if b.room=="lodge" and obj.has_node("SleepExit"):
				var bed_id: String="winter_bed:%s:%s"%[b.id,obj.name]
				targets[bed_id]={"kind":"bed","position":obj.global_position,"radius":1.65,"node":obj}
				if render_rooms:preload("res://scripts/building/bed_comfort.gd").attach(obj,self,bed_id,true)
			if not obj.has_node("SeatAnchor"):continue
			var id: String="winter_seat:%s:%s"%[b.id,obj.name]
			targets[id]={"kind":"bench","position":obj.global_position,"radius":2.4,"node":obj}

func _process(delta: float) -> void:
	super._process(delta)
	if sun_ready:sun.quaternion=sun.quaternion.slerp(sun_target,1.-exp(-delta*6.))
func can_walk(p: Vector3) -> bool:return not construction_at(p) and IceLayout.can_walk(p)
func can_navigate(p: Vector3) -> bool:return can_walk(p) and IceLayout.normal_at(p.x,p.z).y>.86
func navigation_bounds() -> Rect2i:return Rect2i(-175,-154,351,309)
func respawn_position() -> Vector3:
	var p:=IceLayout.arrival();return Vector3(p[0],p[1],p[2])
func player_spawn_position(pos: Array) -> Vector3:
	var p:=Vector3(pos[0],pos[1],pos[2])
	return Vector3(p.x,maxf(p.y,IceLayout.walk_height(p.x,p.z)+.035),p.z) if can_walk(p) else respawn_position()
func is_ice_surface(p: Vector3) -> bool:return IceLayout.is_ice(p)
func movement_acceleration(p: Vector3,moving: bool) -> float:
	return (IceLayout.ACCELERATION if moving else IceLayout.BRAKING) if IceLayout.is_ice(p) else (20. if moving else 24.)
func setup_targets() -> void:
	setup_resources();preload("res://scripts/city/interaction_targets.gd").add_benches(self)
	for r in DB.resources("icefield"):
		if r.item=="branch":continue
		var visual: Node3D=resources[r.id]
		var size_:=Vector3(.82,.10,.24) if r.item=="birch" else Vector3(.52,.10,.46)
		G.ball(visual,Vector3(0,.64 if r.item=="birch" else .55,0),size_,preload("res://scripts/icefield/winter_props.gd").mat("snow"),"SnowCap")
func spawn_npcs() -> void:
	for d in [["farm","冬葵","beret_sage","apron_sage"],["tools","岩叔","beret_plaid_honey","vest_sage"],["clothes","绒绒","pompom_cap_berry","capelet_berry"]]:
		var p: Vector3=scenery.get_node("Shop_"+d[0]+"/MerchantAnchor").global_position
		var n:=spawn_npc("FrostMerchant_"+d[0],d[1],p,{"head":d[2],"body":d[3],"neck":"scarf_red"})
		targets[str(n.name)]={"kind":"shop","position":p,"radius":3.3,"shop":d[0],"node":n,"name":d[1]}
	var tour: Array[Vector2]=[Vector2(-79,90),Vector2(-79,47),Vector2(-40,16),Vector2(-16,16),Vector2(16,21),Vector2(48,-3),Vector2(48,42),Vector2(-79,-12),Vector2(-79,-49),Vector2(-102,-86),Vector2(-110,64)]
	for i in range(RESIDENTS.size()):
		var d: Dictionary=RESIDENTS[i];var p:=Vector3(d.p.x,IceLayout.height_at(d.p.x,d.p.y)+.03,d.p.y)
		var n:=spawn_npc(d.id,d.name,p,{"head":d.head,"body":d.body,"neck":d.neck},d.species)
		var driver:=Driver.new();driver.name="WinterWander";driver.bunny=n;driver.city=self
		for point: Vector2 in tour:driver.route.append(Vector3(point.x,IceLayout.walk_height(point.x,point.y)+.03,point.y))
		n.add_child(driver)
		targets[d.id]={"kind":"npc","position":p,"radius":2.8,"node":n,"name":d.name,"profile":9+i}
	var bakery:=scenery.get_node("Room_bakery") as Node3D
	var baker:=spawn_npc("SnowBaker","麦穗",bakery.to_global(Vector3(-1.45,.14,-2.15)),{"head":"pompom_cap_pine","neck":"kerchief_berry","body":"apron_honey"})
	targets["SnowBaker"]={"kind":"npc","position":baker.position,"radius":3.,"node":baker,"name":"麦穗","profile":15}
	for npc in npcs:npc.set_meta("winter_default",npc.get_meta("equipment").duplicate())
	apply_resident_outfits(session.state().get("winter_outfits",{}))

func apply_resident_outfits(overrides: Dictionary) -> void:
	if npcs.is_empty() or overrides==current_outfits:return
	current_outfits=overrides.duplicate(true)
	for npc in npcs:
		var worn: Dictionary=npc.get_meta("winter_default").merged(overrides.get(str(npc.name),{}),true)
		if worn!=npc.get_meta("equipment"):
			npc.set_meta("equipment",worn)
			Outfit.apply(npc,worn)

func refresh_world() -> void:
	super.refresh_world()
	if not session.is_online():apply_resident_outfits(session.state().get("winter_outfits",{}))

func update_lighting(override_time: float=-1) -> void:
	var old:=sun.quaternion
	super.update_lighting(override_time)
	var t:=override_time if override_time>=0 else fposmod(float(session.state().time)/3600.,1.)
	var celestial:=preload("res://scripts/icefield/polar_celestial.gd").at_time(t)
	var height_:=sin((t-.25)*TAU);var dusk:=1.-smoothstep(.04,.52,absf(height_))
	var day:=ambient_day;var sky: ShaderMaterial=atmosphere.sky.sky_material
	var horizon:=Color("192c50").lerp(Color("8bb9d5"),day).lerp(Color("f7a284"),dusk*.86)
	sky.set_shader_parameter("zenith_color",Color("07172f").lerp(Color("1e699e"),day).lerp(Color("647bb9"),dusk*.55))
	sky.set_shader_parameter("horizon_color",horizon);sky.set_shader_parameter("cloud_color",Color("263950").lerp(Color("eef1ed"),day).lerp(Color("ffc18c"),dusk*.95))
	sun.quaternion=Basis.looking_at(-celestial.key_direction,Vector3.UP).get_rotation_quaternion()
	sun.light_color=Color("fff1d9").lerp(Color("ffb36e"),dusk*.85) if day>.02 else Color("a9c8f2")
	sun.light_energy=celestial.energy;sun.light_specular=celestial.specular;sun.shadow_bias=.10;sun.shadow_normal_bias=.65;sun.shadow_blur=1.3;sun.light_angular_distance=.53
	sky.set_shader_parameter("sun_direction",celestial.sun_direction);sky.set_shader_parameter("moon_direction",celestial.moon_direction)
	sky.set_shader_parameter("solar_visibility",celestial.solar)
	sun_target=sun.quaternion
	if sun_ready and override_time<0:sun.quaternion=old
	sun_ready=true
	atmosphere.fog_density=lerpf(.00038,.00048,day);atmosphere.fog_light_color=horizon
	var ice: ShaderMaterial=scenery.get_meta("ice_material");ice.set_shader_parameter("daylight",day)
	var warmth:=1.-smoothstep(.30,.86,day)
	for entry in lamp_visuals:
		entry.light.visible=warmth>.001;entry.light.light_energy=2.1*warmth
		entry.glass.emission_energy_multiplier=lerpf(.04,.82,warmth)
		entry.halo.set_shader_parameter("opacity",warmth*.20);entry.pool.set_shader_parameter("opacity",warmth*.22)
func update_ambient_lighting() -> void:
	var indoors:=interior_weight()
	atmosphere.ambient_light_energy=lerpf(lerpf(.17,.44,ambient_day),.30,indoors)
	atmosphere.ambient_light_color=Color("799abc").lerp(Color("c9dded"),ambient_day).lerp(Color("e0cbb2"),indoors)
