extends RefCounted
## Pairing is derived from placement, never a persisted support/deletion link.
const C=preload("res://scripts/building/catalog.gd")
const S=preload("res://scripts/building/storeys.gd")
static var cache: Dictionary={}
static func position(row: Dictionary) -> Vector2:return Vector2(row.position[0],row.position[1])
static func slots(table: Dictionary) -> Array:
	var out: Array=[]
	for point in [Vector2(-.9,-1.55),Vector2(.9,-1.55),Vector2(-.9,1.55),Vector2(.9,1.55),Vector2(-2.25,0),Vector2(2.25,0)]:
		var direction:=Vector2(0,-signf(point.y)) if point.y!=0 else Vector2(-signf(point.x),0)
		out.append({"position":position(table)+C.rotate_xz(point,float(table.yaw)),"yaw":fposmod(rad_to_deg(atan2(direction.x,direction.y))+float(table.yaw),360.)})
	return out
static func unobstructed(layout: Dictionary,chair: Vector2,table: Dictionary) -> bool:
	for wall in layout.elements:
		if wall.type!="wall" or S.of(wall)!=S.of(table):continue
		if Geometry2D.segment_intersects_segment(chair,position(table),Vector2(wall.a[0],wall.a[1]),Vector2(wall.b[0],wall.b[1]))!=null:return false
	return true
static func links(layout: Dictionary) -> Dictionary:
	var source: Array=layout.elements.filter(func(row):return row.type=="wall" or row.get("kind","") in ["dining_table","dining_chair"])
	var key:=hash(source)
	if cache.has(key) and cache[key].source==source:return cache[key].links
	var tables: Array=[];var chairs: Array=[];var candidates: Array=[]
	for row in layout.elements:
		if row.get("kind","")=="dining_table":tables.append(row)
		elif row.get("kind","")=="dining_chair":chairs.append(row)
	for table in tables:
		var anchors:=slots(table)
		for chair in chairs:
			if S.of(chair)!=S.of(table) or position(chair).distance_squared_to(position(table))>9.:continue
			for i in range(anchors.size()):
				var distance:=position(chair).distance_squared_to(anchors[i].position)
				if distance>.32*.32 or absf(wrapf(float(chair.yaw)-anchors[i].yaw,-180.,180.))>20.:continue
				if unobstructed(layout,position(chair),table):candidates.append({"table":table.id,"chair":chair.id,"slot":i,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance if not is_equal_approx(a.distance,b.distance) else str(a.table)+str(a.chair)<str(b.table)+str(b.chair))
	var out: Dictionary={};var used: Dictionary={}
	for pair in candidates:
		var slot_key: String=pair.table+":"+str(pair.slot)
		if out.has(pair.chair) or used.has(slot_key):continue
		out[pair.chair]=pair.table;used[slot_key]=true
	if cache.size()>=4:cache.erase(cache.keys()[0])
	cache[key]={"source":source.duplicate(true),"links":out}
	return out
static func snap(layout: Dictionary,chair: Dictionary) -> Dictionary:
	if chair.get("kind","")!="dining_chair":return chair
	var best:=.68*.68;var chosen: Dictionary={};var pairs:=links(layout)
	for table in layout.elements:
		if table.get("kind","")!="dining_table" or S.of(table)!=S.of(chair):continue
		for slot in slots(table):
			var distance:=position(chair).distance_squared_to(slot.position)
			if distance>=best or not unobstructed(layout,slot.position,table):continue
			var occupied:=false
			for other in layout.elements:
				if other.id==chair.get("id","") or pairs.get(other.id,"")!=table.id:continue
				if position(other).distance_squared_to(slot.position)<.5*.5:occupied=true;break
			if not occupied:best=distance;chosen=slot
	if chosen.is_empty():return chair
	var out:=chair.duplicate(true);out.position=[snappedf(chosen.position.x,.001),snappedf(chosen.position.y,.001)];out.yaw=chosen.yaw;return out
static func group(layout: Dictionary,id: String) -> Dictionary:
	var out: Dictionary={id:true};var pairs:=links(layout)
	for chair in pairs:
		if pairs[chair]==id:out[chair]=true
	for row in layout.elements:
		if out.has(row.get("support","")):out[row.id]=true
	return out
