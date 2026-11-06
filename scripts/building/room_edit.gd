extends RefCounted
## Grid plans are immutable during a gesture. Only release compresses and saves.
const L=preload("res://scripts/building/layout.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const R=preload("res://scripts/building/room_plan.gd")
const S=preload("res://scripts/building/storeys.gd")
const C=preload("res://scripts/building/catalog.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
const WallMount=preload("res://scripts/building/wall_mount.gd")
const Surface=preload("res://scripts/building/surface_edit.gd")

static func bounds(cells: Dictionary) -> Rect2:
	if cells.is_empty():return Rect2()
	var first: Vector2i=cells.keys()[0];var last:=first+Vector2i.ONE
	for cell in cells:first=first.min(cell);last=last.max(cell+Vector2i.ONE)
	return Rect2(G.point(first),G.point(last-first))
static func edge_between(cell: Vector2i,direction: Vector2i) -> Vector3i:
	return Vector3i(cell.x+(1 if direction==Vector2i.RIGHT else 0),cell.y+(1 if direction==Vector2i.DOWN else 0),1 if direction.x!=0 else 0)
static func adjacent(edge: Vector3i) -> Array:
	var cell:=Vector2i(edge.x,edge.y)
	return [cell,cell-(Vector2i.DOWN if edge.z==0 else Vector2i.RIGHT)]
static func prepare(layout: Dictionary,level: int) -> Dictionary:
	var grid:=L.compiled(layout,level)
	var context:={"source":layout,"level":level,"grid":grid,"plan":R.make(grid),"below":L.walkable_grid(layout,level-1).floors if level>0 else {},"above":L.walkable_grid(layout,level+1).floors,"objects":[],"openings":[],"roofs":[],"stairs":[],"railings":[],"holes":{},"lower_ceiling":[],"lower_roofs":[]}
	for row in layout.elements:
		if level>0 and S.of(row)==level-1:
			if row.type=="object" and C.mount(row)=="ceiling":context.lower_ceiling.append(row)
			elif row.type=="roof":context.lower_roofs.append(row)
		if row.type=="stairs":
			if level in [S.of(row),S.of(row)+1]:context.stairs.append(row)
			if S.of(row)+1==level:
				for cell in Stairs.hole_cells(row):context.holes[cell]=true
		if S.of(row)!=level:continue
		if row.type=="object":context.objects.append({"row":row,"foot":C.footprint(row),"wall_foot":C.wall_footprint(row),"height":L.base_height(layout,row)})
		elif row.type in ["door","window"]:context.openings.append(row)
		elif row.type=="roof":context.roofs.append(row)
		elif row.type=="railing":context.railings.append(row)
	return context
static func support(context: Dictionary,added: Dictionary,removed: Dictionary) -> Dictionary:
	if context.level>0:
		for cell in added:
			if not context.below.has(cell):return L.fail("扩建范围下方没有楼板支撑，请先扩建下一层。")
	for cell in removed:
		if context.above.has(cell):return L.fail("缩建会让上一层楼板失去支撑，请先调整上一层。")
	if not removed.is_empty() and not context.lower_ceiling.is_empty():
		var retained: Dictionary=context.grid.floors.duplicate()
		for cell in removed:retained.erase(cell)
		for lamp in context.lower_ceiling:
			var foot:=C.footprint(lamp);var covered:=G.covered(foot,retained)
			for roof in context.lower_roofs:
				if L.rect(roof).grow(.002).encloses(foot):covered=true;break
			if not covered:return L.fail("缩建会让下一层的吊灯失去天花板支撑，请先调整吊灯。")
	return {"ok":true}
static func wall_hit(foot: Rect2,walls: Dictionary) -> bool:
	var area:=foot.grow(.13);var first:=G.cell(area.position);var last:=G.cell(area.end)
	for z in range(first.y,last.y+2):
		for x in range(first.x,last.x+2):
			for axis in [0,1]:
				var edge:=Vector3i(x,z,axis)
				if not walls.has(edge):continue
				var ends:=G.ends(edge);var a:=G.point(ends[0]);var b:=G.point(ends[1])
				if foot.intersects(Rect2(a,(b-a)).grow(.13)):return true
	return false
static func check_geometry(context: Dictionary,result: Dictionary) -> Dictionary:
	var grid: Dictionary=result.grid;var floor_: Dictionary=grid.floors
	if grid.walls.size()>L.MAX_WALL_EDGES:return L.fail("墙体超过当前容量。")
	var walkable:=floor_.duplicate()
	for cell in context.holes:walkable.erase(cell)
	var effective: Dictionary=context.source.duplicate(false);effective.elements=context.source.elements.map(func(row):return result.openings.get(row.id,row))
	var objects: Array=[]
	for info in context.objects:
		var row: Dictionary=info.row;var moved: bool=result.moves.has(row.id);var shifted: Dictionary=row
		if moved:
			shifted=row.duplicate();var delta: Vector2=result.moves[row.id];shifted.position=[row.position[0]+delta.x,row.position[1]+delta.y]
		var foot: Rect2=C.footprint(shifted) if moved else info.foot
		if not preload("res://scripts/building/site.gd").within(foot.position) or not preload("res://scripts/building/site.gd").within(foot.end):return L.fail("随墙移动的物件超出了建造地块。")
		var touched: bool=moved or result.region.grow(.3).intersects(foot)
		if touched:
			if C.mount(row)=="wall" and WallMount.support(effective,shifted,grid.walls).is_empty():return L.fail("调整会让挂墙物件失去支撑或与门窗冲突。")
			if C.mount(row)=="ceiling":
				var covered:=G.covered(foot,context.above)
				for roof in context.roofs:
					if L.rect(result.roofs.get(roof.id,roof)).grow(.002).encloses(foot):covered=true;break
				if not covered:return L.fail("调整后吊灯或悬挂物会失去天花板支撑，请先移开。")
			if C.mount(row)=="floor" and not C.OBJECTS[row.kind].get("outdoor",false) and not G.covered(foot,walkable):return L.fail("缩建后家具没有足够的地板，请先移开家具。")
			if C.mount(row)!="ceiling" and not C.OBJECTS[row.kind].get("overlay",false) and wall_hit(C.wall_footprint(shifted).grow(-.02),grid.walls):return L.fail("墙壁与物件冲突，请先移动挡住的物件。")
			if result.get("exterior_expansion",false) and not moved and not context.plan.cell_rooms.has(G.cell(Vector2(row.position[0],row.position[1]))) and result.region.grow(-.01).intersects(foot) and not C.OBJECTS[row.kind].get("overlay",false):return L.fail("扩建范围与室外物件冲突，请先移开物件。")
		objects.append({"row":shifted,"foot":foot,"height":info.height,"moved":moved})
	for i in range(objects.size()):
		var a: Dictionary=objects[i]
		if not a.moved or C.OBJECTS[a.row.kind].get("overlay",false):continue
		for j in range(objects.size()):
			var b: Dictionary=objects[j]
			if i==j or (b.moved and j<i):continue
			if C.OBJECTS[b.row.kind].get("overlay",false) or a.row.get("support","")==b.row.id or b.row.get("support","")==a.row.id:continue
			if minf(a.height+C.OBJECTS[a.row.kind].height,b.height+C.OBJECTS[b.row.kind].height)-maxf(a.height,b.height)<.025:continue
			if a.foot.grow(-.02).intersects(b.foot.grow(-.02)):return L.fail("随墙移动的家具与其他物件冲突。")
	var openings: Array=[]
	for row in context.openings:
		var hole: Dictionary=result.openings.get(row.id,row)
		if not L.opening_supported(hole,grid.walls):return L.fail("缩建会挤掉门窗或使门窗靠墙角过近，请先调整门窗。")
		for other in openings:
			if hole.axis!=other.axis or absf(hole.anchor[1-hole.axis]-other.anchor[1-hole.axis])>.001:continue
			if absf(hole.anchor[hole.axis]-other.anchor[hole.axis])<((2.86 if hole.type=="door" else 2.2)+(2.86 if other.type=="door" else 2.2))*.5+.15:return L.fail("移动后门窗距离过近。")
		openings.append(hole)
	for stair in context.stairs:
		var definition:=Stairs.definition(stair.form)
		var end: Rect2=definition.bottom if S.of(stair)==context.level else definition.top
		if not G.covered(Stairs.world_rect(stair,end).grow(-.02),walkable):return L.fail("缩建会破坏楼梯出入口或上层平台。")
		for part in Stairs.parts(stair):
			for object in objects:
				if object.moved and not C.OBJECTS[object.row.kind].get("overlay",false) and part.grow(-.18).intersects(object.foot.grow(-.01)):return L.fail("随墙移动的家具会挡住楼梯或出入口。")
			if wall_hit(part.grow(-.18),grid.walls):return L.fail("墙壁移动后会挡住楼梯或平台。")
	for roof in context.lower_roofs:
		var area:=L.rect(roof);var touches:=false
		for cell in G.coordinates(roof):
			if floor_.has(cell):touches=true;break
		if touches and not G.covered(area,floor_):return L.fail("上层房间与下层屋顶局部相交，请先生成完整上层楼板或调整屋顶。")
	for roof in context.roofs:
		var next: Dictionary=result.roofs.get(roof.id,roof)
		if not G.covered(L.rect(next),floor_):return L.fail("缩建会让屋顶悬空，请先调整屋顶范围。")
	return {"ok":true}
static func create(context: Dictionary,area: Rect2,finish: Dictionary) -> Dictionary:
	if context.level>=S.MAX:return L.fail("目前最多支持4层房间。")
	if minf(area.size.x,area.size.y)<1.:return L.fail("房间的长、宽至少1米。")
	var site=preload("res://scripts/building/site.gd")
	if not site.within(area.position) or not site.within(area.end):return L.fail("房间需要留在建造地块内。")
	var grid:={"floors":context.grid.floors.duplicate(),"walls":context.grid.walls.duplicate()};var added: Dictionary={}
	var floor_row:={"id":"__room_floor","type":"floor","storey":context.level,"color":finish.get("floor_color","cda56e"),"style":finish.get("floor_style","wood"),"painted":true}
	for cell in G.coordinates({"a":[area.position.x,area.position.y],"b":[area.end.x,area.end.y]}):
		if context.plan.cell_rooms.has(cell):return L.fail("新房间与已有房间重叠。")
		if not grid.floors.has(cell):grid.floors[cell]=floor_row;added[cell]=true
	for edge in grid.walls:
		var ends:=G.ends(edge);var middle: Vector2=(G.point(ends[0])+G.point(ends[1]))*.5
		if area.grow(-.01).has_point(middle):return L.fail("房间内部有已有墙壁，请调整范围。")
	for pair in [[area.position,Vector2(area.end.x,area.position.y)],[Vector2(area.end.x,area.position.y),area.end],[area.end,Vector2(area.position.x,area.end.y)],[Vector2(area.position.x,area.end.y),area.position]]:
		var row:={"id":"__room_wall","type":"wall","storey":context.level,"a":[pair[0].x,pair[0].y],"b":[pair[1].x,pair[1].y],"color":finish.get("color","eadcc5"),"style":finish.get("style","plaster"),"painted":true}
		for edge in G.edges(row):
			if not grid.walls.has(edge):grid.walls[edge]=row
	var checked:=support(context,added,{})
	if not checked.ok:return checked
	var result:={"ok":true,"grid":grid,"moves":{},"openings":{},"roofs":{},"bounds":area,"region":area,"exterior_expansion":true}
	checked=check_geometry(context,result)
	if not checked.ok:return checked
	return result
static func wall_context(context: Dictionary,unit: Dictionary,camera: Vector2) -> Dictionary:
	if unit.get("type","")!="wall":return {}
	var edge: Vector3i=G.edges(unit)[0];var sides:=adjacent(edge);var plan: Dictionary=context.plan
	var preferred:=Surface.inside_side(plan,unit,camera);var room: String=plan.cell_rooms.get(sides[0 if preferred=="positive" else 1],"")
	if room=="":room=plan.cell_rooms.get(sides[1 if preferred=="positive" else 0],"")
	if room=="":return {}
	var step:=Vector3i(1,0,0) if edge.z==0 else Vector3i(0,1,0);var first:=edge;var last:=edge
	for direction in [-1,1]:
		var current: Vector3i=edge+step*direction
		while context.grid.walls.has(current):
			var cells:=adjacent(current)
			if (plan.cell_rooms.get(cells[0],"")==room)==(plan.cell_rooms.get(cells[1],"")==room):break
			if direction<0:first=current
			else:last=current
			current+=step*direction
	var axis: int=1 if edge.z==0 else 0;var along: int=1-axis
	var lo: int=first[along];var hi: int=last[along]+1;var plane: int=first[axis]
	var old_rooms: Dictionary={room:plan.rooms[room].cells};var outside: Dictionary={};var moving_edges: Dictionary={}
	for i in range(lo,hi):
		var e:=Vector3i(i,plane,0) if axis==1 else Vector3i(plane,i,1);moving_edges[e]=context.grid.walls[e]
		var cells:=adjacent(e);var other: String=plan.cell_rooms.get(cells[1] if plan.cell_rooms.get(cells[0],"")==room else cells[0],"")
		outside[i]=other
		if other!="":old_rooms[other]=plan.rooms[other].cells
	var positive_inside: bool=plan.cell_rooms.get(sides[0],"")==room
	var out:={"base":context,"room":room,"axis":axis,"along":along,"plane":plane,"lo":lo,"hi":hi,"outward":-1 if positive_inside else 1,"rooms":old_rooms,"outside":outside,"edges":moving_edges,"follow":{},"end_styles":{}}
	var world_plane: float=plane*.5
	for info in context.objects:
		var row: Dictionary=info.row
		if C.mount(row)!="floor" or C.OBJECTS[row.kind].get("overlay",false):continue
		var foot: Rect2=info.wall_foot;var center: Vector2=foot.get_center();var side: float=signf(center[axis]-world_plane)
		var gap: float=absf((foot.position[axis] if side>0 else foot.end[axis])-world_plane)
		if gap<=.38 and minf(foot.end[along],hi*.5)-maxf(foot.position[along],lo*.5)>.05 and old_rooms.has(plan.cell_rooms.get(G.cell(center),"")):out.follow[row.id]=true
	for info in context.objects:
		if C.mount(info.row)!="wall":continue
		var p:=WallMount.anchor(info.row);var width: float=C.OBJECTS[info.row.kind].size.x
		if absf(p[axis]-world_plane)<.005 and p[along]-width*.5>=lo*.5-.001 and p[along]+width*.5<=hi*.5+.001:out.follow[info.row.id]=true
	var pairs:=preload("res://scripts/building/dining.gd").links(context.source)
	for chair in pairs:
		if out.follow.has(pairs[chair]):out.follow[chair]=true
	for info in context.objects:
		if out.follow.has(info.row.get("support","")):out.follow[info.row.id]=true
	for endpoint in [lo,hi]:
		var n: int=plane-1 if positive_inside else plane;var e:=Vector3i(endpoint,n,1) if axis==1 else Vector3i(n,endpoint,0)
		out.end_styles[endpoint]=context.grid.walls.get(e,context.grid.walls[edge])
	return out
static func resize(context: Dictionary,delta: int) -> Dictionary:
	if context.is_empty():return L.fail("请从完整房间的墙壁开始拖动。")
	var base: Dictionary=context.base;var grid:={"floors":base.grid.floors.duplicate(),"walls":base.grid.walls.duplicate()}
	var rooms: Dictionary={}
	for id in context.rooms:rooms[id]=context.rooms[id].duplicate()
	var expanding: bool=delta*context.outward>0;var target: int=context.plane+delta;var low:=mini(target,context.plane);var high:=maxi(target,context.plane)
	var added: Dictionary={};var removed: Dictionary={};var changed:=Rect2();var exterior:=false
	for i in range(context.lo,context.hi):
		var outside: String=context.outside[i]
		for n in range(low,high):
			var cell:=Vector2i(i,n) if context.axis==1 else Vector2i(n,i)
			if expanding:
				if rooms[context.room].has(cell):return L.fail("扩建会与房间的其他部分相交。")
				rooms[context.room][cell]=true
				var owner: String=base.plan.cell_rooms.get(cell,"")
				if owner!="":
					if not rooms.has(owner):return L.fail("扩建会越过相邻房间的墙壁。")
					rooms[owner].erase(cell)
				else:exterior=true
				if not grid.floors.has(cell):
					var inside: int=context.plane-(1 if context.outward>0 else 0)
					var nearest:=Vector2i(i,inside) if context.axis==1 else Vector2i(inside,i)
					grid.floors[cell]=base.grid.floors.get(nearest,{"id":"__room_floor","type":"floor","color":"cda56e","style":"wood"});added[cell]=true
			else:
				if not rooms[context.room].has(cell):return L.fail("缩建不能越过房间的另一面墙。")
				rooms[context.room].erase(cell)
				if outside!="":rooms[outside][cell]=true
				elif grid.floors.has(cell):grid.floors.erase(cell);removed[cell]=true
	var checked:=support(base,added,removed)
	if not checked.ok:return checked
	for edge in context.edges:grid.walls.erase(edge)
	for i in range(context.lo,context.hi):
		var edge:=Vector3i(i,target,0) if context.axis==1 else Vector3i(target,i,1)
		if grid.walls.has(edge) and delta!=0:return L.fail("移动后与已有墙壁相交。")
		var old:=Vector3i(i,context.plane,0) if context.axis==1 else Vector3i(context.plane,i,1);grid.walls[edge]=context.edges[old]
	# Extend/trim perpendicular end walls according to both rooms' new boundaries.
	for endpoint in [context.lo,context.hi]:
		for n in range(low,high):
			var edge:=Vector3i(endpoint,n,1) if context.axis==1 else Vector3i(n,endpoint,0);var cells:=adjacent(edge);var ids: Array=[]
			for cell in cells:
				var id: String=base.plan.cell_rooms.get(cell,"")
				if context.rooms.has(id):id=""
				for room in rooms:
					if rooms[room].has(cell):id=room;break
				ids.append(id)
			if ids[0]==ids[1]:grid.walls.erase(edge)
			elif not grid.walls.has(edge):grid.walls[edge]=context.end_styles[endpoint]
	for id in rooms:
		var cells: Dictionary=rooms[id];var area:=bounds(cells)
		if cells.size()<4 or minf(area.size.x,area.size.y)<1.:return L.fail("调整后每个房间的长、宽至少1米。")
		if cells.size()==roundi(area.get_area()*4.):
			# The common rectangular case needs only its perimeter and wall crossings.
			var first:=G.cell(area.position);var last:=G.cell(area.end)
			for x in range(first.x,last.x):
				if not grid.walls.has(Vector3i(x,first.y,0)) or not grid.walls.has(Vector3i(x,last.y,0)):return L.fail("移动会破坏房间闭合。")
			for z in range(first.y,last.y):
				if not grid.walls.has(Vector3i(first.x,z,1)) or not grid.walls.has(Vector3i(last.x,z,1)):return L.fail("移动会破坏房间闭合。")
			for edge in grid.walls:
				var ends:=G.ends(edge);var middle: Vector2=(G.point(ends[0])+G.point(ends[1]))*.5
				if area.grow(-.01).has_point(middle):return L.fail("移动会穿过另一面墙。")
			continue
		var start: Vector2i=cells.keys()[0];var queue: Array=[start];var seen: Dictionary={start:true};var cursor:=0
		while cursor<queue.size():
			var cell: Vector2i=queue[cursor];cursor+=1
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+direction;var wall: bool=grid.walls.has(edge_between(cell,direction))
				if cells.has(next):
					if wall:return L.fail("移动会穿过另一面墙，请缩小拖动距离。")
					if not seen.has(next):seen[next]=true;queue.append(next)
				elif not wall:return L.fail("这次移动会破坏房间闭合，请调整相邻墙壁。")
		if seen.size()!=cells.size():return L.fail("缩建会把房间分成互不相连的区域。")
	var a:=Vector2(context.lo*.5,low*.5) if context.axis==1 else Vector2(low*.5,context.lo*.5)
	var size_:=Vector2((context.hi-context.lo)*.5,maxf(.01,(high-low)*.5)) if context.axis==1 else Vector2(maxf(.01,(high-low)*.5),(context.hi-context.lo)*.5)
	var moves: Dictionary={};var openings: Dictionary={};var roofs: Dictionary={};var shift:=Vector2.ZERO;shift[context.axis]=delta*.5
	for id in context.follow:moves[id]=shift
	for hole in base.openings:
		if hole.axis!=context.along or absf(hole.anchor[context.axis]-context.plane*.5)>.001 or hole.anchor[context.along]<context.lo*.5 or hole.anchor[context.along]>context.hi*.5:continue
		var next: Dictionary=hole.duplicate(true);next.anchor[context.axis]+=delta*.5;openings[hole.id]=next
	for roof in base.roofs:
		var area:=L.rect(roof)
		if area.position[context.along]<context.lo*.5-.001 or area.end[context.along]>context.hi*.5+.001:continue
		if not is_equal_approx(area.position[context.axis],context.plane*.5) and not is_equal_approx(area.end[context.axis],context.plane*.5):continue
		var next: Dictionary=roof.duplicate(true)
		for field in ["a","b"]:
			if is_equal_approx(next[field][context.axis],context.plane*.5):next[field][context.axis]+=delta*.5
		roofs[roof.id]=next
	var result:={"ok":true,"grid":grid,"moves":moves,"openings":openings,"roofs":roofs,"bounds":bounds(rooms[context.room]),"rooms":rooms,"region":Rect2(a,size_),"exterior_expansion":exterior,"delta":shift}
	for wall in G.runs(context.edges):
		var area:=L.rect(wall);area.position+=shift
		for railing in base.railings:
			if area.grow(.12).intersects(L.rect(railing).grow(.05)):return L.fail("移动后的墙壁与护栏冲突。")
	for cell in added:
		var p:=G.point(cell)
		if not preload("res://scripts/building/site.gd").within(p) or not preload("res://scripts/building/site.gd").within(p+Vector2.ONE*.5):return L.fail("房间扩建超出了建造地块。")
	checked=check_geometry(base,result)
	if not checked.ok:return checked
	return result
static func materialize(context: Dictionary,result: Dictionary) -> Dictionary:
	var next: Dictionary=context.source.duplicate(true)
	for i in range(next.elements.size()):
		var row: Dictionary=next.elements[i]
		if result.moves.has(row.id):
			var delta: Vector2=result.moves[row.id];row.position=[snappedf(row.position[0]+delta.x,.001),snappedf(row.position[1]+delta.y,.001)]
		if result.openings.has(row.id):next.elements[i]=result.openings[row.id].duplicate(true)
		if result.roofs.has(row.id):next.elements[i]=result.roofs[row.id].duplicate(true)
	# Preview-only row names become real IDs once, on release.
	var grid:={"floors":{},"walls":{}};var ids: Dictionary={}
	for type in ["floors","walls"]:
		for key in result.grid[type]:
			var row: Dictionary=result.grid[type][key]
			if str(row.id).begins_with("__"):
				if not ids.has(row.id):ids[row.id]="build_%d"%next.next_id;next.next_id+=1
				row=row.duplicate();row.id=ids[row.id]
			grid[type][key]=row
	next=G.compress(next,grid,context.level)
	if context.level>0:
		for roof in context.source.elements:
			if roof.type=="roof" and S.of(roof)==context.level-1 and G.covered(L.rect(roof),grid.floors):next=L.remove(next,roof.id)
	return next
