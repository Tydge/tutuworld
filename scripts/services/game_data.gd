extends RefCounted
static var _catalog: Dictionary = {}
const Clothes=preload("res://scripts/appearance/clothing_catalog.gd")
static var _plots: Array = []
static var _resources: Array = []
static var _valley_resources: Array=[]
static var _icefield_resources: Array=[]
const Valley=preload("res://scripts/valley/valley_layout.gd")
static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		_catalog.items.merge(Clothes.items())
	return _catalog
static func item(id: String) -> Dictionary: return catalog().items.get(id,{})
static func recipe(id: String) -> Dictionary: return catalog().recipes.get(id,{})
static func facilities() -> Dictionary:
	var result:={"kitchen":Vector2(21,-20.0),"dining":Vector2(27.8,-18.5),"home_bed":Vector2(-30.7,-4.75)}
	for id in preload("res://scripts/city/production_facilities.gd").defaults():
		var point: Vector3=preload("res://scripts/city/production_facilities.gd").defaults()[id].position
		result[id]=Vector2(point.x,point.z)
	return result
static func recipes_for_station(station: String) -> Array:
	return catalog().recipes.keys().filter(func(id): return recipe(id).get("station","")==station)
static func recipe_skill(id: String) -> String: return "manufacturing" if recipe(id).get("station","")=="workshop" else "cooking"
static func recipe_speed(id: String) -> String: return "manufacture" if recipe_skill(id)=="manufacturing" else "cook"
static func water_capacity(id: String) -> int: return int(item(id).get("water_capacity",0))
static func crop(id: String) -> Dictionary: return catalog().crops.get(id,{})
static func care_stages(id: String) -> Array:
	return crop(id).get("care_stages",catalog().get("crop_care_stages",[{"water":true,"weed":false},{"water":true,"weed":true},{"water":true,"weed":true}]))
static func crop_quality_max(id: String) -> int:
	var opportunities := 1 # Successful sowing, followed by each required care action.
	for stage in care_stages(id):
		opportunities+=int(stage.get("water",false))+int(stage.get("weed",false))
	return opportunities
static func plots() -> Array:
	if not _plots.is_empty(): return _plots
	var out: Array = []
	for row in range(6):
		for col in range(8): out.append({"id":"plot_%02d"%(row*8+col),"x":22+col*2.25,"z":-6+row*2.5})
	_plots=out
	return _plots
static func resources(map_id: String="city") -> Array:
	if map_id=="valley": return valley_resources()
	if map_id=="icefield": return icefield_resources()
	if map_id!="city": return []
	if not _resources.is_empty(): return _resources
	# Seeded spatial samples are stable save identities; refresh deadlines vary per node/generation.
	var spots: Dictionary={
		"limestone":[Vector2(-43,-17),Vector2(-30,-35),Vector2(45,-8),Vector2(-38,28),Vector2(33,25)],
		"copper":[Vector2(-42,-12),Vector2(35,-28),Vector2(-22,4),Vector2(44,18),Vector2(-22,29)],
		"branch":[Vector2(-20,-7),Vector2(13,25),Vector2(-38,16),Vector2(21,-13),Vector2(12,-38)]}
	var random:=RandomNumberGenerator.new();random.seed=622471
	for i in range(15):
		var type_: String=["limestone","copper","branch"][i%3]
		var point: Vector2=spots[type_][i/3]+Vector2(random.randf_range(-.35,.35),random.randf_range(-.35,.35))
		if i==4: point=Vector2(43,-24) # Stable copper node moved clear of the new workshop.
		_resources.append({"id":"resource_%02d"%i,"item":type_,"x":point.x,"z":point.y,"map":"city"})
	for i in range(4):
		var point: Vector2=[Vector2(-12,-7),Vector2(12,-7),Vector2(-12,6),Vector2(12,6)][i]
		_resources.append({"id":"city_orange_%d"%i,"item":"orange","x":point.x,"z":point.y,"map":"city"})
	return _resources
static func all_resources() -> Array: return resources("city")+resources("valley")+resources("icefield")
static func resource(id: String) -> Dictionary:
	for source in all_resources():
		if source.id==id: return source
	return {}
static func refresh_delay(id: String,generation: int) -> float:
	var random:=RandomNumberGenerator.new();random.seed=(id+":"+str(generation)).hash()
	return random.randf_range(3600,7200)

static func shops(map_id: String="city") -> Dictionary:
	if map_id=="icefield":return preload("res://scripts/icefield/icefield_layout.gd").shop_positions()
	return {"farm":Vector2(-18,-28.72),"tools":Vector2(-5,-28.72),"clothes":Vector2(8,-28.72)}

