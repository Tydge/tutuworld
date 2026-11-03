extends RefCounted
const SIZE:=Vector2(108,106)
const HOUSE:=Vector3(12,4,-36)
const STAIRS: Array[Vector2]=[Vector2(-18,-9),Vector2(-18,-27),Vector2(22,-9),Vector2(22,-27),Vector2(12,-24)]
static func river_x(z: float) -> float: return sin(z*.07)*2.0
static func river_half_width(z: float) -> float: return 3.05+smoothstep(28.,58.,z)*6.0
static func bank_height(z: float) -> float: return 4.0 if z< -27.0 else (2.0 if z< -9.0 else 0.0)
static func stair_lane(x: float) -> bool: return absf(x+18)<3.5 or absf(x-22)<3.5
static func terrain_contains(x: float,z: float) -> bool:
	return Vector2(x,z/.88).length()<53 or Vector2((x+13)/14.,(z-42)/19.).length()<1
static func height_at(x: float,z: float) -> float:
	var height_: float=bank_height(z)
	if stair_lane(x):
		if z>= -12 and z<= -6: height_=clampf((-6-z)/6.,0,1)*2
		if z>= -30 and z<= -24: height_=2+clampf((-24-z)/6.,0,1)*2
	if absf(x-12)<3.5 and z>= -27 and z<= -21: height_=2+clampf((-21-z)/6.,0,1)*2
	height_-=smoothstep(50.,60.,z)*1.5
	if z>34:
		var shore_distance: float=(1-Vector2((x+13)/14.,(z-42)/19.).length())*14
		height_-=2*(1-smoothstep(0.,3.,maxf(0,shore_distance)))*smoothstep(34.,42.,z)
	var width:=river_half_width(z)
	height_-=.72*(1-smoothstep(width-.55,width+.25,absf(x-river_x(z))))
	return height_
static func water_level(z: float) -> float:
	return bank_height(z)-.22-smoothstep(42.,62.,z)*1.29
static func stair_height(z: float,center: float,lower: float) -> float:
	return lower+clampf((center+3.6-z)/6.,0,1)*2.
static func bridge_at(p: Vector3) -> bool: return absf(p.z-5)<2.1 and absf(p.x)<6.2
static func on_dock(p: Vector3) -> bool: return p.x> -14.2 and p.x< -2.8 and p.z>45.2 and p.z<49.25
static func walk_height(x: float,z: float) -> float:
	if bridge_at(Vector3(x,0,z)): return .08+.55*sin(clampf((x+6)/12,0,1)*PI)
	if on_dock(Vector3(x,0,z)): return .18
	for stair in STAIRS:
		if absf(x-stair.x)<3.2 and z>=stair.y-3 and z<=stair.y+3.6:
			return stair_height(z,stair.y,2. if stair.y== -24 else bank_height(stair.y+3.1))
	return height_at(x,z)
static func can_walk(p: Vector3) -> bool:
	if absf(p.x-12)<6.35 and absf(p.z+36)<5.35: return true
	if on_dock(p): return true
	var harbor:=Vector2((p.x+13)/11.,(p.z-42)/11.).length()<1.
	if Vector2(p.x,p.z/.88).length()>50 and not harbor: return false
	if absf(p.x-river_x(p.z))<river_half_width(p.z)+.12 and not bridge_at(p): return false
	return true
static func can_navigate(p: Vector3) -> bool:
	if not can_walk(p): return false
	# Only path planning excludes abrupt terrace edges; a player may land and walk away.
	if (absf(p.z+9)<.7 or absf(p.z+27)<.7) and not stair_lane(p.x) and not (p.z< -26 and absf(p.x-12)<3.5): return false
	return true
static func valid_saved_position(map_id: String,p: Vector3) -> bool:
	if not p.is_finite(): return false
	if map_id=="valley": return absf(p.x)<55 and p.z> -46 and p.z<56 and p.y> -6 and p.y<18
	return (absf(p.x)<48 and absf(p.z)<43) or preload("res://scripts/building/site.gd").contains(p)
static func scene_path(map_id: String) -> String: return "res://scenes/valley.tscn" if map_id=="valley" else "res://scenes/city.tscn"
static func dock(map_id: String) -> Vector2: return Vector2(-5.8,47.2) if map_id=="valley" else Vector2(13,41.5)
static func arrival(map_id: String) -> Array: return [-11,.2,43] if map_id=="valley" else [13,.2,39.5]
static func on_path(x: float,z: float) -> bool:
	var west: float=-8-clampf(32-z,0,22)*.4
	if z>31: west=lerpf(-8,-13,smoothstep(31.,46.,z))
	return (absf(x-12)<2.2 and z< -20) or absf(x-west)<2.2 or (z<12 and (absf(x+18)<2.3 or absf(x-22)<2.3)) or (absf(z-5)<2.5 and absf(x)<28)
