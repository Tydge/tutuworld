extends Node
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",label_)
 if not ok:failures.append(label_)
func _ready() -> void:call_deferred("run")
func run() -> void:
 check(OS.has_feature("editor") and not OS.get_cmdline_user_args().has("--test"),"Real editor launch path, without test bypass")
 var deadline:=Time.get_ticks_msec()+35000
 while get_tree().current_scene==null and Time.get_ticks_msec()<deadline:await get_tree().process_frame
 await get_tree().create_timer(1).timeout
 var title:=get_tree().current_scene
 check(is_instance_valid(title) and title.get_node_or_null("CityMap")!=null,"Normal boot reaches title scene")
 if not is_instance_valid(title) or title.get_node_or_null("CityMap")==null:get_tree().quit(1);return
 check(title.get_node("CityMap").get_meta("terrain_material_revision",0)==1,"Downloaded same-build pack does not mask new source materials")
 check(FileAccess.file_exists("user://updates/pending.json") and not FileAccess.file_exists("user://updates/active.json"),"Signed same-build pending pack remains untouched in editor")
 var session=get_node("/root/Session")
 check(session.create_character("建造正常启动验收兔","bunny","bow_rose").ok,"Single-player character starts using isolated local data")
 get_tree().change_scene_to_file("res://scenes/city.tscn")
 await get_tree().process_frame
 deadline=Time.get_ticks_msec()+35000
 while (get_tree().current_scene==null or get_tree().current_scene.name!="IslandCity" or get_tree().current_scene.preparing) and Time.get_ticks_msec()<deadline:await get_tree().process_frame
 var city=get_tree().current_scene
 check(is_instance_valid(city) and city.name=="IslandCity" and city.scenery.get_meta("terrain_material_revision",0)==1,"Normal source boot reaches latest single-player terrain")
 check(city.scenery.get_meta("environment_material_revision",0)==1 and city.scenery.has_node("EastBuildingSite"),"Normal single-player boot loads new environment and eastern site")
 check(city.scenery.get_node("Workshop").door_open,"Normal boot preserves the default open workshop door")
 var event:=InputEventKey.new();event.keycode=KEY_F6;event.physical_keycode=KEY_F6;event.pressed=true;Input.parse_input_event(event)
 await get_tree().process_frame
 event.pressed=false;Input.parse_input_event(event);await get_tree().process_frame
 check(city.build_mode.active,"Real F6 input opens in-game building tools on normal boot")
 check(city.build_mode.place_template(),"Normal single-player edit persists the editable sample room")
 city.build_mode.close_editor()
 check(FileAccess.file_exists("user://island_city_v2.json") and city.session.state().build_layout.elements.size()==16,"Normal local save contains sixteen constructed elements")
 for i in range(4):await get_tree().process_frame
 print("BUILDING_EDITOR_SOURCE_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
 get_tree().quit(0 if failures.is_empty() else 1)
