extends RefCounted
## Resumable version of the closed-region flood fill used by room plans.
const Grid=preload("res://scripts/building/grid_layout.gd")
var grid: Dictionary
var first: Vector2i
var last: Vector2i
var scan: Vector2i
var visited: Dictionary={}
var regions: Dictionary={}
var cell_rooms: Dictionary={}
var queue: Array[Vector2i]=[]
var cursor:=0
var enclosed:=true
var has_floor:=false
var cells: Dictionary={}
var start: Vector2i
var done:=false
func _init(source: Dictionary) -> void:
	grid=source
	if grid.floors.is_empty() and grid.walls.is_empty():done=true;return
	if not grid.floors.is_empty():first=grid.floors.keys()[0]
	else:first=Grid.ends(grid.walls.keys()[0])[0]
	last=first
	for c: Vector2i in grid.floors:first=first.min(c);last=last.max(c+Vector2i.ONE)
	for edge: Vector3i in grid.walls:
		for c in Grid.ends(edge):first=first.min(c);last=last.max(c+Vector2i.ONE)
	first-=Vector2i.ONE;last+=Vector2i.ONE;scan=first
func advance(limit: int) -> void:
	var work:=0
	while not done and work<limit:
		work+=1
		if cursor<queue.size():
			var c: Vector2i=queue[cursor];cursor+=1;cells[c]=true
			if grid.floors.has(c):has_floor=true
			for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
				var edge:=Vector3i(c.x+(1 if direction==Vector2i.RIGHT else 0),c.y+(1 if direction==Vector2i.DOWN else 0),1 if direction.x!=0 else 0)
				if grid.walls.has(edge):continue
				var next: Vector2i=c+direction
				if next.x<first.x or next.y<first.y or next.x>=last.x or next.y>=last.y:enclosed=false;continue
				if visited.has(next):continue
				visited[next]=true;queue.append(next)
			continue
		if not queue.is_empty():
			if enclosed and has_floor:
				var id:="room_%d_%d"%[start.x,start.y];regions[id]={"cells":cells,"id":id}
				for c in cells:cell_rooms[c]=id
			queue=[];cells={};cursor=0
		if scan.y>=last.y:done=true;break
		var at:=scan;scan.x+=1
		if scan.x>=last.x:scan.x=first.x;scan.y+=1
		if visited.has(at):continue
		start=at;enclosed=true;has_floor=false;queue=[start];visited[start]=true
func result(signature: String) -> Dictionary:
	return {"rooms":regions,"cell_rooms":cell_rooms,"floors":grid.floors,"signature":signature}
