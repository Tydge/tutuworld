extends Node
var checks:=0
var failures: Array=[]
func _ready() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label_)
 if not ok:failures.append(label_)
func run() -> void:
 var root=get_tree().root
 var args:=OS.get_cmdline_user_args()
 check(ProjectSettings.load_resource_pack(args[args.find("--base")+1],true),"Original exported client resources load in the native executable")
 var envelope=JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--manifest")+1]))
 var trust=load("res://scripts/services/update_trust.gd")
 var payload: Dictionary=trust.verify_envelope(envelope)
 check(not OS.has_feature("editor"),"Real exported native executable")
 check(not payload.is_empty() and payload.build==8 and payload.version=="0.4.1","Native client accepts the signed 0.4.1 manifest")
 if args.has("--patch"):
  var pack: String=args[args.find("--patch")+1]
  check(FileAccess.get_sha256(pack)==str(payload.pack.sha256),"Downloaded content matches the signed SHA256")
  check(ProjectSettings.load_resource_pack(pack,true),"Legacy native launcher mounts the new signed content")
 var release=load("res://scripts/services/release.gd")
 check(release.VERSION=="0.4.1" and release.BUILD==8 and release.LAUNCHER==2 and release.PROTOCOL==4,"Native resources report 0.4.1/build8/launcher2/protocol4")
 var valley=load("res://scripts/valley/valley_layout.gd")
 check(valley.REVISION==2,"Native resources contain the new landscape revision")
 var map=load("res://scenes/valley_map.scn").instantiate();root.add_child(map)
 check(map.get_meta("continuous_heightfield",false) and map.has_node("AncientForest"),"Native package loads the continuous valley and forest")
 check(load("res://scripts/services/game_data.gd").resources("valley").size()==27,"Native package retains 27 stable valley resources")
 check(not ResourceLoader.exists("res://server/world_server.gd") and not ResourceLoader.exists("res://tests/valley_multiplayer_flow.gd"),"Client package excludes authority code and development fixtures")
 map.queue_free();await get_tree().process_frame
 print("NATIVE_RELEASE041_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);finish(args)

func finish(args: PackedStringArray) -> void:
 var file:=FileAccess.open(args[args.find("--result")+1],FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native":not OS.has_feature("editor")}));file.close()
 get_tree().quit(0 if failures.is_empty() else 1)
