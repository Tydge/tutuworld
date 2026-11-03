extends Node
## Only an occupied bed animates its own covers; all bed geometry keeps the shared pose.
var bed: Node3D
var city: Node3D
var occupancy:=0.
var quilt: MeshInstance3D
var pillow: MeshInstance3D
func _ready() -> void:
	for mesh in bed.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name)=="Quilt":quilt=mesh
		if str(mesh.name)=="Pillow":pillow=mesh
func _process(delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.bunny):return
	var occupied: bool=city.sleep_active and city.get_meta("sleeping_bed",null)==bed
	if not occupied and occupancy<=0.:return
	occupancy=move_toward(occupancy,1. if occupied else 0.,delta*2.2)
	var pose:=preload("res://scripts/characters/sleep_pose.gd").layout(city.bunny.rig_profile)
	if is_instance_valid(quilt):
		quilt.material_override.set_shader_parameter("occupancy",occupancy);quilt.material_override.set_shader_parameter("cover_height",pose.cover_height);quilt.material_override.set_shader_parameter("cover_width",maxf(.75,city.bunny.rig_profile.body_radii.x+.42))
	if is_instance_valid(pillow):
		var tall:=lerpf(.20,pose.pillow_height,occupancy);pillow.scale.y=tall/.20;pillow.position.y=.90+tall*.5
