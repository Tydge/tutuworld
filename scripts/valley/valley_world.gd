extends "res://scripts/city/city_world.gd"
var stream_material: ShaderMaterial
const Layout=preload("res://scripts/valley/valley_layout.gd")
func can_walk(p: Vector3) -> bool: return Layout.can_walk(p)
func can_navigate(p: Vector3) -> bool: return Layout.can_navigate(p)
func navigation_bounds() -> Rect2i: return Rect2i(-54,-46,109,106)
func respawn_position() -> Vector3: return Vector3(-11,.3,43)
func setup_targets() -> void:
	setup_resources()
	preload("res://scripts/city/interaction_targets.gd").add_benches(self)
	for id in ["home_sofa","home_desk"]:
		var seat: Node3D=home.seat_node(id)
		targets[id]={"kind":"bench","position":seat.get_node("ExitAnchor").global_position,"radius":1.65,"node":seat,"label":"坐下来，听听溪水"}
func spawn_npcs() -> void:
	var rng:=RandomNumberGenerator.new();rng.randomize()
	var panda:=spawn_npc("Panda","潘达",Vector3(12,4.2,-29.5),random_clothes(rng),"panda")
	var driver:=preload("res://scripts/valley/panda_routine.gd").new();driver.name="PandaRoutine";driver.bunny=panda;driver.city=self;panda.add_child(driver)
	targets.Panda={"kind":"npc","position":panda.position,"radius":2.8,"node":panda,"name":"潘达","profile":6}
	for i in range(2):
		var id: String="ValleyVisitor%d"%i
		var point: Vector3=Vector3(-18,.1,20) if i==0 else Vector3(22,2.1,-16)
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

func prepare_scenery() -> void:
	# Each running map owns its daylight uniforms.
	var creek: Node3D=scenery.get_node("Creek")
	var original: ShaderMaterial=creek.get_meta("stream_material")
	stream_material=original.duplicate()
	for node in scenery.find_children("*","GeometryInstance3D",true,false):
		if node is GeometryInstance3D and node.material_override==original: node.material_override=stream_material
	# Trail entrance, bridge and cottage only; moonlight carries the forest.
	for lamp in scenery.get_node("Streetlights").get_children():
		var point:=Vector2(lamp.position.x,lamp.position.z)
		if point not in [Vector2(-10,29),Vector2(8,8),Vector2(18,-28)]:
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
	sun.shadow_opacity=lerpf(.46,.86,ambient_day)
	for entry in lamp_visuals: entry.light.light_energy=1.7*cached_warmth
