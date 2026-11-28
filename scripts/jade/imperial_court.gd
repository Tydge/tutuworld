extends RefCounted
## The solo world or multiplayer host owns this one physical seat.
const THRONE := "jade:audience:jade_throne_1"
const EMPEROR := "JadeEmperor"
const REQUEST := "早朝到了，劳卿起身，让朕入座。"
const Seats = preload("res://scripts/city/seating.gd")
const Landing = preload("res://scripts/city/local_landing.gd")
var destination := Vector3.INF

static func show_request(city: Node3D, owner: String) -> void:
	var emperor: CharacterBody3D = city.targets[EMPEROR].node
	if owner == str(emperor.get_meta("shown_request","")):return
	emperor.set_meta("shown_request",owner)
	if owner != "" and owner == city.session.active_character_id:
		city.hud.show_dialogue(emperor,"景昭",REQUEST,"E · 起身让座")
	elif city.hud.bubble_target == emperor and city.talking_npc == "":
		city.hud.hide_dialogue()

func update(city: Node3D, morning: bool) -> void:
	var emperor: CharacterBody3D = city.targets[EMPEROR].node
	var throne: Node3D = city.targets[THRONE].node
	var host := city.has_method("online_players")
	var occupant := ""
	if morning:
		if host:
			occupant = str(city.manager.locks.get("jade:"+THRONE,{}).get("owner",""))
		elif city.nap_active and city.get_meta("resting_furniture",null) == throne:
			occupant = city.session.active_character_id
	emperor.set_meta("court_request",occupant)
	if not host:show_request(city,occupant)
	destination = Vector3.INF
	if city.talking_npc == EMPEROR or (host and is_instance_valid(city.chatting_with(EMPEROR))):return
	var home: Vector3 = emperor.get_meta("court_post")
	if not morning:
		if emperor.seated:
			var landing := Landing.find(city,home,emperor)
			if landing.is_empty():return
			emperor.stand_up(landing.position)
			throne.remove_meta("resident_occupant")
		elif emperor.position.distance_to(home) > .25:
			destination = home
		return
	if emperor.seated or occupant != "" or not seat_is_clear(city,throne,emperor):return
	var aisle := throne.to_global(Vector3(2.08,0,1.04))
	if Vector2(emperor.position.x-aisle.x,emperor.position.z-aisle.z).length() > .17:
		destination = aisle
		return
	emperor.sleep_collision_layer = emperor.collision_layer
	emperor.sit_on_surface(Seats.seat(throne))
	emperor.play_action("hold_court",INF)
	throne.set_meta("resident_occupant",EMPEROR)

# A standing player at the normal exit can remain in front of the throne.
# Check the bodies at the seat itself as well as the authoritative seated owner.
func seat_is_clear(city: Node3D, throne: Node3D, emperor: CharacterBody3D) -> bool:
	var point:=Seats.seat(throne).origin
	var players: Array=city.online_players() if city.has_method("online_players") else [city.bunny]
	for other in players+city.npcs:
		if other==emperor or other.collision_layer==0 or absf(other.position.y-point.y)>2.5:continue
		var radius: float=emperor.rig_profile.head_radii.z+other.rig_profile.head_radii.z+.025
		if Vector2(other.position.x-point.x,other.position.z-point.z).length()<radius:return false
	return true

func walk(city: Node3D, delta: float) -> void:
	var emperor: CharacterBody3D = city.targets[EMPEROR].node
	emperor.walking = false
	emperor.velocity.x=0.
	emperor.velocity.z=0.
	if not destination.is_finite() or emperor.seated or city.talking_npc == EMPEROR:return
	var travel := destination-emperor.position
	travel.y = 0
	if travel.length()<.08:return
	if emperor.action!="":emperor.action=""
	var step:=travel.limit_length(1.55*delta)
	emperor.velocity.x=step.x/delta
	emperor.velocity.z=step.z/delta
	emperor.velocity.y=minf(0.,emperor.velocity.y)-18.*delta
	var start := emperor.position
	emperor.move_on_ground(delta)
	emperor.walking = Vector2(emperor.position.x-start.x,emperor.position.z-start.z).length_squared()>.000001
	if emperor.walking:
		emperor.set_visual_heading(lerp_angle(emperor.visual_heading(),atan2(travel.x,travel.z),1.-exp(-delta*9.)))
		emperor.step_phase+=delta*7.
