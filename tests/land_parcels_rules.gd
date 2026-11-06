extends SceneTree
const Land=preload("res://scripts/building/parcels.gd")
const L=preload("res://scripts/building/layout.gd")
const Authority=preload("res://scripts/services/local_authority.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func command(a: RefCounted,id: String,token: String="") -> Dictionary:return a.execute({"verb":"buy_land","parcel_id":id,"id":token,"player_id":a.state.player_id,"protocol":1})
func run() -> void:
	check(Land.IDS.size()==4 and Land.PRICE==100,"Four fixed parcels cost 100 coins each")
	for id in Land.IDS:
		check(Land.bounds(id).size==Vector2(24,20),"Exact 24 by 20 dimensions: "+id)
		for other in Land.IDS:
			if other!=id:check(not Land.bounds(id).intersects(Land.bounds(other)),"Public space separates "+id+" and "+other)
	var a:=Authority.new();var id: String=Land.IDS[0]
	check(not command(a,id).ok and a.state.coins==650,"Remote purchase is rejected without charging")
	a.state.player_position=[89.,.1,-4.]
	check(not command(a,id).ok,"Standing inside an empty parcel away from its board cannot purchase it")
	a.state.player_position=[79.,.1,7.]
	a.state.coins=99;check(not command(a,id).ok and a.state.land_parcels.plots.is_empty(),"Insufficient funds cannot acquire a parcel")
	a.state.coins=650;check(command(a,id,"purchase-one").ok and a.state.coins==550 and Land.owns(a.state,id),"Authority buys nearby land, charges exactly 100 and records owner")
	check(command(a,id,"purchase-one").ok and a.state.coins==550,"Duplicate command token never charges twice")
	check(not command(a,id).ok and a.state.coins==550,"Already-owned parcel cannot be purchased again")
	var data:=L.add(L.empty(),{"type":"floor","a":[78.,-10.],"b":[98.,4.]})
	var valid:=L.validate(data);check(valid.ok,"Northern parcel accepts structures beyond the old area's northern edge")
	check(Land.validate_edit(a.state,id,valid.layout,0).ok,"Owned parcel accepts in-bounds construction")
	check(not Land.validate_edit(a.state,Land.IDS[1],valid.layout,0).ok,"Unowned parcel cannot be edited")
	check(not Land.validate_edit(a.state,id,valid.layout,1).ok,"Stale parcel revision is rejected")
	var beyond:=L.add(L.empty(),{"type":"floor","a":[98.,-10.],"b":[104.,4.]})
	check(not Land.validate_edit(a.state,id,beyond,0).ok,"Building footprints cannot spill into public land")
	a.state.build_layout=valid.layout
	var other:=L.add(a.state.build_layout,{"type":"floor","a":[120.,-10.],"b":[140.,4.]})
	check(not Land.validate_edit(a.state,id,other,0).ok,"Editing one parcel cannot add buildings to a second parcel")
	var original_id: String=a.state.player_id;a.state.player_id="another_player"
	check(not Land.owns(a.state,id) and not Land.validate_edit(a.state,id,valid.layout,0).ok,"Ownership is attached to stable player identity")
	a.state.player_id=original_id;a.state.map_id="valley"
	check(not command(a,Land.IDS[2]).ok,"Land commands are unavailable outside the city")
	var sample:=preload("res://scripts/building/templates.gd").player_sample("two_storey")
	check(sample.elements.size()==98,"Catalog two-storey template contains all 98 records extracted before clearing the real save")
	for turn in [0.,90.,180.,270.]:
		var placed:=L.merge_template(L.empty(),sample,Land.bounds(id).get_center(),turn)
		var result:=L.validate(placed)
		check(result.ok and result.layout.elements.all(func(row):return Land.contains_row(id,row,result.layout)),"Updated two-storey house fits a parcel at rotation "+str(turn))
	var neighborhood:=L.empty()
	for parcel in Land.IDS:neighborhood=L.merge_template(neighborhood,sample,Land.bounds(parcel).get_center())
	check(L.validate(neighborhood).ok,"All four parcels can hold the updated sample simultaneously within current world capacity")
	print("LAND_PARCELS_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
