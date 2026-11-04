extends RefCounted
## Closed regions are bounded by wall edges. Door/window openings do not merge rooms.
const Grid=preload("res://scripts/building/grid_layout.gd")
const Site=preload("res://scripts/building/site.gd")
static var cache: Dictionary={}
static func key(walls: Dictionary,floors: Dictionary) -> String:
	var a: Array=walls.keys();var b: Array=floors.keys();a.sort();b.sort();return (str(a)+str(b)).sha256_text()
static func make(grid: Dictionary) -> Dictionary:
	var signature:=key(grid.walls,grid.floors)
	if cache.has(signature):return cache[signature]
	var first:=Grid.cell(Site.PLOT.end);var last:=Grid.cell(Site.PLOT.position)
	for c: Vector2i in grid.floors:first=first.min(c);last=last.max(c+Vector2i.ONE)
	for edge: Vector3i in grid.walls:
		for c in Grid.ends(edge):first=first.min(c);last=last.max(c+Vector2i.ONE)
	first-=Vector2i.ONE;last+=Vector2i.ONE
	var visited: Dictionary={};var regions: Dictionary={};var cell_rooms: Dictionary={}
	for z in range(first.y,last.y):
		for x in range(first.x,last.x):
			var start:=Vector2i(x,z)
			if visited.has(start):continue
			var queue: Array[Vector2i]=[start];var cursor:=0;var enclosed:=true;var has_floor:=false;var cells: Dictionary={};visited[start]=true
			while cursor<queue.size():
				var c: Vector2i=queue[cursor];cursor+=1;cells[c]=true
				if grid.floors.has(c):has_floor=true
				for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
					var e:=Vector3i(c.x+(1 if direction==Vector2i.RIGHT else 0),c.y+(1 if direction==Vector2i.DOWN else 0),1 if direction.x!=0 else 0)
					if grid.walls.has(e):continue
					var next: Vector2i=c+direction
					if next.x<first.x or next.y<first.y or next.x>=last.x or next.y>=last.y:enclosed=false;continue
					if visited.has(next):continue
					visited[next]=true;queue.append(next)
			if not enclosed or not has_floor:continue
			var id:="room_%d_%d"%[start.x,start.y];regions[id]={"cells":cells,"id":id}
			for c in cells:cell_rooms[c]=id
	var result:={"rooms":regions,"cell_rooms":cell_rooms,"floors":grid.floors,"signature":signature}
	if cache.size()>=3:cache.erase(cache.keys()[0])
	cache[signature]=result;return result
static func room_at(plan: Dictionary,p: Vector2,require_floor: bool=true) -> String:
	var c:=Grid.cell(p)
	if require_floor and not plan.floors.has(c):return ""
	return str(plan.cell_rooms.get(c,""))
