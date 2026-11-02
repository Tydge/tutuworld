extends Node3D
const G=preload("res://scripts/geometry.gd")
var butterflies: Array=[]
var motes: MultiMeshInstance3D
var clock := 0.0
var daylight := 1.0
var origins: Array[Vector3]=[Vector3(-8,1.85,-7),Vector3(8,2.05,7),Vector3(-10,1.9,5),Vector3(11,2.1,-7),Vector3(22,1.8,9),Vector3(38,1.95,8),Vector3(-11,2.0,28),Vector3(21,1.9,28)]
var woodland:=false
var halos: MultiMeshInstance3D
var glow_lights: Array[OmniLight3D]=[]
var glow_clock:=0.0
var mote_count:=12
var height_sampler: Callable
func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	for i in range(origins.size()):
		var b:=Node3D.new()
		add_child(b)
		b.position=origins[i]
		var wings: Array[Node3D]=[]
		for side in [-1,1]:
			var pivot:=Node3D.new()
			b.add_child(pivot)
			G.ball(pivot,Vector3(side*.09,0,0),Vector3(.13,.025,.10),G.mat("f8d7a2" if i%2==0 else "cfb6d0"),"Wing")
			wings.append(pivot)
		G.ball(b,Vector3.ZERO,Vector3(.02,.02,.10),G.mat("765d45"),"Body")
		for part in b.find_children("*","GeometryInstance3D",true,false): part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		butterflies.append({"node":b,"origin":origins[i],"wings":wings})
	var mesh_:=SphereMesh.new()
	mesh_.radius=.023
	mesh_.height=.046
	mesh_.radial_segments=8
	mesh_.rings=4
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh_
	mote_count=24 if woodland else 12
	mm.instance_count=mote_count
	motes=MultiMeshInstance3D.new()
	motes.multimesh=mm
	var material:=G.mat("f4d899",.8,.7).duplicate() as StandardMaterial3D
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	motes.material_override=material
	motes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)
	if woodland:
		var glow_mesh:=QuadMesh.new();glow_mesh.size=Vector2(.40,.40)
		var glow_material:=ShaderMaterial.new();glow_material.shader=load("res://assets/shaders/lamp_glow.gdshader")
		glow_material.set_shader_parameter("billboard",true);glow_material.set_shader_parameter("strength",.34)
		halos=MultiMeshInstance3D.new();halos.multimesh=MultiMesh.new();halos.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		halos.multimesh.mesh=glow_mesh;halos.multimesh.instance_count=mote_count;halos.material_override=glow_material
		halos.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(halos)
		for i in range(3):
			var glow:=OmniLight3D.new();glow.light_color=Color("d6ed91");glow.light_energy=.22
			glow.omni_range=2.8;glow.shadow_enabled=false;glow.distance_fade_enabled=false
			add_child(glow);glow_lights.append(glow)
func _process(delta: float) -> void:
	clock+=delta
	for i in range(butterflies.size()):
		var b: Dictionary=butterflies[i]
		b.node.visible=daylight>.25
		var p: Vector3=b.origin+Vector3(sin(clock*.45+i)*1.35,sin(clock*1.6+i)*.25,cos(clock*.51+i)*1.0)
		b.node.position=p
		b.node.rotation.y=sin(clock*.25+i)*.6
		b.wings[0].rotation.z=.30+sin(clock*(23.0+i*.7)+i)*.95
		b.wings[1].rotation.z=-.30-sin(clock*(23.0+i*.7)+i)*.95
	motes.visible=daylight<.35
	if is_instance_valid(halos): halos.visible=motes.visible
	for glow in glow_lights: glow.visible=motes.visible
	glow_clock+=delta
	if motes.visible:
		for i in range(mote_count):
			var p:=Vector3(sin(i*4.2)*10+sin(clock*.25+i),.9+sin(clock*.8+i)*.3,cos(i*3.7)*9+sin(clock*.3+i)*.4)
			if woodland:
				var center: Vector3=[Vector3(-7,0,7),Vector3(7,0,8),Vector3(19,0,-18),Vector3(-18,0,-33),Vector3(-12,0,22),Vector3(16,0,-30)][i/4]
				p=center+Vector3(sin(clock*.3+i*4.2)*1.7,.85+sin(clock*.8+i)*.30,cos(clock*.27+i*3.7)*1.5)
			if height_sampler.is_valid(): p.y+=float(height_sampler.call(p.x,p.z))
			var scale_:=.6+sin(clock*1.8+i)*.3
			motes.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale_),p))

			if is_instance_valid(halos): halos.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(.7+scale_*.5)),p))
			if i in [0,8,16] and not glow_lights.is_empty() and glow_clock>.1: glow_lights[i/8].position=p
	if glow_clock>.1: glow_clock=0
