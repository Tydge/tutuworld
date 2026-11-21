extends MeshInstance3D
## Draw temporary expression marks on the existing head surface.

const CatSurface = preload("res://scripts/characters/cat_surface.gd")
const G = preload("res://scripts/geometry.gd")
static var faces: Dictionary = {}
var current := ""

func show_expression(species: String, expression: String) -> void:
	var key := species + "/" + expression
	if not faces.has(key):
		faces[key] = Painter.new(species == "panda").draw(expression)
	if current != key:
		current = key
		mesh = faces[key]
	visible = true

class Painter:
	var panda: bool
	var ink := SurfaceTool.new()
	var light := SurfaceTool.new()
	var pink := SurfaceTool.new()

	func _init(is_panda: bool) -> void:
		panda = is_panda
		for surface in [ink, light, pink]:
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	func draw(expression: String) -> ArrayMesh:
		var eye_x := .293 if panda else .298
		var eye_y := .026 if panda else -.078
		var brow_y := .272 if panda else .104
		for side in [-1., 1.]:
			var x: float = side * eye_x
			var eye := Vector2(x, eye_y)
			var eye_stroke := light if panda else ink
			match expression:
				"laugh":
					curve(eye_stroke, eye + Vector2(-.09, -.005), eye + Vector2(0., .143), eye + Vector2(.09, -.005), .017)
					oval(pink, Vector2(side * .482,eye_y-.125), Vector2(.054,.021))
				"angry":
					curve(eye_stroke, eye + Vector2(-side * .090, -.018), eye + Vector2(0., .035), eye + Vector2(side * .085, .043), .017)
					curve(ink, Vector2(side * .172,brow_y-.042),Vector2(side * .29,brow_y+.027),Vector2(side * .404,brow_y+.062),.021)
				"sad":
					curve(eye_stroke, eye + Vector2(-side * .085,.007), eye + Vector2(side * .023,-.071),eye + Vector2(side * .089,-.026),.014)
					curve(ink,Vector2(side*.174,brow_y+.06),Vector2(side*.29,brow_y+.063),Vector2(side*.398,brow_y-.045),.016)
				"think":
					var squint: float = .065 if side < 0. else .040
					oval(light, eye, Vector2(.087, squint))
					oval(ink, eye + Vector2(.028,.005), Vector2(.036,squint*.74), .003)
					oval(light, eye + Vector2(.020,.023),Vector2(.010,.010),.006)
					curve(ink,Vector2(side*.183,brow_y),Vector2(side*.30,brow_y+(.135 if side<0. else .034)),Vector2(side*.40,brow_y+.028),.015)
		var y := -.342 if panda else -.357
		match expression:
			"laugh":
				oval(ink,Vector2(0.,y-.014),Vector2(.145,.105))
				oval(pink,Vector2(.008,y-.057),Vector2(.074,.033),.003)
				curve(light,Vector2(-.08,y+.038),Vector2(0.,y+.057),Vector2(.080,y+.038),.009,.003)
			"angry":
				curve(ink,Vector2(-.138,y-.002),Vector2(0.,y+.087),Vector2(.138,y-.002),.016)
			"sad":
				curve(ink,Vector2(-.106,y-.016),Vector2(-.023,y+.119),Vector2(.099,y-.033),.016)
			"think":
				oval(ink,Vector2(.047,y),Vector2(.046,.025))
				oval(pink,Vector2(.052,y-.006),Vector2(.025,.010),.003)
		var combined := ArrayMesh.new()
		var layers := [[ink, "31242c"]]
		if panda or expression in ["laugh","think"]:
			layers.append([light, "fdf3dd"])
		if expression in ["laugh","think"]:
			layers.append([pink, "e58a90"])
		for entry in layers:
			var material := G.mat(entry[1], .89).duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			entry[0].set_material(material)
			entry[0].commit(combined)
		return combined

	func project(p: Vector2) -> Vector3:
		if not panda:
			return CatSurface.face_point(p)
		# Match the muzzle and radii in the baked panda head.
		var depth := .66 * sqrt(maxf(.02, 1. - pow(p.x / .73, 2) - pow(p.y / .61, 2)))
		depth += .035 * exp(-pow(p.x / .36, 4) - pow((p.y + .22) / .22, 4))
		return Vector3(p.x, p.y, depth + .010)

	func emit(surface: SurfaceTool, p: Vector2, offset: float) -> void:
		var here := project(p)
		var horizontal := project(p + Vector2(.002,0)) - here
		var vertical := project(p + Vector2(0,.002)) - here
		surface.set_normal(horizontal.cross(vertical).normalized())
		surface.add_vertex(here + Vector3.BACK * offset)

	func quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, offset: float) -> void:
		for point: Vector2 in [a,b,c,c,b,d]:
			emit(surface,point,offset)

	func curve(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, radius: float, offset := 0.) -> void:
		var last := PackedVector2Array()
		for index in range(19):
			var t := float(index) / 18.
			var point := a.lerp(b,t).lerp(b.lerp(c,t),t)
			var normal := (b-a).lerp(c-b,t).normalized().orthogonal()
			var width := radius * lerpf(.23,1.,sqrt(maxf(0., sin(t * PI))))
			var pair := PackedVector2Array([point-normal*width,point+normal*width])
			if not last.is_empty():
				quad(surface,last[0],last[1],pair[0],pair[1],offset)
			last = pair

	func oval(surface: SurfaceTool, center: Vector2, radii: Vector2, offset := 0.) -> void:
		for ring in range(3):
			var inner := float(ring) / 3.
			var outer := float(ring+1) / 3.
			for segment in range(24):
				var a := Vector2.from_angle(TAU * segment / 24.) * radii
				var b := Vector2.from_angle(TAU * (segment+1) / 24.) * radii
				quad(surface,center+a*inner,center+b*inner,center+a*outer,center+b*outer,offset)
