extends SceneTree
const Layout = preload("res://scripts/building/layout.gd")
const Plans = preload("res://scripts/building/templates.gd")
const Catalog = preload("res://scripts/building/catalog.gd")
const Land = preload("res://scripts/building/parcels.gd")
const City = preload("res://scripts/jade/layout.gd")
const Edit = preload("res://scripts/building/room_edit.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func can_expand(data: Dictionary) -> bool:
	var tried: Dictionary={}
	for level in preload("res://scripts/building/storeys.gd").levels(data):
		var ctx:=Edit.prepare(data,level)
		for row in data.elements:
			if row.type!="wall" or int(row.get("storey",0))!=level:continue
			var point:=Layout.rect(row).get_center()
			var unit:=Layout.unit_at(data,row.id,point)
			var drag:=Edit.wall_context(ctx,unit,point)
			if drag.is_empty() or not drag.exterior:continue
			var key:=str([level,drag.axis,drag.plane,drag.lo,drag.hi])
			if tried.has(key):continue
			tried[key]=true
			var result:=Edit.resize(drag,drag.outward)
			if result.ok and Layout.validate(Edit.materialize(ctx,result)).ok:return true
	return false

func _initialize() -> void:
	var lot: String = City.LOTS[0]
	var center := Land.bounds(lot).get_center()
	for house in City.HOUSES:
		check(Catalog.is_house_plan("jade_"+house[4]), house[1]+" has an editable house type")
	for kind in Plans.SAMPLE_NAMES:
		if not Catalog.is_house_plan(kind):
			var sample:=Plans.player_sample(kind)
			var placed:=Layout.validate(Layout.merge_template(Layout.empty("jade"),sample,center))
			check(placed.ok and can_expand(placed.get("layout",{})), "A standard sample can expand on a Jade lot: "+kind)
			continue
		var source := Plans.player_sample(kind)
		check(not source.is_empty(), "Valid native sample "+kind)
		if source.is_empty(): continue
		check(source.elements.all(func(part): return part.type != "object"), "Individually constructible parts "+kind)
		for turn in [0.,90.,180.,270.]:
			var result := Layout.validate(Layout.merge_template(Layout.empty("jade"), source, center, turn))
			check(result.ok and Land.outside(result.get("layout",{}),lot).is_empty(), "%s at %d degrees: %s" % [kind,turn,result.message])
		var placed:=Layout.validate(Layout.merge_template(Layout.empty("jade"),source,center))
		if placed.ok:check(can_expand(placed.layout),"Drag an exterior wall of "+kind)
	var old:=Layout.add(Layout.empty("jade"),{"type":"floor","a":[center.x-3.,center.y-2.],"b":[center.x+2.,center.y+3.],"color":"bbd1a6","style":"terrazzo"})
	old=Layout.add(old,{"type":"object","kind":"jade_cottage","position":[center.x,center.y],"yaw":90.})
	old=Layout.add(old,{"type":"object","kind":"jade_moon_chair","position":[center.x,center.y]})
	var converted:=Layout.validate(Plans.convert_shell(old,old.elements[1]))
	check(converted.ok, "Convert a furnished, rotated cottage over a partial custom floor: "+str(converted.get("message","")))
	if converted.ok:
		var cell:=preload("res://scripts/building/grid_layout.gd").cell(center)
		check(Layout.compiled(converted.layout).floors[cell].id==old.elements[0].id and Layout.compiled(converted.layout).floors[cell].color=="bbd1a6", "Existing floor and finish survive conversion")
		check(Layout.find(converted.layout,old.elements[2].id).position==old.elements[2].position,"Furniture retains its original identity and placement")
		check(Layout.normalize(JSON.parse_string(JSON.stringify(converted.layout)))==converted.layout,"Restored save retains all editable parts")
	var palace := Layout.validate(Layout.merge_template(Layout.empty("jade"), Plans.player_sample("jade_palace"), center)).layout as Dictionary
	var context := Edit.prepare(palace, 0)
	var side: Dictionary = palace.elements.filter(func(part): return part.type == "wall" and part.a[0] == part.b[0] and part.a[0] > center.x)[0]
	var unit := Layout.unit_at(palace, side.id, Layout.rect(side).get_center())
	var drag := Edit.wall_context(context, unit, center)
	var resized := Edit.resize(drag, 1)
	check(resized.ok, "Drag palace facade out by one half-metre cell: "+str(resized.get("message","")))
	if resized.ok:
		var result := Layout.validate(Edit.materialize(context,resized))
		check(result.ok and Layout.usage(result.layout).floor_cells > Layout.usage(palace).floor_cells, "Expanded floor, roof and openings validate")
	var created := Edit.create(Edit.prepare(Layout.empty("jade"),0),Rect2(center,Vector2(4,5)),{"style":"jade_frame"})
	check(created.ok and Layout.validate(Edit.materialize(Edit.prepare(Layout.empty("jade"),0),created)).ok, "Draw a new room from scratch on a Jade parcel")
	print("JADE_BUILDING_RULES failures=", failures)
	quit(1 if failures else 0)
