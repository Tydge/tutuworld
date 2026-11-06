extends Node
## One current-frame render per distinct visible plane/compact cluster, shared by
## all its mirrors. No face-count cap, temporal throttling or quality budget cuts.
const View=preload("res://scripts/city/interior_view.gd")
const PlaneView=preload("res://scripts/city/mirror_plane.gd")
const FACE_LAYER:=1<<19
const MIN_HEIGHT:=64
const MAX_HEIGHT:=640
const MAX_TARGET_EDGE:=4096
const MAX_EMPTY_RATIO:=3.0
var city: Node3D
var mirrors: Array=[]
var slots: Array=[]
var render_count:=0
var active_count:=0
var active_view_count:=0
var face_update_count:=0
var share_coplanar:=true # Reference/diagnostic path; never a user quality setting.
var process_usec:=0
var occluders: Node
var use_wall_occlusion:=true
var fixed_density:=0. # Matched sampling grid for reference image tests only.
var _main_occlusion:=false
var _main_occlusion_saved:=false
var _main_viewport: WeakRef
var _hidden_key:=""
var _hidden: Array[RID]=[]
static func attach(host: Node3D,module: Node3D,building: Node3D) -> void:
	var face: MeshInstance3D=module.find_child("MirrorFace",true,false)
	if face==null:return
	face.material_override=face.material_override.duplicate()
	var manager=host.get_node_or_null("MirrorReflections")
	if manager==null:manager=load("res://scripts/city/mirror_reflections.gd").new();manager.name="MirrorReflections";manager.city=host;host.add_child(manager)
	var bodies: Array[RID]=[]
	for body in module.find_children("*","CollisionObject3D",true,false):bodies.append(body.get_rid())
	manager.mirrors.append({"face":weakref(face),"building":weakref(building),"bodies":bodies,"transform":Transform3D(),"geometry":{}})
func actual_building(building: Node3D) -> bool:
	return is_instance_valid(city.build_mode) and building==city.build_mode.room
func hidden_bodies(building: Node3D) -> Array[RID]:
	var key:=str([building.get_instance_id(),building.storey_view_key,building.mask_key,building.last_view_key,building.material_updates,city.build_mode.layout_revision])
	if key==_hidden_key:return _hidden
	_hidden_key=key;_hidden.assign(building.hidden_camera_bodies)
	for section in building.sections:
		if section.node.is_visible_in_tree() and not section.get("editor_hidden",false) and section.get("alpha",1.)>.002:continue
		for body in section.node.find_children("*","StaticBody3D",true,false):_hidden.append(body.get_rid())
	return _hidden
func visible_from(face: MeshInstance3D,geometry: Dictionary,excluded: Array[RID]) -> bool:
	# Ignore physics retained by hidden editor shells. A centre occluder alone is
	# not enough to reject a partly visible ellipse.
	for point in [Vector2.ZERO,Vector2(-.35,0),Vector2(.35,0),Vector2(0,-.35),Vector2(0,.35)]:
		var target: Vector3=face.global_position+geometry.dx*point.x+geometry.dy*point.y
		var ray:=PhysicsRayQueryParameters3D.create(city.camera.global_position,target,13,excluded)
		if city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return true
	return false
func projection(face: MeshInstance3D,geometry: Dictionary,frustum: Array[Plane]) -> Dictionary:
	var camera_: Camera3D=city.camera
	if not face.is_visible_in_tree() or (camera_.global_position-face.global_position).dot(geometry.normal)<.025 or camera_.is_position_behind(face.global_position):return {}
	var points: Array[Vector2]=[]
	for p in geometry.corners:points.append(camera_.unproject_position(p))
	var area:=Rect2(points[0],Vector2.ZERO)
	for p in points:area=area.expand(p)
	var screen:=get_viewport().get_visible_rect()
	if area.intersection(screen).get_area()<4.:return {}
	var extent: Vector2=face.mesh.size
	var height_: float=maxf(maxf(points[0].distance_to(points[3]),points[1].distance_to(points[2])),maxf(points[0].distance_to(points[1]),points[2].distance_to(points[3]))*extent.y/extent.x)*get_viewport().scaling_3d_scale
	var pixels:=clampi(ceili(height_/32.)*32,MIN_HEIGHT,MAX_HEIGHT)
	var rect: Rect2=geometry.rect if screen.encloses(area) else PlaneView.clipped_rect(geometry,frustum)
	if rect.size.x<.0001 or rect.size.y<.0001:return {}
	return {"rect":rect,"density":float(pixels)/geometry.dy.length()}
