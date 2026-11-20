extends RefCounted
## Local metres from the ground pivot. The model bake and harvest anchors use the same joints.
const COUNT := 5
const STEM_END := Vector3(.034,.258,-.028)

static func direction(i: int) -> Vector3:
	var a: float=[.30,1.61,2.68,4.10,5.42][i]
	return Vector3(sin(a),0,cos(a))

static func elbow(i: int) -> Vector3:
	return direction(i)*(.43+.08*sin(i))+Vector3.UP*(1.97+.17*i)

static func fork(i: int) -> Vector3:
	return direction(i)*float([1.09,1.22,1.03,1.15,1.13][i])+Vector3.UP*(2.62+.15*i)

static func tip(i: int) -> Vector3:
	var out:=direction(i)
	var side:=out.rotated(Vector3.UP,PI*.5)
	return out*(1.64+.08*cos(i*2.1))+side*.13*sin(i)+Vector3.UP*(2.43+.14*i+.15*sin(i))

static func attach(crown: Node3D,tree_model: Node3D) -> void:
	for i in range(COUNT):
		var marker:=Marker3D.new()
		marker.name="FruitSpur%d"%i
		crown.add_child(marker)
		marker.position=crown.to_local(tree_model.to_global(tip(i)))
