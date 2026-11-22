extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func build(builder: SceneTree) -> void:
	var noise:=FastNoiseLite.new();noise.seed=6329;noise.frequency=.009;noise.fractal_octaves=5
	var stone:=StandardMaterial3D.new();stone.vertex_color_use_as_albedo=true;stone.roughness=.98;stone.cull_mode=BaseMaterial3D.CULL_DISABLED
	var horizon:=SurfaceTool.new();horizon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(192):
		for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
			var arc: float=(i+c.x)/192.;var a:=arc*TAU
			var sweep:=arc*6.+.12*sin(a*2.)+.065*sin(a*5.)
			var u:=1.-absf(fposmod(sweep,2.)-1.)
			horizon.set_uv(Vector2(u,1.-c.y));horizon.add_vertex(Vector3(cos(a)*590.,-43.+c.y*(163.+18.*sin(a*3.)-54.*smoothstep(.38,.95,sin(a))),sin(a)*590.))
	var sky_mat:=ShaderMaterial.new();sky_mat.shader=preload("res://assets/shaders/jade_horizon.gdshader");sky_mat.set_shader_parameter("skyline",preload("res://assets/jade/mountain_range.png"))
	var backdrop:=G.mesh(builder.world,horizon.commit(),Vector3.ZERO,sky_mat,"PaintedRange");backdrop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sector in range(20):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(22):
			for i in range(20):
				for c in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var t: float=(j+c.y)/22.;var a: float=(sector*20+i+c.x)*TAU/400.
					var radius:=292.+t*450.;var x:=cos(a)*radius;var z:=sin(a)*radius
					var folds:=noise.get_noise_2d(x,z);var ridges:=1.-absf(noise.get_noise_2d(x+481.,z))
					var peak: float=pow(ridges,3.)*48.+folds*65.+16.*sin(a*9.+t*6.)
					var h:=(-6.+smoothstep(0.,.24,t)*(8.+11.*t+peak*.15))*(1.-.68*smoothstep(.51,.94,sin(a)))
					var tint:=Color("35594e").lerp(Color("829485"),clampf(h/120.+folds*.28,0,1)).lerp(Color("77969c"),t*.57)
					st.set_color(tint.srgb_to_linear());st.add_vertex(Vector3(x,h,z))
		st.index();st.generate_normals();var m:=G.mesh(builder.world,st.commit(),Vector3.ZERO,stone,"FoldedMountains");m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