func cluster(candidates: Array) -> Array:
	var planes: Dictionary={};var result: Array=[]
	for candidate in candidates:
		var geometry: Dictionary=candidate.geometry;var plane_key: String=geometry.key if share_coplanar else str(candidate.face.get_instance_id())
		if not planes.has(plane_key):planes[plane_key]=[]
		var chosen: Dictionary={};var best:=INF
		for group in planes[plane_key]:
			var rect: Rect2=group.rect.merge(candidate.rect);var density: float=maxf(group.density,candidate.density);var size_:=PlaneView.size_for(rect,density)
			# Large empty gaps or a close mirror beside tiny distant ones are cheaper
			# to capture independently. Splitting never lowers their pixel density.
			if rect.get_area()>(group.area+candidate.rect.get_area())*MAX_EMPTY_RATIO or maxi(size_.x,size_.y)>MAX_TARGET_EDGE or density>minf(group.min_density,candidate.density)*2.:continue
			var growth: float=rect.get_area()-group.rect.get_area()
			if growth<best:chosen=group;best=growth
		if chosen.is_empty():
			chosen={"key":plane_key+"/"+str(planes[plane_key].size()),"geometry":geometry,"rect":candidate.rect,"density":candidate.density,"min_density":candidate.density,"area":0.,"members":[]};planes[plane_key].append(chosen);result.append(chosen)
		chosen.rect=chosen.rect.merge(candidate.rect);chosen.density=maxf(chosen.density,candidate.density);chosen.min_density=minf(chosen.min_density,candidate.density);chosen.area+=candidate.rect.get_area();chosen.members.append(candidate)
	return result
func make_slot(key: String) -> Dictionary:
	var viewport:=SubViewport.new();viewport.name="MirrorView";viewport.size=Vector2i(2,2);viewport.world_3d=city.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_2X;viewport.positional_shadow_atlas_size=0;viewport.gui_disable_input=true;add_child(viewport)
	var camera_:=Camera3D.new();camera_.name="ReflectionCamera";camera_.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;viewport.add_child(camera_);camera_.current=true
	var source: Environment=city.camera.environment if city.camera.environment!=null else city.get_world_3d().environment
	if source!=null:
		camera_.environment=source.duplicate();camera_.environment.ssao_enabled=false;camera_.environment.ssil_enabled=false;camera_.environment.ssr_enabled=false;camera_.environment.glow_enabled=false
	return {"key":key,"viewport":viewport,"camera":camera_,"faces":[],"ready_frame":-1,"confirmed":false,"updates":0,"blend":0.,"binding":"","density":0.,"idle":0.,"bound_faces":[],"shrink_size":Vector2i.ZERO,"shrink_time":0. }
func slot_for(face: MeshInstance3D) -> Dictionary:
	for slot in slots:
		if slot.faces.has(face):return slot
	return {}
func unbind(face: Variant) -> void:
	if not is_instance_valid(face):return
	face.material_override.set_shader_parameter("reflection_ready",false);face.material_override.set_shader_parameter("reflection_mix",0.);face.material_override.set_shader_parameter("reflection_texture",null)
