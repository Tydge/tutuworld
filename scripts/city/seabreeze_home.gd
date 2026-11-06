extends Node3D
const View=preload("res://scripts/city/interior_view.gd")
const SleepPose=preload("res://scripts/characters/sleep_pose.gd")
## Seamless room visibility, real shadow-preserving cutaways, door and seating.
@export var floor_size:=Vector2(12,10)
@export var floor_level:=.18
@export var wall_height:=4.4
@export var roof_rise:=1.8
@export var door_width:=2.86
@export var door_height:=3.50
var assembling:=false
var city: Node3D
var inside:=false
var interior_weight:=0.0
var sections: Array[Dictionary]=[]
var door_open:=false
var door_angle:=0.0
var door_target:=0.0
var door_tweening:=false
var navigation_dirty:=false
var clock:=0.0
var last_view_mode:=-1
var roof_hidden:=false
var roof_candidate:=false
var roof_switch_elapsed:=0.0
var hinge: Node3D
var portal_shape: CollisionShape3D
var leaf_shape: CollisionShape3D
var key_light: SpotLight3D
var fill_light: OmniLight3D
var bedside: OmniLight3D
var porch: OmniLight3D
var hearth: SpotLight3D
var last_day:=-1.0
var blueprint: Dictionary
var pillow: MeshInstance3D
var quilt: MeshInstance3D
var quilt_occupancy:=0.0
var bed_occupant: CharacterBody3D
var occlusion_cache: Dictionary={}
func _ready() -> void:
	if assembling: return
	blueprint=get_meta("building_definition",{})
	if blueprint.is_empty(): blueprint=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/seabreeze_cottage.json"))
	for item in $Furnishing.get_children():
		if item.get_meta("module_type","")=="hearth":preload("res://scripts/city/hearth_backing.gd").repair_legacy(item)
	var candidate:=get_parent().get_parent()
	if candidate.has_method("update_target"): city=candidate
	hinge=get_node_or_null("Door/Hinge")
	if is_instance_valid(hinge):
		portal_shape=$Door/PortalCollision.get_child(0);leaf_shape=$Door/Hinge/LeafCollision.get_child(0)
		if blueprint.get("default_door_open",blueprint.get("id","")=="crafting_workshop"):
			door_open=true;door_angle=deg_to_rad(102);door_target=door_angle;hinge.rotation.y=door_angle
			portal_shape.set_deferred("disabled",true)
	key_light=get_node_or_null("Lighting/RoomKey");fill_light=get_node_or_null("Lighting/RoomFill");bedside=get_node_or_null("Lighting/BedsideLight");porch=get_node_or_null("Lighting/PorchLight");hearth=get_node_or_null("Lighting/HearthLight")
	for light in [key_light,fill_light,bedside,porch]:
		if is_instance_valid(light):preload("res://scripts/city/fixture_lighting.gd").configure(light)
	if is_instance_valid(hearth):preload("res://scripts/city/fire_flicker.gd").attach(hearth)
	register_cutaway($Structure/Roof,true)
	for wall in $Structure/Walls.get_children():
		wall.set_meta("view_face",str(wall.name));wall.set_meta("view_floor",floor_level)
		for data in blueprint.walls:
			if str(data.id)==str(wall.name):wall.set_meta("view_openings",data.openings)
		register_cutaway(wall,false)
	if is_instance_valid(hinge):
		for data in blueprint.walls:
			for opening in data.openings:
				if opening.type=="door":hinge.set_meta("view_face",str(data.id))
		register_cutaway(hinge,false);sections[-1]["door"]=true
	if has_node("PorchCanopy"): register_cutaway($PorchCanopy,true)
	quilt=get_node_or_null("Furnishing/bed/Quilt")
	pillow=get_node_or_null("Furnishing/bed/Pillow")
	update_lighting(1.0)
