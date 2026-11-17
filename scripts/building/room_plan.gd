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
	var job=preload("res://scripts/building/room_plan_job.gd").new(grid);job.advance(2147483647)
	return retain(signature,job.result(signature))
static func retain(signature: String,result: Dictionary) -> Dictionary:
	if cache.size()>=8:cache.erase(cache.keys()[0])
	cache[signature]=result;return result
static func make_incremental(grid: Dictionary,tree: SceneTree,budget_usec: int=3000) -> Dictionary:
	var signature:=key(grid.walls,grid.floors)
	if cache.has(signature):return {"plan":cache[signature],"max_slice_usec":0,"yields":0}
	var job=preload("res://scripts/building/room_plan_job.gd").new(grid)
	var slice:=Time.get_ticks_usec();var max_slice:=0;var yields:=0
	while not job.done:
		job.advance(128)
		if Time.get_ticks_usec()-slice>=budget_usec:
			max_slice=maxi(max_slice,Time.get_ticks_usec()-slice);await tree.process_frame;slice=Time.get_ticks_usec();yields+=1
	max_slice=maxi(max_slice,Time.get_ticks_usec()-slice)
	return {"plan":retain(signature,job.result(signature)),"max_slice_usec":max_slice,"yields":yields}

static func room_at(plan: Dictionary,p: Vector2,require_floor: bool=true) -> String:
	var c:=Grid.cell(p)
	if require_floor and not plan.floors.has(c):return ""
	return str(plan.cell_rooms.get(c,""))
