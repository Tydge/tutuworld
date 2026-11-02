extends RefCounted
const G=preload("res://scripts/geometry.gd")
var lamps: Node3D
func group(parent: Node3D,id: String,p:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new();n.name=id;n.position=p;parent.add_child(n);return n
func lamp(p: Vector3) -> void:
	if p.distance_to(Vector3(-4.6,0,-22))<.1: p=Vector3(-10.0,0,-20.2)
	var n:=group(lamps,"Lamp",p)
	var iron:=G.mat("526f67")
	G.cylinder(n,Vector3(0,1.5,0),.075,3,iron)
	G.cylinder(n,Vector3(0,.14,0),.20,.28,iron)
	G.box(n,Vector3(0,3.0,0),Vector3(.42,.65,.42),G.mat("ffe3a1",.7,.16),"GlowGlass")
	for x in [-.23,.23]:
		for z in [-.23,.23]: G.box(n,Vector3(x,3.0,z),Vector3(.045,.70,.045),iron)
	G.box(n,Vector3(0,2.65,0),Vector3(.54,.08,.54),iron)
	G.cylinder(n,Vector3(0,3.39,0),.38,.20,iron,.025)
	var light:=OmniLight3D.new()
	light.name="NightLight"
	light.position.y=2.8
	light.light_color=Color("ffd491")
	light.light_energy=3.2
	light.omni_range=10.5
	light.omni_attenuation=1.25
	light.shadow_enabled=false
	light.visible=false
	light.distance_fade_enabled=false
	n.add_child(light)
	var halo:=ShaderMaterial.new()
	halo.shader=load("res://assets/shaders/lamp_glow.gdshader")
	halo.set_shader_parameter("billboard",true)
	var disc:=QuadMesh.new()
	disc.size=Vector2(1.8,1.8)
	var glow:=G.mesh(n,disc,Vector3(0,3.05,0),halo,"LanternHalo")
	glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool_material:=ShaderMaterial.new()
	pool_material.shader=load("res://assets/shaders/lamp_glow.gdshader")
	var plane:=PlaneMesh.new()
	plane.size=Vector2(8.8,8.8)
	var pool:=G.mesh(n,plane,Vector3(0,.15,0),pool_material,"WarmPool")
	pool.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var frame:=SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in n.get_children():
		if part is MeshInstance3D and part.material_override==iron:
			frame.append_from(part.mesh,0,part.transform)
			n.remove_child(part)
			part.free()
	G.mesh(n,frame.commit(),Vector3.ZERO,iron,"LanternFrame")