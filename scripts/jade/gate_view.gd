extends Node3D
var city: Node3D
func _process(_delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.camera) or not is_instance_valid(city.bunny):return
	var head:=to_local(city.bunny.global_position)+Vector3.UP*1.4
	var camera_pos:=to_local(city.camera.global_position)
	var crown:=AABB(Vector3(-6.9,4.7,-1.9),Vector3(13.8,5.9,3.8)).grow(.32)
	var clear:=preload("res://scripts/city/interior_view.gd").mode(city)==1 or crown.intersects_segment(head,camera_pos)==null
	$GateCrown.visible=clear
	for child in get_children():
		if child is Label3D:child.visible=clear
