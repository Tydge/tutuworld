extends RefCounted
## Sea-level scenery and shop attachments for the starting town.
const CROWN_MATERIAL := preload("res://scenes/coastal/foliage.tres")
const BOX := preload("res://scenes/coastal/wisteria_box.tscn")
const HOME := preload("res://assets/shaders/home_surface.gdshader")
const ROOF := preload("res://assets/shaders/town_roof.gdshader")
const TILES := preload("res://assets/terrain/coastal/barrel_tiles.png")
const PAVING := preload("res://assets/shaders/paving.gdshader")

static func dress(world: Node3D) -> ShaderMaterial:
	if world.has_node("HarborHorizon"):
		return world.get_node("TownHall/CivicClocktower/Stonework").material_override
	var headland := preload("res://scenes/coastal/harbor_horizon.tscn").instantiate()
	# This distant instance sits beyond the navigable coast. A placed tower has its own solid base.
	headland.get_node("LanternPoint/HarborLighthouse/Masonry").collision_layer = 0
	world.add_child(headland)
	var tower := preload("res://scenes/coastal/clocktower.tscn").instantiate()
	tower.position = Vector3(0, 6.95, .1)
	world.get_node("TownHall").add_child(tower)
	preload("res://scripts/city/plaza_fountain.gd").install(world.get_node("CentralPark"))
	var park := world.get_node("CentralPark")
	for p in [Vector3(0,3.50,-4),Vector3(0,3.50,-13),Vector3(-23.5,3.50,-16.7)]:
		var garland:=MeshInstance3D.new()
		garland.name="MarketBunting"
		garland.mesh=preload("res://scenes/coastal/pennants.res")
		garland.position=p
		if p.x<0.:garland.scale.x=11./9.2
		park.add_child(garland)
	var gardens:=preload("res://scripts/city/town_gardens.gd")
	for p in [Vector2(-11,3.4),Vector2(11,3.4),Vector2(-12,-3.6),Vector2(12,-3.6),Vector2(-11,8.4),Vector2(11,8.4),Vector2(-18,4),Vector2(12,20),Vector2(-20,-6)]:
		var pos:=Vector3(p.x,.03,p.y)
		if not gardens.off_pavement(world,pos,.68):continue
		var border:=MeshInstance3D.new()
		border.name="CottageBorder"
		border.mesh=preload("res://scenes/coastal/flowers.res")
		border.position=pos
		border.rotation.y=pos.x*.57
		border.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		park.add_child(border)
	for shop in ["Shop_farm","Shop_tools","Shop_clothes"]:
		dress_shop(world.get_node(shop))
	for tree in world.get_children():
		if str(tree.name).begins_with("Tree"):
			replace_crown(tree)
	for tree in world.find_children("PublicTree*", "Node3D", true, false):
		replace_crown(tree)
	return tower.get_node("Stonework").material_override

static func replace_crown(tree: Node3D) -> void:
	var crown: Node3D = tree.get_node("Crown")
	var bounds := AABB()
	var species: String = tree.get_meta("tree_species","")
	if species.is_empty():
		var fruit:=preload("res://scripts/city/scenery_polish.gd").priority(tree.position)>0
		preload("res://scripts/city/coastal/orchard_tree.gd").install(tree,fruit)
		return
	for part in tree.find_children("*","MeshInstance3D",true,false):
		var mat: Material = part.material_override
		if not (mat is ShaderMaterial and mat.shader == preload("res://assets/shaders/occlusion_fade.gdshader") and mat.get_shader_parameter("vertex_tint")):
			continue
		var box: AABB = (crown.global_transform.affine_inverse() * part.global_transform) * part.get_aabb()
		bounds = box if not bounds.has_volume() else bounds.merge(box)
		part.get_parent().remove_child(part)
		part.free()
	if not bounds.has_volume():
		return
	var greenery := MeshInstance3D.new()
	greenery.name = "LeafSprays"
	var prototype: ArrayMesh
	match species:
		"pine","coastal_pine": prototype = preload("res://scenes/coastal/pine.res")
		"birch": prototype = preload("res://scenes/coastal/birch.res")
		"oak": prototype = preload("res://scenes/coastal/oak.res")
		_: prototype = preload("res://scenes/coastal/oak.res")
	greenery.mesh = prototype
	greenery.material_override = prototype.surface_get_material(0)
	var authored := prototype.get_aabb()
	var size_: Vector3 = bounds.size / authored.size
	greenery.scale = size_
	greenery.position = bounds.get_center() - authored.get_center()*size_
	greenery.visibility_range_end = 145.
	greenery.visibility_range_end_margin = 12.
	crown.add_child(greenery)

