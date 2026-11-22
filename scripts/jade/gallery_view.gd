extends Node3D
const Sight=preload("res://scripts/jade/sight_geometry.gd")
@export var hand:=1.
@export var sight_sections: Dictionary={}
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

	var auto_view:=preload("res://scripts/city/interior_view.gd").mode(city)!=1
	for side in [-1,1]:
		var wing: String="West" if side<0 else "East"
		var stair_z: float=p.z*side*hand
		var landing:=clampf((10.30-stair_z)/8.25,0.,1.)*4.48+.07
		var on_step:=absf(p.x-side*6.0)<1.13 and stair_z>=.62 and stair_z<=10.65 and absf(p.y-landing)<.65
		for rails: bool in [false,true]:
			var id:=wing+("Rails" if rails else "Flight")
			var shape: Array=sight_sections.get(id,[])
			var cut_stair: bool=auto_view and (rails or not on_step) and p.length_squared()<850.
			if cut_stair:
				cut_stair=Sight.obscures(shape,p+Vector3.UP*.88,eye) or Sight.clips_lens(shape,self,eye,city.camera)
			get_node(id).visible=not cut_stair
