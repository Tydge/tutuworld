extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const Session=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:
	var output:=preload("res://tests/test_support.gd").output_dir().get_base_dir();var path:=output+"/four-storey-save.json"
	var data:=L.empty()
	for level in range(4):data=L.add(data,{"type":"floor","a":[110.,-6.],"b":[157.,26.],"storey":level,"style":"cottage_tile" if level==3 else "wood","color":"f4e8cf"})
	for level in range(3):data=L.add(data,{"type":"stairs","form":"u","position":[118.+level*13.,9.],"yaw":0.,"storey":level})
	data=L.add(data,{"type":"object","kind":"cloud_bed","position":[152.,18.],"yaw":0.,"storey":3})
	var checked:=L.validate(data);check(checked.ok,"Four-storey persistence fixture validates")
	if not checked.ok:print(checked.message);quit(1);return
	var session:=Session.new();session.test_mode=true;session.save_path=path;session.create_character("四楼存档兔","bunny","bow_rose");session.state().coins=1234;session.authority.add("sea_salt",7);session.state().player_position=[149.5,14.3,18.];session.test_mode=false
	check(session.save_game(),"Create a real isolated base save")
	var result:=session.set_build_layout(data);check(result.ok and FileAccess.file_exists(path+".building"),"Actual building journal writes all storeys")
	var replayed:=Session.new();replayed.save_path=path;replayed.load_save();check(replayed.state().build_layout==result.layout,"Crash-style reload replays the four-storey building journal before consolidation");replayed.free()
	var bed: Dictionary=result.layout.elements.filter(func(row):return row.get("kind","")=="cloud_bed")[0];check(session.dispatch("rest",{"target":"build:"+str(bed.id)}).ok,"4F bed sleep persists through the actual command writer")
	check(session.save_game() and not FileAccess.file_exists(path+".building"),"Full atomic save consolidates four-storey journal")
	var restored:=Session.new();restored.save_path=path;restored.load_save()
	check(restored.state().build_layout==result.layout,"Disk reload retains every floor, stair ID, opening and tile finish")
	check(restored.state().player_position==[149.5,14.3,18.] and restored.state().rest_bed=="build:"+str(bed.id),"Disk reload restores 4F height and sleeping bed")
	check(int(restored.state().coins)==1234 and restored.authority.count("sea_salt")==7,"Building save leaves character assets intact")
	var source:=JSON.stringify(restored.state().build_layout);restored.test_mode=true;restored.set_player_position(Vector3(145,14.3,18));check(JSON.stringify(restored.state().build_layout)==source,"Moving at 4F does not alter saved construction")
	session.free();restored.free();print("MULTISTOREY_PERSISTENCE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
