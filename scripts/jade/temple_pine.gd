extends RefCounted
## Old courtyard pines spread out over a succession of crooked lateral limbs.
const Forest=preload("res://scripts/valley/ancient_forest.gd")
const G=preload("res://scripts/geometry.gd")
static var pine: ArrayMesh
static func build() -> ArrayMesh:
	if pine:return pine
	var trunk:=SurfaceTool.new();trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var needles:=SurfaceTool.new();needles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine: Array=[Vector3.ZERO,Vector3(-.28,1.2,.01),Vector3(-.06,2.55,.1),Vector3(.71,3.98,.34),Vector3(.48,5.57,.36),Vector3(1.58,6.67,.39),Vector3(2.33,7.72,.05)]
	Forest.tube(trunk,spine,[.56,.46,.37,.31,.22,.16,.034],10)
	for i in range(14):
		var root: Vector3=spine[2+i%4];var angle:=i*2.4-.35
		var axis:=Vector3(cos(angle),0,sin(angle));var side:=Vector3(-axis.z,0,axis.x)
		var reach:=2.92+1.63*sin(i*.8)*sin(i*.8)
		if i%4>=2:reach*=.65
		var elbow:=root+axis*reach*.45+Vector3.DOWN*.33
		var tip:=root+axis*reach+Vector3.UP*(.56+.27*(i%3))+side*.30
		Forest.tube(trunk,[root,elbow,elbow.lerp(tip,.55)+Vector3.UP*.32,tip],[.157,.106,.065,.023],7)
		for j in range(6):
			var t:=.32+j*.129;var joint:=elbow.lerp(tip,t);var fork:=axis.rotated(Vector3.UP,(-1. if j%2 else 1.)*(.43+j*.1))
			Forest.tube(trunk,[joint,joint+fork*.62+Vector3.UP*.45,joint+fork*1.15+Vector3.UP*.38],[.052,.033,.012],5)
			for k in range(5):
				var heading:=fork.rotated(Vector3.UP,(k-2)*.51)
				var cross:=(Vector3(-heading.z,0,heading.x)+Vector3.UP*(.27 if k%2 else -.32)).normalized()
				var pos:=joint+fork*.89+Vector3.UP*.44
				for cell in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					needles.set_uv(Forest.atlas_uv(cell.x,cell.y,0))
					needles.set_color(Color.WHITE*(.73+.15*t+.03*k));needles.set_normal(Vector3.UP)
					needles.add_vertex(pos+heading*(cell.x-.16)*1.55+cross*(cell.y-.5)*1.29+Vector3.UP*.19*cell.x)
	var bark:=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/ancient_bark.gdshader");bark.set_shader_parameter("bark_texture",preload("res://assets/terrain/warm_tree_bark_v1.png"))
	bark.set_shader_parameter("follow_game_camera",true)
	bark.set_shader_parameter("use_instance_slope",false)
	bark.set_shader_parameter("bark_color",Color("6e6151"))
	var leaves:=ShaderMaterial.new();leaves.shader=preload("res://assets/shaders/ancient_foliage.gdshader");leaves.set_shader_parameter("foliage_atlas",preload("res://assets/terrain/woodland/foliage_atlas_v1.png"))
	leaves.set_shader_parameter("follow_game_camera",true)
	trunk.index();trunk.generate_normals();trunk.set_material(bark);pine=trunk.commit();needles.index();needles.set_material(leaves);needles.commit(pine);return pine
static func place(n: Node3D) -> void:
	var shape:=G.mesh(n,build(),Vector3.ZERO,null,"SweepingPine");shape.visibility_range_end=640.
	preload("res://scripts/city/prop_collisions.gd").cylinder(n,"PineTrunk",Vector3.UP*1.65,.47,3.3)
