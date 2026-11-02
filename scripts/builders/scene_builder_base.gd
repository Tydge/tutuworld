extends SceneTree
## Shared, side-effect-free helpers for explicit city and animal generation.
## This base has no automatic generation entry point and never writes bunny.tscn.
const G=preload("res://scripts/geometry.gd")
var rng:=RandomNumberGenerator.new()
var world: Node3D
var wood:=G.mat("ab7852")
var pale_wood:=G.mat("d6ac73")
var tree_index:=0

func own_children(n: Node, scene: Node) -> void:
	for c in n.get_children():
		c.owner = scene
		own_children(c, scene)

func save_scene(n: Node, path: String) -> void:
	own_children(n, n)
	var packed := PackedScene.new()
	var result := packed.pack(n)
	if result != OK: push_error("Cannot pack " + path)
	ResourceSaver.save(packed, path)
	n.free()

func group(parent: Node3D, name_: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	parent.add_child(n)
	return n

func build_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "Atmosphere"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("79b9d8")
	sky_mat.sky_horizon_color = Color("c9e3df")
	sky_mat.ground_bottom_color = Color("8ab3b1")
	sky_mat.ground_horizon_color = Color("c9e3df")
	sky_mat.sun_angle_max = 8.0
	sky.sky_material = sky_mat
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b8d2de")
	settings.ambient_light_energy = 0.48
	settings.tonemap_mode = Environment.TONE_MAPPER_ACES
	settings.tonemap_exposure = 0.82
	settings.fog_enabled = true
	settings.fog_light_color = Color("b9d6df")
	settings.fog_density = 0.002
	settings.fog_sky_affect = 0.15
	settings.glow_enabled = false
	settings.glow_intensity = 0.25
	env.environment = settings
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe3ba")
	sun.light_energy = 0.34
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75
	sun.shadow_bias = 0.04
	world.add_child(sun)

func flower(parent: Node3D, pos: Vector3, material: Material, size: float = .13) -> void:
	for i in range(5):
		var a := i*TAU/5
		G.ball(parent,pos+Vector3(cos(a)*size*.6,.01,sin(a)*size*.6),Vector3(size*.65,.05,size*.65),material,"Petal")
	G.ball(parent,pos+Vector3(0,.055,0),Vector3.ONE*size*.35,G.mat("f3d17a"),"Pollen")
