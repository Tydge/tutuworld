extends RefCounted
## Material-only binding also works on reusable building and scenery modules.
const BARK=preload("res://assets/terrain/warm_tree_bark_v1.png")
const PLASTER=preload("res://assets/terrain/soft_lime_plaster_v1.png")
const SAND=preload("res://assets/terrain/fine_beach_sand_v1.png")
const MOUNTAIN=preload("res://assets/terrain/soft_moss_rock_v1.png")
const LAWN=preload("res://assets/terrain/spring_lawn_v1.png")
const RIDGE=preload("res://assets/shaders/forest_ridge.gdshader")
const HOME=preload("res://assets/shaders/home_surface.gdshader")
static var cache: Dictionary={}
static func plaster(color: Color) -> ShaderMaterial:
	var key:="plaster:"+color.to_html()
	if not cache.has(key):
		var m:=ShaderMaterial.new();m.shader=HOME;m.set_shader_parameter("tint",color);m.set_shader_parameter("plaster_texture",PLASTER);m.set_shader_parameter("plaster_strength",.65);m.set_meta("environment_kind","plaster");cache[key]=m
	return cache[key]
static func bark(color: Color) -> ShaderMaterial:
	var key:="bark:"+color.to_html()
	if not cache.has(key):
		var m:=ShaderMaterial.new();m.shader=preload("res://assets/shaders/tree_bark.gdshader");m.set_shader_parameter("bark_color",color);m.set_shader_parameter("bark_texture",BARK);m.set_meta("environment_kind","bark");cache[key]=m
	return cache[key]
static func apply(world: Node3D) -> void:
	var done: bool=world.get_meta("environment_material_revision",0)>=1
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var m: Material=node.material_override
		if m==null:continue
		var path:=str(world.get_path_to(node))
		if m is ShaderMaterial:
			if m.shader==HOME and "Structure/Walls/" in path:
				# Update in place: cutaway sections retain references to these materials.
				m.set_shader_parameter("plaster_texture",PLASTER);m.set_shader_parameter("plaster_strength",.65)
			elif m.shader==preload("res://assets/shaders/beach_sand.gdshader"):m.set_shader_parameter("sand_texture",SAND)
			elif m.shader==RIDGE:
				m.set_shader_parameter("rock_texture",MOUNTAIN);m.set_shader_parameter("turf_texture",LAWN)
			continue
		if done or not m is StandardMaterial3D:continue
		var hex: String=m.albedo_color.to_html(false)
		if path.begins_with("Tree") and hex in ["ad7c4d","b38a55","94714d","be925e"]:node.material_override=bark(m.albedo_color)
		elif hex in ["e5b66e","e0ad78","e9b4a6","e8c388","d4ddc0","e5d7ba","ddc6ab","d5d8bb","e4cfad"]:node.material_override=plaster(m.albedo_color)
	world.set_meta("environment_material_revision",1)
