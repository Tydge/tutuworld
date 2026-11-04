extends SceneTree
const G=preload("res://scripts/geometry.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
class World extends Node3D:
	var paused:=false
	func can_walk(_p: Vector3) -> bool:return true
	func is_text_entry_active() -> bool:return false
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func walk(actor: CharacterBody3D,angle: float,start_z: float=1.4) -> void:
	var a:=deg_to_rad(angle);actor.position=Vector3(tan(a)*start_z,.04,start_z);actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();await physics_frame
	for i in range(120):actor.simulate_movement(1./60.,Vector3(-sin(a),0,-cos(a)),false,false,true)
func run() -> void:
	var world:=World.new();root.add_child(world);var ground:=G.solid_box(world,Vector3(0,-.5,0),Vector3(40,1,40));ground.collision_layer=8
	var threshold:=G.solid_box(world,Vector3(0,.03,-5),Vector3(20,.30,10));threshold.collision_layer=8
	for species in ["bunny","cat_teacher","panda"]:
		var actor:=Animals.create(species);world.add_child(actor);actor.world=world;actor.set_physics_process(false)
		for angle in [0.,30.,45.,60.,-30.,-45.,-60.]:
			await walk(actor,angle);check(actor.position.z< -1. and absf(actor.position.y-.181)<.02,"Real movement climbs an 18 cm doorway threshold diagonally: %s / %d"%[species,angle])
		# Real 2.86m door opening, with solid jambs on both sides.
		var jambs:=Node3D.new();world.add_child(jambs)
		for side in [-1,1]:preload("res://scripts/city/prop_collisions.gd").box(jambs,"Jamb",Vector3(side*3.715,2,0),Vector3(4.57,4,.24))
		await physics_frame
		for angle in [0.,30.,45.,-30.,-45.]:
			await walk(actor,angle);check(actor.position.z< -.8,"Open doorway keeps valid oblique entries walkable: %s / %d"%[species,angle])
		var closed:=G.solid_box(world,Vector3(0,1.9,0),Vector3(2.72,3.45,.24));closed.collision_layer=4;await physics_frame;await walk(actor,0.);check(actor.position.z>0.,"A closed door still blocks the character: "+species);closed.free();jambs.free()
		threshold.position.y=.28;await physics_frame;await walk(actor,45.);check(actor.position.z>0. and actor.position.y<.05,"A step above 32 cm is not climbed: "+species);threshold.position.y=.03
		var top:=0.
		for child in actor.get_children():
			if not child is CollisionShape3D or child.disabled:continue
			var half: float=child.shape.radius if child.shape is SphereShape3D else (child.shape.height*.5 if child.shape is CylinderShape3D or child.shape is CapsuleShape3D else child.shape.size.y*.5)
			top=maxf(top,child.position.y+half)
		var ceiling:=G.solid_box(world,Vector3(0,top+.10,.4),Vector3(10,.10,2));ceiling.collision_layer=4;await physics_frame;await walk(actor,45.);check(actor.position.z>0.,"A low lintel rejects stepping without head clearance: "+species);ceiling.free();actor.free();await physics_frame
	print("DOORWAY_STEP_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
