extends "res://scripts/city/npc_driver.gd"
# Only valley visitors have this schedule. One shared actor/wardrobe/driver remains in use.
const FADE_SECONDS:=1.0
var presence:=0.0
var parts: Array[GeometryInstance3D]=[]
var labels: Array[Label3D]=[]
var original_layer:=2
func _ready() -> void:
	super._ready()
	original_layer=bunny.collision_layer
	for part in bunny.find_children("*","GeometryInstance3D",true,false):
		if part is Label3D: labels.append(part)
		else: parts.append(part)
	bunny.set_meta("presence",0.0)
	bunny.set_meta("interaction_available",false)
	bunny.collision_layer=0
	bunny.set_physics_process(false)
	apply_presence()
func daytime() -> bool:
	var hour:=fposmod(float(city.session.state().time),3600.)/150.
	return hour>=6 and hour<22
func apply_presence() -> void:
	bunny.set_meta("presence",presence)
	for part in parts: part.transparency=1-presence
	for label in labels: label.visible=presence>=.999
	bunny.visible=presence>0 and bunny.position.distance_to(city.bunny.position)<65
func _physics_process(delta: float) -> void:
	var desired:=1.0 if daytime() else 0.0
	var ready_to_chat:=desired==1 and presence>=.999
	bunny.set_meta("interaction_available",ready_to_chat)
	if not ready_to_chat and city.talking_npc==str(bunny.name): city.end_dialogue()
	if desired==0:
		bunny.walking=false;bunny.velocity=Vector3.ZERO
		bunny.collision_layer=0;bunny.set_physics_process(false)
		path.clear()
	var next:=move_toward(presence,desired,delta/FADE_SECONDS)
	if not is_equal_approx(next,presence): presence=next;apply_presence()
	if presence>=.999 and desired==1:
		bunny.collision_layer=original_layer;bunny.set_physics_process(true)
		bunny.set_meta("interaction_available",true)
		super._physics_process(delta)
	elif city.current_target==str(bunny.name):
		city.current_target="";city.quick_action.clear();city.hud.set_prompt("")
