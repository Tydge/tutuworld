extends RefCounted
const WallMount=preload("res://scripts/building/wall_mount.gd")
const Storeys=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const Site=preload("res://scripts/building/site.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
const MAX_ELEMENTS:=256 # compatibility name; only objects consume this budget
const MAX_LIGHTS:=48
const MAX_WALL_EDGES:=2048
const MAX_WALL_RUNS:=256
const MAX_ROOFS:=128
static var grid_cache: Dictionary={}
static var walk_cache: Dictionary={}
static var last_validation_usec:=0
const STYLES=preload("res://scripts/building/structure_catalog.gd").STYLES
const Structures=preload("res://scripts/building/structure_catalog.gd")
static func empty() -> Dictionary:return {"schema":4,"next_id":1,"elements":[],"grandfathered":{},"lighting_version":1}
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
static func supported(footprint: Rect2,floors: Array) -> bool:
	return Grid.covered(footprint,Grid.index(floors).floors)
static func compiled(layout: Dictionary,level: int=0) -> Dictionary:
	var structures: Array=layout.elements.filter(func(row):return row.type in ["floor","wall"] and Storeys.of(row)==level)
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
	var cells:=0;var edges:=0;var objects:=0;var lights:=0;var roofs:=0
	for level in Storeys.levels(layout):
		var grid:=compiled(layout,level);cells+=grid.floors.size();edges+=grid.walls.size()
	for row in layout.elements:
		if row.type=="object":
			objects+=1
			if Catalog.OBJECTS[row.kind].get("light",false):lights+=1
		elif row.type=="roof":roofs+=1
	return {"floor_cells":cells,"floor_area":cells*.25,"wall_edges":edges,"wall_length":edges*.5,"objects":objects,"lights":lights,"roofs":roofs}
static func snap_object(layout: Dictionary,item: Dictionary,dining_snap: bool=true) -> Dictionary:
	var row:=item.duplicate(true)
	if dining_snap and row.get("kind","")=="dining_chair":
		var aligned:=preload("res://scripts/building/dining.gd").snap(layout,row)
		if aligned.position!=row.position or aligned.yaw!=row.yaw:return aligned
	if row.get("type","")!="object" or Catalog.mount(row)!="floor" or Catalog.OBJECTS[row.kind].get("outdoor",false) or Catalog.OBJECTS[row.kind].get("overlay",false):return row
	# Keep the usual half-metre grid in open space. Near a wall, align the body
	# to its face/skirting instead; the resulting precise position is persisted.
	for axis in [0,1]:
		var bounds:=Catalog.wall_footprint(row);var best:=.451;var shift:=0.
		for wall in layout.elements:
			if wall.type!="wall" or Storeys.of(wall)!=Storeys.of(row) or absf(float(wall.a[axis])-float(wall.b[axis]))>.001:continue
			var across: int=1-axis;var start:=minf(wall.a[across],wall.b[across]);var end:=maxf(wall.a[across],wall.b[across])
			if minf(bounds.end[across],end)-maxf(bounds.position[across],start)<.05:continue
			var plane_: float=wall.a[axis];var side: float=signf(bounds.get_center()[axis]-plane_)
			if is_zero_approx(side):continue
			var edge: float=bounds.position[axis] if side>0 else bounds.end[axis]
			var delta: float=plane_+side*float(Catalog.OBJECTS[row.kind].get("wall_gap",.20))-edge
			if absf(delta)<best:best=absf(delta);shift=delta
		row.position[axis]=snappedf(float(row.position[axis])+shift,.001)
	return row
static func validate(raw: Variant) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if not raw is Dictionary or not (raw.get("schema",1)==1 or raw.get("schema",1)==2 or raw.get("schema",1)==3 or raw.get("schema",1)==4) or not raw.get("elements",[]) is Array:return fail("建造布局格式不正确。")
	var migrating: bool=raw.get("schema",1)==1
	if migrating:raw=split_legacy(raw)

	var clean:=empty();clean.next_id=maxi(1,int(raw.get("next_id",1)));var ids: Dictionary={};var floors: Array=[];var objects: Array=[];var walls: Array=[];var roofs: Array=[];var holes: Array=[]
	for value in raw.get("elements",[]):
		if not value is Dictionary:return fail("物件记录不完整。")
		var id:=str(value.get("id",""));var type:=str(value.get("type",""))
		if id.is_empty() or id.length()>64 or ids.has(id):return fail("物件编号无效或重复。")
		var level: Variant=value.get("storey",0)
		if not (level is int or level is float) or not is_finite(float(level)) or float(level)!=int(level) or int(level)<0 or int(level)>=Storeys.MAX:return fail("目前支持1至4层，请选择有效楼层。")
		var row:={"id":id,"type":type,"color":str(value.get("color","eadcc5")),"style":str(value.get("style","original")),"painted":bool(value.get("painted",false))}
		if int(level)>0:row.storey=int(level)
		if row.color.length()!=6 or not Color.html_is_valid(row.color) or not row.style in STYLES:return fail("请选择有效的颜色和材质。")
		if type in ["door","window","roof"]:
			var form:=str(value.get("form","classic"))
			if not Structures.FORMS[type].has(form):return fail("请选择已有的门窗或屋顶造型。")
			if form!="classic":row.form=form
			if type=="door" and not bool(value.get("default_open",true)):row.default_open=false
			if type=="roof":
				var turn: float=float(value.get("yaw",0))
				if not is_finite(turn) or absf(turn/90.-roundf(turn/90.))>.001:return fail("屋顶旋转须对齐90度。")
				if not is_zero_approx(fposmod(turn,360.)):row.yaw=fposmod(turn,360.)
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
			"floor","roof","wall","railing":
				if not point(value.get("a")) or not point(value.get("b")):return fail("结构要对齐半米网格，并留在建造园地块内。")
				row.a=value.a.duplicate();row.b=value.b.duplicate()
				var size_: Vector2=rect(row).size
				if type in ["wall","railing"]:
					if minf(size_.x,size_.y)>.001 or maxf(size_.x,size_.y)<.5:return fail("墙壁至少长半米，并沿网格方向建造。")
					if type=="wall":walls.append(row)
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
			"stairs":
				if Storeys.of(row)>=Storeys.MAX-1 or not Stairs.FORMS.has(value.get("form","")) or not point(value.get("position")):return fail("楼梯需要有效造型、半米网格，并连接相邻的两层。")
				var turn: float=float(value.get("yaw",0))
				if not is_finite(turn) or absf(turn/90.-roundf(turn/90.))>.001:return fail("楼梯旋转须对齐90度。")
				row.form=value.form;row.position=value.position.duplicate();row.yaw=fposmod(turn,360.)
			"object":
				if not Catalog.OBJECTS.has(value.get("kind","")) or not point(value.get("position"),false):return fail("请选择有效物件，并放在建造园地块内。")
				var yaw: float=float(value.get("yaw",0))
				if not is_finite(yaw) or absf(yaw/90.-roundf(yaw/90.))>.001:return fail("物件旋转须对齐90度。")
				if value.has("appearance"):
					var appearance:=preload("res://scripts/building/appearance.gd").validate(value.kind,value.appearance)
					if not appearance.ok:return fail(appearance.message)
					if not appearance.appearance.is_empty():row.appearance=appearance.appearance
				if Catalog.OBJECTS[value.kind].get("mount","")=="wall":
					var h: Variant=value.get("mount_height",Catalog.OBJECTS[value.kind].mount_height)
					if not (h is float or h is int) or not is_finite(float(h)):return fail("挂墙高度无效。")
					row.mount_height=snappedf(float(h),.001)
				row.kind=value.kind;row.position=[float(String.num(float(value.position[0]),3)),float(String.num(float(value.position[1]),3))];row.yaw=fposmod(yaw,360);row.support=str(value.get("support",""));row.support_level=int(value.get("support_level",0));objects.append(row)
			_:return fail("暂不支持这种结构。")
		ids[id]=row;clean.elements.append(row)
	if clean.elements.filter(func(row):return row.type=="railing").size()>128:return fail("护栏最多128段，请合并相邻护栏。")
	var grid:=compiled(clean)
	var wall_runs:=0
	for story in Storeys.levels(clean):
		var layer:=compiled(clean,story)
		if layer.error!="":return fail(layer.error)
		if not layer.has("compressed_wall"):layer.compressed_wall=Grid.runs(layer.walls);layer.compressed_floor=Grid.rectangles(layer.floors)
		wall_runs+=layer.compressed_wall.size()
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
	if counts.wall_edges>MAX_WALL_EDGES or wall_runs>MAX_WALL_RUNS:return fail("墙体超过当前容量，请减少密集或碎片墙段。")
	if counts.roofs>MAX_ROOFS:return fail("屋顶模块超过当前容量。")
	for i in range(roofs.size()):
		for j in range(i):
			if Storeys.of(roofs[i])==Storeys.of(roofs[j]) and rect(roofs[i]).grow(-.005).intersects(rect(roofs[j]).grow(-.005)):return fail("屋顶不能重叠。")
	for hole in holes:
		var wall: Dictionary=ids.get(hole.wall,{})
		if wall.get("type","")!="wall" or Storeys.of(wall)!=Storeys.of(hole):return fail("门窗必须安装在墙上。")
		if not hole.has("anchor"):
			var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var p:=a+(b-a).normalized()*float(hole.offset)
			hole.anchor=[p.x,p.y];hole.axis=0 if is_equal_approx(a.y,b.y) else 1;hole.reverse=wall.a[hole.axis]>wall.b[hole.axis]
		if not opening_supported(hole,compiled(clean,Storeys.of(hole)).walls):return fail("墙段太短，或门窗离断口/墙角太近。")
		for other in holes:
			if Storeys.of(other)!=Storeys.of(hole) or other.id==hole.id or not other.has("anchor") or other.axis!=hole.axis:continue
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
			if mount=="wall":
				var parent:=WallMount.support(clean,item,compiled(clean,Storeys.of(item)).walls)
				if parent.is_empty():return fail("挂墙物件需要完整墙面，并避开门窗和墙角。")
				item.support=parent.id;continue
			if mount=="ceiling" and ceiling_covered(clean,Catalog.footprint(item),Storeys.of(item)):
				item.support="ceiling:%d"%Storeys.of(item);continue
			var parent: Dictionary=ids.get(item.support,{})
			if parent.is_empty() or Storeys.of(parent)!=Storeys.of(item):return fail("台灯和摆件需要放在桌柜表面，吊灯需要天花板。")
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
		for upper in floors:
			if Storeys.of(upper)==Storeys.of(roof)+1 and rect(roof).grow(-.01).intersects(rect(upper).grow(-.01)):return fail("上层地板与下层旧屋顶相交。完整覆盖会自动换成楼板；局部扩建请先调整旧屋顶。")
		if not Grid.covered(rect(roof),compiled(clean,Storeys.of(roof)).floors):return fail("请先在屋顶下铺好地板。")
	if raw.has("recovery_source"):clean.recovery_source=raw.recovery_source.duplicate(true);clean.recovery_message=raw.get("recovery_message","旧布局需要恢复。")
	var stairs_result:=Stairs.validate(clean)
	if not stairs_result.ok:return stairs_result
	if raw.has("multistorey_showcase"):clean.multistorey_showcase=int(raw.multistorey_showcase)
	for story in Storeys.levels(clean):clean=Grid.compress(clean,compiled(clean,story),story)
	for item in clean.elements:
		if item.type=="object" and Catalog.mount(item)=="wall":item.support=WallMount.support(clean,item,compiled(clean,Storeys.of(item)).walls).id
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
	var next: Dictionary=layout.duplicate(true);var copy:=row.duplicate(true);copy.id="build_%d"%next.next_id;next.next_id+=1;next.elements.append(copy)
	if copy.type=="floor" and Storeys.of(copy)>0:
		# A complete new slab replaces an old lower roof, retaining ceiling fittings.
		var roofs: Array=next.elements.filter(func(item):return item.type=="roof" and Storeys.of(item)==Storeys.of(copy)-1)
		for roof in roofs:
			if Grid.covered(rect(roof),compiled(next,Storeys.of(copy)).floors):next=remove(next,roof.id)
	return next
static func remove(layout: Dictionary,id: String) -> Dictionary:
	var next:=layout.duplicate(true);var removed: Dictionary={id:true}
	for row in next.elements:
		if row.get("wall","")==id or (row.get("support","")==id and not (row.type=="object" and Catalog.mount(row)=="ceiling" and ceiling_covered(next,Catalog.footprint(row),Storeys.of(row),id))):removed[row.id]=true
	next.elements=next.elements.filter(func(row):return not removed.has(row.id))
	next.elements=next.elements.filter(func(row):return row.type!="object" or Catalog.mount(row)!="ceiling" or ceiling_covered(next,Catalog.footprint(row),Storeys.of(row)))
	return next

static func base_height(layout: Dictionary,item: Dictionary) -> float:
	if Catalog.mount(item)=="wall":return Storeys.elevation(item)+WallMount.height(item)
	if Catalog.mount(item)=="ceiling":return Storeys.elevation(item)+4.4-float(Catalog.OBJECTS[item.kind].height)
	if Catalog.mount(item)=="surface":
		var parent:=find(layout,str(item.get("support","")))
		if not parent.is_empty():return Storeys.elevation(item)+surface_height(parent,int(item.get("support_level",0)))
	return Storeys.elevation(item)
static func surface_height(parent: Dictionary,level: int=0) -> float:
	var definition: Dictionary=Catalog.OBJECTS[parent.kind]
	var levels: Array=definition.get("surface_levels",[definition.get("surface_height",0)])
	return float(levels[clampi(level,0,levels.size()-1)])
static func attach_at(layout: Dictionary,item: Dictionary,p: Vector2,support_id: String="",level: int=0) -> Dictionary:
	var row:=item.duplicate(true);row.position=[p.x,p.y];row.support="";row.support_level=0
	var mount:=Catalog.mount(row)
	if mount=="wall":return WallMount.attach(layout,item,p)
	if mount=="ceiling" and ceiling_covered(layout,Catalog.footprint(row),Storeys.of(row)):
		row.support="ceiling:%d"%Storeys.of(row);return row
	for parent in layout.elements:
		if Storeys.of(parent)!=Storeys.of(row):continue
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
static func movement_group(layout: Dictionary,id: String) -> Dictionary:
	return preload("res://scripts/building/dining.gd").group(layout,id)
static func replace(layout: Dictionary,row: Dictionary) -> Dictionary:
	var next:=layout.duplicate(true);var old:=find(next,row.id).duplicate(true)
	if old.is_empty():return next
	var origin:=Vector2.ZERO;var target:=Vector2.ZERO;var turn:=0.
	if old.type in ["object","stairs"]:
		origin=Vector2(old.position[0],old.position[1]);target=Vector2(row.position[0],row.position[1]);turn=float(row.yaw)-float(old.yaw)
	elif old.type in ["floor","wall","roof"]:origin=rect(old).get_center();target=rect(row).get_center()
	var group:=movement_group(layout,row.id)
	for i in range(next.elements.size()):
		var child: Dictionary=next.elements[i]
		if child.id==row.id:next.elements[i]=row.duplicate(true)
		elif group.has(child.id):
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
	var buckets: Dictionary={};var layers: Dictionary={}
	for i in range(objects.size()):
		var item: Dictionary=objects[i];var level:=Storeys.of(item)
		if not layers.has(level):layers[level]=walkable_grid(layout,level)
		grid=layers[level];var footprint:=Catalog.footprint(item);var mount:=Catalog.mount(item)
		if not Site.within(footprint.position) or not Site.within(footprint.end):add_issue(issues,"plot",[item],"物件边缘超出了建造地块。")
		if mount=="floor":
			if (Storeys.of(item)>0 or not Catalog.OBJECTS[item.kind].get("outdoor",false)) and not Grid.covered(footprint,grid.floors):add_issue(issues,"floor",[item]+floors.filter(func(floor_):return rect(floor_).grow(.001).intersects(footprint)),"请先铺好能容纳这件家具的地板。")
		elif mount!="wall":
			var parent:=find(layout,str(item.get("support","")))
			if parent.is_empty() and mount!="ceiling":continue
			var inside:=true
			if mount=="ceiling":inside=ceiling_covered(layout,footprint,Storeys.of(item))
			else:
				var definition: Dictionary=Catalog.OBJECTS[parent.kind];var surface:=Rect2(definition.get("surface_offset",Vector2.ZERO)-definition.surface*.5,definition.surface).grow(.002)
				for x in [-.5,.5]:
					for z in [-.5,.5]:
						var p:=Vector2(item.position[0],item.position[1])+Catalog.rotate_xz(Catalog.OBJECTS[item.kind].get("offset",Vector2.ZERO)+Catalog.OBJECTS[item.kind].size*Vector2(x,z),float(item.yaw))
						var local:=Catalog.rotate_xz(p-Vector2(parent.position[0],parent.position[1]),-float(parent.yaw))
						if not surface.has_point(local):inside=false
			if not inside:add_issue(issues,"surface",[item]+([parent] if not parent.is_empty() else []),"物品超出台面或天花板边缘，请往里移动。")
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
		for key in ["id","type","storey","kind","position","yaw","support","support_level","mount_height","a","b"]:
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
static func merge_template(layout: Dictionary,source: Dictionary,p: Vector2,yaw: float=0.) -> Dictionary:
	var next:=layout.duplicate(true);var ids: Dictionary={}
	for row in source.elements:
		ids[row.id]="build_%d"%next.next_id;next.next_id+=1
	var origin:=template_origin(source)
	for row in source.elements:
		var item: Dictionary=row.duplicate(true);item.id=ids[row.id]
		for field in ["a","b","position","anchor"]:
			if not item.has(field):continue
			var transformed:=p+Catalog.rotate_xz(Vector2(item[field][0],item[field][1])-origin,yaw)
			item[field]=[snappedf(transformed.x,.001),snappedf(transformed.y,.001)]
		if item.type in ["object","stairs","roof"]:
			var turn:=fposmod(float(item.get("yaw",0))+yaw,360.)
			if item.type!="roof" or not is_zero_approx(turn):item.yaw=turn
			else:item.erase("yaw")
		if item.type=="wall" and item.has("faces"):
			# Finishes use world-canonical sides, rather than the wall's drawing order.
			var normal:=Catalog.rotate_xz(Vector2.DOWN if is_equal_approx(row.a[1],row.b[1]) else Vector2.RIGHT,yaw)
			var positive:=Vector2.DOWN if is_equal_approx(item.a[1],item.b[1]) else Vector2.RIGHT
			if normal.dot(positive)<0.:
				var faces: Dictionary={}
				for side in item.faces:faces["negative" if side=="positive" else "positive"]=item.faces[side]
				item.faces=faces
		if item.type in ["door","window"] and item.has("anchor"):
			var tangent:=Catalog.rotate_xz((Vector2.RIGHT if row.axis==0 else Vector2.DOWN)*(-1. if row.get("reverse",false) else 1.),yaw)
			item.axis=0 if absf(tangent.x)>.5 else 1;item.reverse=tangent[item.axis]<0.
		if item.get("wall","")!="":item.wall=ids[item.wall]
		if ids.has(item.get("support","")):item.support=ids[item.support]
		next.elements.append(item)
	return next

static func cleanup_dependents(layout: Dictionary) -> Dictionary:
	var next:=layout.duplicate(true);var floors: Dictionary={};var removed: Dictionary={};var ids: Dictionary={}
	var layers: Dictionary={}
	for level in Storeys.levels(next):layers[level]=compiled(next,level)
	for row in next.elements:ids[row.id]=row
	for row in next.elements:
		floors=layers[Storeys.of(row)].floors
		if row.type=="roof" and not Grid.covered(rect(row),floors):removed[row.id]=true
		elif row.type in ["door","window"]:
			if not opening_supported(row,layers[Storeys.of(row)].walls):removed[row.id]=true
		elif row.type=="object" and Catalog.mount(row)=="floor" and (Storeys.of(row)>0 or not Catalog.OBJECTS[row.kind].get("outdoor",false)) and not Grid.covered(Catalog.footprint(row),floors):removed[row.id]=true
	for row in next.elements:
		if row.type=="object" and Catalog.mount(row)=="wall":
			var parent:=WallMount.support(next,row,layers[Storeys.of(row)].walls)
			if parent.is_empty():removed[row.id]=true
			else:row.support=parent.id
		elif row.type=="object" and Catalog.mount(row)=="ceiling":
			if not ceiling_covered(next,Catalog.footprint(row),Storeys.of(row)):removed[row.id]=true
		elif row.get("support","")!="" and (not ids.has(row.support) or removed.has(row.support)):removed[row.id]=true
	next.elements=next.elements.filter(func(row):return not removed.has(row.id))
	next.elements=next.elements.filter(func(row):return row.type!="object" or Catalog.mount(row)!="ceiling" or ceiling_covered(next,Catalog.footprint(row),Storeys.of(row)))
	return next
static func demolish(layout: Dictionary,bounds: Rect2,filter: String="all",edge: Variant=null,level: int=0) -> Dictionary:
	return cleanup_dependents(Grid.cut(layout,bounds,filter,edge,level))
static func unit_at(layout: Dictionary,id: String,p: Vector2) -> Dictionary:
	var row:=find(layout,id)
	if row.is_empty():return {}
	if row.type=="floor":
		var c:=Grid.cell(p);var result: Dictionary=compiled(layout,Storeys.of(row)).floors.get(c,{})
		if result.is_empty():return {}
		result=result.duplicate(true);result.a=[c.x*.5,c.y*.5];result.b=[c.x*.5+.5,c.y*.5+.5];return result
	if row.type=="wall":
		var axis:=0 if is_equal_approx(row.a[1],row.b[1]) else 1;var start:=Vector2(row.a[0],row.a[1]).min(Vector2(row.b[0],row.b[1]));var finish:=Vector2(row.a[0],row.a[1]).max(Vector2(row.b[0],row.b[1]));var a:=start
		a[axis]=clampf(floorf(p[axis]*2.)*.5,start[axis],finish[axis]-.5);var b:=a;b[axis]+=.5
		var result:=row.duplicate(true);result.a=[a.x,a.y];result.b=[b.x,b.y];return result
	return row
static func replace_unit(layout: Dictionary,old: Dictionary,row: Dictionary) -> Dictionary:
	var grid:=compiled(layout,Storeys.of(old));grid={"floors":grid.floors.duplicate(),"walls":grid.walls.duplicate()}
	var keys: Array=Grid.coordinates(old) if old.type=="floor" else Grid.edges(old)
	var target: Dictionary=grid.floors if old.type=="floor" else grid.walls
	for key in keys:target.erase(key)
	var next:=Grid.compress(layout,grid,Storeys.of(old))
	# Reinsert as a new record; normal validation prevents unsupported moves.
	return add(next,row)

static func opening_supported(row: Dictionary,walls: Dictionary) -> bool:
	if not row.has("anchor"):return false
	var axis: int=row.axis;var half:=1.43 if row.type=="door" else 1.1;var first:=floori((float(row.anchor[axis])-half-.15)/.5);var last:=ceili((float(row.anchor[axis])+half+.15)/.5);var plane_:=roundi(float(row.anchor[1-axis])/.5)
	for i in range(first,last):
		var e:=Vector3i(i,plane_,0) if axis==0 else Vector3i(plane_,i,1)
		if not walls.has(e):return false
	return true

static func ceiling_covered(layout: Dictionary,bounds: Rect2,level: int,ignore: String="") -> bool:
	if level<Storeys.MAX-1 and Grid.covered(bounds,walkable_grid(layout,level+1).floors):return true
	for row in layout.elements:
		if row.type=="roof" and Storeys.of(row)==level and row.id!=ignore and rect(row).grow(.002).encloses(bounds):return true
	return false
static func walkable_grid(layout: Dictionary,level: int) -> Dictionary:
	var source:=compiled(layout,level)
	var stairs: Array=layout.elements.filter(func(row):return row.type=="stairs" and Storeys.of(row)+1==level)
	if stairs.is_empty():return source
	var key: String=source.signature+JSON.stringify(stairs)
	if walk_cache.has(key):return walk_cache[key]
	var result:=source.duplicate();result.floors=source.floors.duplicate();result.erase("compressed_floor");result.erase("compressed_wall")
	for stair in stairs:
		for c in Stairs.hole_cells(stair):result.floors.erase(c)
	result.signature=key.sha256_text()
	if walk_cache.size()>=8:walk_cache.erase(walk_cache.keys()[0])
	walk_cache[key]=result;return result

static func template_origin(source: Dictionary) -> Vector2:
	var floors: Array=source.elements.filter(func(row):return row.type=="floor" and Storeys.of(row)==0)
	if floors.is_empty():floors=source.elements.filter(func(row):return row.type=="floor")
	if floors.is_empty():return Vector2.ZERO
	var area:=rect(floors[0])
	for row in floors:area=area.merge(rect(row))
	var center:=area.get_center()
	return Vector2(snappedf(center.x,.5),snappedf(center.y,.5))

## Preview changes only one opening; committed geometry is already validated.
## Keep the authoritative full validation on placement, not on mouse motion.
static func preview_opening(layout: Dictionary,row: Dictionary,moving_id: String="") -> Dictionary:
	var wall:=find(layout,str(row.get("wall","")))
	if wall.get("type","")!="wall" or Storeys.of(wall)!=Storeys.of(row):return fail("门窗必须安装在墙上。")
	var hole:=row.duplicate(true);var a:=Vector2(wall.a[0],wall.a[1]);var b:=Vector2(wall.b[0],wall.b[1]);var p:=a+(b-a).normalized()*float(hole.offset)
	hole.anchor=[p.x,p.y];hole.axis=0 if is_equal_approx(a.y,b.y) else 1
	if not opening_supported(hole,compiled(layout,Storeys.of(row)).walls):return fail("墙段太短，或门窗离断口/墙角太近。")
	for other in layout.elements:
		if other.type not in ["door","window"] or other.id==moving_id or Storeys.of(other)!=Storeys.of(hole) or not other.has("anchor") or other.axis!=hole.axis:continue
		if absf(hole.anchor[1-hole.axis]-other.anchor[1-hole.axis])>.001:continue
		var width:=2.86 if hole.type=="door" else 2.2;var other_width:=2.86 if other.type=="door" else 2.2
		if absf(hole.anchor[hole.axis]-other.anchor[hole.axis])<(width+other_width)*.5+.15:return fail("门窗之间需要留出墙柱。")
	return {"ok":true}
