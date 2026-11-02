extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void: call_deferred("run")
func files_at(path: String,extensions: Array) -> Array[String]:
	var paths: Array[String]=[]
	var directory:=DirAccess.open(path)
	if directory==null: return paths
	for file in directory.get_files():
		if file.get_extension() in extensions: paths.append(path+"/"+file)
	for folder in directory.get_directories(): paths.append_array(files_at(path+"/"+folder,extensions))
	return paths
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func run() -> void:
	for folder in ["res://scripts","res://tests"]:
		for path in files_at(folder,["gd"]):
			var script: Script=load(path)
			check(script!=null and script.can_instantiate(),"Parse "+path)
	for folder in ["res://scenes","res://config"]:
		for path in files_at(folder,["tscn","scn","tres"]):
			for dependency in ResourceLoader.get_dependencies(path):
				var parts: PackedStringArray=dependency.split("::")
				var target: String=parts[-1]
				check(ResourceLoader.exists(target),path+" dependency "+target)
	for path in ["res://scenes/bunny.tscn","res://scenes/cat_teacher.tscn","res://scenes/panda.tscn","res://scenes/city_map.tscn","res://scenes/valley_map.scn"]:
		check(ResourceLoader.exists(path),"Accepted asset "+path)
	print("PROJECT_INTEGRITY_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
