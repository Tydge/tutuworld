extends Node
## A single fixed-budget planar view shared by the entire lake, with world-space
## reprojection. Captures never include the ice or sea themselves.
const SURFACE_LAYER:=1<<17
const L=preload("res://scripts/icefield/icefield_layout.gd")
var city: Node3D
var viewport: SubViewport
var reflected: Camera3D
var material: ShaderMaterial
var frames:=0
var updates:=0
var initialized:=false
var reflection_root: Node3D
var reflected_sun: DirectionalLight3D
var dynamic_proxies: Array=[]
var static_batches:=0
func _ready() -> void:
	process_priority=30
	material=city.scenery.get_meta("ice_material")
	for mesh_ in city.scenery.find_children("*","GeometryInstance3D",true,false):
		if mesh_.material_override==material or mesh_.name=="PolarSea":mesh_.layers=SURFACE_LAYER
	viewport=SubViewport.new();viewport.name="SharedIceView";viewport.own_world_3d=true;viewport.size=Vector2i(960,600);viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.positional_shadow_atlas_size=0;viewport.gui_disable_input=true;add_child(viewport)
	reflected=Camera3D.new();reflected.name="ReflectedLakeCamera";reflected.cull_mask=city.get_viewport().get_camera_3d().cull_mask if city.get_viewport().get_camera_3d()!=null else 0xFFFFF;reflected.cull_mask=(reflected.cull_mask&~SURFACE_LAYER)|(1<<18);reflected.far=2000.;reflected.near=.1;reflected.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;viewport.add_child(reflected);reflected.current=true
	material.set_shader_parameter("reflection_texture",viewport.get_texture())
func proxy(source: GeometryInstance3D,parent: Node3D) -> GeometryInstance3D:
	var draw: GeometryInstance3D
	if source is MeshInstance3D:
		draw=MeshInstance3D.new();draw.mesh=source.mesh
	elif source is MultiMeshInstance3D:
		draw=MultiMeshInstance3D.new();draw.multimesh=source.multimesh
	else:return null
	draw.material_override=source.material_override;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(draw);draw.global_transform=source.global_transform;return draw
func build_reflection_world() -> void:
	# Static meshes/materials are shared, not copied. This independent render world
	# excludes physics, particles, extra lights and a second set of sun shadow maps.
	reflection_root=Node3D.new();viewport.add_child(reflection_root)
	var environment:=WorldEnvironment.new();environment.environment=city.atmosphere;reflection_root.add_child(environment)
	reflected_sun=DirectionalLight3D.new();reflected_sun.shadow_enabled=false;reflection_root.add_child(reflected_sun)
	var materials: Dictionary={};var batches: Dictionary={}
	for source in city.scenery.find_children("*","GeometryInstance3D",true,false):
		if source.material_override==material or source.name=="PolarSea" or not source.is_visible_in_tree() or source.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:continue
		if not source is MeshInstance3D:proxy(source,reflection_root);continue
		var m: Material=source.material_override
		if m==null:continue
		if m is ShaderMaterial and m.shader==preload("res://assets/shaders/home_surface.gdshader"):
			var key: String="home:"+str(m.get_shader_parameter("pattern"))+str(m.get_shader_parameter("tint"))+str(m.get_shader_parameter("vertex_tint"))+str(m.get_shader_parameter("roughness_value"))+str(m.get_shader_parameter("roof_snow"))
			if not materials.has(key):
				var full: ShaderMaterial=m.duplicate();full.set_shader_parameter("camera_occlusion",false);full.set_shader_parameter("opacity",1.);full.set_shader_parameter("building_roof_cut",false);full.set_shader_parameter("building_wall_cut",false);materials[key]=full
			m=materials[key]
		var tile:=Vector2i(floori(source.global_position.x/64.),floori(source.global_position.z/64.))
		var key: String=str(m.get_instance_id())+":"+str(tile)
		if not batches.has(key):batches[key]={"st":SurfaceTool.new(),"material":m};batches[key].st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in range(source.mesh.get_surface_count()):preload("res://scripts/geometry.gd").append_indexed(batches[key].st,source.mesh,surface,source.global_transform)
	for entry in batches.values():
		entry.st.index();var draw:=MeshInstance3D.new();draw.mesh=entry.st.commit();draw.material_override=entry.material;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;reflection_root.add_child(draw);static_batches+=1
	var actors: Array=[city.bunny];actors.append_array(city.npcs)
	for actor: Node3D in actors:
		for source in actor.find_children("*","GeometryInstance3D",true,false):
			var copy:=proxy(source,reflection_root)
			if copy!=null:dynamic_proxies.append({"source":weakref(source),"draw":copy,"actor":weakref(actor)})
func mirror(p: Vector3) -> Vector3:return Vector3(p.x,2.*L.ICE_LEVEL-p.y,p.z)
func _process(_delta: float) -> void:
	if not is_instance_valid(city.camera):return
	if reflection_root==null:build_reflection_world()
	frames+=1
	if city.bunny.position.x< -43. or city.camera.position.y<L.ICE_LEVEL+.15:
		material.set_shader_parameter("reflection_ready",false);return
	# Every displayed frame gets its matching camera and capture. Temporal skipping
	# makes reflected foreground objects step during orbiting even with reprojection.
	var size_: Vector2=city.get_viewport().get_visible_rect().size
	var desired:=Vector2i(960,maxi(384,roundi(960.*size_.y/maxf(1.,size_.x))))
	if viewport.size!=desired:viewport.size=desired
	reflected.fov=city.camera.fov
	reflected.global_position=mirror(city.camera.global_position)
	var target:=mirror(city.camera.global_position-city.camera.global_basis.z)
	var up: Vector3=city.camera.global_basis.y;up.y=-up.y;up=-up
	reflected.look_at(target,up)
	reflected_sun.global_basis=city.sun.global_basis;reflected_sun.light_color=city.sun.light_color;reflected_sun.light_energy=city.sun.light_energy;reflected_sun.light_specular=city.sun.light_specular
	for entry in dynamic_proxies:
		var source: GeometryInstance3D=entry.source.get_ref();var actor: Node3D=entry.actor.get_ref()
		if not is_instance_valid(source) or not is_instance_valid(actor):entry.draw.hide();continue
		entry.draw.visible=source.is_visible_in_tree() and actor.position.distance_squared_to(city.bunny.position)<4900. and actor.position.x> -52.
		if entry.draw.visible:entry.draw.global_transform=source.global_transform
	if reflected.environment==null:
		reflected.environment=city.atmosphere.duplicate();reflected.environment.ssao_enabled=false;reflected.environment.ssil_enabled=false;reflected.environment.ssr_enabled=false;reflected.environment.glow_enabled=false
	for key in ["ambient_light_energy","ambient_light_color","tonemap_exposure","tonemap_mode","fog_light_color","fog_density"]:reflected.environment.set(key,city.atmosphere.get(key))
	var matrix: Projection=reflected.get_camera_projection()*Projection(reflected.global_transform.affine_inverse())
	material.set_shader_parameter("reflection_matrix",matrix)
	material.set_shader_parameter("reflection_ready",initialized)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;initialized=true;updates+=1
func _exit_tree() -> void:
	if is_instance_valid(material):material.set_shader_parameter("reflection_texture",null);material.set_shader_parameter("reflection_ready",false)
