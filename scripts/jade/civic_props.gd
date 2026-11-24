extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const NAMES={"jade_palace_wall":"朱砂宫墙","jade_festoon":"垂穗灯索","jade_steps":"青石踏步","jade_bamboo":"潇湘丛竹","jade_court_wall":"花窗院墙","jade_practice":"梅花步阵","jade_goods":"南货竹架","jade_signboard":"云纹悬幌"}
static func make(n: Node3D,id: String) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	a.mesh_part(n,id,draw.bind(id))
	match id:
		"jade_palace_wall":P.box(n,"PalaceWall",Vector3.UP*1.6,Vector3(4.,3.2,.71))
		"jade_court_wall":P.box(n,"CourtyardWall",Vector3.UP*1.11,Vector3(4.65,2.22,.45))
		"jade_steps":var ramp:=G.solid_box(n,Vector3(0,.20,0),Vector3(3.4,.31,2.5));ramp.rotation.x=-.20;ramp.collision_layer=8
		"jade_goods":P.box(n,"Shelving",Vector3.UP*.66,Vector3(2.75,1.32,.88))
static func draw(m: Node3D,id: String) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	match id:
		"jade_court_wall","jade_palace_wall":
			var royal:=id=="jade_palace_wall";var w:=4. if royal else 4.65;var h:=3.2 if royal else 2.22
			if royal:
				var plaster:=a.finish("lime").duplicate() as StandardMaterial3D
				plaster.albedo_color=Color("ac5446");G.box(m,Vector3.UP*(h+.32)*.5,Vector3(w,h-.32,.66),plaster)
				a.paint(m,Vector3(0,h-.32,.345),Vector3(w,.24,.06),"stone_relief")
			else:
				a.paint(m,Vector3.UP*.58,Vector3(w,.52,.43),"lime")
				a.paint(m,Vector3.UP*(h-.18),Vector3(w,.36,.43),"lime")
				for side in [-1,1]:a.paint(m,Vector3(side*(w*.5-.615),(h-.36+.84)*.5,0),Vector3(1.23,h-.36-.84,.43),"lime")
				for j in range(-4,5):
					for sign_ in [-1,1]:
						var lo:=Vector3(j*.28,.95,0);var hi:=lo+Vector3(sign_*.39,.83,0)
						if absf(hi.x)<1.11:a.beam(m,lo,hi,.048,"6f766c")
			a.paint(m,Vector3.UP*.16,Vector3(w,.32,.78 if royal else .50),"masonry")
			for side in [-1,1]:
				var coping:=a.paint(m,Vector3(0,h+.09,side*.19),Vector3(w-.004,.10,.53),"tiles") as MeshInstance3D
				coping.rotation.x=.29*side
			a.box(m,Vector3.UP*(h+.19),Vector3(w-.004,.14,.14),"6f7165")
		"jade_festoon":
			for i in range(10):
				var x: float=-7.5+1.5*i;var sag:=4.9+.95*pow(x/7.5,2)
				a.beam(m,Vector3(x,sag,0),Vector3(x+1.5,4.9+.95*pow((x+1.5)/7.5,2),0),.022,"5c513e")
				if i in [1,4,7,9]:a.lantern(m,Vector3(x,sag-.32,0),.39+.08*(i%3))
		"jade_steps":
			for i in range(4):
				var y:=.07+i*.14;a.paint(m,Vector3(0,y-.10,i*.59-.86),Vector3(3.4,.21,.59),"masonry")
		"jade_practice":
			for i in range(5):
				var pos:=Vector3(cos(i*TAU/5.)*.73,.052,sin(i*TAU/5.)*.73)
				G.cylinder(m,pos,.29,.105,G.mat("946d49"))
				var ring:=TorusMesh.new();ring.inner_radius=.23;ring.outer_radius=.25;G.mesh(m,ring,pos+Vector3.UP*.057,G.mat("dcc69c"))
			G.cylinder(m,Vector3.UP*.042,.18,.08,G.mat("b48a57"))
		"jade_goods":
			for x in [-1.28,1.28]:
				for z in [-.4,.4]:a.box(m,Vector3(x,.82,z),Vector3(.085,1.64,.085),"65432e")
			for y in [.38,.98,1.54]:
				a.paint(m,Vector3(0,y,0),Vector3(2.77,.12,.91),"lacquer")
				for i in range(5):
					var p:=Vector3((i-2)*.49,y+.14,.02)
					if int(y*10.)%2==0 or i%2==0:
						G.cylinder(m,p,.14,.18,G.mat(["768b79","bf9976","b9aa83","7c7160","839b91"][i]),.22)
						G.cylinder(m,p+Vector3.UP*.145,.22,.11,G.mat("9e906e"),.125)
						G.cylinder(m,p+Vector3.UP*.224,.108,.07,G.mat("53493b"),.12)
					else:
						var roll:=G.cylinder(m,p,.145,.63,a.finish("swallows" if i%2 else "brocade"));roll.rotation.x=PI/2
		"jade_signboard":
			a.beam(m,Vector3(0,2.75,0),Vector3(0,2.75,1.55),.12,"695039")
			a.beam(m,Vector3(0,2.1,0),Vector3(0,2.75,1.05),.09,"695039")
			for k in range(3):
				var panel:=a.paint(m,Vector3(0,1.88,k*.33+.52),Vector3(.042,1.36,.32),"brocade") as MeshInstance3D;panel.rotation.z=.035*sin(k)
		"jade_bamboo":
			var leaves:=SurfaceTool.new();leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(13):
				var angle:=i*2.399;var base:=Vector3(cos(angle)*(.28+.12*(i%5)),0,sin(angle)*(.31+.11*(i%5)))
				var h:=2.45+1.22*absf(sin(i*9.1));var t:=Vector3(cos(angle)*.43,h,sin(angle)*.43)
				var bark: Material=G.mat(["787e50","73754a","8b8956"][i%3])
				for j in range(7):
					var lo:=base+t*j/7.;var hi:=base+t*(j+1)/7.
					a.beam(m,lo,hi,.054,bark.albedo_color.to_html(false))
					G.cylinder(m,hi,.043,.034,G.mat("acaa75"))
					if j<2:continue
					var dir:=Vector3(cos(angle+j*1.9),.31,sin(angle+j*1.9))
					var twig:=hi+dir*(.5+.05*j);a.beam(m,hi,twig,.019,"86875c")
					for k in range(7):
						var stem:=hi.lerp(twig,(k+.5)/8.);var axis:=dir.rotated(Vector3.UP,(1. if k%2 else -1.)*.85)*.36-Vector3.UP*.24
						var wide:=Vector3(-axis.z,0,axis.x).normalized()*.046
						for v in [stem,stem+axis*.45+wide,stem+axis,stem,stem+axis,stem+axis*.45-wide]:
							leaves.set_color(Color(["506a46","70854f","82925c","4a6746"][k%4]).srgb_to_linear());leaves.add_vertex(v)
			leaves.generate_normals();var leaf:=StandardMaterial3D.new();leaf.vertex_color_use_as_albedo=true;leaf.cull_mode=BaseMaterial3D.CULL_DISABLED;G.mesh(m,leaves.commit(),Vector3.ZERO,leaf)
