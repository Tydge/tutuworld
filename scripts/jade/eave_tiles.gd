extends RefCounted
## Curved barrel tile caps end in a glazed face. Slender pointed drip tiles sit in the gaps.
const G=preload("res://scripts/geometry.gd")
static var glazes: Dictionary={}
static func vertex(st: SurfaceTool,v: Vector3,uv: Vector2) -> void:
	st.set_uv(uv);st.add_vertex(v)
static func trim(eaves: Node3D,w: float,d: float,rise: float,royal: bool) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count:=ceili(w*2./.47);var spacing:=w*2./count
	for side in [-1,1]:
		for i in range(count):
			var u:=2.*(i+.5)/count-1.
			var mouth: Vector3=art.roof_point(w,d,rise,1.,u,side)+Vector3(0,.012,side*.108)
			var back: Vector3=art.roof_point(w,d,rise,1.-.52/d,u,side)+Vector3.UP*.012
			var radius:=spacing*.30
			for j in range(7):
				var phi0:=PI*j/7.;var phi1:=PI*(j+1)/7.
				var a:=Vector3(cos(phi0),sin(phi0),0)*radius
				var b:=Vector3(cos(phi1),sin(phi1),0)*radius
				for v in [mouth+a,back+a,mouth+b,mouth+b,back+a,back+b]:
					vertex(st,v,Vector2(v.x*.8,v.z*1.5))
			for j in range(10):
				var phi0:=j*TAU/10.;var phi1:=(j+1)*TAU/10.
				var a:=Vector3(cos(phi0),sin(phi0),0)
				var b:=Vector3(cos(phi1),sin(phi1),0)
				var tip:=mouth+Vector3(0,-.014,side*.045)
				for v in [tip, mouth+a*radius,mouth+b*radius]:
					vertex(st,v,Vector2(.5,.5)+Vector2(v.x-mouth.x,v.y-mouth.y)*2.)
			var drip:=mouth+Vector3(spacing*.5,-.036,side*.025)
			for v in [drip+Vector3(-.14,.04,0),drip+Vector3(.14,.04,0),drip+Vector3(0,-.155,side*.035)]:
				vertex(st,v,Vector2(v.x,v.y))
	if not glazes.has(royal):
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color("c19347" if royal else "597068")
		mat.metallic=.17;mat.roughness=.35;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		glazes[royal]=mat
	st.index();st.generate_normals()
	G.mesh(eaves,st.commit(),Vector3.ZERO,glazes[royal],"GlazedEaveEnds")
