extends Node3D
var city: Node3D
func _process(_delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.bunny):return
	var p:=to_local(city.bunny.global_position);var head:=p+Vector3.UP*1.35;var eye:=to_local(city.camera.global_position)
	var on_deck:=p.y>3.9 and absf(p.x)<8. and absf(p.z)<3.
	var cut:=on_deck and preload("res://scripts/city/interior_view.gd").mode(city)!=1
	$Canopy.visible=not cut
	for side in [-1,1]:
		var face:=get_node("NorthFace" if side==-1 else "SouthFace") as Node3D
		var box:=AABB(Vector3(-5.7,4.5,side*1.2-.45),Vector3(11.4,3.5,.9))
		face.visible=not cut or (box.intersects_segment(head,eye)==null and box.intersects_segment(head+Vector3.UP*.60,eye)==null)
