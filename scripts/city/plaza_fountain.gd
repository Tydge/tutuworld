extends RefCounted
## A reusable local-space fountain: all visuals, light and collision move together.
const G=preload("res://scripts/geometry.gd")
static func lathe(profile: Array[Vector2],segments: int=64) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		for i in range(segments):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var angle: float=(i+corner.x)*TAU/segments;var p: Vector2=profile[j+corner.y]
				st.set_uv(Vector2(float(i+corner.x)/segments,float(j+corner.y)/profile.size()));st.add_vertex(Vector3(cos(angle)*p.x,p.y,sin(angle)*p.x))
	st.generate_normals();return st.commit()
static func jet_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for jet in range(8):
		var a: float=jet*TAU/8+PI/8;var outward:=Vector3(cos(a),0,sin(a));var side:=Vector3(-sin(a),0,cos(a))
		for step in range(18):
			for edge in range(6):
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var t: float=(step+corner.y)/18.;var q: float=(edge+corner.x)*TAU/6
					var center:=outward*lerpf(.63,2.02,t)+Vector3.UP*(1.68+.90*t-2.10*t*t)
					st.set_uv(Vector2(float(edge+corner.x)/6,t));st.add_vertex(center+(side*cos(q)+Vector3.UP*sin(q))*lerpf(.026,.016,t))
	st.generate_normals();return st.commit()
static func build(parent: Node3D,point:=Vector3.ZERO,bake: bool=true) -> Node3D:
	var root:=Node3D.new();root.name="Fountain";root.position=point;parent.add_child(root)
	root.set_meta("buildable_reference",true);root.set_meta("module_id","plaza_fountain");root.set_meta("module_type","fountain")
	var stone:=G.mat("d0d0b8",.94);var cream:=G.mat("e2d9bb",.93);var tile:=G.mat("618f87",.43);var brass:=G.mat("b89a5e",.52)
	G.cylinder(root,Vector3(0,.10,0),3.15,.18,stone,-1,"Foundation")
	G.cylinder(root,Vector3(0,.22,0),3.02,.16,tile)
	G.mesh(root,lathe([Vector2(2.66,.27),Vector2(2.97,.27),Vector2(3.04,.35),Vector2(3.04,.51),Vector2(2.99,.62),Vector2(2.88,.68),Vector2(2.72,.67),Vector2(2.65,.58),Vector2(2.66,.27)]),Vector3.ZERO,cream,"SculptedPoolRim")
	for i in range(24):
		var a: float=i*TAU/24;var block:=G.box(root,Vector3(cos(a)*3.015,.43,sin(a)*3.015),Vector3(.15,.105,.035),tile,"MosaicInset");block.rotation.y=-a+PI/2
	G.mesh(root,lathe([Vector2(.48,.39),Vector2(.54,.47),Vector2(.42,.56),Vector2(.26,.69),Vector2(.22,1.14),Vector2(.35,1.25),Vector2(.48,1.29)]),Vector3.ZERO,stone,"CentralPedestal")
	G.mesh(root,lathe([Vector2(.05,1.26),Vector2(.43,1.29),Vector2(.78,1.38),Vector2(1.05,1.52),Vector2(1.12,1.63),Vector2(1.10,1.71),Vector2(1.02,1.73),Vector2(.91,1.59),Vector2(.61,1.47),Vector2(.05,1.43)]),Vector3.ZERO,tile,"PetalBowl")
	var rim:=TorusMesh.new();rim.inner_radius=1.025;rim.outer_radius=1.125;rim.rings=64;rim.ring_segments=8;G.mesh(root,rim,Vector3(0,1.71,0),cream,"BowlLip")
	G.cylinder(root,Vector3(0,1.82,0),.12,.55,brass,.075)
	for i in range(5):
		var a: float=i*TAU/5;var leaf:=G.ball(root,Vector3(cos(a)*.16,2.05,sin(a)*.16),Vector3(.12,.28,.065),tile,"LotusBud");leaf.rotation=Vector3(sin(a)*.45,0,-cos(a)*.45)
	G.ball(root,Vector3(0,2.23,0),Vector3(.095,.14,.095),cream)
	var water:=ShaderMaterial.new();water.shader=preload("res://assets/shaders/fountain_water.gdshader")
	var lower:=G.cylinder(root,Vector3(0,.48,0),2.65,.02,water,-1,"PoolWater");lower.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var upper:=G.cylinder(root,Vector3(0,1.61,0),.98,.012,water,-1,"BowlWater");upper.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var jets: ShaderMaterial=water.duplicate();jets.set_shader_parameter("jet",true)
	var flow:=G.mesh(root,jet_mesh(),Vector3.ZERO,jets,"EightWaterArcs");flow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body:=StaticBody3D.new();body.name="PoolCollision";body.collision_layer=5;body.collision_mask=0;body.position.y=.34;root.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=3.04;shape.height=.68;collision.shape=shape;body.add_child(collision)
	var light:=OmniLight3D.new();light.name="FountainGlow";light.position=Vector3(0,.95,0);light.light_color=Color("97d8cf");light.light_energy=0;light.omni_range=6;light.shadow_enabled=false;root.add_child(light)
	if bake:preload("res://scripts/city/home_builder.gd").new().bake_section(root)
	return root
