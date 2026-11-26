extends RefCounted
## Bend the cat's own ink strokes. Both lids and the pupil keep their topology
## and are projected back onto the cheek together as the eye opens or smiles.
const Surface = preload("res://scripts/characters/cat_surface.gd")
static var shapes_by_mesh: Dictionary = {}
var brush: MeshInstance3D
var neutral: ArrayMesh
var pivot: Vector3
var current := ""

func _init(eyes: Node3D) -> void:
	brush = eyes.get_node("Brushwork")
	neutral = brush.mesh
	pivot = eyes.position
	if not shapes_by_mesh.has(neutral):
		shapes_by_mesh[neutral] = {}

func pose(expression: String, strength: float) -> void:
	if expression != current:
		var shapes: Dictionary = shapes_by_mesh[neutral]
		if not shapes.has(expression):
			shapes[expression] = make_shape(expression)
		brush.mesh = shapes[expression]
		current = expression
	brush.set_blend_shape_value(0,strength)

func reset() -> void:
	if not current.is_empty():
		brush.mesh = neutral
		current = ""

# Opening relative to the resting lid, lift at its center, and outer-corner tilt.
static func lids(expression: String, left: bool) -> Vector3:
	match expression:
		"wave": return Vector3(.91,.014,0.)
		"cheer": return Vector3(.47,.045,.008)
		"thanks": return Vector3(.67,.026,0.)
		"love": return Vector3(.54,.040,.008)
		"agree": return Vector3(.80,.013,0.)
		"refuse": return Vector3(.62,0.,.031)
		"snicker": return Vector3(.44 if left else .69,.020,.028)
		"sweat": return Vector3(.76 if left else 1.04,0.,-.018)
		"shock": return Vector3(1.45,-.018,-.012)
	return Vector3(1.,0.,0.)

func make_shape(expression: String) -> ArrayMesh:
	var base := neutral.surface_get_arrays(0)
	var vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = base[Mesh.ARRAY_NORMAL].duplicate()
	var inner := Surface.eye_corner(false)
	var outer := Surface.eye_corner(true)
	for i in vertices.size():
		var p := vertices[i]+pivot
		var t := clampf(inverse_lerp(inner.x,outer.x,absf(p.x)),0.,1.)
		var axis := lerpf(inner.y,outer.y,t)
		var lid := lids(expression,p.x<0.)
		var face := Vector2(p.x,axis+(p.y-axis)*lid.x+sin(PI*t)*lid.y+(t-.5)*lid.z)
		var surface := Surface.face_point(face)
		# At wide openings the flat pupil triangles span a longer chord of
		# the cheek. Lift the ink enough to keep the whole pupil visible.
		vertices[i] = surface-pivot+Vector3.BACK*.020*maxf(0.,lid.x-1.)
		var dx := Surface.face_point(face+Vector2(.001,0))-surface
		var dy := Surface.face_point(face+Vector2(0,.001))-surface
		normals[i] = dx.cross(dy).normalized()
	var target := []
	target.resize(Mesh.ARRAY_MAX)
	target[Mesh.ARRAY_VERTEX] = vertices
	target[Mesh.ARRAY_NORMAL] = normals
	target[Mesh.ARRAY_TANGENT] = base[Mesh.ARRAY_TANGENT]
	var result := ArrayMesh.new()
	result.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	result.add_blend_shape(&"Expression")
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base,[target])
	return result
