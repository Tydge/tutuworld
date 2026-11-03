extends SceneTree
const S=preload("res://scripts/services/session.gd")
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var folder:=ProjectSettings.globalize_path("res://.qa-artifacts/building-store-"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(folder)
	var s:=S.new();s.name="Session";root.add_child(s);s.create_character("检查点兔","bunny","bow_rose");s.test_mode=false;s.save_path=folder+"/save.json";check(s.save_game(),"Establish a real full-save checkpoint")
	var base:=FileAccess.get_file_as_string(s.save_path);var layout:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[82.,10.]})
	check(s.set_build_layout(layout).ok and FileAccess.file_exists(s.save_path+".building"),"Building edits atomically persist a building-only checkpoint")
	check(FileAccess.get_file_as_string(s.save_path)==base,"A build edit does not rewrite the full character and world save")
	var stable_revision: int=s.authority.revision;var journal_before:=FileAccess.get_file_as_string(s.save_path+".building")
	check(s.set_build_layout(layout).ok and s.authority.revision==stable_revision and FileAccess.get_file_as_string(s.save_path+".building")==journal_before,"An unchanged layout does not advance revision or write another checkpoint")

	var recovered:=S.new();recovered.name="Recovered";root.add_child(recovered);recovered.test_mode=false;recovered.save_path=s.save_path;recovered.load_save()
	check(recovered.state().build_layout==s.state().build_layout,"Restart replays the latest layout before periodic full-save consolidation")
	check(recovered.state().coins==s.state().coins and recovered.state().inventory==s.state().inventory,"Journal recovery preserves character assets")
	var second:=L.add(s.state().build_layout,{"type":"wall","a":[70.,0.],"b":[82.,0.]});check(s.set_build_layout(second).ok,"Second edit atomically replaces the previous layout journal")
	var corrupt:=FileAccess.open(s.save_path+".building",FileAccess.WRITE);corrupt.store_string("{corrupt");corrupt.close()
	recovered.load_save();check(recovered.state().build_layout.elements.size()==1,"Interrupted/corrupt newest journal falls back to its valid backup")
	check(s.save_game() and not FileAccess.file_exists(s.save_path+".building"),"Successful full save consolidates and removes the incremental checkpoint")
	recovered.load_save();check(recovered.state().build_layout==s.state().build_layout,"Consolidated full save restores the complete latest layout")
	var Store=preload("res://scripts/building/layout_store.gd");var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(s.save_path));var saved_layout: Dictionary=disk.world.build_layout.duplicate(true)
	Store.write(s.save_path,"stale-generation",str(disk.world.get("world_id","local")),L.empty());Store.replay(s.save_path,disk,str(disk.building_generation));check(disk.world.build_layout==saved_layout,"A journal from a different full-save generation cannot overwrite the layout")
	Store.write(s.save_path,str(disk.building_generation),"foreign-world",L.empty());Store.replay(s.save_path,disk,str(disk.building_generation));check(disk.world.build_layout==saved_layout,"A foreign world's checkpoint cannot overwrite the player's layout")
	Store.consolidate(s.save_path)

	var previous: Dictionary=s.state().build_layout.duplicate(true);var revision: int=s.authority.revision;s.save_path=folder+"/missing/save.json"
	check(not s.set_build_layout(L.empty()).ok and s.state().build_layout==previous and s.authority.revision==revision,"A journal write failure rolls back layout and revision")
	s.test_mode=true;recovered.test_mode=true
	print("BUILDING_STORE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
