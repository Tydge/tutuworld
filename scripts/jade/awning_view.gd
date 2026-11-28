extends Node3D
## A player's view can pass under a canopy while the counter, stock and posts stay in place.
const Sight = preload("res://scripts/jade/sight_geometry.gd")
@export var sight_sections: Dictionary = {}

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var camera := get_viewport().get_camera_3d()
	var city := camera.get_parent() if camera else null
	var cloth := get_node_or_null("Canopy") as Node3D
	if cloth == null:
		return
	if city and city.has_method("update_camera") and is_instance_valid(city.build_mode) and city.build_mode.active and get_parent().get_parent().get_meta("furniture_kind","") == "jade_gallery":
		cloth.visible = city.build_mode.roof_view
		return
	if not city or not city.has_method("update_camera") or not is_instance_valid(city.bunny) or (is_instance_valid(city.build_mode) and city.build_mode.active):
		cloth.visible = true
		return
	var actor := to_local(city.bunny.global_position)
	if actor.length_squared() > 28.*28.:
		cloth.visible = true
		return
	if preload("res://scripts/city/interior_view.gd").mode(city)==1:
		cloth.visible=true
		return
	var eye := to_local(camera.global_position)
	var section: Array = sight_sections.get("Canopy",[])
	cloth.visible = not (Sight.obscures(section,actor + Vector3.UP*1.1,eye) or Sight.clips_lens(section,self,eye,camera))