func bind_group(slot: Dictionary,group: Dictionary,rect: Rect2) -> void:
	var faces: Array=[];var all_faces: Array=[];var fingerprint: Array=[rect]
	for member in group.members:faces.append(member.face)
	for member in group.get("binding_members",group.members):all_faces.append(member.face);fingerprint.append([member.face.get_instance_id(),member.face.global_transform])
	var binding:=str(fingerprint)
	if slot.binding!=binding:
		for member in group.get("binding_members",group.members):
			var face: MeshInstance3D=member.face;var material: ShaderMaterial=face.material_override;var mapping:=PlaneView.uv(member.geometry,rect)
			if material.get_shader_parameter("reflection_texture")!=slot.viewport.get_texture():
				material.set_shader_parameter("reflection_texture",slot.viewport.get_texture());material.set_shader_parameter("reflection_ready",slot.confirmed);material.set_shader_parameter("reflection_mix",slot.blend)
			material.set_shader_parameter("reflection_uv_x",mapping[0]);material.set_shader_parameter("reflection_uv_y",mapping[1])
		slot.binding=binding
	slot.faces=faces;slot.bound_faces=all_faces;slot.idle=0.

func _process(delta: float) -> void:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(city) or not is_instance_valid(city.camera):return
	var started:=Time.get_ticks_usec()
	if occluders==null:occluders=preload("res://scripts/city/mirror_occluders.gd").new();occluders.name="MirrorOccluders";occluders.city=city;add_child(occluders)
	var has_occluders: bool=occluders.sync() and use_wall_occlusion
	if not _main_occlusion_saved:_main_occlusion=city.get_viewport().use_occlusion_culling;_main_viewport=weakref(city.get_viewport());_main_occlusion_saved=true
	# Native occluders are shared by the World3D. In free occlusion they keep
	# solid reflection walls, so the main camera must not cull through those walls.
	var room: Node3D=city.build_mode.room
	var free_occlusion: bool=is_instance_valid(room) and not room.editor_active and View.mode(city)==View.OCCLUSION
	city.get_viewport().use_occlusion_culling=(_main_occlusion or has_occluders) and not free_occlusion
	var plane_bounds: Dictionary={}
	var candidates: Array=[];var retained: Array=[];var frustum: Array[Plane]=city.camera.get_frustum()
	for entry in mirrors:
		var face: MeshInstance3D=entry.face.get_ref();var building: Node3D=entry.building.get_ref()
		if not is_instance_valid(face) or not is_instance_valid(building):continue
		retained.append(entry)
		if not actual_building(building):continue
		if entry.geometry.is_empty() or entry.transform!=face.global_transform:
			entry.transform=face.global_transform;entry.geometry=PlaneView.describe(face)
		if not face.is_visible_in_tree():continue
		var geometry: Dictionary=entry.geometry
		if not plane_bounds.has(geometry.key):plane_bounds[geometry.key]={"rect":geometry.rect,"area":0.,"members":[]}
		plane_bounds[geometry.key].rect=plane_bounds[geometry.key].rect.merge(geometry.rect);plane_bounds[geometry.key].area+=geometry.rect.get_area();plane_bounds[geometry.key].members.append({"face":face,"geometry":geometry})
		var projected:=projection(face,entry.geometry,frustum)
		if projected.is_empty():continue
		var excluded: Array[RID]=hidden_bodies(building).duplicate();excluded.append_array(entry.bodies)
		if not visible_from(face,entry.geometry,excluded):continue
		projected.face=face;projected.geometry=entry.geometry;candidates.append(projected)
	mirrors=retained;active_count=candidates.size()
	var groups:=cluster(candidates);var plane_counts: Dictionary={}
	for group in groups:plane_counts[group.geometry.key]=int(plane_counts.get(group.geometry.key,0))+1
	active_view_count=groups.size();var active_keys: Dictionary={}
	for group in groups:
		active_keys[group.key]=true
	# Keep texture bindings while a cached view is off-screen. Rebinding a
	# ViewportTexture at every screen edge causes Metal dependency/driver stalls.
	for slot in slots.duplicate():
		if active_keys.has(slot.key):continue
		slot.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		slot.faces=[];slot.binding="";slot.idle+=delta
		if slot.idle>30.:
			for entry in mirrors:
				var face: MeshInstance3D=entry.face.get_ref()
				if is_instance_valid(face) and face.material_override.get_shader_parameter("reflection_texture")==slot.viewport.get_texture():unbind(face)
			slot.viewport.queue_free();slots.erase(slot)
	for group in groups:
		var matching: Array=slots.filter(func(item):return item.key==group.key);var slot: Dictionary
		if matching.is_empty():slot=make_slot(group.key);slots.append(slot)
		else:slot=matching[0]
		# Retain density while a small projection shrinks, without reducing detail
		# when it grows. This is allocation hysteresis, not temporal upsampling.
		if slot.density==0. or group.density>slot.density or group.density<slot.density*.65:slot.density=group.density
		if fixed_density>0.:slot.density=fixed_density
		var reserved: Rect2=group.rect
		var bounds: Dictionary=plane_bounds[group.geometry.key]
		if share_coplanar and plane_counts[group.geometry.key]==1 and bounds.rect.get_area()<=bounds.area*MAX_EMPTY_RATIO and maxi(PlaneView.size_for(bounds.rect,slot.density).x,PlaneView.size_for(bounds.rect,slot.density).y)<=MAX_TARGET_EDGE:reserved=bounds.rect;group.binding_members=bounds.members
		var desired:=PlaneView.size_for(reserved,slot.density);var size_: Vector2i=slot.viewport.size
		var bucket:=Vector2i(int(nearest_po2(desired.x)),int(nearest_po2(desired.y)))
		if bucket!=slot.shrink_size:slot.shrink_size=bucket;slot.shrink_time=0.
		else:slot.shrink_time+=delta
		for axis in [0,1]:
			if bucket[axis]>size_[axis] or (bucket[axis]<size_[axis] and bucket.x*bucket.y<size_.x*size_.y*.25 and slot.shrink_time>1.):size_[axis]=bucket[axis]
		if fixed_density>0.:size_=desired
		if slot.viewport.size!=size_:slot.viewport.size=size_
		var capture_density: float=minf((size_.x-2)/maxf(.0001,reserved.size.x),(size_.y-2)/maxf(.0001,reserved.size.y)) if fixed_density<=0. else slot.density
		var rect:=PlaneView.capture_rect(reserved,size_,capture_density)
		slot.viewport.use_occlusion_culling=has_occluders
		bind_group(slot,group,rect)
		if slot.ready_frame>=0 and Engine.get_frames_drawn()>slot.ready_frame:
			var blend:=minf(1.,slot.blend+delta*8.)
			if not slot.confirmed or blend!=slot.blend:
				slot.confirmed=true;slot.blend=blend
				for face in slot.bound_faces:
					if is_instance_valid(face):face.material_override.set_shader_parameter("reflection_ready",true);face.material_override.set_shader_parameter("reflection_mix",blend)
		slot.camera.cull_mask=(city.camera.cull_mask & ~FACE_LAYER) | View.REFLECTION_LAYER
		if slot.camera.environment!=null and is_instance_valid(city.atmosphere):
			for property in ["ambient_light_energy","ambient_light_color","tonemap_exposure","tonemap_mode"]:
				var value: Variant=city.atmosphere.get(property)
				if slot.camera.environment.get(property)!=value:slot.camera.environment.set(property,value)
		if PlaneView.pose(slot.camera,city.camera.global_position,group.geometry,rect):
			slot.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;render_count+=1;slot.updates+=1;face_update_count+=slot.faces.size()
			if slot.ready_frame<0:slot.ready_frame=Engine.get_frames_drawn()
	process_usec=Time.get_ticks_usec()-started

func _exit_tree() -> void:
	if _main_occlusion_saved:
		var viewport: Viewport=_main_viewport.get_ref()
		if is_instance_valid(viewport):viewport.use_occlusion_culling=_main_occlusion
