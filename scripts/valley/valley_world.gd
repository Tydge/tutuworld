extends "res://scripts/city/city_world.gd"
var stream_material: ShaderMaterial
const Layout=preload("res://scripts/valley/valley_layout.gd")
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
	# Each running map owns its daylight uniforms.
	var creek: Node3D=scenery.get_node("Creek")
	if not creek.get_meta("unified_water",false):
		var original: ShaderMaterial=creek.get_meta("stream_material")
		stream_material=original.duplicate()
		for node in scenery.find_children("*","GeometryInstance3D",true,false):
			if node.material_override==original:node.material_override=stream_material
	# Trail entrance, bridge and cottage only; moonlight carries the forest.
	for lamp in scenery.get_node("Streetlights").get_children():
		var point:=Vector2(lamp.position.x,lamp.position.z)
		if point not in [Vector2(-20,58),Vector2(16,16),Vector2(36,-56)]:
			lamp.get_parent().remove_child(lamp);lamp.free()
func update_lighting(override_time: float=-1) -> void:
	super.update_lighting(override_time)
	if stream_material:
		var sea: ShaderMaterial=scenery.get_node("Island").get_meta("sea_material")
		stream_material.set_shader_parameter("sea_color",sea.get_shader_parameter("sea_color"))
		stream_material.set_shader_parameter("daylight",ambient_day)
	sun.light_energy=lerpf(.30,1.45,ambient_day)
	sun.light_color=Color("b0c9f2").lerp(Color("fff6e6"),ambient_day)
	if ambient_day<.01: sun.rotation_degrees=Vector3(-43,-32,0)
	sun.shadow_opacity=lerpf(.42,.76,ambient_day)
	atmosphere.fog_density=lerpf(.0011,.0018,ambient_day)
	for entry in lamp_visuals: entry.light.light_energy=1.7*cached_warmth
