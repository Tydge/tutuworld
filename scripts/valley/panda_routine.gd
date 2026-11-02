extends "res://scripts/city/npc_driver.gd"
var started:=false
var returning:=false
func is_night() -> bool:
	var fraction:=fposmod(float(city.session.state().time)/3600.,1.)
	return fraction<.25 or fraction>=20./24.
func bed() -> Node3D: return city.home.get_node("Furnishing/bed")
func sleep_now() -> void:
	bunny.walking=false;bunny.velocity=Vector3.ZERO
	bunny.lie_in_bed(bed());city.home.bed_occupant=bunny
	path.clear();returning=false
	for label in bunny.find_children("*","Label3D",true,false): label.visible=false
	if city.talking_npc==str(bunny.name): city.end_dialogue()
func wake_now() -> void:
	var exit_position: Vector3=bed().get_node("SleepExit").global_position
	if city.has_method("safe_npc_exit"):
		var result: Dictionary=city.safe_npc_exit(bunny,exit_position)
		if result.is_empty():return
		exit_position=result.position
	bunny.stand_up(exit_position)
	city.home.bed_occupant=null
	for label in bunny.find_children("*","Label3D",true,false):
		if label.text=="潘达": label.visible=true
	path.clear();wait=.5
func choose_destination() -> void:
	if is_night():
		var next: PackedVector3Array=city.navigation.path_between(bunny.position,bed().get_node("SleepExit").global_position)
		if next.size()>1: path=next;path_index=0;returning=true;speed=1.6;repath_count+=1
		else: wait=1.0
	else:
		returning=false;super.choose_destination()
func _physics_process(delta: float) -> void:
	if not started:
		started=true
		if is_night(): sleep_now()
	if bunny.sleeping:
		if not is_night(): wake_now()
		else: return
	if is_night():
		if bunny.position.distance_to(bed().get_node("SleepExit").global_position)<1.0: sleep_now();return
		if not returning: path.clear();wait=0
	elif returning: returning=false;path.clear()
	super._physics_process(delta)
