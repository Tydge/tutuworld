extends RefCounted
const L=preload("res://scripts/building/layout.gd")
const S=preload("res://scripts/building/storeys.gd")
const G=preload("res://scripts/building/grid_layout.gd")
const Stairs=preload("res://scripts/building/stairs.gd")
static func safe(previous: Dictionary,next: Dictionary,actor: Vector3) -> bool:
	for row in previous.elements:
		if row.type!="stairs" or actor.y<S.elevation(row)+.5 or actor.y>S.elevation(row)+S.HEIGHT-.25:continue
		if Stairs.bounds(row).has_point(Vector2(actor.x,actor.z)) and L.find(next,row.id)!=row:return false
	var level:=S.at_height(actor.y)
	if level==0:return true
	var cell:=G.cell(Vector2(actor.x,actor.z))
	if L.walkable_grid(previous,level).floors.has(cell) and not L.walkable_grid(next,level).floors.has(cell):return false
	return not has_exit(previous,actor) or has_exit(next,actor)
static func has_exit(layout: Dictionary,actor: Vector3) -> bool:
	var start:=Vector3i(G.cell(Vector2(actor.x,actor.z)).x,G.cell(Vector2(actor.x,actor.z)).y,S.at_height(actor.y));var visited: Dictionary={start:true};var queue: Array=[start];var cursor:=0;var layers: Array=[];var links: Dictionary={}
	for level in range(S.MAX):layers.append(L.walkable_grid(layout,level))
	for row in layout.elements:
		if row.type!="stairs":continue
		var route:=Stairs.route(row);var a:=G.cell(Vector2(route[0].x,route[0].z));var b:=G.cell(Vector2(route[-1].x,route[-1].z));var lower:=Vector3i(a.x,a.y,S.of(row));var upper:=Vector3i(b.x,b.y,S.of(row)+1)
		if not links.has(lower):links[lower]=[]
		if not links.has(upper):links[upper]=[]
		links[lower].append(upper);links[upper].append(lower)
	var doors: Dictionary={}
	for row in layout.elements:
		if row.type!="door" or not row.has("anchor"):continue
		var half:=1.3;var axis: int=row.axis;var plane_:=roundi(row.anchor[1-axis]*2.)
		for i in range(ceili((row.anchor[axis]-half)*2.),floori((row.anchor[axis]+half)*2.)):
			var edge:=Vector3i(i,plane_,0) if axis==0 else Vector3i(plane_,i,1);doors[str(S.of(row))+str(edge)]=true
	while cursor<queue.size():
		var cell: Vector3i=queue[cursor];cursor+=1
		if cell.z==0:return true
		var layer: Dictionary=layers[cell.z]
		var neighbors: Array=links.get(cell,[]).duplicate()
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=Vector2i(cell.x,cell.y)+direction
			if not layer.floors.has(next):continue
			var edge:=Vector3i(cell.x+(1 if direction==Vector2i.RIGHT else 0),cell.y+(1 if direction==Vector2i.DOWN else 0),1 if direction.x!=0 else 0)
			if layer.walls.has(edge) and not doors.has(str(cell.z)+str(edge)):continue
			neighbors.append(Vector3i(next.x,next.y,cell.z))
		for neighbor in neighbors:
			if visited.has(neighbor):continue
			visited[neighbor]=true;queue.append(neighbor)
	return false
