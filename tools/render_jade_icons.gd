extends SceneTree
## Bake item cards from the same wardrobe, resource and furniture meshes used in play.
const DB=preload("res://scripts/services/game_data.gd")
const G=preload("res://scripts/geometry.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var ids: Array=[]
	for id in DB.Clothes.items():
		if DB.item(id).get("rank","") in ["folk","court","loom","palace"]:ids.append(id)
	ids.sort()
	ids.append_array(["cedar","silver_ore","nephrite","forged_axe","forged_pick","forged_hammer","cotton","ramie","cotton_cloth","ramie_cloth","jade_screen","jade_lamp","jade_basin","jade_chime","jade_parasol","jade_ceramics"])
	var sheet:=Image.create_empty(6*144,ceili(ids.size()/6.)*144,false,Image.FORMAT_RGBA8)
	var garments:=preload("res://scripts/ui/garment_thumbnails.gd").new();garments.species="bunny";root.add_child(garments)
	var view:=SubViewport.new();view.own_world_3d=true;view.size=Vector2i(192,192);view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("fff3dd");env.ambient_light_energy=.81;camera.environment=env;view.add_child(camera)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_energy=1.2;view.add_child(sun)
	for i in range(ids.size()):
		var id: String=ids[i];var photo: Image
		if DB.item(id).kind=="clothing":
			var tile:=TextureRect.new();garments.request(id,{},tile)
			for frame in range(16):
				await process_frame;RenderingServer.force_draw()
				if tile.texture!=null:break
			if tile.texture!=null:photo=tile.texture.get_image()
			tile.free()
		else:
			var subject:=model(id);view.add_child(subject)
			var bounds:=AABB();var first:=true
			for mesh: MeshInstance3D in subject.find_children("*","MeshInstance3D",true,false):
				if not mesh.is_visible_in_tree():continue
				var box:=mesh.global_transform*mesh.get_aabb();bounds=box if first else bounds.merge(box);first=false
			var center:=bounds.get_center()
			camera.position=center+Vector3(.64,.49,1.05).normalized()*9.;camera.look_at(center);camera.size=maxf(.2,bounds.size.length()*1.08);camera.current=true
			for frame in range(3):await process_frame;RenderingServer.force_draw()
			photo=view.get_texture().get_image();subject.free()
		if photo==null or not photo.get_used_rect().has_area():push_error("Empty icon "+id);quit(1);return
		photo=photo.get_region(photo.get_used_rect());photo.convert(Image.FORMAT_RGBA8)
		var scale_:=128./maxf(photo.get_width(),photo.get_height());photo.resize(maxi(1,roundi(scale_*photo.get_width())),maxi(1,roundi(scale_*photo.get_height())),Image.INTERPOLATE_LANCZOS)
		var coord:=Vector2i(i%6,i/6)*144+(Vector2i(144,144)-photo.get_size())/2;sheet.blit_rect(photo,Rect2i(Vector2i.ZERO,photo.get_size()),coord)
	var result:=sheet.save_png("res://assets/jade/item_portraits.png")
	var meta:=FileAccess.open("res://assets/jade/item_portraits.json",FileAccess.WRITE);meta.store_string(JSON.stringify(ids,"  ")+"\n");meta.close();print("JADE_ITEM_PORTRAITS ",ids.size()," result ",result);quit(result)
func model(id: String) -> Node3D:
	if id in ["cedar","silver_ore","nephrite"]:return preload("res://scripts/city/resource_visual.gd").make(id)
	if id.begins_with("forged_"):
		var row: Array={"forged_axe":["gather_wood","cedar"],"forged_pick":["gather_copper","silver_ore"],"forged_hammer":["gather_stone","nephrite"]}[id]
		return preload("res://scripts/city/tool_models.gd").make(row[0],"",row[1])
	var n:=Node3D.new()
	if id in ["cotton","ramie"]:
		var asset: Node3D=load("res://assets/harvest/"+id+".glb").instantiate()
		var mature:=asset.find_child("Phase4",true,false)
		for child in asset.get_children():
			if child!=mature and not child.is_ancestor_of(mature):child.hide()
		n.add_child(asset)
	elif id.ends_with("_cloth"):
		var fabric:=G.mat("dfd1ab" if id=="cotton_cloth" else "8d9879");var seam:=G.mat("8c846a")
		for j in range(3):
			G.box(n,Vector3(j*.03,j*.10,0),Vector3(1.15,.088,.66),fabric)
			for k in range(10):G.box(n,Vector3(-.50+k*.114,.039+j*.10,.23),Vector3(.067,.013,.016),seam)
	else:preload("res://scripts/building/furniture_builder.gd").new().build_item(n,id)
	return n
