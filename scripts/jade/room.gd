extends Node3D
@export var sight_sections: Dictionary={}
const Sight=preload("res://scripts/jade/sight_geometry.gd")
@export var floor_size:=Vector2(12.2,10.2)
@export var shell_kind: String="hall"
@export var wall_height:=4.7
const floor_level:=.08
var city: Node3D
@onready var wall_occluder:=get_node_or_null("OpaqueWalls") as OccluderInstance3D
var inside:=false
var using_cutaway:=false
var distant_proxy: MeshInstance3D
var interior_weight:=0.
func contains_position(point: Vector3) -> bool:
	var p:=to_local(point)
	if p.y<-.3 or p.y>=wall_height+(3.5 if has_node("UpperFloor") else 0.):return false
	var bounds:=Rect2(-floor_size*.5,floor_size)
	if shell_kind=="court" and p.x< -floor_size.x*.5:return Rect2(Vector2(-floor_size.x*.5-3.9,-floor_size.y*.5+.3),Vector2(4.,floor_size.y*.58)).has_point(Vector2(p.x,p.z))
	if shell_kind=="pavilion":return absf(p.x)/(.5*floor_size.x)+absf(p.z)/(.5*floor_size.y)<1.61 and bounds.has_point(Vector2(p.x,p.z))
	return bounds.has_point(Vector2(p.x,p.z))
func update_lighting(day: float) -> void:
	var light:=get_node_or_null("Furnishing/RoomLight") as OmniLight3D
	var energy:=lerpf(2.5,.85,day)
	if light and not is_equal_approx(light.light_energy,energy):light.light_energy=energy
func _process(delta: float) -> void:
	if not is_instance_valid(city) or not is_instance_valid(city.camera):return
	if not is_instance_valid(distant_proxy):distant_proxy=get_node_or_null("DistantShell") as MeshInstance3D
	if has_meta("player_prefab") and is_instance_valid(city.build_mode) and city.build_mode.active:
		var outside_view: bool = city.build_mode.roof_view
		$Exterior.visible = outside_view
		$HouseName.visible = outside_view
		if has_node("UpperFloor"): $UpperFloor.visible = outside_view
		if has_node("West/SideEaves"): $West/SideEaves.visible = outside_view
		var local_eye := to_local(city.camera.global_position)
		for face in ["Front","Rear","East","West"]:
			var toward: Vector3 = {"Front":Vector3.BACK,"Rear":Vector3.FORWARD,"East":Vector3.RIGHT,"West":Vector3.LEFT}[face]
			get_node(face).visible = outside_view or city.build_mode.show_roof or local_eye.dot(toward) < 0.
		using_cutaway = true
		return
	if has_node("West/SideEaves"): $West/SideEaves.show()
	var p:=to_local(city.bunny.global_position)
	var near_room:=p.length_squared()<760.
	if wall_occluder:wall_occluder.visible=not near_room
	var eye:=to_local(city.camera.global_position)
	var outside:=(Vector2(eye.x,eye.z).abs()-floor_size*.5).max(Vector2.ZERO)
	var height:=maxf(0.,absf(eye.y-wall_height*.5)-wall_height*.5)
	var distance_sq:=outside.length_squared()+height*height
	# Solid side and rear walls fully hide furnishings from the street. Open
	# theatres, pavilions, side courts and upper galleries can be seen from other sides.
	var open_side:=eye.z>floor_size.y*.5 or shell_kind in ["theatre","pavilion","court","loft","clocktower","inn"]
	var see_inside:=distance_sq<38.*38. and open_side
	var radius:=36. if distant_proxy and distant_proxy.visible else 43.
	var detail: bool=not distant_proxy or distance_sq<radius*radius
	if distant_proxy and distant_proxy.visible==detail:
		distant_proxy.visible=not detail;using_cutaway=false
		for part in get_children():
			if part is Node3D and part!=distant_proxy and part!=wall_occluder and part!=$Furnishing:part.visible=detail
	if not detail:
		$HouseName.visible=distance_sq<84.*84.
		$Furnishing.visible=see_inside
		inside=false;interior_weight=0.;return
	inside=contains_position(city.bunny.global_position)
	interior_weight=move_toward(interior_weight,1. if inside else 0.,delta*5.)
	$Furnishing.visible=near_room or see_inside
	var view:=preload("res://scripts/city/interior_view.gd").mode(city)
	var cut:=near_room and view!=1
	if not cut and not using_cutaway:return
	using_cutaway=cut
	var head:=p+Vector3.UP*1.1
	var bounds:=AABB(Vector3(-floor_size.x*.5,wall_height-.1,-floor_size.y*.5),Vector3(floor_size.x,.75,floor_size.y))
	var cut_roof:=cut and (inside or bounds.intersects_segment(head,eye)!=null or section_obstructs("Exterior",head,eye))
	if has_node("UpperFloor"):$UpperFloor.visible=not cut_roof or p.y>wall_height-1.
	$Exterior.visible=not cut_roof;$HouseName.visible=not cut_roof
	var w:=floor_size.x*.5;var d:=floor_size.y*.5;var full:=wall_height+(3.4 if has_node("UpperFloor") else 0.)
	for entry in [[$Front,Vector3(-w,0,d-.22),Vector3(2*w,full,.45)],[$Rear,Vector3(-w,0,-d-.22),Vector3(2*w,full,.45)],[$West,Vector3(-w-.22,0,-d),Vector3(.45,full,2*d)],[$East,Vector3(w-.22,0,-d),Vector3(.45,full,2*d)]]:
		var box:=AABB(entry[1],entry[2]).grow(.93 if has_node("UpperFloor") else .20)
		var blocked:=false
		if cut:
			for delta_ in [Vector3.ZERO,Vector3(.38,.62,0),Vector3(-.38,.62,0),Vector3(0,-.52,.26),Vector3(0,.70,-.31)]:
				if box.intersects_segment(head+delta_,eye)!=null:blocked=true;break
		if cut and not blocked:blocked=section_obstructs(str(entry[0].name),head,eye)
		entry[0].visible=not blocked

func section_obstructs(section_name: String,head: Vector3,eye: Vector3) -> bool:
	var section: Array = sight_sections.get(section_name,[])
	return Sight.obscures(section,head,eye) or Sight.clips_lens(section,self,eye,city.camera)
