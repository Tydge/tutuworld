extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var studio:=preload("res://scripts/building/thumbnail_studio.gd").new();root.add_child(studio);studio.request("canopy_bed")
	await process_frame
	check(studio.busy and studio.stage.get_child_count()==1,"A pending render owns a real model before any completed draw")
	var material: WeakRef
	for mesh in studio.stage.get_child(0).find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial and mesh.material_override.shader.resource_path.ends_with("home_surface.gdshader"):material=weakref(mesh.material_override);break
	check(material!=null and material.get_ref()!=null,"The thumbnail has a live generated material")
	var owner: WeakRef=weakref(studio);studio.queue_free();await process_frame;await process_frame
	check(owner.get_ref()==null and material.get_ref()==null,"Removing a map cancels its pending draw and releases generated resources")
	print("THUMBNAIL_LIFECYCLE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
