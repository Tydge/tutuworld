extends SceneTree
const A=preload("res://scripts/building/appearance.gd")
const F=preload("res://scripts/building/module_factory.gd")
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var bed:=Node3D.new();root.add_child(bed);F.builder(bed).build_item(bed,"bed")
	var quilt: MeshInstance3D=bed.find_child("Quilt",true,false)
	var pillow: MeshInstance3D=bed.find_child("Pillow",true,false);var untouched: Material=pillow.material_override
	var original: Material=quilt.material_override
	var row:={"kind":"bed","appearance":{}}
	for id in A.Catalog.choices("fabric"):
		if not A.Catalog.is_pattern(id):continue
		row.appearance={"quilt":{"material":id,"color":"789eaa","accent":"c76c82"}}
		check(A.validate("bed",row.appearance).ok,"Two independent color channels validate for SVG or AI pattern: "+id)
		A.restore(bed);A.apply(bed,row)
		check(quilt.material_override.get_shader_parameter("dye")==Color("789eaa") and quilt.material_override.get_shader_parameter("accent")==Color("c76c82"),"Base and pattern colors reach their separate shader channels: "+id)
		check(quilt.material_override.get_shader_parameter("pattern_strength")==1.,"Explicit pattern colors use the full mask instead of mixing extra base dye into the pattern: "+id)
		check(quilt.material_override.shader==original.shader and pillow.material_override==untouched,"Pattern recoloring preserves quilt deformation and the neighboring part: "+id)
		row.appearance.quilt.accent="78a863";A.restore(bed);A.apply(bed,row)
		check(quilt.material_override.get_shader_parameter("dye")==Color("789eaa") and quilt.material_override.get_shader_parameter("accent")==Color("78a863"),"Changing only the accent retains the base color: "+id)
		var data:=preload("res://scripts/building/templates.gd").cottage();var stored: Dictionary=data.elements.filter(func(r):return r.get("kind","")=="bed")[0];stored.appearance=row.appearance.duplicate(true)
		check(L.normalize(JSON.parse_string(JSON.stringify(data)))==L.validate(data).layout,"Independent pattern colors survive compact layout JSON: "+id)
	A.restore(bed);A.apply(bed,{"kind":"bed","appearance":{"quilt":{"material":"original","accent":"c76c82"}}})
	check(quilt.material_override.get_shader_parameter("dye")==original.get_shader_parameter("dye") and quilt.material_override.get_shader_parameter("accent")==Color("c76c82"),"Original patterned fabric can change the accent while preserving its original base dye")
	check(A.channels(bed,"quilt","original").enabled and not A.channels(bed,"frame","original").enabled,"Original patterned material exposes two channels; plain wood exposes one")
	check(not A.validate("bed",{"quilt":{"material":"dots","accent":"zzzzzz"}}).ok,"Malformed secondary colors are rejected")
	check(not A.validate("bed",{"frame":{"accent":"c76c82"}}).ok,"Non-fabric parts reject unused secondary channels")
	var legacy:=A.validate("bed",{"quilt":{"material":"dots","color":"789eaa"}})
	check(legacy.ok and not legacy.appearance.quilt.has("accent"),"Old one-color saves retain their representation and default accent")
	A.restore(bed);A.apply(bed,{"kind":"bed","appearance":legacy.appearance})
	check(quilt.material_override.get_shader_parameter("accent")==Color("f2e5cf"),"Existing custom fabrics keep the previous cream accent")
	check(is_equal_approx(float(quilt.material_override.get_shader_parameter("pattern_strength")),.78),"Existing single-color fabrics preserve their original pattern contrast")
	var studio=preload("res://scripts/building/thumbnail_studio.gd").new();var other: Dictionary=row.duplicate(true);other.appearance.quilt.accent="123456"
	check(studio.variant_key(row)!=studio.variant_key(other),"Secondary color changes invalidate the real-model thumbnail variant")
	studio.free();bed.free()
	print("PATTERN_COLORS_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
