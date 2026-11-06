extends Node3D
const Food=preload("res://scripts/city/food_visual.gd")
const G=preload("res://scripts/geometry.gd")
var city: Node3D
var meal: Node3D
var steam: MultiMeshInstance3D
var clock:=0.0
func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	var shape:=SphereMesh.new()
	shape.radius=1
	shape.height=2
	shape.radial_segments=8
	shape.rings=4
	mm.mesh=shape
	mm.instance_count=6
	steam=MultiMeshInstance3D.new()
	steam.multimesh=mm
	var material:=G.mat("e8e1cb").duplicate() as StandardMaterial3D
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color("f5e9d3",.22)
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	steam.material_override=material
	steam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(steam)
	steam.position=city.scenery.get_node("Kitchen/PotSteam").global_position
func serve(item: String,at: Vector3=Vector3.INF) -> void:
	clear_meal()
	meal=Food.make(item)
	add_child(meal)
	meal.position=at if at.is_finite() else city.scenery.get_node("DiningTable/MealAnchor").global_position
func clear_meal() -> void:
	if is_instance_valid(meal):
		remove_child(meal)
		meal.queue_free()
	meal=null
func _process(delta: float) -> void:
	clock+=delta
	var job: Dictionary=city.session.job()
	var cooking: bool=job.get("verb","")=="craft" and job.get("station","kitchen")=="kitchen"
	if city.session.is_online():
		var owner: String=city.session.online_locks.get(city.map_id+":kitchen",{}).get("owner","")
		cooking=cooking or owner!=""
		if job.get("verb","")!="eat" and is_instance_valid(city.online_view):
			owner=city.session.online_locks.get(city.map_id+":dining",{}).get("owner","")
			var remote_job: Dictionary=city.online_view.motion.get(owner,{}).get("job",{})
			if remote_job.get("verb","")=="eat":job=remote_job
	if cooking:
		var target: Dictionary=city.targets.get(job.get("target","kitchen"),{})
		if target.has("effect_anchor"):steam.global_position=target.effect_anchor.global_position
		else:steam.global_position=city.scenery.get_node("Kitchen/PotSteam").global_position
	steam.visible=cooking or city.preparing
	if steam.visible:
		for i in range(6):
			var age:=fmod(clock*.45+i*.17,1)
			var p:=Vector3(sin(age*4+i)*.07,age*.7,cos(age*3+i)*.055)
			var size_:=sin(age*PI)*.075
			steam.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size_,size_*.7,size_)),p))
	if is_instance_valid(meal) and job.get("verb","")=="eat":
		var portion:=lerpf(1,.30,float(job.elapsed)/float(job.duration))
		meal.get_node("Food").scale=Vector3(portion,1,portion)
