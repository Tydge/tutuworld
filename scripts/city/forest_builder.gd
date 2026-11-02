extends RefCounted
const G=preload("res://scripts/geometry.gd")
var world: Node3D
var rng:=RandomNumberGenerator.new()
var tree_index:=0
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func tree(pos: Vector3,height: float,color: String="64a85d",fruit_tree: bool=false) -> Node3D:
	var t:=group(world,"Tree%02d"%tree_index,pos)
	tree_index+=1
	var archetype:=rng.randi_range(0,4)
	if fruit_tree: archetype=3
	height*=rng.randf_range(.88,1.12)
	var trunk_height:=height*rng.randf_range(.48,.60)
	var trunk_radius:=rng.randf_range(.25,.38)
	var bark:=G.mat(["ad7c4d","b38a55","94714d","be925e"][rng.randi_range(0,3)])
	var lean:=Vector3(rng.randf_range(-.15,.15),0,rng.randf_range(-.15,.15))
	G.capsule(t,Vector3(0,.08,0),Vector3(lean.x,trunk_height,lean.z),trunk_radius,bark,"Trunk")
	G.solid_cylinder(t,Vector3(0,trunk_height*.5,0),trunk_radius,trunk_height)
	for i in range(rng.randi_range(3,5)):
		var a:=rng.randf()*TAU
		G.capsule(t,Vector3(cos(a)*rng.randf_range(.4,.7),.06,sin(a)*.55),Vector3(0,.55,0),trunk_radius*.42,bark)
	var crown:=group(t,"Crown",Vector3(lean.x,height*.74,lean.z))
	var foliage:=ShaderMaterial.new()
	foliage.shader=load("res://assets/shaders/occlusion_fade.gdshader")
	foliage.set_shader_parameter("vertex_tint",true)
	var leaf_color:=Color(color).lerp(Color(["3d8057","76a553","5a9950","83ad5a"][rng.randi_range(0,3)]),.35)
	var seed_:=rng.randf()*100
	if archetype==4:
		crown.position.y=height*.46
		for tier in range(4):
			var u:=float(tier)/3
			var bough:=G.mesh(crown,canopy_mesh(seed_+tier,leaf_color,true),Vector3(rng.randf_range(-.08,.08),u*height*.40,0),foliage,"EvergreenCrown")
			bough.scale=Vector3(lerpf(height*.31,.35,u),height*.27,lerpf(height*.31,.35,u))
	else:
		var width:=height*rng.randf_range(.29,.35)*(1.10 if archetype==0 else .95)
		var tall:=height*(.34 if archetype==2 else rng.randf_range(.25,.30))
		var body:=G.mesh(crown,canopy_mesh(seed_,leaf_color),Vector3.ZERO,foliage,"SoftCrown")
		body.scale=Vector3(width,tall,width*rng.randf_range(.88,1.06))
		body.rotation.y=rng.randf()*TAU
		for i in range(3):
			var a:=i*TAU/3+seed_
			G.capsule(t,Vector3(0,trunk_height*.88,0),crown.position+Vector3(cos(a)*width*.25,-tall*.05,sin(a)*width*.25),.10,bark,"Branch")
		t.set_meta("fruit_crown_size",Vector2(width,tall))
	return t

func canopy_mesh(seed_: float, color: Color, evergreen: bool=false) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=20
	var segments:=36
	for ring in range(rings+1):
		var v:=float(ring)/rings
		var theta:=v*PI
		for segment in range(segments+1):
			var phi:=float(segment)/segments*TAU
			var lobes: float=1+.075*sin(phi*3+seed_)*sin(theta)*sin(theta)+.045*cos(phi*5-seed_)*sin(theta*2)
			var p:=Vector3(cos(phi)*sin(theta)*lobes,cos(theta),sin(phi)*sin(theta)*lobes)
			if evergreen:
				var radius:=pow(v,.8)*(1+.035*sin(phi*7+seed_))
				p=Vector3(cos(phi)*radius,.7-v,sin(phi)*radius)
			var tone: float=.94+(.5+.5*cos(theta))*.08+sin(phi*4+seed_)*sin(theta*3)*.018
			st.set_color(color*tone)
			st.set_uv(Vector2(float(segment)/segments,v))
			st.add_vertex(p)
	for ring in range(rings):
		for segment in range(segments):
			var i:=ring*(segments+1)+segment
			for index in [i,i+segments+1,i+1,i+1,i+segments+1,i+segments+2]: st.add_index(index)
	if evergreen:
		st.set_color(color*.90)
		st.add_vertex(Vector3(0,-.3,0))
		var center: int=(rings+1)*(segments+1)
		for segment in range(segments):
			for index in [rings*(segments+1)+segment,center,rings*(segments+1)+segment+1]: st.add_index(index)
	st.generate_normals()
	return st.commit()
