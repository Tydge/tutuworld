extends SubViewportContainer
const Animals=preload("res://scripts/characters/animal_factory.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const G=preload("res://scripts/geometry.gd")
var preview_size:=Vector2i(300,410)
var actor: CharacterBody3D
var species:="bunny"
var equipment: Dictionary={}
var viewport: SubViewport
var stage: Node3D
var cached_actors: Dictionary={}
var cached_equipment: Dictionary={}
var head_only:=false
var display_size:=Vector2.ZERO
var portrait_camera: Camera3D
func _ready() -> void:
	custom_minimum_size=display_size if display_size!=Vector2.ZERO else Vector2(preview_size)
	stretch=true
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	viewport=SubViewport.new()
	viewport.size=preview_size
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	stage=Node3D.new()
	if head_only: stage.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	viewport.add_child(stage)
	var environment:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("f2efd9",0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("d9dfcf")
	env.ambient_light_energy=.62
	environment.environment=env
	stage.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=1.15
	sun.shadow_enabled=true
	stage.add_child(sun)
	if not head_only: G.cylinder(stage,Vector3(0,-.045,0),.91,.09,G.mat("dae3c9"))
	update_character(species,equipment)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.55
	camera.position=Vector3(1.4,1.85,6)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.48,0))
	camera.current=true
	portrait_camera=camera
	if head_only: configure_head()
func configure_head() -> void:
	if not head_only or not is_instance_valid(actor): return
	for child in actor.visual.get_children(): child.visible=child==actor.head
	actor.visual.rotation.y=.26
	actor.set_physics_process(false)
	if is_instance_valid(portrait_camera):
		var center: Vector3=actor.rig_profile.head_center+Vector3(0,actor.rig_profile.portrait_center_offset,0)
		portrait_camera.size=actor.rig_profile.portrait_size
		portrait_camera.position=center+Vector3(0,0,6);portrait_camera.look_at(center)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
func _gui_input(event: InputEvent) -> void:
	if not head_only and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_instance_valid(actor):
		actor.visual.rotation.y+=event.relative.x*.012
		accept_event()

func update_equipment(worn: Dictionary) -> void:
	update_character(species,worn)
func update_character(species_id: String,worn: Dictionary) -> void:
	species=species_id
	equipment=worn.duplicate()
	if not is_instance_valid(stage): return
	if is_instance_valid(actor):
		actor.hide()
		actor.process_mode=Node.PROCESS_MODE_DISABLED
	if not cached_actors.has(species):
		var animal:=Animals.create(species)
		animal.collision_layer=0
		animal.collision_mask=0
		stage.add_child(animal)
		animal.visual.rotation.y=.18
		cached_actors[species]=animal
	actor=cached_actors[species]
	actor.process_mode=Node.PROCESS_MODE_INHERIT
	actor.show()
	if not cached_equipment.has(species) or cached_equipment[species]!=worn:
		Outfit.apply(actor,worn)
		cached_equipment[species]=worn.duplicate()
	if head_only: configure_head()

func warm_models() -> void:
	var previous_species:=species
	var previous_equipment:=equipment.duplicate()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for kind in Animals.Catalog.ids():
		update_character(kind,{"head":"bow_rose","neck":"scarf_red","body":"vest_rose"})
		for frame in range(2):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
	update_character(previous_species,previous_equipment)
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
