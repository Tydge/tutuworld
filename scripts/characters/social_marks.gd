extends RefCounted
## Camera-facing comic accents for the nine short social gestures.
const G := preload("res://scripts/geometry.gd")
static var heart: ArrayMesh
static var drop: ArrayMesh
static var sparkle: ArrayMesh

static func line(node: Node3D, a: Vector2, b: Vector2, width: float, material: Material) -> void:
	G.capsule(node,Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),width,material)

static func glint(node: Node3D, material: Material) -> void:
	if sparkle==null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim := PackedVector2Array([Vector2(0,.166),Vector2(.032,.036),Vector2(.113,0),Vector2(.032,-.03),Vector2(0,-.166),Vector2(-.032,-.03),Vector2(-.113,0),Vector2(-.032,.036)])
		for i in rim.size():
			st.set_normal(Vector3.BACK)
			st.add_vertex(Vector3(0,0,.025))
			st.add_vertex(Vector3(rim[i].x,rim[i].y,0))
			var next := rim[(i+1)%rim.size()]
			st.add_vertex(Vector3(next.x,next.y,0))
		sparkle = st.commit()
	G.mesh(node,sparkle,Vector3.ZERO,material,"Glint")

static func make_heart() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := PackedVector2Array()
	for i in 48:
		var a := TAU*i/48.
		rim.append(.0125*Vector2(16.*pow(sin(a),3),13.*cos(a)-5.*cos(2.*a)-2.*cos(3.*a)-cos(4.*a)))
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i+1)%rim.size()]
		for v: Vector3 in [Vector3(0,0,.070),Vector3(a.x,a.y,0),Vector3(b.x,b.y,0),
				Vector3(0,0,-.030),Vector3(b.x,b.y,0),Vector3(a.x,a.y,0)]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

static func make_drop() -> ArrayMesh:
	# A single pear silhouette. The tip and round belly stay connected as it falls.
	var sphere := SphereMesh.new()
	sphere.radius = 1.
	sphere.height = 2.
	sphere.radial_segments = 32
	sphere.rings = 16
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var v := vertices[i]
		var width := .173*(1.-.69*v.y)
		vertices[i] = Vector3(v.x*width,.29*v.y+.067*v.y*v.y,v.z*width)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func build(fx: Node3D,id: String) -> void:
	match id:
		"wave":
			for i in 2:
				var n: Node3D = fx.particle()
				line(n,Vector2(-.07,-.065),Vector2(.008,0),.024,fx.paint("ffc179"))
				line(n,Vector2(.008,0),Vector2(.052,.082),.024,fx.paint("ffc179"))
		"cheer", "thanks", "snicker":
			var count := 3 if id=="cheer" else 1
			for i in count:
				glint(fx.particle(),fx.paint(["ffbc5f","f69399","ffdf83"][i]))
		"love":
			if heart==null:
				heart = make_heart()
			for i in 2:
				var n: Node3D = fx.particle()
				G.mesh(n,heart,Vector3.ZERO,fx.paint("f2798e" if i==0 else "ffb1b7"),"Heart")
				G.ball(n,Vector3(-.093,.061,.042),Vector3(.037,.020,.013),fx.paint("ffe3dd"))
		"agree":
			var n: Node3D = fx.particle()
			var mint: Material = fx.paint("59b78a")
			line(n,Vector2(-.17,0),Vector2(-.047,-.104),.039,mint)
			line(n,Vector2(-.047,-.104),Vector2(.183,.157),.039,mint)
		"refuse":
			var n: Node3D = fx.particle()
			var coral: Material = fx.paint("e97875")
			line(n,Vector2(-.144,-.144),Vector2(.144,.144),.039,coral)
			line(n,Vector2(-.144,.144),Vector2(.144,-.144),.039,coral)
		"sweat":
			if drop==null:
				drop = make_drop()
			var n: Node3D = fx.particle()
			G.mesh(n,drop,Vector3.ZERO,fx.paint("69bee1"),"BigSweatDrop")
			G.ball(n,Vector3(-.067,-.030,.147),Vector3(.033,.062,.022),fx.paint("e1f7ff"))
		"shock":
			for i in 2:
				var n: Node3D = fx.particle()
				var gold: Material = fx.paint("ffa94d")
				line(n,Vector2(-.14,.13),Vector2(.034,.033),.031,gold)
				line(n,Vector2(.034,.033),Vector2(-.052,-.028),.031,gold)
				line(n,Vector2(-.052,-.028),Vector2(.112,-.15),.031,gold)

static func animate(part: Node3D,id: String,i: int,t: float,radius: Vector3,strength: float) -> void:
	var x := radius.x
	var y := radius.y
	var size := 1.
	match id:
		"wave":
			var swing := sin((t-.31)*TAU*2.25)
			part.position = Vector3(x+.16+.15*i,.06+.105*i+.04*swing,.30)
			part.rotation.z = -.18+.14*swing
			size = (.85-.19*i)*smoothstep(.19,.41,t)
		"cheer":
			var f := clampf((t-.22-.07*i)/1.22,0.,1.)
			var side := -1. if i==1 else 1.
			part.position = Vector3(side*(x+.07+.27*f),.08+.88*sin(PI*f)+.18*i,.20)
			part.rotation.z = side*(f*2.0+.45*i)
			size = sin(PI*f)*(.92+.19*i)
		"thanks":
			part.position = Vector3(-x-.10,.31+.17*smoothstep(.65,1.35,t),.23)
			size = .94*sin(PI*clampf((t-.40)/1.15,0.,1.))
		"love":
			var f := clampf((t-.58-.32*i)/.98,0.,1.)
			var flight := smoothstep(0.,1.,f)
			var drift := 1.-pow(1.-f,2)
			part.position = Vector3(.23+(x+.28)*drift,-y*.86+.98*flight*flight-.18*i,radius.z+.16+.26*f)
			part.rotation.z = -.22+.40*f
			size = (1.20-.47*i)*smoothstep(0.,.20,f)*(1.-smoothstep(.78,1.,f))
		"agree", "refuse":
			size = smoothstep(.25,.40,t)+.21*sin(PI*clampf((t-.38)/.28,0.,1.))
			part.position = Vector3(x+.23,.34,.20)
		"snicker":
			var f := clampf((t-.60)/.83,0.,1.)
			part.position = Vector3(x+.07,-.03+.11*f,.42)
			part.rotation.z = -.26+.56*f
			size = .94*sin(PI*f)
		"sweat":
			var slide := smoothstep(.69,1.56,t)
			part.position = Vector3(x*.92+.10*slide,y*.65-.79*slide,radius.z*.57)
			part.rotation.z = -.26+.20*slide
			size = 1.14*smoothstep(.19,.59,t)*(1.-smoothstep(1.57,1.90,t))
		"shock":
			var side := 1. if i==0 else -1.
			var f := smoothstep(.21+.035*i,.34+.035*i,t)
			part.position = Vector3(side*(x+.09+.20*f),y*.51+.13*f,.23)
			part.rotation.y = PI if i==0 else 0.
			size = 1.14*f*(1.-smoothstep(.91,1.37,t))
	part.visible = size*strength>.01
	part.scale = Vector3.ONE*maxf(.001,size*strength)
