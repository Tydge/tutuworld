extends RefCounted
const SECTORS:=20
const RADIAL_CELLS:=24
const ARC_CELLS:=24
const G=preload("res://scripts/geometry.gd")
const J=preload("res://scripts/jade/layout.gd")
static func build(builder: SceneTree) -> void:
	var noise:=FastNoiseLite.new();noise.seed=6329;noise.frequency=.009;noise.fractal_octaves=3
	var stone:=ShaderMaterial.new();stone.shader=preload("res://assets/shaders/jade_foothills.gdshader")
	stone.set_shader_parameter("forest",preload("res://assets/terrain/woodland/forest_turf_v1.png"))
	stone.set_shader_parameter("hillside",preload("res://assets/terrain/soft_moss_rock_v1.png"))
	var horizon:=SurfaceTool.new();horizon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(192):
		for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
			var arc: float=(i+c.x)/192.;var a:=arc*TAU
			var sweep:=arc*4.+.11*sin(a*2.)+.06*sin(a*5.)
			var u:=1.-absf(fposmod(sweep,2.)-1.)
			var distance_:=640.+42.*sin(a*3.+.3)+24.*cos(a*2.)
			var crest:=152.+18.*sin(a*3.)-43.*smoothstep(.38,.95,sin(a))
			horizon.set_uv(Vector2(u,1.-c.y))
			horizon.add_vertex(Vector3(cos(a)*distance_,-35.+c.y*crest,sin(a)*distance_))
	var sky_mat:=ShaderMaterial.new();sky_mat.shader=preload("res://assets/shaders/jade_horizon.gdshader");sky_mat.set_shader_parameter("skyline",preload("res://assets/jade/mountain_range.png"))
	var backdrop:=G.mesh(builder.world,horizon.commit(),Vector3.ZERO,sky_mat,"PaintedRange");backdrop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var canopy_rng:=RandomNumberGenerator.new()
	canopy_rng.seed=11491
	for sector in range(SECTORS):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(RADIAL_CELLS):
			for i in range(ARC_CELLS):
				var cell:=PackedVector3Array()
				for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var t: float=float(j+c.y)/RADIAL_CELLS
					var a: float=(sector*ARC_CELLS+i+c.x)*TAU/(SECTORS*ARC_CELLS)
					# The corners of the island extend beyond the old circular foothill line.
					# Leave a channel there before the first ridge rises above the sea.
					var ray:=Vector2(cos(a),sin(a))
					var shore:=minf(J.LIMIT.x/maxf(absf(ray.x),.001),J.LIMIT.y/maxf(absf(ray.y),.001))
					var radius:=lerpf(maxf(292.,shore+68.),742.,t)
					var x:=ray.x*radius;var z:=ray.y*radius
					var folds:=noise.get_noise_2d(x,z);var ridges:=1.-absf(noise.get_noise_2d(x+481.,z))
					var peak: float=pow(ridges,3.)*48.+folds*65.+16.*sin(a*9.+t*6.)
					var h:=(-6.+smoothstep(0.,.24,t)*(8.+11.*t+peak*.15))*(1.-.68*smoothstep(.51,.94,sin(a)))
					# Across the river the two nearer shoulders overlap beneath the painted far peaks.
					# Leave a saddle behind the central palace and an open horizon at the ferry.
					var shoulder:=maxf(exp(-pow(angle_difference(a,-2.09)/.33,2.)),.80*exp(-pow(angle_difference(a,-1.06)/.25,2.)))
					# The eastern shore looks across two wooded spurs. Leave the southern ferry horizon open.
					shoulder=maxf(shoulder,.30*exp(-pow(angle_difference(a,.61)/.26,2.))+.19*exp(-pow(angle_difference(a,.98)/.16,2.)))
					var depth:=exp(-pow((t-.29-.048*sin(6.*a))/.16,2.))
					var low_ridge:=exp(-pow((t-.19-.055*sin(a*5.+.6))/.115,2.))
					var high_ridge:=exp(-pow((t-.47-.072*sin(a*3.))/.17,2.))
					var opening:=1.-.83*smoothstep(.30,.95,sin(a))
					h+=opening*(low_ridge*(6.+4.*folds+3.*ridges)+high_ridge*(16.+9.*folds+6.*ridges))
					h+=shoulder*depth*smoothstep(.04,.24,t)*(32.+12.*folds+8.*ridges)
					var tint:=Color("35594e").lerp(Color("829485"),clampf(h/120.+folds*.28,0,1)).lerp(Color("77969c"),t*.57)
					tint=tint.lerp(Color("627f80"),shoulder*depth*.45)
					var vertex:=Vector3(x,h,z)
					cell.append(vertex)
					st.set_color(tint.srgb_to_linear());st.add_vertex(vertex)
				if j<14 and canopy_rng.randf()<.24:
					var tri:=0 if canopy_rng.randf()<.5 else 3
					var u:=canopy_rng.randf();var v:=canopy_rng.randf()
					if u+v>1.:u=1.-u;v=1.-v
					var base:=cell[tri]+(cell[tri+1]-cell[tri])*u+(cell[tri+2]-cell[tri])*v
					if base.y>8.:crown(st,base,canopy_rng)
		st.index();st.generate_normals();var m:=G.mesh(builder.world,st.commit(),Vector3.ZERO,stone,"FoldedMountains");m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# Small joined crowns break up the ridge silhouettes. They share the terrain
# material and sector mesh, so an entire hillside still takes one submission.
static func crown(st: SurfaceTool,base: Vector3,rng: RandomNumberGenerator) -> void:
	var h:=rng.randf_range(1.4,3.0)
	var spread:=h*rng.randf_range(.34,.62)
	var lean:=Vector3(rng.randf_range(-.35,.35),0.,rng.randf_range(-.35,.35))
	var tint:=Color("395449").lerp(Color("536b56"),rng.randf())
	var angle:=rng.randf()*TAU
	var lo:=PackedVector3Array();var hi:=PackedVector3Array()
	for i in range(6):
		var a:=angle+i*TAU/6.
		var side:=Vector3(cos(a),0.,sin(a))*spread*rng.randf_range(.87,1.08)
		lo.append(base+side+Vector3.UP*h*.24)
		hi.append(base+side*.57+lean+Vector3.UP*h*.74)
	var top:=base+lean+Vector3.UP*h
	for i in range(6):
		var k: int=(i+1)%6
		for p: Vector3 in [base-Vector3.UP*.4,lo[i],lo[k],lo[i],hi[i],hi[k],lo[i],hi[k],lo[k],hi[i],top,hi[k]]:
			st.set_color(tint.lightened(.024*clampf((p.y-base.y)/h,0.,1.)).srgb_to_linear())
			st.add_vertex(p)
