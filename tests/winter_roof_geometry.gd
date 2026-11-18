extends SceneTree
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func front_hit(model: Node3D,origin: Vector3,direction: Vector3,snow_only: bool=false) -> Vector3:
	var nearest:=Vector3.INF;var distance_:=INF
	for part in model.find_children("*","MeshInstance3D",true,false):
		if part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		if snow_only and not (part.material_override is ShaderMaterial and part.material_override.shader==preload("res://assets/shaders/polar_snow.gdshader")):continue
		for surface in range(part.mesh.get_surface_count()):
			var arrays: Array=part.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var count_: int=indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0,count_,3):
				var a: Vector3=part.transform*vertices[indices[i] if not indices.is_empty() else i]
				var b: Vector3=part.transform*vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c: Vector3=part.transform*vertices[indices[i+2] if not indices.is_empty() else i+2]
				if (c-a).cross(b-a).dot(direction)>=-.00001:continue
				var hit: Variant=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
				if hit!=null and origin.distance_to(hit)<distance_:nearest=hit;distance_=origin.distance_to(hit)
	return nearest
func run() -> void:
	for id in ["chalet","chapel"]:
		var model: Node3D=load("res://scenes/winter/"+id+".scn").instantiate();root.add_child(model)
		for side in [-1.,1.]:
			for x in [-4.,-2.,0.,2.,4.]:
				var top: float=5.5+3.1*(1.-absf(x)/5.4)
				var p:=Vector3(x,lerpf(5.5,top,.55),side*12.)
				var hit:=front_hit(model,p,Vector3(0,0,-side))
				check(hit.is_finite() and absf(hit.z-side*4.6)<.3,"Actual outward-facing closed gable "+id+" side="+str(side)+" x="+str(x))
		for x in [-5.,-3.,-1.,1.,3.,5.]:
			var hit:=front_hit(model,Vector3(x,14,4.35),Vector3.DOWN,true)
			var top: float=5.5+3.1*(1.-absf(x)/5.4)
			check(hit.is_finite() and absf(hit.y-top)<.28,"Saved snow roof physically meets the gable without a raised gap "+id+" x="+str(x))
		model.free()
	print("WINTER_ROOF_GEOMETRY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
