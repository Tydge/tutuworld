extends RefCounted
## Stable parcel IDs and world-space geometry shared by UI and authority.
## Ownership lives in world state; no UI-only grants or mutable global active bounds.
const PRICE:=100
const REACH:=3.5
const SIGN_REACH:=2.6
const SIZE:=Vector2(24,20)
const IDS:=["east_nw","east_ne","east_sw","east_se"]
const ORIGINS:=[Vector2(77,-14),Vector2(119,-14),Vector2(77,14),Vector2(119,14)]
const NAMES:=["海风一号地","花庭二号地","林荫三号地","听潮四号地"]
static func empty() -> Dictionary:return {"version":1,"plots":{}}
static func bounds(id: String) -> Rect2:
	var index:=IDS.find(id)
	return Rect2(ORIGINS[index],SIZE) if index>=0 else Rect2()
static func title(id: String) -> String:
	var index:=IDS.find(id)
	return NAMES[index] if index>=0 else "未知地皮"
static func includes(rect: Rect2,p: Vector2) -> bool:
	return p.x>=rect.position.x-.001 and p.x<=rect.end.x+.001 and p.y>=rect.position.y-.001 and p.y<=rect.end.y+.001
static func distance_to(id: String,p: Vector3) -> float:
	var rect:=bounds(id);var q:=Vector2(p.x,p.z)
	return q.distance_to(q.clamp(rect.position,rect.end)) if rect.size!=Vector2.ZERO else INF
static func sign_position(id: String) -> Vector3:
	var index:=IDS.find(id)
	if index<0:return Vector3(INF,INF,INF)
	var rect:=bounds(id)
	return Vector3(rect.position.x+2.,0,rect.end.y+1.25 if index<2 else rect.position.y-1.25)
static func at_sign(p: Vector3,id: String) -> bool:
	var sign:=sign_position(id)
	return id in IDS and absf(p.y)<1.7 and Vector2(p.x-sign.x,p.z-sign.z).length()<=SIGN_REACH
static func nearest(p: Vector3) -> String:
	var best:=REACH;var result:=""
	for id in IDS:
		var gap:=distance_to(id,p)
		if gap<=best:best=gap;result=id
	return result
static func normalize(raw: Variant) -> Dictionary:
	var result:=empty()
	if not raw is Dictionary or not raw.get("plots",{}) is Dictionary:return result
	for id in IDS:
		var record: Variant=raw.get("plots",{}).get(id,{})
		if record is Dictionary and record.get("owner_id","") is String and not record.get("owner_id","").is_empty():
			result.plots[id]={"owner_id":record.owner_id,"revision":maxi(0,int(record.get("revision",0))),"purchased_at":maxi(0,int(record.get("purchased_at",0)))}
	return result
static func owner(state: Dictionary,id: String) -> String:return str(state.get("land_parcels",{}).get("plots",{}).get(id,{}).get("owner_id",""))
static func owns(state: Dictionary,id: String) -> bool:return id in IDS and owner(state,id)==str(state.get("player_id",""))
static func row_bounds(row: Dictionary,layout: Dictionary) -> Rect2:
	match row.get("type",""):
		"floor","wall","roof","railing":
			var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);return Rect2(a.min(b),(b-a).abs())
		"object":return preload("res://scripts/building/catalog.gd").footprint(row)
		"stairs":return load("res://scripts/building/stairs.gd").bounds(row)
		"door","window":
			if row.has("anchor"):return Rect2(Vector2(row.anchor[0],row.anchor[1]),Vector2.ZERO)
			for wall in layout.elements:
				if wall.id==row.get("wall",""):
					var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);return Rect2(a+(b-a).normalized()*float(row.offset),Vector2.ZERO)
	return Rect2(Vector2(INF,INF),Vector2.ZERO)
static func contains_row(id: String,row: Dictionary,layout: Dictionary) -> bool:
	var rect:=row_bounds(row,layout);var plot:=bounds(id)
	return plot.size!=Vector2.ZERO and includes(plot,rect.position) and includes(plot,rect.end)
static func outside(layout: Dictionary,id: String) -> Array:
	return layout.get("elements",[]).filter(func(row):return not contains_row(id,row,layout))
static func validate_edit(state: Dictionary,id: String,candidate: Dictionary,expected_revision: int=-1) -> Dictionary:
	if id not in IDS or not owns(state,id):return {"ok":false,"message":"只能建造自己已经购买的地皮。"}
	var revision: int=state.land_parcels.plots[id].revision
	if expected_revision>=0 and expected_revision!=revision:return {"ok":false,"message":"这块地皮已有更新，请重新进入建造。"}
	# IDs can change when contiguous floor/wall runs compress. Compare the entire
	# untouched region, not only changed IDs; public land and other parcels stay fixed.
	if outside(state.build_layout,id)!=outside(candidate,id):return {"ok":false,"message":"本次只能修改当前地皮，不能越界建造或修改其他地皮。"}
	return {"ok":true,"revision":revision}
