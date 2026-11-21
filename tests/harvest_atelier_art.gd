extends SceneTree
const Animals = preload("res://scripts/characters/animal_factory.gd")
const Outfit = preload("res://scripts/city/outfit.gd")
const Atelier = preload("res://scripts/appearance/resident_atelier.gd")
const DB = preload("res://scripts/services/game_data.gd")
const Crop = preload("res://scripts/city/crop_visual.gd")
const G = preload("res://scripts/geometry.gd")
var stage := Node3D.new()
var camera := Camera3D.new()
var actors: Array[CharacterBody3D] = []
var output := preload("res://tests/test_support.gd").output_dir()
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frame(center: Vector3, offset: Vector3, height: float) -> void:
	camera.position = center + offset
	camera.look_at(center)
	camera.size = height

func photo(id: String) -> void:
	for i in 3:
		await process_frame
		RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+id+".png")

func run() -> void:
	root.size = Vector2i(1440, 840)
	root.msaa_3d = Viewport.MSAA_4X
	root.add_child(stage)
	stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("e8e3d5")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("fff2dc")
	world.environment.ambient_light_energy = .67
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	stage.add_child(sun)
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var floor_ := G.box(stage,Vector3(0,-.07,0),Vector3(40,.12,35),G.mat("c9c4ad"))
	for species in Animals.Catalog.ids():
		var actor := Animals.create(species)
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.position.x = (actors.size()-1)*2.18
		actors.append(actor)
	frame(Vector3(0,1.53,0),Vector3(0,.73,9),3.82)
	for k in Atelier.LOOKS.size():
		for actor in actors:
			Outfit.apply(actor,Atelier.LOOKS[k])
			var rig: Resource = actor.rig_profile
			for pair in [["Visual/Head/Wardrobe_head", rig.hat_offset],["Visual/Wardrobe_body",rig.body_center],["Visual/Wardrobe_neck",rig.neck_center]]:
				var mount := actor.get_node(str(pair[0])) as Node3D
				check(mount != null and mount.get_child_count()==1, str(rig.species_id)+"/"+str(pair[0]))
				if mount:
					var part := mount.get_child(0) as MeshInstance3D
					for surface in part.mesh.get_surface_count():
						check(part.get_surface_override_material(surface)!=null,"Missing material "+str(part.mesh.resource_name))
			for side in ["Left","Right"]:
				check(actor.has_node("Visual/"+side+"Arm/Wardrobe_body_sleeve"),"Sleeve follows "+side)
		for view in [0., .65, 1.59, 3.14]:
			for actor in actors:
				actor.visual.rotation.y = view
			await photo("fit-%d-%03d"%[k,roundi(rad_to_deg(view))])
		for action in ["harvest_tree","eat","nap"]:
			for actor in actors:
				actor.visual.rotation.y = .5
				actor.play_action(action,2.)
				for i in 32: actor.animate_pose(1./60.)
			await photo("fit-%d-%s"%[k,action])
		for actor in actors:
			actor.action = ""
			for i in 32: actor.animate_pose(1./60.)
			Outfit.apply(actor,{})
			check(actor.find_children("Wardrobe_*","",true,false).is_empty(),"Unequip clears the sleeves and all mounts")
	for combo in Atelier.LOOKS:
		for actor in actors:
			Outfit.apply(actor,{"neck":combo.neck})
			actor.visual.rotation.y = .18
		frame(Vector3(0,1.16,0),Vector3(0,.10,9),3.80)
		await photo("neck-"+str(combo.neck))
	for actor in actors: actor.free()
	floor_.material_override = G.mat("876544")
	var patches: Array[Node3D]=[]
	for crop in DB.catalog().crops:
		var plot := Crop.new()
		plot.position = Vector3((patches.size()-2)*1.82,.087,0)
		stage.add_child(plot)
		patches.append(plot)
		var previous: MultiMesh
		for phase in 5:
			var record := {"crop":crop,"growth":float(DB.crop(crop).days)*3600*phase/4.0}
			plot.refresh(record,{"ready":phase==4,"weed":false,"water":false})
			var mesh: MultiMesh = plot.plants.multimesh
			check(mesh!=previous and mesh.instance_count==4 and mesh.mesh.get_surface_count()==1,"One shared planting per stage "+crop)
			plot.refresh(record,{"ready":phase==4,"weed":true,"water":false})
			check(plot.plants.multimesh==mesh and plot.weeds.visible,"Weeding leaves standing crop geometry intact")
			previous=mesh
		plot.refresh({"crop":"","growth":0},{"water":false,"weed":false,"ready":false})
		check(not plot.visible,"Harvest clears plot")
		plot.refresh({"crop":crop,"growth":float(DB.crop(crop).days)*3600},{"ready":true,"weed":false,"water":false})
		plot.marker.hide()
	for view in range(patches.size()):
		frame(patches[view].position+Vector3(0,.23,0),Vector3(.42,1.2,2.2),1.44)
		await photo("crop-"+str(DB.catalog().crops.keys()[view]))
	var weed_plot: Node3D = patches[0]
	var crop_id: String = DB.catalog().crops.keys()[0]
	for phase in [1,3]:
		var data := {"crop":crop_id,"growth":float(DB.crop(crop_id).days)*3600*phase/4.}
		weed_plot.refresh(data,{"water":false,"weed":true,"ready":false})
		weed_plot.marker.hide()
		frame(weed_plot.position+Vector3(0,.11,0),Vector3(.15,1.50,2.3),1.58)
		await photo("weeds-stage-%d"%phase)
		weed_plot.refresh(data,{"water":false,"weed":false,"ready":false})
		check(not weed_plot.weeds.visible,"Weeding removes every wild plant")
	weed_plot.refresh({"crop":crop_id,"growth":float(DB.crop(crop_id).days)*3600},{"water":false,"weed":false,"ready":true})
	frame(Vector3(0,.30,0),Vector3(.4,2.6,5),5.5)
	await photo("ripe-field")
	print("HARVEST_ATELIER_ART_RESULT ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if failures.is_empty() else 1)
