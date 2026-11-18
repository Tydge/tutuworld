extends RefCounted
## Explicit map registry shared by loading, ferries, persistence and the server.
const IDS=["city","valley","icefield"]
static func title(id: String) -> String:return {"city":"海岛城","valley":"眠风山谷","icefield":"冰原岛"}.get(id,"海岛城")
static func scene(id: String) -> String:return "res://scenes/"+id+".tscn"
static func scenery(id: String) -> String:return {"city":"res://scenes/city_map.tscn","valley":"res://scenes/valley_map.scn","icefield":"res://scenes/icefield_map.scn"}.get(id,"res://scenes/city_map.tscn")
static func dock(id: String) -> Vector2:
	return preload("res://scripts/icefield/icefield_layout.gd").DOCK if id=="icefield" else preload("res://scripts/valley/valley_layout.gd").dock(id)
static func arrival(id: String) -> Array:
	return preload("res://scripts/icefield/icefield_layout.gd").arrival() if id=="icefield" else preload("res://scripts/valley/valley_layout.gd").arrival(id)
static func allowed(origin: String,destination: String) -> bool:return (origin=="city" and destination in ["valley","icefield"]) or (origin in ["valley","icefield"] and destination=="city")