func register_cutaway(section: Node3D,roof: bool) -> void:
	var materials: Array[ShaderMaterial]=[]
	var glass: Array[GeometryInstance3D]=[]
	var visuals: Array[GeometryInstance3D]=[]
	var bounds:=AABB();var has_bounds:=false
	for part in section.find_children("*","MeshInstance3D",true,false):
		var old: Material=part.material_override
		var box: AABB=section.global_transform.affine_inverse()*part.global_transform*part.get_aabb();bounds=box if not has_bounds else bounds.merge(box);has_bounds=true
		visuals.append(part)
		if old is StandardMaterial3D and old.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:
			glass.append(part)
			continue
		if part.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var proxy:=MeshInstance3D.new();proxy.name="PersistentShadow";proxy.mesh=part.mesh;proxy.transform=part.transform;proxy.material_override=old;proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			part.get_parent().add_child(proxy);part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial
		if old is ShaderMaterial and old.shader==load("res://assets/shaders/home_surface.gdshader"): material=old.duplicate()
		else:
			material=ShaderMaterial.new();material.shader=load("res://assets/shaders/home_surface.gdshader")
			if old is StandardMaterial3D: material.set_shader_parameter("tint",old.albedo_color)
		if not roof: material.set_shader_parameter("cut_base_height",global_position.y+floor_level+.62)
		part.material_override=material;materials.append(material)
	sections.append({"node":section,"roof":roof,"bounds":bounds,"alpha":1.0,"target":1.0,"materials":materials,"glass":glass,"visuals":visuals,"labels":section.find_children("*","Label3D",true,false)})
func contains_position(point: Vector3) -> bool:
	var p:=to_local(point)
	if blueprint.has("floor_regions"):
		for region in blueprint.floor_regions:
			if Rect2(region[0],region[1],region[2],region[3]).grow(-.08).has_point(Vector2(p.x,p.z)) and p.y>-.1 and p.y<floor_level+wall_height-.2:return true
		return false
	return absf(p.x)<floor_size.x*.5-.1 and absf(p.z)<floor_size.y*.5-.1 and p.y>-.1 and p.y<floor_level+wall_height-.2
func toggle_door(actor: CharacterBody3D) -> Dictionary:
	if door_tweening: return {"ok":false,"message":"门正在慢慢打开。"}
	if door_open:door_target=0
	else: door_target=deg_to_rad(102 if $Door.to_local(actor.global_position).z>0 else -102)
	door_open=not door_open;door_tweening=true;navigation_dirty=true
	leaf_shape.set_deferred("disabled",true);portal_shape.set_deferred("disabled",true)
	return {"ok":true,"message":""}
func _physics_process(delta: float) -> void:
	if assembling or not is_instance_valid(hinge): return
	if door_tweening:
		door_angle=move_toward(door_angle,door_target,delta*deg_to_rad(170))
		hinge.rotation.y=door_angle
		var moving:=absf(door_angle-door_target)>.001
		leaf_shape.set_deferred("disabled",moving)
		portal_shape.set_deferred("disabled",moving or absf(door_angle)>deg_to_rad(70))
		if not moving:
			door_tweening=false
			if navigation_dirty and is_instance_valid(city) and is_instance_valid(city.navigation):
				navigation_dirty=false
				var bounds:=AABB($Door.to_global(Vector3(-3,-.1,-4)),Vector3.ZERO)
				for x in [-3,3]:
					for z in [-4,4]: bounds=bounds.expand($Door.to_global(Vector3(x,wall_height,z)))
				city.navigation.refresh_region(bounds)
