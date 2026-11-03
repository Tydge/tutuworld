extends RefCounted
const Site=preload("res://scripts/building/site.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
const MAX_ELEMENTS:=256 # compatibility name; only objects consume this budget
const MAX_LIGHTS:=16
const MAX_WALL_EDGES:=2048
const MAX_WALL_RUNS:=256
const MAX_ROOFS:=128
static var grid_cache: Dictionary={}
static var last_validation_usec:=0
const STYLES=preload("res://scripts/building/structure_catalog.gd").STYLES
const Structures=preload("res://scripts/building/structure_catalog.gd")
static func empty() -> Dictionary:return {"schema":3,"next_id":1,"elements":[],"grandfathered":{},"lighting_version":1}
static func fail(message: String) -> Dictionary:return {"ok":false,"message":message}
static func point(value: Variant,grid: bool=true) -> bool:
	if not value is Array or value.size()!=2:return false
	for v in value:
		if not (v is float or v is int) or not is_finite(float(v)):return false
		if grid and absf(v*2.-roundf(v*2.))>.001:return false
	return Site.within(Vector2(value[0],value[1]))
static func rect(row: Dictionary) -> Rect2:
	var a:=Vector2(row.a[0],row.a[1]);var b:=Vector2(row.b[0],row.b[1]);return Rect2(a.min(b),(b-a).abs())
static func find(layout: Dictionary,id: String) -> Dictionary:
	for row in layout.elements:
		if row.id==id:return row
	return {}
static func contains_in_floor(p: Vector2,floors: Array) -> bool:
	for floor_ in floors:
		if rect(floor_).grow(.002).has_point(p):return true
	return false
static func supported(footprint: Rect2,floors: Array) -> bool:
	return Grid.covered(footprint,Grid.index(floors).floors)
static func compiled(layout: Dictionary) -> Dictionary:
	var structures: Array=layout.elements.filter(func(row):return row.type in ["floor","wall"])
	var cache_key:=hash(structures)
	if grid_cache.has(cache_key) and grid_cache[cache_key].source==structures:return grid_cache[cache_key].compiled
	var key:=JSON.stringify(structures).sha256_text()
	var result:=Grid.index(structures);result["signature"]=key;result["wall_buckets"]={}
	for row in structures:
		if row.type!="wall":continue
		var r:=rect(row).grow(.3);var a:=Vector2i(floori(r.position.x/3.),floori(r.position.y/3.));var b:=Vector2i(floori(r.end.x/3.),floori(r.end.y/3.))
		for z in range(a.y,b.y+1):
			for x in range(a.x,b.x+1):
				var bucket:=Vector2i(x,z)
				if not result.wall_buckets.has(bucket):result.wall_buckets[bucket]=[]
				result.wall_buckets[bucket].append(row)
	if grid_cache.size()>=4:grid_cache.erase(grid_cache.keys()[0])
	grid_cache[cache_key]={"source":structures.duplicate(true),"compiled":result};return result
static func usage(layout: Dictionary) -> Dictionary:
	var grid:=compiled(layout);var objects:=0;var lights:=0;var roofs:=0
	for row in layout.elements:
		if row.type=="object":
			objects+=1
			if Catalog.OBJECTS[row.kind].get("light",false):lights+=1
		elif row.type=="roof":roofs+=1
	return {"floor_cells":grid.floors.size(),"floor_area":grid.floors.size()*.25,"wall_edges":grid.walls.size(),"wall_length":grid.walls.size()*.5,"objects":objects,"lights":lights,"roofs":roofs}
static func snap_object(layout: Dictionary,item: Dictionary) -> Dictionary:
	var row:=item.duplicate(true)
	if row.get("type","")!="object" or Catalog.mount(row)!="floor" or Catalog.OBJECTS[row.kind].get("outdoor",false) or Catalog.OBJECTS[row.kind].get("overlay",false):return row
	# Keep the usual half-metre grid in open space. Near a wall, align the body
	# to its face/skirting instead; the resulting precise position is persisted.
	for axis in [0,1]:
		var bounds:=Catalog.wall_footprint(row);var best:=.451;var shift:=0.
		for wall in layout.elements:
			if wall.type!="wall" or absf(float(wall.a[axis])-float(wall.b[axis]))>.001:continue
			var across: int=1-axis;var start:=minf(wall.a[across],wall.b[across]);var end:=maxf(wall.a[across],wall.b[across])
			if minf(bounds.end[across],end)-maxf(bounds.position[across],start)<.05:continue
			var plane_: float=wall.a[axis];var side: float=signf(bounds.get_center()[axis]-plane_)
			if is_zero_approx(side):continue
			var edge: float=bounds.position[axis] if side>0 else bounds.end[axis]
			var delta: float=plane_+side*.20-edge
			if absf(delta)<best:best=absf(delta);shift=delta
		row.position[axis]=snappedf(float(row.position[axis])+shift,.001)
	return row
static func validate(raw: Variant) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if not raw is Dictionary or not (raw.get("schema",1)==1 or raw.get("schema",1)==2 or raw.get("schema",1)==3) or not raw.get("elements",[]) is Array:return fail("建造布局格式不正确。")
	var migrating: bool=raw.get("schema",1)==1
	if migrating:raw=split_legacy(raw)

	var clean:=empty();clean.next_id=maxi(1,int(raw.get("next_id",1)));var ids: Dictionary={};var floors: Array=[];var objects: Array=[];var walls: Array=[];var roofs: Array=[];var holes: Array=[]
	for value in raw.get("elements",[]):
		if not value is Dictionary:return fail("物件记录不完整。")
		var id:=str(value.get("id",""));var type:=str(value.get("type",""))
		if id.is_empty() or id.length()>64 or ids.has(id):return fail("物件编号无效或重复。")
		var row:={"id":id,"type":type,"color":str(value.get("color","eadcc5")),"style":str(value.get("style","original")),"painted":bool(value.get("painted",false))}
		if row.color.length()!=6 or not Color.html_is_valid(row.color) or not row.style in STYLES:return fail("请选择有效的颜色和材质。")
		if type in ["door","window","roof"]:
			var form:=str(value.get("form","classic"))
			if not Structures.FORMS[type].has(form):return fail("请选择已有的门窗或屋顶造型。")
			if form!="classic":row.form=form
		if type=="wall" and value.has("faces"):
			if not value.faces is Dictionary:return fail("墙面装修格式不正确。")
			var faces: Dictionary={}
			for side in ["positive","negative"]:
				if not value.faces.has(side):continue
				var face: Variant=value.faces[side]
				if not face is Dictionary:return fail("墙面装修格式不正确。")
				var tint:=str(face.get("color",row.color));var style:=str(face.get("style",row.style))
				if tint.length()!=6 or not Color.html_is_valid(tint) or not style in STYLES:return fail("请选择有效的墙面颜色和纹理。")
				faces[side]={"color":tint,"style":style,"painted":bool(face.get("painted",true))}
			if faces.size()!=value.faces.size():return fail("未知的墙面方向。")
			if not faces.is_empty():row.faces=faces
		match type:
			"floor","roof","wall":
				if not point(value.get("a")) or not point(value.get("b")):return fail("结构要对齐半米网格，并留在建造园地块内。")
				row.a=value.a.duplicate();row.b=value.b.duplicate()
				var size_: Vector2=rect(row).size
				if type=="wall":
					if minf(size_.x,size_.y)>.001 or maxf(size_.x,size_.y)<.5:return fail("墙壁至少长半米，并沿网格方向建造。")
					walls.append(row)
				elif minf(size_.x,size_.y)<(.5 if type=="floor" else 1.):return fail("地板至少半米，屋顶至少1米。")
				elif type=="floor":floors.append(row)
				else:roofs.append(row)
			"door","window":
				if not (value.get("offset") is float or value.get("offset") is int) or not is_finite(float(value.offset)):return fail("门窗位置无效。")
				row.wall=str(value.get("wall",""));row.offset=float(value.offset)
				if value.has("anchor"):
					if not point(value.anchor,false) or not int(value.get("axis",-1)) in [0,1]:return fail("门窗挂点无效。")
					row.anchor=value.anchor.duplicate();row.axis=int(value.axis);row.reverse=bool(value.get("reverse",false))
				holes.append(row)
			"object":
				if not Catalog.OBJECTS.has(value.get("kind","")) or not point(value.get("position"),false):return fail("请选择有效物件，并放在建造园地块内。")
				var yaw: float=float(value.get("yaw",0))
				if not is_finite(yaw) or absf(yaw/90.-roundf(yaw/90.))>.001:return fail("物件旋转须对齐90度。")
				if value.has("appearance"):
					var appearance:=preload("res://scripts/building/appearance.gd").validate(value.kind,value.appearance)
					if not appearance.ok:return fail(appearance.message)
					if not appearance.appearance.is_empty():row.appearance=appearance.appearance
				row.kind=value.kind;row.position=[float(String.num(float(value.position[0]),3)),float(String.num(float(value.position[1]),3))];row.yaw=fposmod(yaw,360);row.support=str(value.get("support",""));row.support_level=int(value.get("support_level",0));objects.append(row)
			_:return fail("暂不支持这种结构。")
		ids[id]=row;clean.elements.append(row)
	var grid:=compiled(clean)
	if grid.error!="":return fail(grid.error)
	# Older layouts did not count their fireplaces as lights. Preserve those exact
	# existing IDs without allowing newly placed fireplaces to evade the budget.
	var old_fires: Array=raw.get("legacy_fireplaces",[]) if raw.get("legacy_fireplaces",[]) is Array else []
	if int(raw.get("lighting_version",0))==0:
		for row in objects:
			if row.kind=="hearth":old_fires.append(row.id)
	var retained_fires: Array=[]
	for row in objects:
		if row.kind=="hearth" and row.id in old_fires:retained_fires.append(row.id)
	if not retained_fires.is_empty():clean.legacy_fireplaces=retained_fires
	var counts:=usage(clean)
	var light_limit:=MAX_LIGHTS
	if not retained_fires.is_empty():
		var previous_limit:=int(raw.get("legacy_light_limit",counts.lights if int(raw.get("lighting_version",0))==0 else MAX_LIGHTS))
		light_limit=maxi(MAX_LIGHTS,mini(previous_limit,MAX_LIGHTS+retained_fires.size()))
		if mini(light_limit,int(counts.lights))>MAX_LIGHTS:clean.legacy_light_limit=mini(light_limit,int(counts.lights))
	if counts.objects>MAX_ELEMENTS:return fail("家具和摆件最多%d件；地板、墙体另计。"%MAX_ELEMENTS)
	if counts.lights>light_limit:return fail("实际照明灯具最多%d盏。"%MAX_LIGHTS)
	if not grid.has("compressed_wall"):grid["compressed_wall"]=Grid.runs(grid.walls);grid["compressed_floor"]=Grid.rectangles(grid.floors)
	if counts.wall_edges>MAX_WALL_EDGES or grid.compressed_wall.size()>MAX_WALL_RUNS:return fail("墙体超过当前容量，请减少密集或碎片墙段。")
	if counts.roofs>MAX_ROOFS:return fail("屋顶模块超过当前容量。")
	for i in range(roofs.size()):
		for j in range(i):
			if rect(roofs[i]).grow(-.005).intersects(rect(roofs[j]).grow(-.005)):return fail("屋顶不能重叠。")
	for hole in holes:
		var wall: Dictionary=ids.get(hole.wall,{})
		if wall.get("type","")!="wall":return fail("门窗必须安装在墙上。")
		if not hole.has("anchor"):
			var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var p:=a+(b-a).normalized()*float(hole.offset)
			hole.anchor=[p.x,p.y];hole.axis=0 if is_equal_approx(a.y,b.y) else 1;hole.reverse=wall.a[hole.axis]>wall.b[hole.axis]
		if not opening_supported(hole,grid.walls):return fail("墙段太短，或门窗离断口/墙角太近。")
		for other in holes:
			if other.id==hole.id or not other.has("anchor") or other.axis!=hole.axis:continue
			if absf(hole.anchor[1-hole.axis]-other.anchor[1-hole.axis])>.001:continue
			var width:=2.86 if hole.type=="door" else 2.2;var other_width:=2.86 if other.type=="door" else 2.2
			if absf(hole.anchor[hole.axis]-other.anchor[hole.axis])<(width+other_width)*.5+.15:return fail("门窗之间需要留出墙柱。")
	# Attachment references are structural, so legacy exemptions never permit cycles
	# or missing support. Geometry exemptions are tied to exact, unchanged rows.
	for item in objects:
		var mount:=Catalog.mount(item)
		if mount=="floor":
			if item.support!="":return fail("落地家具不能依附在其他物件上。")
		else:
			var parent: Dictionary=ids.get(item.support,{})
			if parent.is_empty():return fail("台灯和摆件需要放在桌柜表面，吊灯需要天花板。")
			if mount=="ceiling" and parent.type!="roof":return fail("请先盖好屋顶，再安装吊灯。")
			if mount=="surface" and (item.support_level<0 or item.support_level>=Catalog.OBJECTS.get(parent.get("kind",""),{}).get("surface_levels",[0]).size()):return fail("请选择有效的台面或层板。")
			if mount=="surface" and (parent.type!="object" or not Catalog.OBJECTS[parent.kind].has("surface") or Catalog.mount(parent)!="floor"):return fail("这里没有可摆放物品的台面。")
	var issues:=placement_issues(clean,grid)
	var previous: Dictionary=raw.get("grandfathered",{}) if raw.get("grandfathered",{}) is Dictionary else {}
	for key in issues:
		var issue: Dictionary=issues[key]
		if migrating or previous.get(key,"")==issue.signature:clean.grandfathered[key]=issue.signature
		else:return fail(issue.message)
	for roof in roofs:
		if not Grid.covered(rect(roof),grid.floors):return fail("请先在屋顶下铺好地板。")
	if raw.has("recovery_source"):clean.recovery_source=raw.recovery_source.duplicate(true);clean.recovery_message=raw.get("recovery_message","旧布局需要恢复。")
	clean=Grid.compress(clean,grid)
	last_validation_usec=Time.get_ticks_usec()-started
	return {"ok":true,"layout":clean,"message":"已保存建造布局。"}
static func normalize(raw: Variant) -> Dictionary:
	var result:=validate(raw)
	if result.ok:return result.layout
	var recovered:=empty()
	# Preserve unreadable source for recovery rather than silently erasing it on save.
	if raw is Dictionary and not raw.is_empty():recovered["recovery_source"]=raw.duplicate(true);recovered["recovery_message"]=result.message
	return recovered
static func add(layout: Dictionary,row: Dictionary) -> Dictionary:
	var next: Dictionary=layout.duplicate(true);var copy:=row.duplicate(true);copy.id="build_%d"%next.next_id;next.next_id+=1;next.elements.append(copy);return next
static func remove(layout: Dictionary,id: String) -> Dictionary:
	var next:=layout.duplicate(true);var removed: Dictionary={id:true}
	for row in next.elements:
		if row.get("wall","")==id or row.get("support","")==id:removed[row.id]=true
	next.elements=next.elements.filter(func(row):return not removed.has(row.id));return next

static func base_height(layout: Dictionary,item: Dictionary) -> float:
	if Catalog.mount(item)=="ceiling":return 4.4-float(Catalog.OBJECTS[item.kind].height)
	if Catalog.mount(item)=="surface":
		var parent:=find(layout,str(item.get("support","")))
		if not parent.is_empty():return surface_height(parent,int(item.get("support_level",0)))
	return 0.
static func surface_height(parent: Dictionary,level: int=0) -> float:
	var definition: Dictionary=Catalog.OBJECTS[parent.kind]
	var levels: Array=definition.get("surface_levels",[definition.get("surface_height",0)])
	return float(levels[clampi(level,0,levels.size()-1)])
static func attach_at(layout: Dictionary,item: Dictionary,p: Vector2,support_id: String="",level: int=0) -> Dictionary:
	var row:=item.duplicate(true);row.position=[p.x,p.y];row.support="";row.support_level=0
	var mount:=Catalog.mount(row)
	for parent in layout.elements:
		if support_id!="" and parent.id!=support_id:continue
		if mount=="ceiling" and parent.type=="roof" and rect(parent).has_point(p):row.support=parent.id;break
		if mount=="surface" and parent.type=="object" and Catalog.OBJECTS[parent.kind].has("surface"):
			var definition: Dictionary=Catalog.OBJECTS[parent.kind]
			var local:=Catalog.rotate_xz(p-Vector2(parent.position[0],parent.position[1]),-float(parent.yaw))
			var surface:=Rect2(definition.get("surface_offset",Vector2.ZERO)-definition.surface*.5,definition.surface)
			if surface.has_point(local):
				var shape:=Catalog.bounds({"position":[0,0],"yaw":float(row.get("yaw",0))-float(parent.yaw)},Catalog.OBJECTS[row.kind].size,Catalog.OBJECTS[row.kind].get("offset",Vector2.ZERO))
				if shape.size.x<=surface.size.x+.002 and shape.size.y<=surface.size.y+.002:
					local=local.clamp(surface.position-shape.position,surface.end-shape.end)
					var placed:=Vector2(parent.position[0],parent.position[1])+Catalog.rotate_xz(local,float(parent.yaw));row.position=[float(String.num(placed.x,3)),float(String.num(placed.y,3))]
				row.support=parent.id;row.support_level=level;break
	return row
static func replace(layout: Dictionary,row: Dictionary) -> Dictionary:
	var next:=layout.duplicate(true);var old:=find(next,row.id).duplicate(true)
	if old.is_empty():return next
	var origin:=Vector2.ZERO;var target:=Vector2.ZERO;var turn:=0.
	if old.type=="object":
		origin=Vector2(old.position[0],old.position[1]);target=Vector2(row.position[0],row.position[1]);turn=float(row.yaw)-float(old.yaw)
	elif old.type in ["floor","wall","roof"]:origin=rect(old).get_center();target=rect(row).get_center()
	for i in range(next.elements.size()):
		var child: Dictionary=next.elements[i]
		if child.id==row.id:next.elements[i]=row.duplicate(true)
		elif child.get("support","")==row.id:
			var p:=target+Catalog.rotate_xz(Vector2(child.position[0],child.position[1])-origin,turn)
			child.position=[snappedf(p.x,.001),snappedf(p.y,.001)];child.yaw=fposmod(float(child.yaw)+turn,360.)
	return next
static func placement_issues(layout: Dictionary,grid: Dictionary={}) -> Dictionary:
	if grid.is_empty():grid=compiled(layout)
	var issues: Dictionary={};var floors: Array=[];var walls: Array=[];var objects: Array=[]
	for row in layout.elements:
		if row.type=="floor":floors.append(row)
		elif row.type=="wall":walls.append(row)
		elif row.type=="object":objects.append(row)
	var buckets: Dictionary={}
	for i in range(objects.size()):
		var item: Dictionary=objects[i];var footprint:=Catalog.footprint(item);var mount:=Catalog.mount(item)
		if not Site.within(footprint.position) or not Site.within(footprint.end):add_issue(issues,"plot",[item],"物件边缘超出了建造地块。")
		if mount=="floor":
			if not Catalog.OBJECTS[item.kind].get("outdoor",false) and not Grid.covered(footprint,grid.floors):add_issue(issues,"floor",[item]+floors.filter(func(floor_):return rect(floor_).grow(.001).intersects(footprint)),"请先铺好能容纳这件家具的地板。")
		else:
			var parent:=find(layout,str(item.get("support","")))
			if parent.is_empty():continue
			var inside:=true
			if mount=="ceiling":inside=rect(parent).grow(.002).encloses(footprint)
			else:
				var definition: Dictionary=Catalog.OBJECTS[parent.kind];var surface:=Rect2(definition.get("surface_offset",Vector2.ZERO)-definition.surface*.5,definition.surface).grow(.002)
				for x in [-.5,.5]:
					for z in [-.5,.5]:
						var p:=Vector2(item.position[0],item.position[1])+Catalog.rotate_xz(Catalog.OBJECTS[item.kind].get("offset",Vector2.ZERO)+Catalog.OBJECTS[item.kind].size*Vector2(x,z),float(item.yaw))
						var local:=Catalog.rotate_xz(p-Vector2(parent.position[0],parent.position[1]),-float(parent.yaw))
						if not surface.has_point(local):inside=false
			if not inside:add_issue(issues,"surface",[item,parent],"物品超出台面或天花板边缘，请往里移动。")
		if mount!="ceiling" and not Catalog.OBJECTS[item.kind].get("overlay",false):
			var candidates: Dictionary={};var a:=Vector2i(floori(footprint.position.x/3.),floori(footprint.position.y/3.));var b:=Vector2i(floori(footprint.end.x/3.),floori(footprint.end.y/3.))
			for z in range(a.y,b.y+1):
				for x in range(a.x,b.x+1):
					for wall in grid.wall_buckets.get(Vector2i(x,z),[]):candidates[wall.id]=wall
			for wall in candidates.values():
				if Catalog.wall_footprint(item).grow(-.02).intersects(rect(wall).grow(.13)):add_issue(issues,"wall",[item,wall],"物件与墙壁相交，请留出空间。")
		if Catalog.OBJECTS[item.kind].get("overlay",false):continue
		var near: Dictionary={};var first:=Vector2i(floori(footprint.position.x/3.),floori(footprint.position.y/3.));var last:=Vector2i(floori(footprint.end.x/3.),floori(footprint.end.y/3.))
		for z in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key:=Vector2i(x,z)
				for j in buckets.get(key,[]):near[j]=true
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(i)
		for j in near:
			var other: Dictionary=objects[j]
			if Catalog.OBJECTS[other.kind].get("overlay",false):continue
			if item.get("support","")==other.id or other.get("support","")==item.id:continue
			var h1:=base_height(layout,item);var h2:=base_height(layout,other)
			if minf(h1+float(Catalog.OBJECTS[item.kind].height),h2+float(Catalog.OBJECTS[other.kind].height))-maxf(h1,h2)<.025:continue
			if footprint.grow(-.02).intersects(Catalog.footprint(other).grow(-.02)):add_issue(issues,"overlap",[item,other],"物件重叠了，请移动到空位。")
	return issues
static func add_issue(issues: Dictionary,type: String,rows: Array,message: String) -> void:
	var ids: Array=[];var geometry: Array=[]
	for row in rows:
		ids.append(row.id)
		var data:={}
		for key in ["id","type","kind","position","yaw","support","support_level","a","b"]:
			if row.has(key):data[key]=row[key]
		geometry.append(data)
	issues[type+":"+":".join(ids)]={"signature":JSON.stringify(geometry).sha256_text(),"message":message}
static func split_legacy(raw: Dictionary) -> Dictionary:
	var next:=raw.duplicate(true);next.schema=2;next.elements=next.get("elements",[]);var additions: Array=[]
	var serial:=maxi(1,int(next.get("next_id",1)));var ids: Dictionary={}
	for row in next.elements:
		if row is Dictionary:ids[str(row.get("id",""))]=true
	for row in next.elements:
		if not row is Dictionary or row.get("type","")!="object" or not point(row.get("position"),false):continue
		row.support="";var parts: Array=[]
		match row.get("kind",""):
			"bed":parts=[["bedside",Vector2(-1.9,-.9),""],["table_lamp",Vector2(-1.9,-.9),"bedside"]]
			"desk":parts=[["chair",Vector2(0,-1.1),""],["letter",Vector2(.1,-.06),"self"],["small_plant",Vector2(.86,.16),"self"]]
			"tea_table":parts=[["cup",Vector2(.48,0),"self"],["book",Vector2(-.5,.08),"self"]]
			"forest_cabinet":parts=[["small_plant",Vector2(.4,0),"self"]]
			"bookshelf":
				for shelf in range(3):
					for i in range(6):parts.append(["standing_book",Vector2(-.52+i*.20,.02),"self",3-shelf])
			"hearth":parts=[["small_plant",Vector2(-.91,0),"self"],["clock",Vector2(.55,0),"self"]]
		var local_ids: Dictionary={"self":row.id}
		for part in parts:
			while ids.has("build_%d"%serial):serial+=1
			var id:="build_%d"%serial;serial+=1;ids[id]=true;local_ids[part[0]]=id
			var p:=Vector2(row.position[0],row.position[1])+Catalog.rotate_xz(part[1],float(row.get("yaw",0)))
			additions.append({"id":id,"type":"object","kind":part[0],"position":[snappedf(p.x,.001),snappedf(p.y,.001)],"yaw":row.get("yaw",0),"support":local_ids.get(part[2],""),"support_level":part[3] if part.size()>3 else 0,"color":row.get("color","eadcc5"),"style":row.get("style","original"),"painted":row.get("painted",false)})
	next.elements.append_array(additions);next.next_id=serial;return next
static func merge_template(layout: Dictionary,source: Dictionary,p: Vector2) -> Dictionary:
	var next:=layout.duplicate(true);var ids: Dictionary={}
	for row in source.elements:
		ids[row.id]="build_%d"%next.next_id;next.next_id+=1
	var first_floor: Dictionary=source.elements.filter(func(row):return row.type=="floor")[0]
	var shift:=p-rect(first_floor).get_center()
	for row in source.elements:
		var item: Dictionary=row.duplicate(true);item.id=ids[row.id]
		if item.type in ["floor","roof","wall"]:
			item.a=[float(item.a[0])+shift.x,float(item.a[1])+shift.y];item.b=[float(item.b[0])+shift.x,float(item.b[1])+shift.y]
		elif item.type=="object":item.position=[float(String.num(float(item.position[0])+shift.x,3)),float(String.num(float(item.position[1])+shift.y,3))]
		if item.has("anchor"):item.anchor=[float(item.anchor[0])+shift.x,float(item.anchor[1])+shift.y]
		if item.get("wall","")!="":item.wall=ids[item.wall]
		if item.get("support","")!="":item.support=ids[item.support]
		next.elements.append(item)
	return next

static func cleanup_dependents(layout: Dictionary) -> Dictionary:
	var next:=layout.duplicate(true);var floors: Dictionary=compiled(next).floors;var removed: Dictionary={};var ids: Dictionary={}
	for row in next.elements:ids[row.id]=row
	for row in next.elements:
		if row.type=="roof" and not Grid.covered(rect(row),floors):removed[row.id]=true
		elif row.type in ["door","window"]:
			if not opening_supported(row,compiled(next).walls):removed[row.id]=true
		elif row.type=="object" and Catalog.mount(row)=="floor" and not Catalog.OBJECTS[row.kind].get("outdoor",false) and not Grid.covered(Catalog.footprint(row),floors):removed[row.id]=true
	for row in next.elements:
		if row.get("support","")!="" and (not ids.has(row.support) or removed.has(row.support)):removed[row.id]=true
	next.elements=next.elements.filter(func(row):return not removed.has(row.id));return next
static func demolish(layout: Dictionary,bounds: Rect2,filter: String="all",edge: Variant=null) -> Dictionary:
	return cleanup_dependents(Grid.cut(layout,bounds,filter,edge))
static func unit_at(layout: Dictionary,id: String,p: Vector2) -> Dictionary:
	var row:=find(layout,id)
	if row.is_empty():return {}
	if row.type=="floor":
		var c:=Grid.cell(p);var result: Dictionary=compiled(layout).floors.get(c,{})
		if result.is_empty():return {}
		result=result.duplicate(true);result.a=[c.x*.5,c.y*.5];result.b=[c.x*.5+.5,c.y*.5+.5];return result
	if row.type=="wall":
		var axis:=0 if is_equal_approx(row.a[1],row.b[1]) else 1;var start:=Vector2(row.a[0],row.a[1]).min(Vector2(row.b[0],row.b[1]));var finish:=Vector2(row.a[0],row.a[1]).max(Vector2(row.b[0],row.b[1]));var a:=start
		a[axis]=clampf(floorf(p[axis]*2.)*.5,start[axis],finish[axis]-.5);var b:=a;b[axis]+=.5
		var result:=row.duplicate(true);result.a=[a.x,a.y];result.b=[b.x,b.y];return result
	return row
static func replace_unit(layout: Dictionary,old: Dictionary,row: Dictionary) -> Dictionary:
	var grid:=compiled(layout);grid={"floors":grid.floors.duplicate(),"walls":grid.walls.duplicate()}
	var keys: Array=Grid.coordinates(old) if old.type=="floor" else Grid.edges(old)
	var target: Dictionary=grid.floors if old.type=="floor" else grid.walls
	for key in keys:target.erase(key)
	var next:=Grid.compress(layout,grid)
	# Reinsert as a new record; normal validation prevents unsupported moves.
	return add(next,row)

static func opening_supported(row: Dictionary,walls: Dictionary) -> bool:
	if not row.has("anchor"):return false
	var axis: int=row.axis;var half:=1.43 if row.type=="door" else 1.1;var first:=floori((float(row.anchor[axis])-half-.15)/.5);var last:=ceili((float(row.anchor[axis])+half+.15)/.5);var plane_:=roundi(float(row.anchor[1-axis])/.5)
	for i in range(first,last):
		var e:=Vector3i(i,plane_,0) if axis==0 else Vector3i(plane_,i,1)
		if not walls.has(e):return false
	return true
