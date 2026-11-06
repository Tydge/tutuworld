extends Node
## Two cropped planar views at most; hidden, distant and back-facing mirrors cost no draws.
const MAX_ACTIVE:=2
const INTERVAL:=1./30.
const FACE_LAYER:=1<<19
var city: Node3D
var mirrors: Array=[]
var slots: Array=[]
var elapsed:=0.
var cursor:=0
var render_count:=0
var active_count:=0
var last_eye:=Vector3.INF
static func attach(host: Node3D,module: Node3D,building: Node3D) -> void:
	var face: MeshInstance3D=module.find_child("MirrorFace",true,false)
	if face==null:return
	face.material_override=face.material_override.duplicate()
	var manager=host.get_node_or_null("MirrorReflections")
	if manager==null:manager=load("res://scripts/city/mirror_reflections.gd").new();manager.name="MirrorReflections";manager.city=host;host.add_child(manager)
	manager.mirrors.append({"face":weakref(face),"building":weakref(building)})
static func pose(camera_: Camera3D,eye: Vector3,face: MeshInstance3D) -> bool:
	var center:=face.global_position;var normal:=face.global_basis.z.normalized();var up:=face.global_basis.y.normalized();var distance: float=(eye-center).dot(normal)
	if distance<.06:return false
	var reflected:=eye-normal*(2.*distance)
	camera_.global_transform=Transform3D(Basis(-face.global_basis.x.normalized(),up,-normal),reflected)
	var point:=camera_.to_local(center);var near_:=distance+.012;var factor:=near_/distance;var extent: Vector2=face.mesh.size
	camera_.keep_aspect=Camera3D.KEEP_HEIGHT
	camera_.set_frustum(extent.y*factor,Vector2(point.x,point.y)*factor,near_,distance+55.)
	return true
func actual_building(building: Node3D) -> bool:
	return is_instance_valid(city.build_mode) and building==city.build_mode.room
func score(face: MeshInstance3D,camera_: Camera3D) -> float:
	if not face.is_visible_in_tree():return 0.
	var difference:=camera_.global_position-face.global_position;var distance:=difference.length()
	if distance>18. or distance<.12 or difference.dot(face.global_basis.z)<distance*.10 or camera_.is_position_behind(face.global_position):return 0.
	var extent: Vector2=face.mesh.size;var area:=Rect2(camera_.unproject_position(face.global_position),Vector2.ZERO)
	for x in [-.5,.5]:
		for y in [-.5,.5]:area=area.expand(camera_.unproject_position(face.to_global(Vector3(x*extent.x,y*extent.y,0))))
	area=area.intersection(get_viewport().get_visible_rect())
	if area.get_area()<400.:return 0.
	var excluded: Array[RID]=[]
	var owner_: Node=face.get_parent()
	while owner_ is Node3D and not owner_.has_meta("furniture_kind"):owner_=owner_.get_parent()
	if is_instance_valid(owner_):
		for body in owner_.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(camera_.global_position,face.global_position,13,excluded)
	if not city.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return 0.
	return area.get_area()
func make_slot() -> Dictionary:
	var viewport:=SubViewport.new();viewport.name="MirrorView";viewport.size=Vector2i(246,384);viewport.world_3d=city.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.msaa_3d=Viewport.MSAA_2X;viewport.positional_shadow_atlas_size=0;viewport.gui_disable_input=true;add_child(viewport)
	var camera_:=Camera3D.new();camera_.name="ReflectionCamera";camera_.cull_mask=city.camera.cull_mask & ~FACE_LAYER;viewport.add_child(camera_);camera_.current=true
	var source: Environment=city.camera.environment if city.camera.environment!=null else city.get_world_3d().environment
	if source!=null:
		camera_.environment=source.duplicate();camera_.environment.ssao_enabled=false;camera_.environment.ssil_enabled=false;camera_.environment.ssr_enabled=false;camera_.environment.glow_enabled=false
	return {"viewport":viewport,"camera":camera_,"face":null,"ready_frame":-1}
func bind(slot: Dictionary,face: MeshInstance3D) -> void:
	if slot.face==face:return
	if is_instance_valid(slot.face):slot.face.material_override.set_shader_parameter("reflection_ready",false)
	slot.face=face;slot.ready_frame=-1
	if is_instance_valid(face):face.material_override.set_shader_parameter("reflection_texture",slot.viewport.get_texture());face.material_override.set_shader_parameter("reflection_ready",false)
func _process(delta: float) -> void:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(city) or not is_instance_valid(city.camera):return
	elapsed+=delta
	for slot in slots:
		if slot.ready_frame>=0 and Engine.get_frames_drawn()>slot.ready_frame and is_instance_valid(slot.face):slot.face.material_override.set_shader_parameter("reflection_ready",true)
	var moving: bool=last_eye.is_finite() and city.camera.global_position.distance_squared_to(last_eye)>.0001
	if elapsed<(1./60. if moving else INTERVAL):return
	elapsed=0.;last_eye=city.camera.global_position
	var candidates: Array=[];var retained: Array=[]
	for entry in mirrors:
		var face: MeshInstance3D=entry.face.get_ref();var building: Node3D=entry.building.get_ref()
		if not is_instance_valid(face) or not is_instance_valid(building):continue
		retained.append(entry)
		if not actual_building(building):continue
		var value:=score(face,city.camera)
		if value>0.:candidates.append({"face":face,"score":value})
	mirrors=retained;candidates.sort_custom(func(a,b):return a.score>b.score);active_count=mini(MAX_ACTIVE,candidates.size())
	while slots.size()<active_count:slots.append(make_slot())
	for i in range(slots.size()):bind(slots[i],candidates[i].face if i<active_count else null)
	if active_count==0:return
	cursor=(cursor+1)%active_count;var slot: Dictionary=slots[cursor];var face: MeshInstance3D=slot.face
	var extent: Vector2=face.mesh.size;var pixels:=640 if candidates[cursor].score>140000. else (384 if candidates[cursor].score>16000. else 192);var size_:=Vector2i(roundi(pixels*extent.x/extent.y),pixels)
	if slot.viewport.size!=size_:slot.viewport.size=size_
	slot.camera.cull_mask=city.camera.cull_mask & ~FACE_LAYER
	if slot.camera.environment!=null and is_instance_valid(city.atmosphere):
		for property in ["ambient_light_energy","ambient_light_color","tonemap_exposure","tonemap_mode"]:
			var value: Variant=city.atmosphere.get(property)
			if slot.camera.environment.get(property)!=value:slot.camera.environment.set(property,value)
	if pose(slot.camera,city.camera.global_position,face):
		slot.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;render_count+=1
		if slot.ready_frame<0:slot.ready_frame=Engine.get_frames_drawn()