func _process(delta: float) -> void:
	if assembling or not is_instance_valid(city) or not is_instance_valid(city.bunny): return
	clock+=delta
	var point: Vector3=city.bunny.get_global_transform_interpolated().origin
	var local:=to_local(point)
	inside=contains_position(point)
	var edge: float=minf(floor_size.x*.5-absf(local.x),floor_size.y*.5-absf(local.z))
	var target_weight: float=smoothstep(-.25,.9,edge) if local.y<wall_height-1.0 else 0.0
	if blueprint.has("floor_regions") and not inside:target_weight=0.
	interior_weight=move_toward(interior_weight,target_weight,delta*3.5)
	var from:=to_local(point+Vector3(0,1.65,0))
	var camera:=to_local(city.camera.position)
	var room:=AABB(Vector3(-floor_size.x*.5-.3,0,-floor_size.y*.5-.3),Vector3(floor_size.x+.6,wall_height+roof_rise+.5,floor_size.y+.6))
	var obstructs: bool=room.intersects_segment(from,camera)!=null
	var candidate_hidden:=inside or obstructs
	# Hold a cutaway across small boundary/camera changes instead of toggling every frame.
	if roof_hidden and not candidate_hidden:
		var expanded:=room.grow(.6)
		candidate_hidden=expanded.intersects_segment(from,camera)!=null
	if candidate_hidden!=roof_candidate:
		roof_candidate=candidate_hidden;roof_switch_elapsed=0.0
	roof_switch_elapsed+=delta
	if inside or roof_switch_elapsed>=(.10 if roof_candidate else .25): roof_hidden=roof_candidate
	var view_mode:=View.mode(city);var view_changed:=view_mode!=last_view_mode;last_view_mode=view_mode
	var remove_roof:=roof_hidden
	if view_mode==View.FULL:roof_hidden=false
	if view_mode!=View.AUTO:remove_roof=false
	var occluded:=View.sample_targets(sections,city.camera.global_position,point,occlusion_cache,view_changed) if view_mode==View.OCCLUSION and (inside or obstructs) else {}
	if view_mode==View.OCCLUSION:roof_hidden=false
	for section in sections:
		var hide_section:=false
		if section.roof: hide_section=remove_roof
		elif section.has("parent_wall"):
			for wall_section in sections:
				if wall_section.node==section.parent_wall:hide_section=wall_section.target<.5;break
		elif section.get("door",false): hide_section=inside and camera.z>from.z+.1
		elif remove_roof:
			var center: Vector3=section.node.position+Vector3(0,2.1,0)
			var normal: Vector3=section.node.get_meta("outward",Vector3.ZERO)
			var half_width: float=float(section.node.get_meta("length",floor_size.x))*.5+.2
			var relative_from: Vector3=section.node.to_local(to_global(from))
			var relative_camera: Vector3=section.node.to_local(to_global(camera))
			var slab:=AABB(Vector3(-half_width,-.1,-.30),Vector3(half_width*2,wall_height+.25,.60))
			hide_section=slab.intersects_segment(relative_from,relative_camera)!=null
			# Wider cutaways make the full room readable instead of a narrow peephole.
			if inside and normal.dot(camera-center)>.15: hide_section=true
		var previous_alpha: float=section.alpha
		var alpha: float
		if view_mode==View.OCCLUSION:
			alpha=View.fade(section,occluded.has(View.face(section)),delta)
			if section.roof and section.target<.5:roof_hidden=true
		else:
			section.erase("occlusion_hold")
			if view_mode==View.FULL:hide_section=false
			section.target=0.0 if hide_section else 1.0;alpha=move_toward(section.alpha,section.target,delta*5.0);section.alpha=alpha
		if not view_changed and is_equal_approx(alpha,previous_alpha):continue
		for material in section.materials:
			material.set_shader_parameter("camera_occlusion",view_mode==View.OCCLUSION);material.set_shader_parameter("opacity",alpha);material.set_shader_parameter("cut_base_height",-100. if section.roof or view_mode==View.OCCLUSION else global_position.y+floor_level+.62)
		for visual in section.visuals:
			if not section.glass.has(visual):View.set_visual_visible(visual,alpha>.002 or (not section.roof and view_mode==View.AUTO),view_mode==View.OCCLUSION)
		for pane in section.glass:View.set_visual_visible(pane,alpha>.40,view_mode==View.OCCLUSION)
		for label in section.labels:label.visible=alpha>.70

	if is_instance_valid(quilt):
		var occupied: bool=bed_occupant.sleeping if is_instance_valid(bed_occupant) else city.sleep_active and city.get_meta("sleeping_bed",null)==get_node("Furnishing/bed")
		if not occupied and quilt_occupancy<=0.:return
		quilt_occupancy=move_toward(quilt_occupancy,1.0 if occupied else 0.0,delta*2.2)
		quilt.material_override.set_shader_parameter("occupancy",quilt_occupancy)
		var profile: Resource=bed_occupant.rig_profile if is_instance_valid(bed_occupant) else city.bunny.rig_profile
		var pose:=SleepPose.layout(profile)
		quilt.material_override.set_shader_parameter("cover_height",pose.cover_height)
		quilt.material_override.set_shader_parameter("cover_width",maxf(.75,profile.body_radii.x+.42))
		if is_instance_valid(pillow):
			var height_: float=lerpf(.20,pose.pillow_height,quilt_occupancy)
			pillow.scale.y=height_/.20;pillow.position.y=.90+height_*.5
func update_lighting(day: float) -> void:
	if assembling:return
	last_day=day
	if is_instance_valid(key_light):key_light.light_energy=lerpf(4.2,3.5,day)
	if is_instance_valid(fill_light):fill_light.light_energy=lerpf(1.55,1.25,day)
	if is_instance_valid(bedside): bedside.light_energy=lerpf(1.0,.30,day)
	if is_instance_valid(porch): porch.light_energy=lerpf(2.2,.05,day)
func door_action_position() -> Vector3: return $Door/ActionAnchor.global_position
func seat_node(id: String) -> Node3D:
	return $Furnishing/sofa if id=="home_sofa" else $Furnishing/desk
