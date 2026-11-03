extends SceneTree
const A=preload("res://scripts/building/appearance.gd")
const C=preload("res://scripts/building/catalog.gd")
const F=preload("res://scripts/building/module_factory.gd")
const L=preload("res://scripts/building/layout.gd")
const View=preload("res://scripts/city/interior_view.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func model(kind: String) -> Node3D:
	var n:=Node3D.new();root.add_child(n);F.builder(n).build_item(n,kind);return n
func mesh(n: Node3D,id: String) -> MeshInstance3D:
	for item in n.find_children("*","MeshInstance3D",true,false):
		if item.get_meta("appearance_part","")==id:return item
	return null
func run() -> void:
	for kind in C.OBJECTS:
		var n:=model(kind);var valid: bool=not A.parts(kind).is_empty() and n.get_meta("appearance_unmatched",[]).is_empty();var ids: Dictionary={}
		for row in A.parts(kind):
			if ids.has(row.id) or mesh(n,row.id)==null:valid=false
			ids[row.id]=true
		check(valid,"Every declared part maps to actual geometry with no unassigned surfaces: "+kind)
		for preset in A.presets():check(A.validate(kind,A.preset(kind,preset)).ok,"Material-family preset validates: "+kind+" / "+preset)
		n.free()
	var bed:=model("bed");var other:=model("bed");var quilt:=mesh(bed,"quilt");var pillow:=mesh(bed,"pillow");var saved_quilt: Material=quilt.material_override;var saved_pillow: Material=pillow.material_override;var untouched: Material=mesh(other,"frame").material_override
	var row:={"type":"object","kind":"bed","painted":false,"color":"b8c4a3","style":"original","appearance":{"frame":{"material":"original","color":"8d638f"}}};F.paint(bed,row)
	check(quilt.material_override==saved_quilt and pillow.material_override==saved_pillow,"Changing the frame preserves bedding materials and patterns")
	check(mesh(bed,"frame").material_override.get_shader_parameter("pattern")==1,"Recoloring a frame retains its wood grain")
	check(mesh(other,"frame").material_override==untouched and untouched.get_shader_parameter("tint")==Color.WHITE,"A material change cannot leak to another object")
	row.appearance={"quilt":{"material":"sprig","color":"829ac1"}};A.restore(bed);F.paint(bed,row)
	check(quilt.material_override.shader==saved_quilt.shader and quilt.material_override.get_shader_parameter("fabric_mask")==A.Fabric.texture("sprig"),"Changing a quilt pattern retains its drape shader and uses the selected mask")
	row.appearance={"quilt":{"material":"solid","color":"829ac1"}};F.paint(bed,row);check(not quilt.material_override.get_shader_parameter("patterned"),"A solid quilt material explicitly disables the pattern")
	row.appearance={"frame":{"material":"original"}};A.restore(bed);F.paint(bed,row);check(mesh(bed,"frame").material_override.get_shader_parameter("tint")==Color.WHITE,"Restoring a part recovers the original material rather than the last tint")
	check(not A.validate("bed",{"missing":{"color":"ffffff"}}).ok,"Unknown material slots are rejected")
	check(not A.validate("bed",{"quilt":{"material":"wood"}}).ok,"A fabric part rejects unrelated structural materials")
	check(not A.validate("bed",{"frame":{"color":"zzzzzz"}}).ok,"Invalid part colors are rejected")
	var data:=preload("res://scripts/building/templates.gd").cottage();var source: Dictionary=data.elements.filter(func(item):return item.get("kind","")=="bed")[0];source.appearance={"frame":{"material":"wood","color":"9a7562"},"quilt":{"material":"sprig","color":"829ac1"}}
	check(L.normalize(JSON.parse_string(JSON.stringify(data)))==L.validate(data).layout,"Part appearance survives compact layout validation and JSON round-trip")
	var legacy:=source.duplicate(true);legacy.erase("appearance");legacy.painted=true;legacy.color="a989bc";check(not L.validate(L.replace(data,legacy)).layout.elements.filter(func(item):return item.get("kind","")=="bed")[0].has("appearance"),"Legacy all-object colors retain their original compatibility representation")
	var studio=preload("res://scripts/building/thumbnail_studio.gd").new();var key: String=studio.variant_key(source);var moved:=source.duplicate(true);moved.id="other";moved.position=[80.,11.];check(studio.variant_key(moved)==key,"Appearance thumbnails reuse a key across object positions and IDs");moved.appearance.frame.color="bc8888";check(studio.variant_key(moved)!=key,"Different part appearances have distinct thumbnail keys");studio.free()
	var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("部位规则兔","bunny","bow_rose")
	check(s.settings.interior_view_mode==2 and not s.settings.interior_view_hint_seen,"First-time preferences default to free occlusion view with an unseen hint")
	s.set_setting("interior_view_mode",1);s.set_setting("interior_view_mode",99);check(s.settings.interior_view_mode==1,"Camera settings accept valid modes and reject invalid modes")
	var wall:=Node3D.new();wall.position=Vector3(0,0,3);root.add_child(wall);wall.set_meta("length",10.)
	var section:={"node":wall,"bounds":AABB(Vector3(-5,0,-.12),Vector3(10,4.6,.24)),"alpha":1.,"target":1.}
	check(View.obstructs(section,Vector3(0,2,8),Vector3.ZERO),"A wall between camera and actor is classified as an entire occluding face")
	wall.position.z=-3;check(not View.obstructs(section,Vector3(0,2,8),Vector3.ZERO),"The rear wall remains visible because it is beyond the actor")
	wall.position=Vector3(8,0,3);check(not View.obstructs(section,Vector3(0,2,8),Vector3.ZERO),"A side wall outside the sightline remains visible")
	wall.position=Vector3(0,0,3);wall.set_meta("view_openings",[{"offset":5.,"bottom":0.,"width":2.86,"height":3.5}]);check(not View.obstructs(section,Vector3(0,2,8),Vector3.ZERO),"An unobstructed doorway is excluded from wall occlusion")
	var faces:=View.wall_faces({Vector3i(1,1,0):{"id":"one","a":[70.,0.],"b":[74.,0.]},Vector3i(2,1,0):{"id":"two","a":[74.,0.],"b":[80.,0.]},Vector3i(3,1,0):{"id":"three","a":[85.,0.],"b":[90.,0.]}})
	check(faces.one==faces.two and faces.one!=faces.three,"Connected differently decorated runs share a wall face; separated houses do not")
	View.fade(section,true,.2);View.fade(section,false,.01);check(section.target==0.,"A short release hold prevents wall visibility flicker")
	View.fade(section,false,.2);check(section.target==1.,"The complete wall restores after the sightline clears and hold expires");wall.free()

	var folder:=ProjectSettings.globalize_path("res://.qa-artifacts/appearance-settings-"+str(Time.get_ticks_usec()));DirAccess.make_dir_recursive_absolute(folder);s.set_build_layout(data);s.settings.interior_view_hint_seen=true;s.save_path=folder+"/save.json";s.test_mode=false;var written: bool=s.save_game();s.test_mode=true
	var recovered=load("res://scripts/services/session.gd").new();recovered.name="AppearanceRecovered";root.add_child(recovered);recovered.save_path=s.save_path;recovered.load_save()
	check(written and recovered.settings.interior_view_mode==1 and recovered.settings.interior_view_hint_seen,"Camera choice and the one-time hint flag survive a real full-save reload")
	check(recovered.state().build_layout==s.state().build_layout and recovered.state().coins==s.state().coins,"Per-part appearances reload through Session without changing character assets")
	bed.free();other.free();print("APPEARANCE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
