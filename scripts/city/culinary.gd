extends Node3D
const Food=preload("res://scripts/city/food_visual.gd")
const G=preload("res://scripts/geometry.gd")
var city: Node3D
var meal: Node3D
var kitchen_anchor: Node3D
var steam: MultiMeshInstance3D
var clock:=0.0
func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	kitchen_anchor=city.scenery.get_node_or_null("Kitchen/PotSteam")
	if kitchen_anchor==null:
		set_process(false)
		return
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
	steam.global_position=kitchen_anchor.global_position
func warm_models() -> void:
	# Build meshes and prime every portion behind the existing loading cover.
	# Starting a meal then only instantiates cached resources and toggles nodes.
	for id in Food.IDS:
		var preview:=Food.make(id);preview.name="MealWarmup";add_child(preview)
		preview.global_position=city.camera.global_position-city.camera.global_basis.z*1.7
		for portion in range(4):
			Food.set_portion(preview,portion)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		preview.free()
func serve(item: String,at: Vector3=Vector3.INF) -> void:
	clear_meal()
	meal=Food.make(item)
	if kitchen_anchor==null:set_process(true)
	add_child(meal)
	meal.position=at if at.is_finite() else city.scenery.get_node("DiningTable/MealAnchor").global_position
func clear_meal() -> void:
	if is_instance_valid(meal):
		remove_child(meal)
		meal.queue_free()
	meal=null
	if kitchen_anchor==null:set_process(false)
func _process(delta: float) -> void:
	clock+=delta
	var job: Dictionary=city.session.job()
	if is_instance_valid(meal) and job.get("verb","")=="eat":
		Food.animate(meal,float(job.elapsed),float(job.duration))
		city.bunny.meal_elapsed=float(job.elapsed)
		city.bunny.meal_duration=float(job.duration)
	if steam==null:return
	var cook: Dictionary=job if job.get("verb","")=="craft" and job.get("station","kitchen")=="kitchen" else {}
	if cook.is_empty() and city.session.is_online() and is_instance_valid(city.online_view):
		for row in city.online_view.motion.values():
			var work: Dictionary=row.get("job",{})
			if work.get("verb","")=="craft" and work.get("station","kitchen")=="kitchen":
				cook=work
				break
	if not cook.is_empty():
		var target: Dictionary=city.targets.get(cook.get("target","kitchen"),{})
		steam.global_position=target.effect_anchor.global_position if target.has("effect_anchor") else kitchen_anchor.global_position
	steam.visible=not cook.is_empty() or city.preparing
	if steam.visible:
		for i in range(6):
			var age:=fmod(clock*.45+i*.17,1)
			var p:=Vector3(sin(age*4+i)*.07,age*.7,cos(age*3+i)*.055)
			var size_:=sin(age*PI)*.075
			steam.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size_,size_*.7,size_)),p))
