extends SceneTree
const S=preload("res://scripts/services/session.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args();var offset:=args.find("--fixture-root")
	if not args.has("--test") or offset<0 or offset+1>=args.size():quit(2);return
	var path:=ProjectSettings.globalize_path(args[offset+1]).simplify_path();var allowed:=ProjectSettings.globalize_path("res://.qa-artifacts").simplify_path()+"/"
	if not path.begins_with(allowed):quit(2);return
	var s:=S.new();s.test_mode=true;s.save_path=path+"/save.json"
	if args.has("--limited-write"):
		var before:=FileAccess.get_file_as_bytes(s.save_path);var backup:=FileAccess.get_file_as_bytes(s.save_path+".bak");var checkpoint:=FileAccess.get_file_as_bytes(s.save_path+".building")
		s.load_save();s.test_mode=false;var saved:=s.save_game();var copied:=preload("res://scripts/services/atomic_file.gd").copy_verified(s.save_path,s.save_path+".bak")
		print("SAVE_FAULT_PROBE ",JSON.stringify({"save_returned":saved,"backup_returned":copied,"primary_preserved":before==FileAccess.get_file_as_bytes(s.save_path),"backup_preserved":backup==FileAccess.get_file_as_bytes(s.save_path+".bak"),"checkpoint_preserved":checkpoint==FileAccess.get_file_as_bytes(s.save_path+".building")}))
	else:
		DirAccess.make_dir_recursive_absolute(path);s.create_character("写入隔离兔","bunny","bow_rose");s.test_mode=false
		var ok:=s.save_game() and s.save_game();ok=ok and s.set_build_layout(preload("res://scripts/building/layout.gd").add(preload("res://scripts/building/layout.gd").empty(),{"type":"floor","a":[70.,0.],"b":[82.,10.]})).ok
		print("SAVE_FAULT_SETUP ",ok)
		s.free();quit(0 if ok else 1);return
	s.test_mode=true;s.free();quit()
