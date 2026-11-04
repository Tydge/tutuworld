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
var stair_reservations: Array=[]
const GROUND_MARGIN:=.45
const SUPPORT_OFFSETS=[Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.7071,.7071),Vector2(.7071,-.7071),Vector2(-.7071,.7071),Vector2(-.7071,-.7071)]
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
	for area: Rect2 in stair_reservations:
		if area.has_point(Vector2(x,z)):return true
	# The outdoor grid samples ground near its own height. Upper storeys must
	# never replace a street cell with the roof / highest floor above it.
	var top:=.75 if preload("res://scripts/building/site.gd").contains(Vector3(x,0,z)) and get_parent().get("map_id")=="city" else 18.
	floor_query.from=Vector3(x,top,z);floor_query.to=Vector3(x,-1.5,z)
	var floor_hit:=space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		floor_heights.erase(Vector2i(x,z));return true
	var height_: float=floor_hit.position.y
	# A legal center is insufficient at a bridge or cliff edge. Keep the feet supported.
	if not supported(Vector3(x,height_,z),space):return true
	floor_heights[Vector2i(x,z)]=height_
	query.transform=Transform3D(Basis.IDENTITY,Vector3(x,height_+1.39,z))
	return not space.intersect_shape(query,1).is_empty()
func supported(point: Vector3,space: PhysicsDirectSpaceState3D,margin: float=GROUND_MARGIN) -> bool:
	for sample: Vector2 in SUPPORT_OFFSETS:
		var offset:=Vector3(sample.x*margin,0,sample.y*margin)
		floor_query.from=point+offset+Vector3.UP*.4;floor_query.to=point+offset-Vector3.UP*.45
		var hit:=space.intersect_ray(floor_query)
		if hit.is_empty() or hit.normal.y<.7:return false
	return true
func can_step(from: Vector3,to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D=get_parent().get_world_3d().direct_space_state
	var next:=Vector3(to.x,from.y,to.z)
	if supported(next,space):return true
	# A previously displaced actor can walk back toward supported ground, without teleporting.
	if supported(from,space) or not supported(next,space,0.):return false
	var cell:=closest_free(from)
	if cell.x==999:return false
	var safe:=Vector2(cell.x,cell.y)
	return Vector2(to.x,to.z).distance_squared_to(safe)<Vector2(from.x,from.z).distance_squared_to(safe)
func build() -> void:
	await get_tree().physics_frame
	reserve_stairs()
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
	reserve_stairs()
	var space: PhysicsDirectSpaceState3D=get_parent().get_world_3d().direct_space_state
	for z in range(floori(bounds.position.z)-1,ceili(bounds.end.z)+2):
		for x in range(floori(bounds.position.x)-1,ceili(bounds.end.x)+2):
			var cell:=Vector2i(x,z)
			if grid.is_in_boundsv(cell): grid.set_point_solid(cell,blocked(space,x,z))
	await rebuild_destinations()

func reserve_stairs() -> void:
	stair_reservations.clear()
	var editor: Variant=get_parent().get("build_mode")
	if not is_instance_valid(editor):return
	for row in editor.layout.elements:
		if row.type=="stairs" and int(row.get("storey",0))==0:
			for area in preload("res://scripts/building/stairs.gd").parts(row):stair_reservations.append(area.grow(.45))
