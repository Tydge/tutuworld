extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const C=preload("res://scripts/building/structure_catalog.gd")
const E=preload("res://scripts/building/surface_edit.gd")
const S=preload("res://scripts/services/session.gd")
class Host extends Node3D:
	var scenery: Node3D
	var camera: Camera3D
	var bunny: CharacterBody3D
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func clean(data: Dictionary) -> Dictionary:
	var result:=L.validate(data);check(result.ok,"Fixture validates: "+str(result.get("message","")));return result.get("layout",L.empty())
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var data:=L.add(L.empty(),{"type":"floor","a":[64.,0.],"b":[88.,12.],"color":"cda56e","style":"wood"})
	for pair in [[[64.,0.],[88.,0.]],[[88.,0.],[88.,12.]],[[88.,12.],[64.,12.]],[[64.,12.],[64.,0.]],[[76.,0.],[76.,12.]]]:data=L.add(data,{"type":"wall","a":pair[0],"b":pair[1]})
	data=clean(data);var grid:=L.compiled(data);var selected:=L.unit_at(data,grid.floors[Vector2i(134,8)].id,Vector2(67.25,4.25))
	var one:=clean(E.paint(data,selected,Color("bd9d94"),"terrazzo",false,0,Vector2(70,6)))
	check(L.compiled(one).floors.values().filter(func(row):return row.style=="terrazzo").size()==1,"Disabling room paint changes exactly one half-metre cell")
	var batch:=clean(E.paint(data,selected,Color("bd9d94"),"terrazzo",true,0,Vector2(70,6)))
	check(L.compiled(batch).floors.values().filter(func(row):return row.style=="terrazzo").size()==576,"Default batch changes every matching cell in this room")
	check(L.compiled(batch).floors[Vector2i(160,8)].style=="wood","The neighboring room keeps its original floor")
	var special:=selected.duplicate(true);special.color="ffffff";var mixed:=clean(L.replace_unit(data,selected,special));var next:=clean(E.paint(mixed,L.unit_at(mixed,L.compiled(mixed).floors[Vector2i(136,8)].id,Vector2(68.25,4.25)),Color("c6b498"),"herringbone",true,0,Vector2(70,6)))
	check(L.compiled(next).floors[Vector2i(134,8)].color=="ffffff","A different existing floor finish stays unchanged by batch paint")
	var wall: Dictionary=grid.walls[Vector3i(134,0,0)];var unit:=L.unit_at(data,wall.id,Vector2(67.25,0));var inside:=clean(E.paint(data,unit,Color("9cab92"),"botanical",true,0,Vector2(70,6)))
	var inside_grid:=L.compiled(inside)
	check(C.surface(inside_grid.walls[Vector3i(134,0,0)],"positive").style=="botanical" and C.surface(inside_grid.walls[Vector3i(134,0,0)],"negative").style=="original","Only the inside of a reversed or forward wall changes")
	check(C.surface(inside_grid.walls[Vector3i(152,8,1)],"negative").style=="botanical" and C.surface(inside_grid.walls[Vector3i(152,8,1)],"positive").style=="original","A shared partition preserves the neighboring room's wall face")
	check(C.surface(inside_grid.walls[Vector3i(160,0,0)],"positive").style=="original","Wall batching does not reach the adjacent room")
	check(L.normalize(JSON.parse_string(JSON.stringify(inside)))==inside,"Two wall finishes survive compact save and reload")
	var roof:=data.duplicate(true);roof=L.add(roof,{"type":"roof","a":[64.,0.],"b":[76.,12.]});var basewall: Dictionary=grid.walls[Vector3i(134,0,0)]
	for type in C.FORMS:
		for form in C.FORMS[type]:
			var candidate:=L.add(data,{"type":type,"form":form,"wall":basewall.id,"offset":6.,"a":[64.,0.],"b":[76.,12.]})
			var valid:=L.validate(candidate);check(valid.ok,"Each structural form validates: "+type+"/"+form)
			if valid.ok:check(L.normalize(JSON.parse_string(JSON.stringify(valid.layout)))==valid.layout,"Form persists: "+type+"/"+form)
	check(not L.validate(L.add(data,{"type":"roof","form":"unknown","a":[64.,0.],"b":[76.,12.]})).ok,"Unknown forms cannot enter the save")
	for kind in ["bed","canopy_bed","cloud_bed"]:
		var s:=S.new();s.test_mode=true;s.create_character("睡眠规则兔","bunny","bow_rose");s.set_build_layout(L.add(data,{"type":"object","kind":kind,"position":[70.,6.],"yaw":90.}))
		var bed: Dictionary=s.state().build_layout.elements.filter(func(row):return row.get("kind","")==kind)[0];var target:="build:"+str(bed.id);var p:=Vector2(70,6)+preload("res://scripts/building/catalog.gd").rotate_xz(Vector2(-2.6,.3),90.)
		s.state().player_position=[p.x,.2,p.y];check(s.dispatch("rest",{"target":target}).ok and s.state().rest_bed==target,"Authoritative sleep accepts the actual rotated built bed: "+kind)
		var restored=s.restore_state(s.snapshot());check(restored.state.rest_bed==target and restored.state.rest_mode=="sleep","Reload preserves sleep on the same built bed: "+kind)
		check(s.dispatch("wake").ok and s.state().rest_bed=="","Wake clears the selected bed: "+kind);s.free()
	var host:=Host.new();root.add_child(host);host.scenery=Node3D.new();host.add_child(host.scenery)
	var twins:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[90.,12.]})
	for x in [75.,83.]:twins=L.add(twins,{"type":"object","kind":"canopy_bed","position":[x,6.],"yaw":0.})
	var room:=preload("res://scripts/building/module_factory.gd").make(L.validate(twins).layout,host);var quilts: Array=[]
	for mesh in room.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial and mesh.material_override.shader==preload("res://assets/shaders/sleep_quilt.gdshader"):quilts.append(mesh)
	check(quilts.size()==2 and quilts[0].material_override!=quilts[1].material_override,"Prototype reuse gives every bed its own animated quilt material")
	quilts[1].material_override.set_shader_parameter("occupancy",.12);quilts[0].material_override.set_shader_parameter("occupancy",.75)
	check(is_equal_approx(float(quilts[1].material_override.get_shader_parameter("occupancy")),.12),"Sleeping in one same-kind bed never raises the other bed's covers")
	host.free()
	print("BUILDING_EXPANSION_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
