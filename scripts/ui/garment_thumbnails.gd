extends SubViewport
## Photograph the owned garment on its species rig, including separate sleeves and trims.
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const DB=preload("res://scripts/services/game_data.gd")
static var cache: Dictionary={}
var species: String
var actor: CharacterBody3D
var camera: Camera3D
var pending: Dictionary={}
var active: Dictionary={}
var draws:=0

func _ready() -> void:
	size=Vector2i(144,144)
	own_world_3d=true
	transparent_bg=true
	msaa_3d=Viewport.MSAA_4X
	render_target_update_mode=SubViewport.UPDATE_DISABLED
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color.WHITE
	env.ambient_light_energy=.70
	camera=Camera3D.new()
	# A catalog photo jumps between items with very different bounds.
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.environment=env
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current=true
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-42,-28,0)
	light.light_energy=1.05
	add_child(light)
	actor=Animals.create(species)
	actor.collision_layer=0
	actor.collision_mask=0
	actor.process_mode=Node.PROCESS_MODE_DISABLED
	actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(actor)
	# Leave bones and anchors in place, including anchors parented to a mesh.
	for part in actor.find_children("*","VisualInstance3D",true,false):part.layers=0
	RenderingServer.frame_post_draw.connect(capture)
	set_process(false)

func request(id: String,design: Dictionary,tile: TextureRect) -> void:
	var key:=JSON.stringify([species,id,design.get("color",""),design.get("accent",""),design.get("pattern","")])
	tile.set_meta("portrait_key",key)
	if cache.has(key):
		tile.texture=cache[key]
		pending.erase(id)
		return
	pending[id]={"id":id,"key":key,"design":design.duplicate(),"tile":tile}
	set_process(true)

func _process(_delta: float) -> void:
	if not active.is_empty():return
	if pending.is_empty():
		set_process(false)
		return
	var id: String=pending.keys()[0]
	active=pending[id]
	pending.erase(id)
	var slot: String=DB.item(id).slot
	Outfit.apply(actor,{slot:id},{id:active.design})
	var bounds:=AABB()
	var first:=true
	for part in actor.find_children("*","MeshInstance3D",true,false):
		if part.layers==0:continue
		var box: AABB=part.global_transform*part.get_aabb()
		bounds=box if first else bounds.merge(box)
		first=false
	var center:=bounds.get_center()
	camera.position=center+Vector3(.20,.32,1.).normalized()*3.
	camera.look_at(center)
	camera.size=maxf(.12,bounds.size.length()*1.05)
	draws=0
	render_target_update_mode=SubViewport.UPDATE_ALWAYS

func capture() -> void:
	if active.is_empty():return
	draws+=1
	if draws<2:return
	var photo:=get_texture().get_image()
	var used:=photo.get_used_rect()
	if not used.has_area() and draws<4:return
	render_target_update_mode=SubViewport.UPDATE_DISABLED
	if used.has_area():
		photo=photo.get_region(used)
		photo.generate_mipmaps()
		var portrait:=ImageTexture.create_from_image(photo)
		if cache.size()>=96:cache.erase(cache.keys()[0])
		cache[active.key]=portrait
		var tile: TextureRect=active.tile
		if is_instance_valid(tile) and tile.get_meta("portrait_key")==active.key:tile.texture=portrait
	active.clear()

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(capture):RenderingServer.frame_post_draw.disconnect(capture)
	pending.clear()
	active.clear()
