extends Node
## One offscreen studio renders real catalog models into cached static thumbnails.
signal thumbnail_ready(id: String,texture: Texture2D)
signal draw_ready
var exiting:=false
const Catalog=preload("res://scripts/building/catalog.gd")
const Factory=preload("res://scripts/building/module_factory.gd")
var cache: Dictionary={}
var pending: Array[String]=[]
var variants: Dictionary={}
var busy:=false
var active_key:=""
var retries: Dictionary={}
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
func _ready() -> void:
	RenderingServer.frame_post_draw.connect(on_draw_completed)
	viewport=SubViewport.new();viewport.name="ThumbnailViewport";viewport.size=Vector2i(144,112);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
	stage=Node3D.new();stage.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;viewport.add_child(stage)
	var environment:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(0,0,0,0);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff1da");env.ambient_light_energy=.8;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=env;viewport.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.8;viewport.add_child(light)
	camera=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera);camera.current=true
func variant_key(row: Dictionary) -> String:
	var kind: String=row.get("kind","")
	if not row.get("painted",false) and row.get("appearance",{}).is_empty():return kind
	return kind+"@"+JSON.stringify([row.get("color",""),row.get("style","original"),row.get("painted",false),row.get("appearance",{})]).sha256_text()
func request_variant(row: Dictionary) -> void:
	var key:=variant_key(row)
	if key.contains("@"):variants[key]=row.duplicate(true)
	request(key)
func request(id: String) -> void:
	if cache.has(id):
		if valid_image(cache[id].get_image()):thumbnail_ready.emit(id,cache[id]);return
		cache.erase(id)
	if id==active_key:return
	if not pending.has(id):pending.append(id);retries[id]=0
	if not busy:render_next.call_deferred()
func render_next() -> void:
	if busy or pending.is_empty():return
	busy=true
	var key: String=pending.pop_front();active_key=key;var variant: Dictionary=variants.get(key,{});var id: String=variant.get("kind",key);var model:=Node3D.new();stage.add_child(model)
	var builder:=Factory.builder(model)
	var form:="classic"
	if id.contains(":"):
		var parts:=id.split(":");id=parts[0];form=parts[1]
	if id=="template":
		build_template_thumbnail(model,preload("res://scripts/building/templates.gd").player_sample(form))
	elif id=="stairs":preload("res://scripts/building/stairs.gd").build(builder,model,{"form":form if form in ["straight","l","u"] else "straight","color":"c6a373"})
	elif id=="railing":preload("res://scripts/building/stairs.gd").rail(builder,model,Vector3(-2,0,0),Vector3(2,0,0))
	elif Catalog.OBJECTS.has(id):builder.build_item(model,id)
	else:
		match id:
			"room":
				builder.blueprint.size=[4.,4.];builder.build_floor(model)
				for pair in [[[-2.,-2.],[2.,-2.]],[[2.,-2.],[2.,2.]]]:builder.build_wall(model,{"id":"RoomWall","a":pair[0],"b":pair[1],"openings":[]})
			"wall","door","window":
				var openings: Array=[]
				if id!="wall":openings=[{"id":"preview","type":id,"offset":2.5,"width":2.86 if id=="door" else 2.2,"height":3.5 if id=="door" else 2.,"bottom":0. if id=="door" else 1.1,"form":form}]
				var data:={"id":"wall","a":[-2.5,0],"b":[2.5,0],"openings":openings};builder.blueprint.walls=[data];builder.build_wall(model,data)
				if id=="door":model.set_script(preload("res://scripts/building/room_door.gd"));builder.build_door(model)
			"roof":builder.roof_form=form;builder.blueprint.size=[4.,3.];builder.build_roof(model)
			_:builder.blueprint.size=[4.,3.];builder.build_floor(model)
	if not variant.is_empty():Factory.paint(model,variant)
	var bounds:=AABB();var found:=false
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB=model.global_transform.affine_inverse()*mesh.global_transform*mesh.get_aabb()
		bounds=box if not found else bounds.merge(box);found=true
	var center:=bounds.get_center();var radius:=maxf(.4,bounds.size.length()*.5)
	camera.size=radius*2.1;camera.position=center+Vector3(1.2,.9,1.5).normalized()*radius*4.;camera.look_at(center);camera.force_update_transform();camera.reset_physics_interpolation()
	# Keep this model alive over two complete rendering frames. A frame_post_draw
	# arriving in the frame that scheduled the model can still contain the old/empty target.
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	var img: Image
	for attempt in range(4):
		await draw_ready
		if exiting or not is_inside_tree():return
		if attempt==0:continue
		img=viewport.get_texture().get_image()
		if valid_image(img):break
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if valid_image(img):
		cache[key]=ImageTexture.create_from_image(img);retries.erase(key);thumbnail_ready.emit(key,cache[key])
	else:
		retries[key]=int(retries.get(key,0))+1
		if retries[key]<3 and not pending.has(key):pending.append(key)
	stage.remove_child(model);model.free();busy=false;active_key=""

	if variants.size()>64:
		var oldest: String=variants.keys()[0];variants.erase(oldest);cache.erase(oldest)
	if not pending.is_empty():render_next.call_deferred()

func valid_image(img: Image) -> bool:
	if img==null or img.is_empty():return false
	var used:=img.get_used_rect()
	return used.size.x>2 and used.size.y>2 and used.get_area()>=64

func on_draw_completed() -> void:draw_ready.emit()
func _exit_tree() -> void:
	exiting=true;pending.clear()
	if RenderingServer.frame_post_draw.is_connected(on_draw_completed):RenderingServer.frame_post_draw.disconnect(on_draw_completed)
	# Resolve the owned wait while the studio/model still exist. Waiting directly
	# on RenderingServer kept coroutine resources alive after a map was removed.
	draw_ready.emit()

func build_template_thumbnail(model: Node3D,source: Dictionary) -> void:
	# Catalog silhouettes need only floors, walls/openings and roofs, not furniture or live lights.
	var origin:=preload("res://scripts/building/layout.gd").template_origin(source)
	for level in preload("res://scripts/building/storeys.gd").levels(source):
		var layer:=Node3D.new();model.add_child(layer);layer.position.y=level*4.7
		var builder:=Factory.builder(layer)
		for row in source.elements:
			if int(row.get("storey",0))!=level:continue
			if row.type=="wall":
				var data:=Factory.wall_data(source,row,origin)
				for opening in data.openings:opening.geometry_only=false
				builder.blueprint.materials.plaster=row.color;builder.build_wall(layer,data)
			elif row.type in ["floor","roof"]:
				var rect:=preload("res://scripts/building/layout.gd").rect(row);var center:=rect.get_center()-origin
				var part:=Node3D.new();layer.add_child(part);part.position=Vector3(center.x,0,center.y)
				if row.type=="floor":preload("res://scripts/geometry.gd").box(part,Vector3(0,.03,0),Vector3(rect.size.x,.3,rect.size.y),Factory.floor_material(row))
				else:
					builder.blueprint.size=[rect.size.x,rect.size.y];builder.blueprint.materials.roof=row.color;builder.roof_form=row.get("form","classic");builder.build_roof(part)
