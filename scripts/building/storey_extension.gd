extends RefCounted
## Plan upstairs construction without changing the live layout or its checkpoint.
const L=preload("res://scripts/building/layout.gd")
const Grid=preload("res://scripts/building/grid_layout.gd")
const Rooms=preload("res://scripts/building/room_plan.gd")
const Storeys=preload("res://scripts/building/storeys.gd")
const Stairs=preload("res://scripts/building/stairs.gd")

static func footprint(grid: Dictionary,p: Vector2) -> Dictionary:
	var start:=Grid.cell(p)
	if not grid.floors.has(start):return {}
	var plan:=Rooms.make(grid);var room:=Rooms.room_at(plan,p);var cells: Dictionary={}
	if room!="":
		# Adjacent enclosed rooms belong to the same house; exterior paving does not.
		var links: Dictionary={}
		for edge in grid.walls:
			var a:=Vector2i(edge.x,edge.y);var b:=a-(Vector2i.DOWN if edge.z==0 else Vector2i.RIGHT)
			var first: String=plan.cell_rooms.get(a,"");var second: String=plan.cell_rooms.get(b,"")
			if first=="" or second=="" or first==second:continue
			if not links.has(first):links[first]=[]
			if not links.has(second):links[second]=[]
			links[first].append(second);links[second].append(first)
		var rooms: Dictionary={room:true};var queue: Array=[room];var cursor:=0
		while cursor<queue.size():
			var current: String=queue[cursor];cursor+=1
			for neighbor in links.get(current,[]):
				if not rooms.has(neighbor):rooms[neighbor]=true;queue.append(neighbor)
		for id in rooms:
			for c in plan.rooms[id].cells:
				if grid.floors.has(c):cells[c]=grid.floors[c]
	else:
		# Before walls exist, use the selected connected foundation, never the plot bbox.
		cells[start]=grid.floors[start];var queue: Array=[start];var cursor:=0
		while cursor<queue.size():
			var current: Vector2i=queue[cursor];cursor+=1
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=current+direction
				if grid.floors.has(next) and not cells.has(next):cells[next]=grid.floors[next];queue.append(next)
	return cells

static func append_cells(layout: Dictionary,cells: Dictionary,level: int) -> Dictionary:
	var next:=layout
	for rect in Grid.rectangles(cells):
		var row:={"type":"floor","a":rect.a,"b":rect.b,"storey":level,"color":rect.get("color","cda56e"),"style":rect.get("style","wood"),"painted":rect.get("painted",false)}
		next=L.add(next,row)
	return next

static var first_floor_cache: Dictionary={}
static func landing_cells(layout: Dictionary,stair: Dictionary) -> Dictionary:
	var upper: Dictionary=L.compiled(layout,Storeys.of(stair)+1).floors;var cells: Dictionary={}
	var top:=Stairs.world_rect(stair,Stairs.definition(stair.form).top)
	var route:=Stairs.route(stair);var sample:=Grid.cell(Vector2(route[0].x,route[0].z))
	var finish: Dictionary=L.compiled(layout,Storeys.of(stair)).floors.get(sample,{"color":"cda56e","style":"wood"})
	for c in Grid.coordinates({"a":[top.position.x,top.position.y],"b":[top.end.x,top.end.y]}):
		if not upper.has(c):cells[c]=finish
	var source:=L.walkable_grid(layout,Storeys.of(stair))
	var key: String=source.signature+str(sample)
	var house: Dictionary={}
	for entry in first_floor_cache.values():
		if entry.signature==source.signature and entry.cells.has(sample):house=entry.cells;break
	if house.is_empty():
		house=footprint(source,Vector2(route[0].x,route[0].z))
		if first_floor_cache.size()>=4:first_floor_cache.erase(first_floor_cache.keys()[0])
		first_floor_cache[key]={"signature":source.signature,"cells":house}
	var already_built:=false
	for c in house:
		if upper.has(c):already_built=true;break
	if not already_built:
		var holes: Dictionary={}
		for c in Stairs.hole_cells(stair):holes[c]=true
		for c in house:
			if not upper.has(c) and not holes.has(c):cells[c]=house[c]
	return cells

static func place_stair(layout: Dictionary,row: Dictionary,moving: String="") -> Dictionary:
	var next:=L.add(layout,row) if moving=="" else L.replace(layout,row)
	return append_cells(next,landing_cells(layout,row),Storeys.of(row)+1)

static func preview_stair(layout: Dictionary,row: Dictionary,moving: String="") -> Dictionary:
	if Storeys.of(row)>=Storeys.MAX-1:return L.fail("4楼已达层数上限，请在较低楼层放置楼梯。")
	var cells:=landing_cells(layout,row)
	var candidate:=append_cells(layout,cells,Storeys.of(row)+1)
	var result:=Stairs.preview(candidate,row,moving)
	result["landing_cells"]=cells
	result["candidate"]=L.add(candidate,row) if moving=="" else L.replace(candidate,row)
	if not result.ok and layout.elements.any(func(item):return item.type=="roof" and Storeys.of(item)==Storeys.of(row) and L.rect(item).intersects(Stairs.bounds(row))):result.message="楼梯会穿过旧屋顶；请先用“生成上层楼板”替换屋顶，或调整屋顶范围。"
	return result

static func plan(layout: Dictionary,level: int,p: Vector2) -> Dictionary:
	if level>=Storeys.MAX-1:return L.fail("4楼已达层数上限。")
	var selected:=footprint(L.walkable_grid(layout,level),p)
	if selected.is_empty():return L.fail("请点击本层房屋的地板，选择要生成楼板的范围。")
	var upper: Dictionary=L.compiled(layout,level+1).floors;var holes: Dictionary={};var missing: Dictionary={}
	for stair in layout.elements:
		if stair.type=="stairs" and Storeys.of(stair)==level:
			for cell in Stairs.hole_cells(stair):holes[cell]=true
	for cell in selected:
		if not upper.has(cell) and not holes.has(cell):missing[cell]=selected[cell]
	if missing.is_empty():return L.fail("这个范围的上层楼板已经铺好；楼梯洞会保留。")
	var next:=append_cells(layout,missing,level+1)
	# A stair opening counts as part of the replaced ceiling footprint, not a reason
	# to retain an entire roof through the stair. Partially intersecting roofs fail below.
	var covered: Dictionary=L.compiled(next,level+1).floors.duplicate();covered.merge(holes)
	var removed_roofs:=0;var removed_fixtures:=0
	for roof in layout.elements:
		if roof.type=="roof" and Storeys.of(roof)==level and Grid.covered(L.rect(roof),covered) and not L.find(next,roof.id).is_empty():next=L.remove(next,roof.id)
	for roof in layout.elements:
		if roof.type=="roof" and L.find(next,roof.id).is_empty():removed_roofs+=1
		if roof.type=="object" and L.find(next,roof.id).is_empty():removed_fixtures+=1
	var result:=L.validate(next)
	if not result.ok:return result
	return {"ok":true,"layout":result.layout,"cells":missing,"level":level+1,"area":missing.size()*.25,"removed_roofs":removed_roofs,"removed_fixtures":removed_fixtures}
