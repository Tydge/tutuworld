extends MeshInstance3D
## Two baked folds follow the existing leg pivots without cloth simulation.
var actor: Node3D
var weights := Vector2.ZERO

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var next := Vector2(
		smoothstep(.18,.94,-actor.left_leg.basis.y.z),
		smoothstep(.18,.94,-actor.right_leg.basis.y.z)
	)
	if not next.is_equal_approx(weights):
		set_blend_shape_value(0,next.x)
		set_blend_shape_value(1,next.y)
		weights = next
