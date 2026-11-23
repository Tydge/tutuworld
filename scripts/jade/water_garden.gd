extends RefCounted
const G=preload("res://scripts/geometry.gd")
static var water: ShaderMaterial
static var rock: StandardMaterial3D
static func surface(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for v in [a,b,c]:
		st.set_uv(Vector2(v.x+.47*v.y,v.z+.53*v.y)*.53);st.add_vertex(v)
static func natural_stone() -> StandardMaterial3D:
	if rock==null:
		rock=StandardMaterial3D.new();rock.albedo_texture=preload("res://assets/terrain/soft_moss_rock_v1.png");rock.albedo_color=Color("a0a395");rock.roughness=.93;rock.cull_mode=BaseMaterial3D.CULL_DISABLED
	return rock
static func edge(a: float) -> Vector3:
	var rim:=preload("res://scripts/jade/layout.gd").pond_rim(a)
	return Vector3(rim.x,.107,rim.y)
static func flower(n: Node3D,center: Vector3,r: float) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(3):
		for i in range(9-layer):
			var a: float=i*TAU/(9.-layer)+layer*.43
			var axis:=Vector3(cos(a),0,sin(a));var tangent:=Vector3(-axis.z,0,axis.x)
			var foot:=center+axis*r*.09
			var tip:=center+axis*r*(1.08-layer*.26)+Vector3.UP*r*(.48+.21*layer)
			var mid:=foot.lerp(tip,.6)-Vector3.UP*r*.20
			var left:=mid+tangent*r*(.34-layer*.06);var right:=mid-tangent*r*(.34-layer*.06)
			for v in [foot,left,mid,foot,mid,right,left,tip,mid,mid,tip,right]:
				st.set_color(Color("f4d8d4").lerp(Color("b5677b"),.8 if v==tip else .06).srgb_to_linear());st.add_vertex(v)
	st.generate_normals();var petal:=StandardMaterial3D.new();petal.vertex_color_use_as_albedo=true;petal.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(n,st.commit(),Vector3.ZERO,petal)
	G.cylinder(n,center+Vector3.UP*.04,r*.16,.05,G.mat("cba557"))
static func pond(n: Node3D) -> void:
	var liquid:=SurfaceTool.new();liquid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var border:=SurfaceTool.new();border.begin(Mesh.PRIMITIVE_TRIANGLES)
	const segments:=preload("res://scripts/jade/layout.gd").POND_SEGMENTS
	for i in range(segments):
		var a:=edge(i*TAU/segments);var b:=edge((i+1)*TAU/segments)
		for v in [Vector3(0,.106,0),a,b]:
			liquid.set_uv(Vector2(v.x,v.z));liquid.set_uv2(Vector2(0. if v==a or v==b else 1.,0));liquid.add_vertex(v)
		var outer:=a*Vector3(1.08,1.,1.08)+Vector3.UP*(.032+.035*sin(i*1.23));var next:=b*Vector3(1.08,1.,1.08)+Vector3.UP*(.032+.035*sin((i+1)*1.23))
		var bank:=outer*Vector3(1.09,1.,1.09)-Vector3.UP*.17;var bank2:=next*Vector3(1.09,1.,1.09)-Vector3.UP*.17
		surface(border,a,outer,b);surface(border,outer,next,b);surface(border,outer,bank,next);surface(border,bank,bank2,next)
	if water==null:
		water=ShaderMaterial.new();water.shader=preload("res://assets/shaders/jade_pond.gdshader");water.set_shader_parameter("stones",preload("res://assets/terrain/soft_moss_rock_v1.png"));water.set_shader_parameter("ripples",preload("res://assets/terrain/water_ripple_normals_v1.png"))
	liquid.generate_normals();liquid.generate_tangents();G.mesh(n,liquid.commit(),Vector3.ZERO,water)
	border.generate_normals();G.mesh(n,border.commit(),Vector3.ZERO,natural_stone())
	var pads:=SurfaceTool.new();pads.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(23):
		var a:=i*2.399;var d:=(.26+.68*(i%8)/8.)
		var p:=edge(a)*Vector3(d,1.,d)+Vector3.UP*.022;var r:=.13+.13*(i%4)/3.
		for k in range(24):
			var theta:=a+.14+5.96*k/24.;var next:=theta+5.96/24.
			var u:=p+Vector3(cos(theta)*r,.026*sin(theta*3.)+.014,sin(theta)*r*.80)
			var v:=p+Vector3(cos(next)*r,.026*sin(next*3.)+.014,sin(next)*r*.80)
			for f in [p,u,v]:
				pads.set_color(Color("385842").lerp(Color("91a269"),.82 if f==p or k%5==0 else .38).srgb_to_linear());pads.add_vertex(f)
		if i%5==1:
			var bud:=p+Vector3(.10,.31+.03*(i%3),.03);flower(n,bud,.145)
			G.cylinder(n,p+Vector3(.10,.15,.03),.014,.32,G.mat("627748"))
	pads.generate_normals();var leaf:=StandardMaterial3D.new();leaf.vertex_color_use_as_albedo=true;leaf.cull_mode=BaseMaterial3D.CULL_DISABLED;G.mesh(n,pads.commit(),Vector3.ZERO,leaf)
	var rng:=RandomNumberGenerator.new();rng.seed=39329
	var sedge:=SurfaceTool.new();sedge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pebbles:=SurfaceTool.new();pebbles.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(76):
		var theta:=i*TAU/76.;var e:=edge(theta)
		var extent:=.5+.5*sin(theta*3.+.24)
		if extent>.15:
			var p:=e*rng.randf_range(.96,1.3);p.y=.10
			for j in range(8):
				var phi:=rng.randf()*TAU;var length_:=rng.randf_range(.10,.43)*(.65+extent)
				var axis:=Vector3(cos(phi)*length_,rng.randf_range(.15,.62),sin(phi)*length_)
				preload("res://scripts/jade/grove.gd").blade(sedge,p+Vector3(cos(phi)*.11,0,sin(phi)*.11),axis,.021+rng.randf()*.021,Color("456951").lerp(Color("98ab65"),rng.randf()),false)
		for j in range(3):
			var q:=e*rng.randf_range(.90,1.25);q.y=.087+rng.randf()*.032
			var width:=rng.randf_range(.076,.21);var height:=width*rng.randf_range(.32,.70);var tint:=Color("7e8168").lerp(Color("aca99a"),rng.randf())
			for k in range(7):
				var phi:=k*TAU/7.;var after:=phi+TAU/7.
				var v0:=q+Vector3(cos(phi)*width,0,sin(phi)*width*.69);var v1:=q+Vector3(cos(after)*width,0,sin(after)*width*.69)
				for v in [v0,q+Vector3(width*.14,height,0),v1]:pebbles.set_color(tint.srgb_to_linear());pebbles.add_vertex(v)
	var shoreline:=StandardMaterial3D.new();shoreline.vertex_color_use_as_albedo=true;shoreline.roughness=.91;shoreline.cull_mode=BaseMaterial3D.CULL_DISABLED
	pebbles.index();pebbles.generate_normals();G.mesh(n,pebbles.commit(),Vector3.ZERO,shoreline)
	sedge.index();G.mesh(n,sedge.commit(),Vector3.ZERO,shoreline)
static func stone_point(a: float,b: float,i: int) -> Vector3:
	var tube:=.31+.12*sin(3.*a+i)+.055*cos(b*3.+a*4.)
	var ring:=.61+.10*cos(3.*a+.4*i)+tube*cos(b)
	var y:=ring*sin(a)
	return Vector3(ring*cos(a)*(.83+i*.045)+.22*y+.09*sin(a*4.),y*(1.72-i*.10),tube*sin(b)*1.55+.14*sin(a*2.))
static func scholar_stones(n: Node3D) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var offset: Vector3=[Vector3(.12,1.41,.05),Vector3(-.74,.85,.28),Vector3(.92,.57,-.27)][i]
		var rot:=Basis(Vector3.UP,i*1.23)
		for k in range(24):
			for j in range(10):
				for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var v:=offset+rot*stone_point((k+c.x)*TAU/24.,(j+c.y)*TAU/10.,i)*(1.-i*.20)
					st.set_uv(Vector2(v.x+v.z*.28,v.y)*.52);st.add_vertex(v)
	st.index();st.generate_normals();G.mesh(n,st.commit(),Vector3.ZERO,natural_stone())
