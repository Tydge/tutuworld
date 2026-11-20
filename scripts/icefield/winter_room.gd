extends Node3D
const View=preload("res://scripts/city/interior_view.gd")
const floor_size:=Vector2(10.8,9.2)
const floor_level:=.12
const wall_height:=5.5
const BOUNDS:=AABB(Vector3(-5.6,0,-5.3),Vector3(11.2,8.7,10.9))
var interior_weight:=0.
var inside:=false
var city: Node3D
var cutaway:=false
var exterior_shadow_modes: Dictionary={}

func _ready() -> void:
	for part in $Exterior.get_children():exterior_shadow_modes[part]=part.cast_shadow

func contains_position(point: Vector3) -> bool:
	var p:=to_local(point)
	return absf(p.x)<5.25 and absf(p.z)<4.5 and p.y>-.15 and p.y<wall_height

func update_lighting(day: float) -> void:
	var light:=get_node_or_null("Furnishing/RoomFill") as OmniLight3D
	if light:light.light_energy=lerpf(1.5,.85,day)

func _process(delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.camera):return
	var actor:=to_local(city.bunny.get_global_transform_interpolated().origin)
	var camera:=to_local(city.camera.global_position)
	var close:=actor.length_squared()<400.
	if not close and not cutaway and not $Furnishing.visible and interior_weight==0.:return
	inside=absf(actor.x)<5.25 and absf(actor.z)<4.5 and actor.y>-.15 and actor.y<wall_height
	var edge:=minf(5.4-absf(actor.x),4.6-absf(actor.z))
	interior_weight=move_toward(interior_weight,smoothstep(-.25,.9,edge) if actor.y<wall_height else 0.,delta*4.)
	$Furnishing.visible=close
	var head:=actor+Vector3.UP*1.35
	var obstructs:=BOUNDS.intersects_segment(head,camera)!=null
	var reveal:=View.mode(city)!=View.FULL and (inside or obstructs)
	if reveal!=cutaway:
		cutaway=reveal
		if has_node("HouseName"):$HouseName.visible=not reveal
		$Sections.visible=reveal
		for mesh in $Exterior.get_children():
			var shadow_mode: int=exterior_shadow_modes[mesh]
			mesh.visible=not reveal or shadow_mode!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if reveal else shadow_mode
	if not reveal:return
	$Sections/Roof.visible=false
	$Sections/Front.visible=camera.z<4.45
	$Sections/Back.visible=camera.z> -4.45
	$Sections/East.visible=camera.x<5.22
	$Sections/West.visible=camera.x> -5.22
