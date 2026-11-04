extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const T=preload("res://scripts/building/templates.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label_: String) -> void:
	checks+=1;print("PASS " if value else "FAIL ",label_)
	if not value:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var old:=T.cottage();check(not old.elements.is_empty(),"Single-storey template still validates")
	var raw:=T.two_storey();var result:=L.validate(raw);print("TWO_STOREY_VALIDATION ",result.get("message"));check(result.ok,"Furnished two-storey sample validates")
	if result.ok:
		var data: Dictionary=result.layout
		check(is_equal_approx(L.compiled(data,0).floors.size()*.25,240.),"Sample footprint is exactly twice the old 120sqm")
		check(L.compiled(data,1).floors.size()==960,"Upper floor has 240sqm including open balcony and stair opening source")
		check(L.walkable_grid(data,1).floors.size()<960,"Stair owns a derived upper-floor opening")
		check(L.normalize(JSON.parse_string(JSON.stringify(data)))==data,"All levels, fittings, openings and stairs survive JSON round trip")
		var added:=preload("res://scripts/building/showcase.gd").ensure(old)
		check(added!=old and int(added.get("multistorey_showcase",0))==1,"Existing cottage gains a separate east sample additively")
		check(preload("res://scripts/building/showcase.gd").ensure(added)==added,"Sample migration is idempotent")
		for row in old.elements:check(L.find(added,row.id)==row,"Old element preserved: "+row.id)
	for form in Stairs.FORMS:
		for yaw in [0.,90.,180.,270.]:
			var data:=L.empty()
			for level in [0,1]:data=L.add(data,{"type":"floor","a":[110.,-5.],"b":[128.,25.],"storey":level})
			data=L.add(data,{"type":"stairs","position":[119.,10.],"storey":0,"form":form,"yaw":yaw})
			var checked:=L.validate(data);check(Stairs.preview({"elements":data.elements.slice(0,-1)},data.elements[-1]).ok==checked.ok,"Fast stair preview agrees with full validation: "+form+"/"+str(yaw));check(checked.ok,"Stair validates both landings: "+form+"/"+str(yaw))
			if not checked.ok:print(checked.message);continue
			var stair: Dictionary=checked.layout.elements.filter(func(row):return row.type=="stairs")[0]
			var removed:=L.validate(L.remove(checked.layout,stair.id));check(removed.ok and L.walkable_grid(removed.layout,1).floors.size()==L.compiled(removed.layout,1).floors.size(),"Removing stairs restores only their derived opening")
			var path:=Stairs.route(stair);check(path[0].y<.19 and is_equal_approx(path[-1].y,4.88),"Continuous stair route connects actual floor elevations")
	var bad:=L.add(L.empty(),{"type":"floor","a":[110.,0.],"b":[120.,10.],"storey":4});check(not L.validate(bad).ok,"Reject a fifth floor")
	print("MULTISTOREY_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
