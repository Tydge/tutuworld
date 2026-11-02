extends RefCounted
const Catalog=preload("res://scripts/characters/animal_catalog.gd")
const SCENES=Catalog.SCENES
static var lit_white: StandardMaterial3D
static func create(species_id: String="bunny") -> CharacterBody3D:
	var scene: PackedScene=load(SCENES.get(species_id,SCENES.bunny))
	var animal: CharacterBody3D=scene.instantiate()
	var head_collision:=CollisionShape3D.new()
	head_collision.name="HeadCollision"
	var sphere:=SphereShape3D.new()
	sphere.radius=maxf(animal.rig_profile.head_collision_radius,animal.rig_profile.head_radii.x+.015)
	head_collision.shape=sphere
	head_collision.position=animal.rig_profile.head_center
	animal.add_child(head_collision)
	animal.collision_layer=2
	animal.collision_mask=15
	animal.floor_constant_speed=true
	# Feet, rather than a raised capsule bottom, meet the walkable surface.
	for child in animal.get_children():
		if child is CollisionShape3D and child!=head_collision: child.position.y-=.015
	# Outline shells are a screen contour, not a second physical shadow caster.
	for part in animal.find_children("InkOutline","MeshInstance3D",true,false):
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Approved geometry is untouched; skin now receives real sun / room light.
	if species_id=="bunny":
		if lit_white==null:
			lit_white=StandardMaterial3D.new()
			lit_white.albedo_color=Color("f9f8f3")
			lit_white.roughness=.94
			lit_white.metallic_specular=.18
		for part in animal.find_children("*","MeshInstance3D",true,false):
			if part.material_override is ShaderMaterial and part.material_override.shader.code.contains("smoothstep(-0.65,0.85"):
				part.material_override=lit_white
	return animal
