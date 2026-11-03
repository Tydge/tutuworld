extends SceneTree
const Catalog=preload("res://scripts/appearance/material_catalog.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
const A=preload("res://scripts/building/appearance.gd")
const F=preload("res://scripts/building/module_factory.gd")
const L=preload("res://scripts/building/layout.gd")
const DB=preload("res://scripts/services/game_data.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	check(Catalog.errors().is_empty(),"Material catalog has valid IDs, families, resources and scales: "+str(Catalog.errors()))
	var clothes=preload("res://scripts/appearance/clothing_catalog.gd")
	check(clothes.errors().is_empty(),"Data-defined clothing styles, colors, patterns and starter IDs validate: "+str(clothes.errors()))
	var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/appearance_legacy_clothes.json"))
	for id in legacy:check(DB.item(id)==legacy[id],"Existing clothing configuration is preserved exactly: "+id)
	check(legacy.size()==27,"Compatibility fixture covers all original 27 clothing IDs")
	check(DB.starter_clothes().size()==9 and "vest_stripes_sage" not in DB.starter_clothes(),"New shop garments do not change starter gifts")
	for id in DB.catalog().items:
		var item:=DB.item(id)
		if item.kind!="clothing":continue
		check(item.pattern in Catalog.choices("fabric","clothing") and item.slot in ["head","body","neck"],"Garment references a supported fabric and slot: "+id)
	for kind in preload("res://scripts/building/catalog.gd").OBJECTS:
		for part in A.parts(kind):
			var allowed:=A.allowed(part)
			check(Catalog.data().families.has(part.family) and not allowed.is_empty(),"Every part resolves its material family: "+kind+"/"+part.id)
	check(A.allowed({"family":"wood"})==["original","wood","solid"],"Existing wood material order is unchanged")
	check(A.allowed({"family":"fabric","materials":["original","dots"]})==["original","dots"],"A specific part can restrict the shared choices without code")
	check(A.allowed({"family":"metal","materials":["dots"]}).is_empty(),"A part cannot opt into an incompatible material family")
	for id in ["stripes","dots","daisies"]:
		check(id in A.allowed(A.part("bed","quilt")) and id in Catalog.choices("fabric","clothing"),"New fabric is shared by furniture and clothing: "+id)
		check(not id in A.allowed(A.part("bed","frame")),"New fabric is excluded from the wooden bed frame: "+id)
		var first:=Fabric.material({"pattern":id,"color":"789eaa"});var other:=Fabric.material({"pattern":id,"color":"c8767a"})
		check(first.get_shader_parameter("fabric_mask")!=null and first.get_shader_parameter("fabric_mask")==other.get_shader_parameter("fabric_mask") and first!=other,"Pattern texture is shared while dye instances stay independent: "+id)
		check(first.get_shader_parameter("dye")==Color("789eaa") and other.get_shader_parameter("dye")==Color("c8767a"),"Object colors cannot leak through shared textures: "+id)
		var layout:=preload("res://scripts/building/templates.gd").cottage()
		var row: Dictionary=layout.elements.filter(func(r):return r.get("kind","")=="bed")[0]
		row.appearance={"quilt":{"material":id,"color":"789eaa"}}
		check(L.validate(layout).ok and L.normalize(JSON.parse_string(JSON.stringify(layout)))==L.normalize(layout),"New pattern survives schema3 validation and JSON round-trip: "+id)
	check(Fabric.material({"pattern":"tartan"}).get_shader_parameter("pattern_scale")==12.0 and Fabric.material({"pattern":"sprig"}).get_shader_parameter("pattern_scale")==3.2,"Existing clothing pattern sizes retain their original defaults")
	check(Fabric.material({"pattern":"dots","pattern_scale":7.0}).get_shader_parameter("pattern_scale")==7.0,"An individual garment can override its pattern scale")
	check(not Fabric.material({"pattern":"removed_pattern"}).get_shader_parameter("patterned"),"Unknown rendering-only patterns fall back to solid safely")
	check(not A.validate("bed",{"quilt":{"material":"removed_pattern"}}).ok,"Unknown saved furniture material IDs are rejected explicitly")
	var ai:=Fabric.texture("daisies").get_image()
	check(ai.get_width()==512 and ai.get_height()==512 and ai.has_mipmaps(),"AI fabric imports at 512px with mipmaps instead of loading the full original")
	var minimum:=1.0;var maximum:=0.0;var seam:=0.0
	for y in ai.get_height():seam+=absf(ai.get_pixel(0,y).r-ai.get_pixel(ai.get_width()-1,y).r)
	for x in ai.get_width():seam+=absf(ai.get_pixel(x,0).r-ai.get_pixel(x,ai.get_height()-1).r)
	for row in 4:
		for column in 4:
			var filled:=0.0
			for y in range(row*128,(row+1)*128):
				for x in range(column*128,(column+1)*128):
					if ai.get_pixel(x,y).r>.25:filled+=1.0
			var coverage:=filled/(128*128);minimum=minf(minimum,coverage);maximum=maxf(maximum,coverage)
	check(seam/(ai.get_width()+ai.get_height())<.005,"AI fabric meets at the tile edges without a visible brightness jump")
	check(minimum>.02 and maximum<.5,"All sixteen AI tile regions contain motifs without empty central patches")
	print("AI_FABRIC_METRICS ",JSON.stringify({"width":ai.get_width(),"height":ai.get_height(),"mipmaps":ai.has_mipmaps(),"bytes":ai.get_data_size(),"edge_mae":seam/(ai.get_width()+ai.get_height()),"minimum_region_coverage":minimum,"maximum_region_coverage":maximum}))
	# A new entry not known to any renderer or UI code must still work end-to-end.
	var probe: Dictionary=Catalog.definition("stripes").duplicate(true);probe.name="Data-only probe";probe.order=99;Catalog.data().materials["data_only_probe"]=probe
	check("data_only_probe" in A.allowed(A.part("bed","quilt")),"A data-only registration automatically becomes a furniture choice")
	var n:=Node3D.new();root.add_child(n);F.builder(n).build_item(n,"bed")
	A.apply(n,{"kind":"bed","appearance":{"quilt":{"material":"data_only_probe","color":"789eaa"}}})
	var quilt: MeshInstance3D=n.find_child("Quilt",true,false)
	check(quilt.material_override.get_shader_parameter("fabric_mask")==Fabric.texture("data_only_probe") and quilt.material_override.shader==load("res://assets/shaders/sleep_quilt.gdshader"),"A data-only pattern works on the deformable quilt without a renderer branch")
	n.free();Catalog.data().materials.erase("data_only_probe");Fabric.textures.erase("data_only_probe")
	var tagged:=Node3D.new();root.add_child(tagged)
	var surface:=MeshInstance3D.new();surface.name="UnrelatedName";surface.mesh=BoxMesh.new();surface.material_override=StandardMaterial3D.new();surface.material_override.albedo_color=Color.MAGENTA;surface.set_meta("appearance_part","frame");tagged.add_child(surface)
	A.prepare(tagged,"bed",F.builder(tagged))
	check(tagged.get_meta("appearance_unmatched").is_empty() and tagged.has_node("Part_frame"),"Explicit model part IDs work independently of mesh names and source colors")
	tagged.free()
	check(preload("res://scripts/city/fabric_library.gd").texture("dots")==Fabric.texture("dots"),"Legacy fabric entry delegates to the shared renderer and cache")
	print("MATERIAL_CATALOG_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
