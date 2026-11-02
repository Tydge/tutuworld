extends Node
## Shared clearance grid and connected walking destinations across the whole island.
var grid:=AStarGrid2D.new()
var ready_for_paths:=false
var query:=PhysicsShapeQueryParameters3D.new()
var floor_query:=PhysicsRayQueryParameters3D.new()
var map_bounds:=Rect2i(-52,-46,105,93)
var component_of: Dictionary={}
var destinations: Dictionary={}
var sampling_ready:=false
var sampling_revision:=0
var floor_heights: Dictionary={}
func _ready() -> void:
	if get_parent().has_method("navigation_bounds"): map_bounds=get_parent().navigation_bounds()
	grid.region=map_bounds;grid.cell_size=Vector2.ONE
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE;grid.update()
	var footprint:=CylinderShape3D.new();footprint.radius=.94;footprint.height=2.40
	query.shape=footprint;query.collision_mask=5;query.collide_with_areas=false
	floor_query.collision_mask=8
	build.call_deferred()
func blocked(space: PhysicsDirectSpaceState3D,x: int,z: int) -> bool:
	if not get_parent().can_navigate(Vector3(x,0,z)): return true
	floor_query.from=Vector3(x,18,z);floor_query.to=Vector3(x,-1.5,z)
	var floor_hit:=space.intersect_ray(floor_query)
	var height_: float=0.0 if floor_hit.is_empty() else float(floor_hit.position.y)
	floor_heights[Vector2i(x,z)]=height_
	query.transform=Transform3D(Basis.IDENTITY,Vector3(x,height_+1.39,z))
	return not space.intersect_shape(query,1).is_empty()
func build() -> void:
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D=get_parent().get_world_3d().direct_space_state
	var count_:=0
	for z in range(map_bounds.position.y,map_bounds.end.y):
		for x in range(map_bounds.position.x,map_bounds.end.x):
			grid.set_point_solid(Vector2i(x,z),blocked(space,x,z));count_+=1
			if count_%600==0: await get_tree().physics_frame
	await rebuild_destinations()
	ready_for_paths=true
	print("WANDER_GRID_READY cells=",count_," components=",destinations.size())
static func zone(point: Vector3) -> int:
	var column:=0 if point.x< -18 else (2 if point.x>18 else 1)
	var row:=0 if point.z< -14 else (2 if point.z>14 else 1)
	return row*3+column
func rebuild_destinations() -> void:
	sampling_revision+=1;var generation:=sampling_revision;sampling_ready=false
	var components: Dictionary={};var buckets: Dictionary={};var component:=0;var visited:=0
	for z in range(map_bounds.position.y,map_bounds.end.y):
		for x in range(map_bounds.position.x,map_bounds.end.x):
			var start:=Vector2i(x,z)
			if grid.is_point_solid(start) or components.has(start): continue
			var queue: Array[Vector2i]=[start];components[start]=component
			var areas: Array=[]
			for i in range(9): areas.append([])
			var cursor:=0
			while cursor<queue.size():
				var cell:=queue[cursor];cursor+=1
				areas[zone(Vector3(cell.x,0,cell.y))].append(cell)
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i=cell+offset
					if not grid.is_in_boundsv(next) or grid.is_point_solid(next) or components.has(next): continue
					components[next]=component;queue.append(next)
				visited+=1
				if visited%1200==0:
					await get_tree().physics_frame
					if generation!=sampling_revision: return
			buckets[component]=areas;component+=1
	if generation!=sampling_revision: return
	component_of=components;destinations=buckets;sampling_ready=true
func closest_free(p: Vector3) -> Vector2i:
	var origin:=Vector2i(roundi(p.x),roundi(p.z));var result:=Vector2i(999,999);var closest:=1e9
	for ring in range(6):
		for z in range(-ring,ring+1):
			for x in range(-ring,ring+1):
				if ring>0 and absi(x)!=ring and absi(z)!=ring: continue
				var q:=origin+Vector2i(x,z)
				if not grid.is_in_boundsv(q) or grid.is_point_solid(q): continue
				var d:=Vector2(q.x-p.x,q.y-p.z).length_squared()
				if d<closest: result=q;closest=d
		if result.x!=999: break
	return result
func random_destination(from: Vector3,rng: RandomNumberGenerator,recent: Array[int]) -> Dictionary:
	if not sampling_ready: return {}
	var cell:=closest_free(from)
	if not component_of.has(cell): return {}
	var areas: Array=destinations[component_of[cell]]
	var preferred: Array[int]=[];var fallback: Array[int]=[]
	for i in range(9):
		if areas[i].is_empty(): continue
		fallback.append(i)
		if i!=zone(from) and not recent.has(i): preferred.append(i)
	var choices: Array[int]=preferred if not preferred.is_empty() else fallback
	if choices.is_empty(): return {}
	var selected: int=choices[rng.randi_range(0,choices.size()-1)]
	var destination: Vector2i=areas[selected][rng.randi_range(0,areas[selected].size()-1)]
	return {"position":Vector3(destination.x,floor_heights.get(destination,0.0),destination.y),"zone":selected}
func path_between(from: Vector3,to: Vector3) -> PackedVector3Array:
	var path:=PackedVector3Array()
	if not ready_for_paths: return path
	var a:=closest_free(from);var b:=closest_free(to)
	if a.x==999 or b.x==999: return path
	if sampling_ready and component_of.get(a,-1)!=component_of.get(b,-2): return path
	for id in grid.get_id_path(a,b): path.append(Vector3(id.x,floor_heights.get(id,0.0),id.y))
	return path
func refresh_region(bounds: AABB) -> void:
	if not ready_for_paths: return
	await get_tree().physics_frame;await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D=get_parent().get_world_3d().direct_space_state
	for z in range(floori(bounds.position.z)-1,ceili(bounds.end.z)+2):
		for x in range(floori(bounds.position.x)-1,ceili(bounds.end.x)+2):
			var cell:=Vector2i(x,z)
			if grid.is_in_boundsv(cell): grid.set_point_solid(cell,blocked(space,x,z))
	await rebuild_destinations()
