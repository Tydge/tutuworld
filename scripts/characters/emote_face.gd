extends MeshInstance3D
## Draw temporary expression marks on the existing head surface.

const CatSurface = preload("res://scripts/characters/cat_surface.gd")
const Motion = preload("res://scripts/characters/emote_motion.gd")
const G = preload("res://scripts/geometry.gd")
static var faces: Dictionary = {}
var current := ""

static func uses_model_eyes(species: String, expression: String) -> bool:
	return species == "bunny" or (species == "cat_teacher" and expression in Motion.SOCIAL) or (species == "panda" and expression == "refuse")

static func uses_model_mouth(species: String, expression: String) -> bool:
	return species == "bunny" and (expression not in Motion.SOCIAL or expression in ["wave","thanks","love","agree"])

func show_expression(species: String, expression: String) -> void:
	var key := species + "/" + expression
	if not faces.has(key):
		faces[key] = Painter.new(species).draw(expression,uses_model_eyes(species,expression),uses_model_mouth(species,expression))
	if current != key:
		current = key
		mesh = faces[key]
	visible = true

class Painter:
	var panda: bool
	var bunny: bool
	var used := {}
	var ink := SurfaceTool.new()
	var light := SurfaceTool.new()
	var pink := SurfaceTool.new()

	func _init(species: String) -> void:
		panda = species == "panda"
		bunny = species == "bunny"
		for surface in [ink, light, pink]:
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	func draw(expression: String, model_eyes: bool, model_mouth: bool) -> ArrayMesh:
		if not model_eyes:
			draw_eyes(expression)
		if expression == "thanks" or (expression == "love" and not bunny):
			var cheek_y := -.19 if bunny else (-.104 if panda else -.208)
			for side in [-1.,1.]:
				oval(pink,Vector2(side*(.43 if bunny else .45),cheek_y),Vector2(.068,.026))
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
			_:
				if not model_mouth:
					social_mouth(expression,y)
		var combined := ArrayMesh.new()
		for entry in [[ink,"31242c"],[light,"fdf3dd"],[pink,"e58a90"]]:
			if not used.has(entry[0]):
				continue
			var material := G.mat(entry[1], .89).duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			entry[0].set_material(material)
			entry[0].commit(combined)
		return combined

	func draw_eyes(expression: String) -> void:
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
				_:
					social_eye(expression,eye,eye_stroke,side,brow_y)

	func social_eye(id: String,eye: Vector2,stroke: SurfaceTool,side: float,brow: float) -> void:
		var x := eye.x
		match id:
			"shock", "sweat", "wave":
				var height := .112 if id=="shock" else .074
				var glance := -.034 if id=="sweat" else .012
				oval(light,eye,Vector2(.097,height))
				oval(ink,eye+Vector2(glance,0),Vector2(.030,.047) if id=="shock" else Vector2(.044,.052),.003)
				oval(light,eye+Vector2(glance-.01,.018),Vector2(.012,.012),.006)
				var raise := .053 if id=="shock" else .015
				curve(ink,Vector2(x-.09,brow+raise),Vector2(x,brow+raise+.069),Vector2(x+.09,brow+raise+.015),.014)
			"snicker":
				curve(stroke,eye+Vector2(-.09,-side*.023),eye+Vector2(0,-.028),eye+Vector2(.09,side*.023),.019)
				curve(ink,Vector2(x-.086,brow+.022),Vector2(x,brow+.075),Vector2(x+.082,brow-.015),.015)
			_:
				var arch := .13 if id in ["cheer","love"] else .071
				curve(stroke,eye+Vector2(-.092,-.012),eye+Vector2(0,arch),eye+Vector2(.092,-.012),.018)

	func social_mouth(id: String,y: float) -> void:
		var center := Vector2(.012,y)
		match id:
			"wave", "thanks", "agree":
				var depth := .108 if id=="wave" else .074
				curve(ink,center+Vector2(-.115,.029),center+Vector2(0,-depth),center+Vector2(.118,.035),.019)
			"cheer":
				oval(ink,center,Vector2(.137,.112))
				oval(pink,center+Vector2(.010,-.047),Vector2(.073,.035),.003)
			"love":
				curve(ink,center+Vector2(-.076,.050),center+Vector2(.045,.043),center+Vector2(-.015,0),.018)
				curve(ink,center+Vector2(-.015,0),center+Vector2(.034,-.051),center+Vector2(-.073,-.045),.018)
			"refuse":
				curve(ink,center+Vector2(-.105,-.015),center+Vector2(-.012,.069),center+Vector2(.115,-.012),.020)
			"snicker":
				curve(ink,center+Vector2(-.095,-.015),center+Vector2(.062,-.071),center+Vector2(.146,.086),.020)
				curve(ink,center+Vector2(.119,.070),center+Vector2(.148,.080),center+Vector2(.159,.047),.012)
			"sweat":
				curve(ink,center+Vector2(-.116,.027),center+Vector2(-.080,-.057),center+Vector2(-.016,-.008),.017)
				curve(ink,center+Vector2(-.016,-.008),center+Vector2(.046,.041),center+Vector2(.107,-.029),.017)
			"shock":
				oval(ink,center,Vector2(.084,.120))
				oval(pink,center+Vector2(.006,-.066),Vector2(.045,.026),.003)

	func project(p: Vector2) -> Vector3:
		if bunny:
			var z := .79*sqrt(maxf(.02,1.-pow(p.x/.84,2)-pow(p.y/.76,2)))
			return Vector3(p.x,p.y,z+.012)
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
		used[surface] = true
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
		used[surface] = true
		for ring in range(3):
			var inner := float(ring) / 3.
			var outer := float(ring+1) / 3.
			for segment in range(24):
				var a := Vector2.from_angle(TAU * segment / 24.) * radii
				var b := Vector2.from_angle(TAU * (segment+1) / 24.) * radii
				quad(surface,center+a*inner,center+b*inner,center+a*outer,center+b*outer,offset)
