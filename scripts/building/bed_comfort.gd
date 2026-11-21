extends Node
## Only an occupied bed animates its own covers; all bed geometry keeps the shared pose.
var bed: Node3D
var city: Node3D
var occupancy:=0.
var target_id: String
var own_quilt:=false
var quilt: MeshInstance3D
var pillow: MeshInstance3D
func _ready() -> void:
	for mesh in bed.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name)=="Quilt" and mesh.material_override is ShaderMaterial:
			quilt=mesh
			if own_quilt:quilt.material_override=quilt.material_override.duplicate()
		if str(mesh.name)=="Pillow":pillow=mesh
func _process(delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.bunny):return
	var occupant: CharacterBody3D=city.bunny
	var occupied: bool=city.sleep_active and city.get_meta("sleeping_bed",null)==bed
	if not occupied and city.session.is_online() and is_instance_valid(city.online_view):
		for id in city.online_view.motion:
			var pose: Dictionary=city.online_view.motion[id].get("pose",{})
			if pose.get("kind","")=="sleep" and pose.get("target","")==target_id:
				var actor=city.online_view.actor_for(id)
				if is_instance_valid(actor):occupant=actor;occupied=true;break
	if not occupied and occupancy<=0.:return
	occupancy=move_toward(occupancy,1. if occupied else 0.,delta*2.2)
	var pose:=preload("res://scripts/characters/sleep_pose.gd").layout(occupant.rig_profile)
	if is_instance_valid(quilt):
		quilt.material_override.set_shader_parameter("occupancy",occupancy);quilt.material_override.set_shader_parameter("cover_height",pose.cover_height);quilt.material_override.set_shader_parameter("cover_width",maxf(.75,occupant.rig_profile.body_radii.x+.42))
	if is_instance_valid(pillow):
		var tall:=lerpf(.20,pose.pillow_height,occupancy);pillow.scale.y=tall/.20;pillow.position.y=.90+tall*.5

static func attach(node: Node3D,host: Node3D,id: String,unique_quilt: bool=false) -> void:
	if node.has_node("BedComfort"):return
	var comfort=load("res://scripts/building/bed_comfort.gd").new()
	comfort.name="BedComfort";comfort.bed=node;comfort.city=host;comfort.target_id=id;comfort.own_quilt=unique_quilt
	node.add_child(comfort)