static func category(id: String,clothing_slots: bool=false) -> String:
	var definition:=item(id)
	if definition.get("kind","")=="clothing": return definition.slot if clothing_slots else "clothing"
	return definition.get("kind","")
static func food_category(id: String) -> String:
	if item(id).has("food_category"): return item(id).food_category
	var style: String=item(id).get("style","")
	return "soup" if style.ends_with("soup") else ("salad" if style.ends_with("salad") else "stew")
static func effect_summary(id: String) -> String:
	var definition:=item(id)
	return str(definition.get("effect_text",""))+(" · 1游戏天" if not definition.get("effect",{}).is_empty() else "")

static func starter_clothes() -> Array[String]:
	return Clothes.starters()

static func valley_resources() -> Array:
	if not _valley_resources.is_empty(): return _valley_resources
	var points: Dictionary={
		"branch":[Vector2(-29,27),Vector2(17,21),Vector2(-33,-17),Vector2(34,-19),Vector2(21,-37)],
		"birch":[Vector2(-38,13),Vector2(31,27),Vector2(-12,-19),Vector2(36,-12),Vector2(-29,-32)],
		"orange":[Vector2(-23,16),Vector2(19,12),Vector2(-29,-16),Vector2(33,-19),Vector2(-14,-34)],
		"copper":[Vector2(-39,-3),Vector2(32,6),Vector2(-37,-24),Vector2(12,-19)],
		"iron":[Vector2(-22,-37),Vector2(38,-26)],
		"limestone":[Vector2(-37,21),Vector2(37,14),Vector2(-20,-17),Vector2(28,-35)],
		"sandstone":[Vector2(-37,-28),Vector2(31,-32)]}
	var rng:=RandomNumberGenerator.new();rng.seed=823165
	for type_ in points:
		for i in range(points[type_].size()):
			var point: Vector2=(points[type_][i]+Vector2(rng.randf_range(-.25,.25),rng.randf_range(-.25,.25)))*2.
			# Stable resource IDs survive the redesign; move their approach onto a gentle slope.
			if Valley.normal_at(point.x,point.y).y<.88:
				var origin:=point;var found:=false
				for ring in range(1,21):
					for sample in range(24):
						var candidate:=origin+Vector2(cos(sample*TAU/24),sin(sample*TAU/24))*ring*.75
						if not Valley.can_walk(Vector3(candidate.x,0,candidate.y)) or Valley.normal_at(candidate.x,candidate.y).y<.88 or Valley.on_path(candidate.x,candidate.y):continue
						if candidate.distance_to(Vector2(Valley.HOUSE.x,Valley.HOUSE.z))<15:continue
						point=candidate;found=true;break
					if found:break
			_valley_resources.append({"id":"valley_%s_%d"%[type_,i],"item":type_,"x":point.x,"z":point.y,"y":Valley.height_at(point.x,point.y),"map":"valley"})
	return _valley_resources
static func icefield_resources() -> Array:
	if not _icefield_resources.is_empty():return _icefield_resources
	var layout=preload("res://scripts/icefield/icefield_layout.gd")
	var points: Dictionary={
		"branch":[Vector2(-147,8),Vector2(-145,46),Vector2(-105,91),Vector2(-31,74),Vector2(-36,-93),Vector2(23,98)],
		"birch":[Vector2(-146,-29),Vector2(-127,88),Vector2(-44,93),Vector2(-39,-47),Vector2(-141,-76),Vector2(-52,113)],
		"copper":[Vector2(-146,-59),Vector2(-76,-112),Vector2(37,-114),Vector2(117,-60),Vector2(133,36),Vector2(61,116)],
		"iron":[Vector2(-138,59),Vector2(-27,-124),Vector2(83,-99),Vector2(150,-18)],
		"limestone":[Vector2(-151,-2),Vector2(-118,99),Vector2(15,-126),Vector2(142,60),Vector2(95,96),Vector2(-18,105)],
		"sandstone":[Vector2(-137,-80),Vector2(-58,-117),Vector2(112,-84),Vector2(121,78)]}
	for type_ in points:
		for i in range(points[type_].size()):
			var p: Vector2=points[type_][i]
			var radial: float=layout.ellipse(p.x,p.y)
			if radial>.895:p*=.895/radial
			_icefield_resources.append({"id":"icefield_%s_%02d"%[type_,i],"item":type_,"x":p.x,"z":p.y,"y":layout.height_at(p.x,p.y),"map":"icefield"})
	return _icefield_resources
