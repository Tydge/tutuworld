extends Node3D
var door_width:=2.72
var door_height:=3.45
var door_open:=true
var door_angle:=-PI*.55
var door_target:=-PI*.55
var door_tweening:=false
var host: Node3D
var hinge: Node3D
var portal: CollisionShape3D
var right_hinge: Node3D
var right_leaf: CollisionShape3D
var leaf: CollisionShape3D
func configure(city: Node3D) -> void:
	host=city;hinge=$Hinge;portal=$PortalCollision.get_child(0);leaf=$Hinge/LeafCollision.get_child(0)
	right_hinge=get_node_or_null("RightHinge")
	if right_hinge:right_leaf=right_hinge.get_node("LeafCollision").get_child(0)
	pose_leaves()
	portal.set_deferred("disabled",door_open)
func pose_leaves() -> void:
	hinge.rotation.y=-door_angle if right_hinge else door_angle
	if right_hinge:right_hinge.rotation.y=PI+door_angle
func disable_leaves(disabled: bool) -> void:
	leaf.set_deferred("disabled",disabled)
	if right_leaf:right_leaf.set_deferred("disabled",disabled)
func door_action_position() -> Vector3:return $ActionAnchor.global_position
func toggle_door(actor: CharacterBody3D) -> Dictionary:
	if door_tweening:return {"ok":false,"message":"门正在转动。"}

	door_open=not door_open;door_target=-PI*.55 if door_open else 0.;door_tweening=true
	disable_leaves(true);portal.set_deferred("disabled",true)
	return {"ok":true,"message":""}
func _physics_process(delta: float) -> void:
	if not is_instance_valid(hinge) or not door_tweening:return
	door_angle=move_toward(door_angle,door_target,delta*3.);pose_leaves()
	var moving:=absf(door_angle-door_target)>.001
	disable_leaves(moving);portal.set_deferred("disabled",moving or absf(door_angle)>1.22)
	if not moving:
		door_tweening=false
		if is_instance_valid(host) and is_instance_valid(host.navigation):host.navigation.refresh_region(AABB(global_position-Vector3(4,1,4),Vector3(8,7,8)))
