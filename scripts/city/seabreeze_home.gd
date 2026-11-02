extends Node3D
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
func _ready() -> void:
	if assembling: return
	blueprint=get_meta("building_definition",{})
	if blueprint.is_empty(): blueprint=JSON.parse_string(FileAccess.get_file_as_string("res://data/houses/seabreeze_cottage.json"))
	var candidate:=get_parent().get_parent()
	if candidate.has_method("update_target"): city=candidate
	hinge=get_node_or_null("Door/Hinge")
	if is_instance_valid(hinge):
		portal_shape=$Door/PortalCollision.get_child(0);leaf_shape=$Door/Hinge/LeafCollision.get_child(0)
	key_light=$Lighting/RoomKey;fill_light=$Lighting/RoomFill;bedside=get_node_or_null("Lighting/BedsideLight");porch=get_node_or_null("Lighting/PorchLight");hearth=get_node_or_null("Lighting/HearthLight")
	register_cutaway($Structure/Roof,true)
	for wall in $Structure/Walls.get_children(): register_cutaway(wall,false)
	if is_instance_valid(hinge):
		register_cutaway(hinge,false);sections[-1]["door"]=true
	if has_node("PorchCanopy"): register_cutaway($PorchCanopy,true)
	quilt=get_node_or_null("Furnishing/bed/Quilt")
	pillow=get_node_or_null("Furnishing/bed/Pillow")
	update_lighting(1.0)
func register_cutaway(section: Node3D,roof: bool) -> void:
	var materials: Array[ShaderMaterial]=[]
	var glass: Array[GeometryInstance3D]=[]
	var visuals: Array[GeometryInstance3D]=[]
	for part in section.find_children("*","MeshInstance3D",true,false):
		var old: Material=part.material_override
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
	sections.append({"node":section,"roof":roof,"alpha":1.0,"target":1.0,"materials":materials,"glass":glass,"visuals":visuals,"labels":section.find_children("*","Label3D",true,false)})
func contains_position(point: Vector3) -> bool:
	var p:=to_local(point)
	return absf(p.x)<floor_size.x*.5-.1 and absf(p.z)<floor_size.y*.5-.1 and p.y>-.1 and p.y<floor_level+wall_height-.2
func toggle_door(actor: CharacterBody3D) -> Dictionary:
	if door_tweening: return {"ok":false,"message":"门正在慢慢打开。"}
	if door_open:
		# Do not sweep a physical door through a character.
		var minimum: float=-door_width-1.0 if door_target>0 else -.5
		var maximum: float=.7 if door_target>0 else door_width+1.5
		var actors: Array=[actor]
		if is_instance_valid(city): actors.append_array(city.npcs)
		if is_instance_valid(city) and city.has_method("online_players"):actors.append_array(city.online_players())
		for other in actors:
			var p: Vector3=$Door.to_local(other.global_position)
			if absf(p.x)<door_width*.5+.95 and p.z>minimum and p.z<maximum: return {"ok":false,"message":"先让开门扇的位置，再关门吧。"}
		door_target=0
	else: door_target=deg_to_rad(102 if $Door.to_local(actor.global_position).z>0 else -102)
	door_open=not door_open;door_tweening=true;navigation_dirty=true
	return {"ok":true,"message":""}
func _physics_process(delta: float) -> void:
	if assembling or not is_instance_valid(hinge): return
	if door_tweening:
		door_angle=move_toward(door_angle,door_target,delta*deg_to_rad(170))
		hinge.rotation.y=door_angle
		var moving:=absf(door_angle-door_target)>.001
		leaf_shape.set_deferred("disabled",moving)
		portal_shape.set_deferred("disabled",absf(door_angle)>deg_to_rad(70))
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
	var remove_roof:=roof_hidden
	for section in sections:
		var hide_section:=false
		if section.roof: hide_section=remove_roof
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
		section.target=0.0 if hide_section else 1.0
		var alpha: float=move_toward(section.alpha,section.target,delta*5.0)
		if is_equal_approx(alpha,section.alpha): continue
		section.alpha=alpha
		for material in section.materials: material.set_shader_parameter("opacity",alpha)
		for visual in section.visuals: visual.visible=alpha>.002 or not section.roof
		for pane in section.glass: pane.visible=alpha>.40
		for label in section.labels: label.visible=alpha>.70
	if is_instance_valid(quilt):
		var occupied: bool=bed_occupant.sleeping if is_instance_valid(bed_occupant) else city.sleep_active
		quilt_occupancy=move_toward(quilt_occupancy,1.0 if occupied else 0.0,delta*2.2)
		quilt.material_override.set_shader_parameter("occupancy",quilt_occupancy)
		var profile: Resource=bed_occupant.rig_profile if is_instance_valid(bed_occupant) else city.bunny.rig_profile
		var pose:=SleepPose.layout(profile)
		quilt.material_override.set_shader_parameter("cover_height",pose.cover_height)
		quilt.material_override.set_shader_parameter("cover_width",maxf(.75,profile.body_radii.x+.42))
		if is_instance_valid(pillow):
			var height_: float=lerpf(.20,pose.pillow_height,quilt_occupancy)
			pillow.scale.y=height_/.20;pillow.position.y=.90+height_*.5
	if is_instance_valid(hearth): hearth.light_energy=(.55+(1-last_day)*.45)*(1+.025*sin(clock*4)+.014*sin(clock*7.7))
func update_lighting(day: float) -> void:
	if assembling or not is_instance_valid(key_light): return
	last_day=day
	key_light.light_energy=lerpf(4.2,3.5,day)
	fill_light.light_energy=lerpf(1.55,1.25,day)
	if is_instance_valid(bedside): bedside.light_energy=lerpf(1.0,.30,day)
	if is_instance_valid(porch): porch.light_energy=lerpf(2.2,.05,day)
func door_action_position() -> Vector3: return $Door/ActionAnchor.global_position
func seat_node(id: String) -> Node3D:
	return $Furnishing/sofa if id=="home_sofa" else $Furnishing/desk
