extends "res://scripts/city/city_world.gd"
const Layout=preload("res://scripts/valley/valley_layout.gd")
var sun_target:=Quaternion.IDENTITY
var sun_initialized:=false
func _process(delta: float) -> void:
	super._process(delta)
	if sun_initialized:sun.quaternion=sun.quaternion.slerp(sun_target,1.-exp(-delta*8.))
func can_walk(p: Vector3) -> bool: return Layout.can_walk(p)
func can_navigate(p: Vector3) -> bool: return Layout.can_navigate(p)
func navigation_bounds() -> Rect2i: return Rect2i(-108,-96,217,220)
func respawn_position() -> Vector3: return Vector3(-22,Layout.walk_height(-22,86)+.035,86)
func player_spawn_position(pos: Array) -> Vector3:
	var p:=Vector3(pos[0],pos[1],pos[2])
	if not Layout.can_walk(p):return respawn_position()
	var floor_: float=Layout.walk_height(p.x,p.z)+.035
	if absf(p.x-Layout.HOUSE.x)<6.35 and absf(p.z-Layout.HOUSE.z)<5.35:floor_=Layout.HOUSE.y+.20
	p.y=maxf(p.y,floor_);return p
func setup_targets() -> void:
	setup_resources()
	preload("res://scripts/city/interaction_targets.gd").add_benches(self)
	for id in ["home_sofa","home_desk"]:
		var seat: Node3D=home.seat_node(id)
		preload("res://scripts/city/seating.gd").ensure(seat,2 if id=="home_sofa" else 1)
		targets[id]={"kind":"bench","position":seat.get_node("ExitAnchor").global_position,"radius":1.65,"node":seat,"label":"坐下来，听听溪水"}
func spawn_npcs() -> void:
	var rng:=RandomNumberGenerator.new();rng.randomize()
	var panda:=spawn_npc("Panda","潘达",Vector3(24,Layout.height_at(24,-65.5)+.2,-65.5),random_clothes(rng),"panda")
	var driver:=preload("res://scripts/valley/panda_routine.gd").new();driver.name="PandaRoutine";driver.bunny=panda;driver.city=self;panda.add_child(driver)
	targets.Panda={"kind":"npc","position":panda.position,"radius":2.8,"node":panda,"name":"潘达","profile":6}
	for i in range(2):
		var id: String="ValleyVisitor%d"%i
		var point: Vector3=Vector3(-36,Layout.height_at(-36,40)+.2,40) if i==0 else Vector3(44,Layout.height_at(44,-32)+.2,-32)
		var name_: String="叶芽" if i==0 else "溪豆"
		var visitor:=spawn_npc(id,name_,point,random_clothes(rng),"bunny")
		var routine:=preload("res://scripts/valley/visitor_routine.gd").new();routine.name="VisitorRoutine";routine.city=self;routine.bunny=visitor;visitor.add_child(routine)
		targets[id]={"kind":"npc","position":point,"radius":2.8,"node":visitor,"name":name_,"profile":7+i}
func random_clothes(rng: RandomNumberGenerator) -> Dictionary:
	var worn: Dictionary={}
	for slot in ["head","body","neck"]:
		var choices: Array=[]
		for id in DB.catalog().items:
			if DB.item(id).get("slot","")==slot: choices.append(id)
		worn[slot]=choices[rng.randi_range(0,choices.size()-1)]
	return worn
func interact() -> void:
	if current_target=="Panda" and targets.Panda.node.sleeping:
		hud.notify("潘达睡得正香，明天再来聊吧。")
		return
	super.interact()

func recover_spawn() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if session.is_online() or sleep_active or nap_active:return
	# A valid hillside position is already supported by the real capsule. Only
	# search for a replacement when new scenery actually overlaps the avatar.
	var query:=PhysicsShapeQueryParameters3D.new();query.collision_mask=7;query.exclude=[bunny.get_rid()]
	var blocked:=false
	for child in bunny.get_children():
		if not child is CollisionShape3D or child.disabled:continue
		query.shape=child.shape;query.transform=bunny.global_transform*child.transform
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():blocked=true;break
	if not blocked:return
	var result: Dictionary=preload("res://scripts/city/local_landing.gd").find(self,bunny.position,bunny)
	if result.is_empty():result=preload("res://scripts/city/local_landing.gd").find(self,respawn_position(),bunny)
	if not result.is_empty():
		bunny.position=result.position;bunny.velocity=Vector3.ZERO;bunny.reset_physics_interpolation();session.set_player_position(bunny.position)
func prepare_scenery() -> void:
	recover_spawn.call_deferred()
	var forest_view=preload("res://scripts/valley/woodland_view.gd").new();forest_view.city=self;add_child(forest_view)
	# Trail entrance, bridge and cottage only; moonlight carries the forest.
	for lamp in scenery.get_node("Streetlights").get_children():
		var point:=Vector2(lamp.position.x,lamp.position.z)
		if point not in [Vector2(-20,58),Vector2(16,16),Vector2(36,-56)]:
			lamp.get_parent().remove_child(lamp);lamp.free()
func update_lighting(override_time: float=-1) -> void:
	var previous:=sun.quaternion
	super.update_lighting(override_time)
	var t:=override_time if override_time>=0 else fposmod(float(session.state().time)/3600.,1.)
	var low_sun:=1.-smoothstep(.12,.65,sin((t-.25)*TAU))
	sun.light_energy=lerpf(.30,1.35,ambient_day)
	sun.light_color=Color("b0c9f2").lerp(Color("fff2db").lerp(Color("ffd0a0"),low_sun*.55),ambient_day)
	if ambient_day<.01: sun.rotation_degrees=Vector3(-43,-32,0)
	sun.shadow_opacity=lerpf(.42,.86,ambient_day)
	sun.light_angular_distance=.53;sun.shadow_blur=1.15;sun.shadow_normal_bias=.35
	sun_target=sun.quaternion
	if sun_initialized and override_time<0:sun.quaternion=previous
	sun_initialized=true
	atmosphere.fog_density=lerpf(.0009,.0012,ambient_day)
	for entry in lamp_visuals: entry.light.light_energy=1.7*cached_warmth
func update_ambient_lighting() -> void:
	var indoors:=interior_weight()
	atmosphere.ambient_light_energy=lerpf(lerpf(.28,.46,ambient_day),lerpf(.26,.34,ambient_day),indoors)
	atmosphere.ambient_light_color=Color("7894b8").lerp(Color("c6d9eb"),ambient_day).lerp(Color("d9c6a5"),indoors*.60)
