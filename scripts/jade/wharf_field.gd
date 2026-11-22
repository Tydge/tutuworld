extends RefCounted
const G=preload("res://scripts/geometry.gd")
const A=preload("res://scripts/jade/architecture.gd")
const J=preload("res://scripts/jade/layout.gd")
static func steps(builder: SceneTree) -> void:
	var collision:=SurfaceTool.new();collision.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-158,-100):
		for v in [Vector2(-6,0),Vector2(6,0),Vector2(-6,1),Vector2(6,0),Vector2(6,1),Vector2(-6,1)]:
			var axis: float=z+v.y
			var lift:=.19*smoothstep(-158.,-155.,axis)*(1.-smoothstep(-105.,-100.,axis))
			collision.add_vertex(Vector3(v.x,J.height_at(v.x,axis)+lift,axis))
	var ramp:=StaticBody3D.new();ramp.name="ProcessionalRamp";ramp.collision_layer=8;ramp.collision_mask=0
	var shape:=CollisionShape3D.new();shape.shape=collision.commit().create_trimesh_shape();ramp.add_child(shape);builder.world.add_child(ramp)
static func wharf(builder: SceneTree,dock: Node3D) -> void:
	var plank:=StandardMaterial3D.new();plank.albedo_texture=preload("res://assets/terrain/coastal/quay_oak.png");plank.uv1_scale=Vector3(2.9,.39,1.)
	plank.roughness=.86
	for j in range(26):
		var z:=j*.49-6.1
		var tint:=plank.duplicate() as StandardMaterial3D;tint.albedo_color=Color("a89777").lerp(Color("c2b08b"),absf(sin(j*8.7))*.56)
		for k in range(2):
			var split:=.58*sin(j*4.);var x: float=(-1.75 if k==0 else 1.75)+split*.5
			G.box(dock,Vector3(x,-.12,z),Vector3(3.45+(split if k==0 else -split),.24,.484),tint)
		for side in [-1.,1.]:
			G.cylinder(dock,Vector3(side*3.07,.003,z),.036,.012,G.mat("4d463a"))
	for side in [-1.,1.]:
		for k in range(4):
			var z: float=-5.75+k*3.68
			var p:=Vector3(side*3.32,.42,z)
			G.cylinder(dock,p,.16,1.05,plank,.14)
			for j in range(3):
				var coil:=TorusMesh.new();coil.inner_radius=.147;coil.outer_radius=.181;coil.rings=12;coil.ring_segments=5;G.mesh(dock,coil,p+Vector3.UP*(.25+j*.055),G.mat("a6916d"))
			if k<3:
				for j in range(6):
					var t: float=j/6.;var f: float=(j+1)/6.
					A.beam(dock,p+Vector3(0,.29-.24*sin(t*PI),3.68*t),p+Vector3(0,.29-.24*sin(f*PI),3.68*f),.049,"a6916d")
	builder.fixture(builder.world,"jade_market_stall",J.point(-9,196),.58)
	builder.fixture(builder.world,"jade_goods",J.point(-12,194),-.5)
	builder.fixture(builder.world,"jade_lamp",J.point(5.05,196))
static func field(builder: SceneTree) -> void:
	var earth:=ShaderMaterial.new();earth.shader=preload("res://assets/shaders/farm_soil.gdshader");earth.set_shader_parameter("soil_color",Color("9b7857"));earth.set_shader_parameter("texture_mean",Vector3(.185,.064,.0215));earth.set_shader_parameter("soil_texture",preload("res://assets/terrain/cultivated_soil_v1.png"))
	var plough:=SurfaceTool.new();plough.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plot in J.farm():
		for j in range(6):
			for i in range(12):
				for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var u: float=(i+off.x)/12.;var v: float=(j+off.y)/6.
					var envelope:=pow(maxf(0.,sin(PI*u)*sin(PI*v)),.34)
					var height:=.025+envelope*(.097+.05*cos(u*TAU*3.))
					plough.add_vertex(Vector3(plot.x+(u-.5)*2.20,2.+height,plot.z+(v-.5)*2.44))
	plough.index();plough.generate_normals();G.mesh(builder.world,plough.commit(),Vector3.ZERO,earth,"Furrows")
	for i in range(11):
		for side in [-1,1]:
			if i in [3,4] and side==1:continue
			var p:=J.point(-177.3+i*2.2,121.65+side*6.1)
			G.cylinder(builder.world,p+Vector3.UP*.54,.054,1.08,G.mat("887347"),.037)
			if i<10 and (side==-1 or i not in [2,3,4]):
				for y in [.41,.76]:A.beam(builder.world,p+Vector3.UP*y,p+Vector3(2.20,y-.05,0),.049,"95835c")
	for k in range(5):builder.fixture(builder.world,"jade_bamboo",J.point(-182.6+1.5*k,113.-.62*k),k*.91)
	builder.fixture(builder.world,"jade_goods",J.point(-149.6,118),-.5)
	builder.fixture(builder.world,"jade_lamp",J.point(-147.6,123))
