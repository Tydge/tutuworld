extends Node3D
const G=preload("res://scripts/geometry.gd")
var age:=0.0
var pieces: Array[MeshInstance3D]=[]
func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mesh:=PrismMesh.new();mesh.size=Vector3(.07,.13,.035)
	for i in range(9):
		var part:=G.mesh(self,mesh,Vector3.ZERO,G.mat("f0cc74" if i%2 else "fff0ba",.45,.15))
		part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pieces.append(part)
func _process(delta: float) -> void:
	age+=delta
	if age>=.85: queue_free();return
	var progress:=age/.85
	for i in range(pieces.size()):
		var angle:=i*TAU/pieces.size()
		pieces[i].position=Vector3(cos(angle)*progress*.7,sin(progress*PI)*.6+float(i%3)*.05,sin(angle)*progress*.7)
		pieces[i].rotation=Vector3(progress*2,angle,progress*3)
		pieces[i].scale=Vector3.ONE*sin(progress*PI)
