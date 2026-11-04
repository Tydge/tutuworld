extends SceneTree
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:
	var path:="res://.qa-artifacts/multistorey-private-source.json"
	if not FileAccess.file_exists(path):print("FAIL Private layout clone is required for this local compatibility check");quit(1);return
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var validated:=L.validate(raw);check(validated.ok,"Current schema3 local layout validates without recovery or erasure")
	if not validated.ok:print(validated.message);quit(1);return
	var old: Dictionary=validated.layout;var next:=preload("res://scripts/building/showcase.gd").ensure(old);check(int(next.get("multistorey_showcase",0))==1,"East sample fits alongside current local buildings and light budget")
	check(L.validate(next).ok,"Merged current save and sample remain valid")
	for row in old.elements:check(L.find(next,row.id)==row,"Retain current local element "+row.id)
	check(L.usage(next).lights<=L.MAX_LIGHTS and L.usage(next).objects<=L.MAX_ELEMENTS,"Migration respects the global light and furniture budgets")
	check(preload("res://scripts/building/showcase.gd").ensure(next)==next,"Reload never duplicates the sample")
	var output:=preload("res://tests/test_support.gd").output_dir().get_base_dir()+"/compatibility.json";FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"old_rows":old.elements.size(),"merged_rows":next.elements.size(),"old_usage":L.usage(old),"merged_usage":L.usage(next),"all_existing_rows_preserved":failures.is_empty(),"live_save_written":false},"  "))
	print("MULTISTOREY_MIGRATION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
