extends RefCounted
## One movable module: shared opaque meshes, soil and collision in local space.
const G=preload("res://scripts/geometry.gd")
const Blooms=preload("res://scripts/city/meadow_blossoms.gd")
static var border_mesh: ArrayMesh
static var flowers_mesh: ArrayMesh
static var soil_mesh: CylinderMesh
static var border_material: StandardMaterial3D
static var flowers_material: ShaderMaterial
static var soil_material: ShaderMaterial

static func quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	for point in [a,b,c,a,c,d]:
		st.set_color(color);st.add_vertex(point)
static func stone_band(st: SurfaceTool,inner: float,outer: float,bottom: float,top: float,offset: float,rng: RandomNumberGenerator) -> void:
	# Beveled individual blocks, with narrow recessed joints and staggered courses.
	var profile: Array[Vector2]=[Vector2(inner+.025,bottom),Vector2(outer-.025,bottom),Vector2(outer,bottom+.025),Vector2(outer,top-.025),Vector2(outer-.025,top),Vector2(inner+.025,top),Vector2(inner,top-.025),Vector2(inner,bottom+.025)]
	for block in range(24):
		var a: float=(block+offset)*TAU/24+.005
		var b: float=(block+1+offset)*TAU/24-.005
		var tint:=Color("a4aaa1").lerp(Color("c1c2b0"),rng.randf())
		for side in range(profile.size()):
			var p: Vector2=profile[side];var q: Vector2=profile[(side+1)%profile.size()]
			quad(st,Vector3(cos(a)*p.x,p.y,sin(a)*p.x),Vector3(cos(b)*p.x,p.y,sin(b)*p.x),Vector3(cos(b)*q.x,q.y,sin(b)*q.x),Vector3(cos(a)*q.x,q.y,sin(a)*q.x),tint)
		for angle in [a,b]:
			for j in range(1,profile.size()-1):
				for index in ([0,j+1,j] if angle==a else [0,j,j+1]):
					var p: Vector2=profile[index];st.set_color(tint.darkened(.12));st.add_vertex(Vector3(cos(angle)*p.x,p.y,sin(angle)*p.x))
static func leaf(st: SurfaceTool,origin: Vector3,angle: float,length_: float,width_: float,color: Color) -> void:
	var out:=Vector3(cos(angle),.35,sin(angle)).normalized();var side:=Vector3(-sin(angle),0,cos(angle))
	for i in range(5):
		var u: float=i/5.;var v: float=(i+1)/5.
		var p:=origin+out*length_*u+Vector3.UP*sin(u*PI)*.06
		var q:=origin+out*length_*v+Vector3.UP*sin(v*PI)*.06
		for sign_ in [-1,1]:
			quad(st,p,p+side*sign_*sin(u*PI)*width_-Vector3.UP*.015,q+side*sign_*sin(v*PI)*width_-Vector3.UP*.015,q,color.lightened(.045) if sign_==1 else color)
static func prepare() -> void:
	if border_mesh!=null:return
	var rng:=RandomNumberGenerator.new();rng.seed=823307
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	stone_band(st,1.34,1.59,.025,.23,0.,rng)
	stone_band(st,1.34,1.57,.23,.39,.5,rng)
	stone_band(st,1.29,1.62,.39,.48,0.,rng)
	st.generate_normals();border_mesh=st.commit()
	border_material=G.mat("ffffff").duplicate();border_material.vertex_color_use_as_albedo=true;border_material.vertex_color_is_srgb=true;border_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	soil_mesh=CylinderMesh.new();soil_mesh.bottom_radius=1.34;soil_mesh.top_radius=1.34;soil_mesh.height=.05;soil_mesh.radial_segments=48
	soil_material=ShaderMaterial.new();soil_material.shader=preload("res://assets/shaders/farm_soil.gdshader")
	soil_material.set_shader_parameter("soil_color",Color("694b35"));soil_material.set_shader_parameter("soil_texture",preload("res://assets/terrain/cultivated_soil_v1.png"));soil_material.set_shader_parameter("texture_mean",Vector3(.185,.064,.0215));soil_material.set_shader_parameter("detail_strength",.48)
	st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	# A dense green underplanting hides neither the soil nor the stone cap.
	for i in range(64):
		var a: float=i*2.39996;var r: float=sqrt((i+.5)/64.)*1.14
		var origin:=Vector3(cos(a)*r,.415+rng.randf_range(0,.05),sin(a)*r)
		for j in range(4):leaf(st,origin,a+j*TAU/4,rng.randf_range(.16,.29),.055,Color("56824a").lerp(Color("83a65b"),rng.randf()))
	var colors: Array[Color]=[Color("f2b7ad"),Color("f5d493"),Color("fff1cd"),Color("cebad7")]
	for i in range(39):
		var a: float=i*2.39996;var r: float=sqrt((i+.5)/39.)*1.12
		var point:=Vector3(cos(a)*r,.42,sin(a)*r)
		var scale_: float=rng.randf_range(.65,1.0)+(1.-r)*.35
		Blooms.bloom(st,point,colors[(i/6)%colors.size()],rng,scale_)
	st.generate_normals();flowers_mesh=st.commit()
	flowers_material=ShaderMaterial.new();flowers_material.shader=preload("res://assets/shaders/forest_blossoms.gdshader")
static func build(parent: Node3D,point: Vector3,index: int) -> Node3D:
	prepare()
	var node:=Node3D.new();node.name="PlazaFlowerbed%d"%index;node.position=point;node.rotation.y=index*1.37;parent.add_child(node)
	node.set_meta("buildable_reference",true);node.set_meta("module_type","flowerbed");node.set_meta("module_id","plaza_flowerbed_%d"%index)
	G.mesh(node,border_mesh,Vector3.ZERO,border_material,"BeveledStoneBorder")
	G.mesh(node,soil_mesh,Vector3(0,.402,0),soil_material,"PlantingSoil")
	var flowers:=G.mesh(node,flowers_mesh,Vector3.ZERO,flowers_material,"MixedFlowersAndLeaves")
	flowers.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preload("res://scripts/city/prop_collisions.gd").cylinder(node,"FlowerbedCollision",Vector3(0,.25,0),1.60,.50)
	return node
