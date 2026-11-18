extends RefCounted
const W=preload("res://scripts/icefield/winter_props.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const IDS=["campfire","log_stack","snow_fence","ice_fishing","winter_lantern","trail_sign","ice_crystal","picnic_table"]
static func make(id: String) -> Node3D:
	var n:=W.module(id)
	match id:
		"campfire":
			var charcoal:=ShaderMaterial.new();charcoal.shader=load("res://assets/shaders/winter_charcoal.gdshader")
			G.ball(n,Vector3(0,.075,0),Vector3(.93,.08,.92),W.mat("373d3d"))
			for i in range(14):
				var a: float=i*TAU/14.;var s: float=1.+.15*sin(i*7.);var stone:=G.ball(n,Vector3(cos(a)*1.05,.18,sin(a)*1.05),Vector3(.28,.20,.24)*s,W.mat("69757b"));stone.rotation.y=a
			for i in range(24):
				var a: float=i*2.399;var r: float=.16+float(i%5)*.125;G.ball(n,Vector3(cos(a)*r,.18,sin(a)*r),Vector3(.11,.07,.09),charcoal)
			for i in range(7):
				var a: float=i*PI/3.5;var dir:=Vector3(cos(a),.08*sin(i*3.),sin(a)).normalized()
				var log_:=G.cylinder(n,Vector3(sin(i)*.10,.27+i*.035,cos(i)*.08),.14,1.55,charcoal,.11);log_.quaternion=Quaternion(Vector3.UP,dir)
			var flame:=ShaderMaterial.new();flame.shader=load("res://assets/shaders/winter_fire.gdshader");flame.set_shader_parameter("flame_atlas",load("res://assets/terrain/winter/campfire_flames_v1.png"))
			for i in range(3):
				var quad:=QuadMesh.new();quad.size=Vector2(1.16-i*.14,1.65-i*.18);var mesh:=G.mesh(n,quad,Vector3(sin(i*2.)*.12,1.03-i*.07,cos(i*2.)*.12),flame,"FireFlame");mesh.rotation.y=i*PI/3.;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var light:=OmniLight3D.new();light.name="FireLight";light.position=Vector3(0,1.3,0);light.light_color=Color("ff9f4d");light.light_energy=2.0;light.omni_range=8.;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=45.;light.distance_fade_length=10.;n.add_child(light)
			P.cylinder(n,"FireRingCollision",Vector3(0,.3,0),1.1,.6)
			W.group(n,"ActionAnchor",Vector3(0,0,2.2));W.group(n,"EffectAnchor",Vector3(0,1.1,0))
		"log_stack":
			for row in range(3):
				for col in range(4-row):
					var p:=Vector3((col-(3-row)*.5)*.38,.21+row*.35,0)
					var log_:=G.cylinder(n,p,.21,1.65,W.mat("wood"));log_.rotation.x=PI*.5
					for side in [-1,1]:var end:=G.cylinder(n,p+Vector3(0,0,side*.835),.17,.018,W.mat("bba07a"));end.rotation.x=PI*.5
			G.ball(n,Vector3(0,1.03,0),Vector3(.48,.17,.84),W.mat("snow"));P.box(n,"StackCollision",Vector3(0,.55,0),Vector3(1.7,1.1,1.8))
		"snow_fence":
			for x in [-2.,0.,2.]:
				W.box(n,Vector3(x,.65,0),Vector3(.18,1.3,.18),"wood");G.ball(n,Vector3(x,1.34,0),Vector3(.19,.13,.19),W.mat("snow"))
			for y in [.43,.91]:W.box(n,Vector3(0,y,0),Vector3(4.2,.13,.12),"wood");W.box(n,Vector3(0,y+.09,0),Vector3(4.25,.07,.18),"snow")
			P.box(n,"FenceCollision",Vector3(0,.65,0),Vector3(4.3,1.3,.27))
		"winter_lantern":
			W.box(n,Vector3(0,.25,0),Vector3(.34,.48,.34),"glass")
			for x in [-.19,.19]:
				for z in [-.19,.19]:W.box(n,Vector3(x,.27,z),Vector3(.035,.54,.035),"darkwood")
			W.box(n,Vector3(0,.56,0),Vector3(.48,.08,.48),"darkwood");W.box(n,Vector3(0,.62,0),Vector3(.46,.06,.46),"snow")
			P.box(n,"LanternCollision",Vector3(0,.3,0),Vector3(.5,.6,.5))
		"trail_sign":
			W.box(n,Vector3(0,1.,0),Vector3(.13,2.,.13),"wood")
			W.box(n,Vector3(0,1.7,0),Vector3(2.3,.40,.16),"wood");W.box(n,Vector3(0,1.94,0),Vector3(2.4,.09,.24),"snow")
			G.text3d(n,"雪镇  ←  ·  →  冰原",Vector3(0,1.7,.09),19,Color("f9e4bf"));P.cylinder(n,"PostCollision",Vector3(0,1.,0),.14,2.)
		"ice_crystal":
			for i in range(5):
				var a: float=i*2.399;var crystal:=G.cylinder(n,Vector3(cos(a)*.42,.55+float(i%3)*.13,sin(a)*.4),.24,1.2+float(i%3)*.3,W.mat("ice"),.025);crystal.mesh.radial_segments=6;crystal.rotation.z=sin(a)*.2
			P.cylinder(n,"CrystalCollision",Vector3(0,.6,0),.7,1.2)
		"ice_fishing":
			var ring:=TorusMesh.new();ring.inner_radius=.52;ring.outer_radius=.72;G.mesh(n,ring,Vector3(0,.03,0),W.mat("snow"))
			G.cylinder(n,Vector3(0,.015,0),.53,.025,W.mat("16384c"))
			G.capsule(n,Vector3(1.2,.2,.3),Vector3(.4,1.8,-.1),.025,W.mat("wood"))
			G.capsule(n,Vector3(.4,1.8,-.1),Vector3(0,.06,0),.006,W.mat("b4c5ce"))
			W.box(n,Vector3(1.25,.32,.4),Vector3(.7,.12,.55),"wood")
			for x in [.98,1.52]:W.box(n,Vector3(x,.14,.4),Vector3(.06,.28,.45),"wood")
			var bucket:=G.cylinder(n,Vector3(-1.1,.24,.1),.27,.46,W.mat("829da9"),.31)
			P.box(n,"FishingStoolCollision",Vector3(1.25,.23,.4),Vector3(.75,.46,.6));W.group(n,"ActionAnchor",Vector3(1.25,.4,.4));W.group(n,"ExitAnchor",Vector3(1.7,0,1.2))
		"picnic_table":
			for x in [-1.1,1.1]:
				for side in [-1,1]:G.capsule(n,Vector3(x,.05,side*.85),Vector3(x,.95,side*.38),.065,W.mat("wood"))
			for i in range(5):W.box(n,Vector3(0,1.,-.5+i*.25),Vector3(3.2,.12,.22),"wood")
			for side in [-1,1]:W.box(n,Vector3(0,.51,side*1.05),Vector3(3.2,.13,.38),"wood");W.box(n,Vector3(0,.60,side*1.05),Vector3(3.25,.07,.4),"snow")
			P.box(n,"TableCollision",Vector3(0,.5,0),Vector3(3.2,1.,1.4))
	W.merge(n);return n
