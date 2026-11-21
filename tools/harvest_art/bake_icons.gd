extends SceneTree
## python3 tools/harvest_art/produce.py .qa-artifacts/produce.glb first.
const DB = preload("res://scripts/services/game_data.gd")
const Outfit = preload("res://scripts/city/outfit.gd")
const Animals = preload("res://scripts/characters/animal_factory.gd")
var studio := SubViewport.new()
var stage := Node3D.new()
var camera := Camera3D.new()
var destination := ProjectSettings.globalize_path("res://assets/ui/atelier")

func _initialize() -> void: call_deferred("run")

func photograph(id: String, model: Node3D, angle: Vector3, roll: float = 0.0) -> void:
	var bounds := AABB()
	var first := true
	for part in model.find_children("*","MeshInstance3D",true,false):
		var box: AABB = part.global_transform * part.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	camera.position = center + angle.normalized()*4.
	camera.look_at(center)
	camera.rotate_object_local(Vector3.FORWARD,roll)
	camera.size = bounds.size.length()*1.08
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := studio.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var rect := image.get_used_rect()
	var crop := image.get_region(rect)
	var size_ := Vector2(crop.get_size())
	size_ *= 116./maxf(size_.x,size_.y)
	crop.resize(maxi(1,roundi(size_.x)),maxi(1,roundi(size_.y)),Image.INTERPOLATE_LANCZOS)
	var icon := Image.create_empty(128,128,false,Image.FORMAT_RGBA8)
	icon.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),(Vector2i(128,128)-crop.get_size())/2)
	icon.save_png(destination+"/"+id+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	studio.size = Vector2i(520,520)
	studio.own_world_3d = true
	studio.transparent_bg = true
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	studio.msaa_3d = Viewport.MSAA_4X
	root.add_child(studio)
	studio.add_child(stage)
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("f5eddf")
	world.environment.ambient_light_energy = .73
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-26,0)
	sun.light_energy = 1.16
	stage.add_child(sun)
	var mannequin := Animals.create("cat_teacher")
	stage.add_child(mannequin)
	mannequin.hide()
	mannequin.set_physics_process(false)
	for id in DB.catalog().items:
		var item := DB.item(id)
		if item.get("collection","")!="atelier": continue
		Outfit.apply(mannequin,{item.slot:id})
		var isolated := Node3D.new()
		stage.add_child(isolated)
		for mount in mannequin.find_children("Wardrobe_*","Node3D",true,false):
			var parts := mount.find_children("*","MeshInstance3D",true,false)
			if mount is MeshInstance3D: parts.append(mount)
			for part in parts:
				var copy := part.duplicate() as MeshInstance3D
				copy.set_script(null)
				if item.style=="silk_bowtie":
					# Photograph just the butterfly and wrap, as on a tailor’s sample card.
					var butterfly := ArrayMesh.new()
					for surface in part.mesh.get_surface_count():
						if part.mesh.surface_get_material(surface).resource_name=="Ribbon": continue
						butterfly.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.mesh.surface_get_arrays(surface))
						butterfly.surface_set_material(butterfly.get_surface_count()-1,part.get_active_material(surface))
					copy.mesh = butterfly
					for surface in butterfly.get_surface_count(): copy.set_surface_override_material(surface,null)
				isolated.add_child(copy)
				copy.transform = part.global_transform
		var angle := Vector3(.38,.25,1)
		if item.slot=="head": angle=Vector3(-.34,.47,1)
		if item.style=="gold_chain": angle=Vector3(.10,1.05,1)
		if item.style=="silk_bowtie": angle=Vector3(.02,.05,1)
		await photograph(item.style,isolated,angle)
		isolated.free()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("res://.qa-artifacts/produce.glb",state)
	if error!=OK: quit(1); return
	var produce := document.generate_scene(state)
	stage.add_child(produce)
	var bodies := produce.find_children("*","MeshInstance3D",true,false)
	for part in bodies:
		part.material_override = preload("res://assets/harvest/pigment.tres")
		part.hide()
	for part in bodies:
		var holder := Node3D.new()
		stage.add_child(holder)
		part.reparent(holder)
		part.show()
		await photograph(str(part.name),holder,Vector3(.36,.76,1),.56 if part.name=="carrot" else .12)
		holder.free()
	quit()
