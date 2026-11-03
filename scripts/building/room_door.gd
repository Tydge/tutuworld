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
var leaf: CollisionShape3D
func configure(city: Node3D) -> void:
	host=city;hinge=$Hinge;portal=$PortalCollision.get_child(0);leaf=$Hinge/LeafCollision.get_child(0)
	hinge.rotation.y=door_angle;portal.set_deferred("disabled",true)
func door_action_position() -> Vector3:return $ActionAnchor.global_position
func toggle_door(actor: CharacterBody3D) -> Dictionary:
	if door_tweening:return {"ok":false,"message":"门正在转动。"}

	door_open=not door_open;door_target=-PI*.55 if door_open else 0.;door_tweening=true
	leaf.set_deferred("disabled",true);portal.set_deferred("disabled",true)
	return {"ok":true,"message":""}
func _physics_process(delta: float) -> void:
	if not is_instance_valid(hinge) or not door_tweening:return
	door_angle=move_toward(door_angle,door_target,delta*3.);hinge.rotation.y=door_angle
	var moving:=absf(door_angle-door_target)>.001
	leaf.set_deferred("disabled",moving);portal.set_deferred("disabled",moving or absf(door_angle)>1.22)
	if not moving:
		door_tweening=false
		if is_instance_valid(host) and is_instance_valid(host.navigation):host.navigation.refresh_region(AABB(global_position-Vector3(4,1,4),Vector3(8,7,8)))
