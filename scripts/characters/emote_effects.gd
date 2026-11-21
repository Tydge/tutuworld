extends Node3D
## Three-dimensional comic marks. These stay outside the face on every species.
const G = preload("res://scripts/geometry.gd")
static var colors: Dictionary = {}

var kind := ""
var marks: Node3D
var particles: Array[Node3D] = []

func show_effect(id: String) -> void:
	if id == kind:
		return
	kind = id
	if is_instance_valid(marks):
		remove_child(marks)
		marks.queue_free()
	marks = Node3D.new()
	marks.name = "ComicMarks"
	add_child(marks)
	particles.clear()
	match kind:
		"laugh":
			for i in range(3):
				var star := particle()
				var size := .145 - i * .019
				for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
					G.capsule(star,axis * -size,axis * size,.027,paint("ffc961"))
				G.ball(star,Vector3.ZERO,Vector3.ONE*.067,paint("fff0ac"))
		"angry":
			var sign := particle()
			for side_x in [-1., 1.]:
				for side_y in [-1., 1.]:
					var anchor := Vector3(side_x * .20, side_y * .11, 0)
					var middle := Vector3(side_x * .094, side_y * .083, 0)
					var end := Vector3(side_x * .095, side_y * .192, 0)
					G.capsule(sign, anchor, middle, .035,paint("f17b76"))
					G.capsule(sign, middle, end, .035,paint("f17b76"))
			for i in range(3):
				var puff := particle()
				for lobe in [Vector3(-.082,0,0),Vector3(.065,.018,0),Vector3(0,.081,0)]:
					G.ball(puff,lobe,Vector3(.115,.086,.092),paint("fff2e6"))
		"sad":
			for i in range(3):
				var tear := particle()
				G.ball(tear,Vector3.ZERO,Vector3(.076,.113,.060),paint("87c9ef"))
				G.ball(tear,Vector3(0,.064,0),Vector3(.047,.078,.043),paint("87c9ef"))
				G.ball(tear,Vector3(-.024,.018,.052),Vector3(.019,.036,.009),paint("e4f9ff"))
		"think":
			for i in range(3):
				var bubble := particle()
				G.ball(bubble,Vector3.ZERO,Vector3.ONE*(.095+i*.033),paint("ffe6a2"))
				G.ball(bubble,Vector3(-.033,.035,.078+i*.018),Vector3.ONE*(.023+i*.004),paint("fff9df"))
	for part in marks.find_children("*","GeometryInstance3D",true,false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func animate(actor: Node3D, age: float, strength: float) -> void:
	var height: float = actor.rig_profile.mood_height
	var right: float = actor.rig_profile.head_radii.x
	position = Vector3(0, height - .35, 0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		rotation.y = atan2(camera.global_position.x - global_position.x, camera.global_position.z - global_position.z) - actor.global_rotation.y
	else:
		rotation.y = actor.visual.rotation.y
	visible = not particles.is_empty() and strength > .08
	if not visible:
		return
	for index in range(particles.size()):
		var part := particles[index]
		var phase := fposmod(age * 1.8 - index * .27, 1.0)
		var plume := sin(phase * PI)
		var size := strength
		match kind:
			"laugh":
				var side := -1. if index == 1 else 1.
				part.position = Vector3(side*(right+.23+phase*.38),.16+index*.19+phase*.40,.19)
				part.rotation.z = phase * 1.7 + index * .9
				size *= .38 + .72*plume
			"angry":
				if index == 0:
					part.position = Vector3(right+.06,.23+.025*sin(age*16.),.35)
					part.rotation.z = .21 + .13*sin(age*17.)
					size *= 1.0 + .16*sin(age*13.)
				else:
					part.position = Vector3(-right-.14-phase*.33,-.37+phase*.52+(index-1)*.05,.29)
					size *= .12 + .70*plume
			"sad":
				var side := -1. if index == 1 else 1.
				part.position = Vector3(side*(right+.12+phase*.20),-.45-phase*.57,.41)
				part.rotation.z = side*.12
				size *= .30 + .80*plume
			"think":
				part.position = Vector3(right+.02+.19*index,-.18+.20*index+.044*sin(age*6-index),.25)
				size *= .78 + .22*sin(age*7-index)
		part.scale = Vector3.ONE * maxf(.001,size)

func particle() -> Node3D:
	var node := Node3D.new()
	marks.add_child(node)
	particles.append(node)
	return node

static func paint(hex: String) -> StandardMaterial3D:
	if not colors.has(hex):
		var m := G.mat(hex).duplicate() as StandardMaterial3D
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		colors[hex] = m
	return colors[hex]
