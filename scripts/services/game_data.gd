extends RefCounted
static var _catalog: Dictionary = {}
static var _plots: Array = []
static var _resources: Array = []
static var _valley_resources: Array=[]
const Valley=preload("res://scripts/valley/valley_layout.gd")
static func catalog() -> Dictionary:
	if _catalog.is_empty():
		_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		var colors := {"rose":["莓果红","c8767a"],"sage":["鼠尾草绿","629184"],"honey":["蜂蜜黄","dfb660"]}
		for type_ in ["bow","beret","overalls","vest"]:
			for color in colors:
				var names := {"bow":"蝴蝶结","beret":"贝雷帽","overalls":"背带裤","vest":"马甲"}
				_catalog.items[type_+"_"+color] = {"name":colors[color][0]+names[type_],"kind":"clothing","slot":"head" if type_ in ["bow","beret"] else "body","style":type_,"color":colors[color][1],"price":65 if type_ in ["overalls","vest"] else 40,"sell":0,"shop":"clothes","description":"头部装饰，同位置只能佩戴一件。" if type_ in ["bow","beret"] else "身体装饰，同位置只能穿着一件。"}
		var neck_colors := {"red":["莓红","be5864","ffe7c8"],"blue":["海蓝","527fa7","d5e7e7"],"green":["森林绿","4c8973","f5db99"]}
		for color in neck_colors:
			var dye: Array=neck_colors[color]
			_catalog.items["scarf_"+color]={"name":dye[0]+"格纹围巾","kind":"clothing","slot":"neck","style":"scarf","color":dye[1],"accent":dye[2],"price":55,"sell":0,"shop":"clothes","description":"柔软的格纹围巾。脖子装饰，同位置只佩戴一件。"}
			_catalog.items["bell_"+color]={"name":dye[0]+"带金铃铛","kind":"clothing","slot":"neck","style":"bell","color":dye[1],"price":60,"sell":0,"shop":"clothes","description":"彩色颈带搭配金黄色铃铛。脖子装饰，同位置只佩戴一件。"}
		for id in _catalog.items:
			var item_: Dictionary=_catalog.items[id]
			if item_.kind=="clothing": item_["pattern"]="tartan" if item_.style=="scarf" else "solid"
		for color in colors:
			var dye: Array=colors[color]
			_catalog.items["bow_plaid_"+color]={"name":dye[0]+"格纹蝴蝶结","kind":"clothing","slot":"head","style":"bow","pattern":"tartan","pattern_scale":7.0,"color":dye[1],"accent":"f4e4bf","price":58,"sell":0,"shop":"clothes","description":"带着细格纹的柔软蝴蝶结，轻轻系在耳边。"}
			_catalog.items["beret_plaid_"+color]={"name":dye[0]+"格纹贝雷帽","kind":"clothing","slot":"head","style":"beret","pattern":"tartan","pattern_scale":9.0,"color":dye[1],"accent":"f4e4bf","price":58,"sell":0,"shop":"clothes","description":"柔软的暖格纹贝雷帽。"}
			_catalog.items["apron_"+color]={"name":dye[0]+"花叶围裙","kind":"clothing","slot":"body","style":"apron","pattern":"sprig","color":dye[1],"accent":"f8e7c4","price":72,"sell":0,"shop":"clothes","description":"口袋里装一点花香。"}
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
static func all_resources() -> Array: return resources("city")+resources("valley")
static func resource(id: String) -> Dictionary:
	for source in all_resources():
		if source.id==id: return source
	return {}
static func refresh_delay(id: String,generation: int) -> float:
	var random:=RandomNumberGenerator.new();random.seed=(id+":"+str(generation)).hash()
	return random.randf_range(3600,7200)

static func shops() -> Dictionary:
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
	var out: Array[String]=[]
	for style in ["bow","scarf","vest"]:
		for id in catalog().items:
			var definition:=item(id)
			if definition.get("style","")==style and (style!="bow" or definition.get("pattern","solid")=="solid"): out.append(id)
	return out

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
			var point: Vector2=points[type_][i]+Vector2(rng.randf_range(-.25,.25),rng.randf_range(-.25,.25))
			_valley_resources.append({"id":"valley_%s_%d"%[type_,i],"item":type_,"x":point.x,"z":point.y,"y":Valley.height_at(point.x,point.y),"map":"valley"})
	return _valley_resources