static func dress_shop(shop: Node3D) -> void:
	var kind:=str(shop.get_meta("shop",str(shop.name).trim_prefix("Shop_")))
	for entry in [["awning","PorchCanopy",Vector3(0,3.38,4.06)],["shutters","Structure/Walls/south",Vector3(0,0,4.15)],["medallion","Structure/Roof",Vector3(0,4.96,4.26)]]:
		var owner_: Node3D=shop.get_node(entry[1])
		for section in shop.sections:
			if section.node!=owner_:continue
			var detail:=MeshInstance3D.new()
			detail.name=str(entry[0]).capitalize()
			detail.mesh=load("res://scenes/coastal/"+entry[0]+"_"+kind+".res")
			owner_.add_child(detail)
			detail.global_transform=shop.global_transform*Transform3D(Basis.IDENTITY,entry[2])
			var pigment:=ShaderMaterial.new()
			pigment.shader=HOME
			pigment.set_shader_parameter("vertex_tint",true)
			detail.material_override=pigment
			section.materials.append(pigment)
			section.visuals.append(detail)
			break
	var wall := shop.get_node("Structure/Walls/south")
	for section in shop.sections:
		if section.node != wall:
			continue
		for side in [-1.,1.]:
			var flowers: Node3D = BOX.instantiate()
			wall.add_child(flowers)
			flowers.global_transform = shop.global_transform * Transform3D(Basis.IDENTITY,Vector3(side*3.58,1.80,4.14))
			for mesh in flowers.find_children("*","MeshInstance3D",true,false):
				var mat := ShaderMaterial.new()
				if mesh.name == "Bracket":
					mat.shader = HOME
					mat.set_shader_parameter("vertex_tint",true)
				else:
					mat = CROWN_MATERIAL.duplicate()
				mat.set_shader_parameter("cut_base_height",shop.global_position.y+shop.floor_level+.62)
				mesh.material_override = mat
				section.materials.append(mat)
				section.visuals.append(mesh)
		break

static func set_tiles(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("coastal_tiles",true)
	mat.set_shader_parameter("barrel_tiles",TILES)

static func roof_module(module: Node3D) -> void:
	for mesh in module.find_children("*","MeshInstance3D",true,false):
		var mat: Material = mesh.material_override
		if mat is ShaderMaterial and mat.shader == HOME and mat.get_shader_parameter("pattern") == 2:
			var copy: ShaderMaterial = mat.duplicate()
			set_tiles(copy)
			mesh.material_override = copy

static func finish_interiors(interiors: Array[Node3D]) -> void:
	for building in interiors:
		for section in building.sections:
			if section.node != building.get_node("Structure/Roof"): continue
			for mat: ShaderMaterial in section.materials:
				if mat.get_shader_parameter("pattern") == 2: set_tiles(mat)

static func bind_streets(node: GeometryInstance3D, copies: Dictionary) -> void:
	var original: Material = node.material_override
	if original is StandardMaterial3D and original.albedo_color.to_html(false) in ["ab7852","d6ac73"]:
		if not copies.has(original):
			var wood := ShaderMaterial.new()
			wood.shader=preload("res://assets/shaders/harbor_timber.gdshader")
			wood.set_shader_parameter("timber",preload("res://assets/terrain/coastal/quay_oak.png"))
			wood.set_shader_parameter("tint",original.albedo_color)
			copies[original]=wood
		node.material_override=copies[original]
		return
	if not (original is ShaderMaterial and original.shader in [PAVING,ROOF]):
		return
	if not copies.has(original):
		var mat: ShaderMaterial = original.duplicate()
		if mat.shader == ROOF:
			set_tiles(mat)
		else:
			mat.set_shader_parameter("coastal_stone",true)
		copies[original] = mat
	node.material_override = copies[original]

static func update_landmarks(sun: DirectionalLight3D, sea: ShaderMaterial, dial: ShaderMaterial, t: float, day: float) -> void:
	# Street fixtures carry the nearby shadows at night; the moon covers the playable square.
	sun.directional_shadow_max_distance=lerpf(26.,48.,day)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		sun.light_angular_distance=.35*day
	dial.set_shader_parameter("night",1.-day)
	dial.set_shader_parameter("hands",Vector2(fposmod(t*2.,1.),fposmod(t*24.,1.))*TAU)
	if sea != null:
		sea.set_shader_parameter("sun_direction",sun.global_basis.z)
		sea.set_shader_parameter("solar_day",day)
