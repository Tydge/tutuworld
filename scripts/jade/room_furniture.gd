extends RefCounted
## One baked near mesh per model. Build pieces split the same surfaces for individual finishes.
const A=preload("res://scripts/jade/architecture.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const WOOD="694433"
const EDGE="bc8c50"
const JADE="458a83"
const GOLD="dba754"
const SIZES={
	"jade_court_carpet":Vector3(3.52,.026,4.4),
	"jade_moon_chair":Vector3(1.18,1.64,1.16),
	"jade_throne":Vector3(2.12,2.83,1.7),
	"jade_alcove_bed":Vector3(2.85,2.85,4.5),
	"jade_altar_table":Vector3(3.2,1.14,1.8),
	"jade_tea_desk":Vector3(2.4,0.76,1.36),
	"jade_curio":Vector3(2.4,2.4,0.9),
	"jade_apothecary":Vector3(2.3,1.96,0.92),
	"jade_censer":Vector3(0.76,0.7,0.58),
	"jade_scrolls":Vector3(0.78,1.35,0.78),
	"jade_blossom":Vector3(0.98,1.52,0.76),
	"jade_qin":Vector3(2.5,1.04,1.15),
	"jade_loom":Vector3(2.42,2.12,1.52),
	"jade_abacus":Vector3(2.52,1.26,1.3),
	"jade_wheel":Vector3(1.4,1.43,1.4),
	"jade_clepsydra":Vector3(1.6,2.05,1.16),
	"jade_brush":Vector3(2.7,1.58,1.4),
	"jade_vat":Vector3(1.05,1.3,1.05),
	"jade_embroidery":Vector3(1.9,1.75,1.05),
	"jade_balance":Vector3(2.4,1.81,1.26),
	"jade_sandtray":Vector3(2.65,1.1,1.45),
	"jade_dress":Vector3(1.9,2.13,0.87),
	"jade_gong":Vector3(1.75,1.92,1.15)}
static func make(n: Node3D,kind: String) -> void:
	A.mesh_part(n,kind,draw.bind(kind))
	if kind=="jade_court_carpet":return
	var s: Vector3=SIZES[kind]
	if kind in ["jade_moon_chair","jade_throne"]:
		A.group(n,"SeatAnchor",Vector3(0,.81,0))
		A.group(n,"ExitAnchor",Vector3(0,.12,s.z*.5+.87))
	if kind=="jade_alcove_bed":
		A.group(n,"ActionAnchor",Vector3(-2.1,.20,.30))
		A.group(n,"SleepExit",Vector3(-2.,.20,1.5))
		var cloth:=PlaneMesh.new()
		cloth.size=Vector2(2.45,2.34);cloth.subdivide_width=20;cloth.subdivide_depth=22
		var quilt:=ShaderMaterial.new()
		quilt.shader=preload("res://assets/shaders/sleep_quilt.gdshader")
		preload("res://scripts/appearance/fabric_material.gd").configure(quilt,{"pattern":"sprig","color":"376b73","accent":"ebcc8e"},"quilt")
		G.mesh(n,cloth,Vector3(0,.985,.78),quilt,"Quilt").set_meta("dynamic_mesh",true)
		s.y=1.3
	P.box(n,"Solid",Vector3.UP*s.y*.5,s)
static func table(n: Node3D,w: float,d: float,h: float) -> void:
	for side in [-1.,1.]:
		for end in [-1.,1.]:
			var x: float=side*(w*.5-.16);var z: float=end*(d*.5-.13)
			A.beam(n,Vector3(x,.08,z),Vector3(x*.96,h-.08,z*.95),.11,WOOD)
			A.box(n,Vector3(x,.07,z),Vector3(.18,.13,.17),WOOD)
		A.box(n,Vector3(0,h-.20,side*(d*.5-.16)),Vector3(w-.27,.18,.11),WOOD)
	A.box(n,Vector3.UP*(h-.075),Vector3(w,.15,d),WOOD)
	A.box(n,Vector3.UP*(h-.014),Vector3(w-.14,.03,d-.13),EDGE)
static func vase(n: Node3D,p: Vector3,k: float,pigment: String) -> void:
	var m:=G.mat(pigment,.34)
	for row in [[.10,.17,.26,.20],[.34,.26,.32,.28],[.58,.32,.15,.20],[.75,.15,.13,.14],[.84,.13,.17,.05]]:
		G.cylinder(n,p+Vector3.UP*float(row[0])*k,row[1]*k,row[3]*k,m,row[2]*k)
static func panel(n: Node3D,p: Vector3,size_: Vector2,texture: String) -> void:
	var face:=QuadMesh.new();face.size=size_
	G.mesh(n,face,p,A.finish(texture))
static func draw(n: Node3D,kind: String) -> void:
	var size_: Vector3=SIZES[kind]
	match kind:
		"jade_court_carpet":
			A.box(n,Vector3.UP*.011,Vector3(3.52,.022,4.4),GOLD)
			var carpet:=PlaneMesh.new();carpet.size=Vector2(3.36,4.23)
			G.mesh(n,carpet,Vector3.UP*.024,A.finish("peony_apron"))
		"jade_moon_chair","jade_throne":
			var royal:=kind=="jade_throne"
			var w:=size_.x;var d:=size_.z
			table(n,w,d,.74)
			A.paint(n,Vector3(0,.77,0),Vector3(w*.82,.08,d*.78),"brocade" if royal else "swallows")
			if royal:
				A.box(n,Vector3(0,1.73,-.69),Vector3(1.87,1.91,.17),GOLD)
				panel(n,Vector3(0,1.73,-.59),Vector2(1.70,1.76),"dragon_relief")
				for side in [-1.,1.]:
					A.beam(n,Vector3(side*.94,.8,-.61),Vector3(side*.94,2.64,-.61),.10,GOLD)
					A.paint(n,Vector3(side*.94,1.19,0),Vector3(.18,.18,1.34),"wood_relief")
					G.ball(n,Vector3(side*.94,1.21,.62),Vector3(.13,.12,.16),G.mat(GOLD))
					A.beam(n,Vector3(side*.94,.79,.49),Vector3(side*.94,1.19,.49),.12,WOOD)
				A.box(n,Vector3(0,2.72,-.69),Vector3(1.96,.12,.21),GOLD)
				for side in [-1.,1.]:
					var gild:=G.mat(GOLD,.36)
					# Curl the arm rails forward into two dragon heads, with a swept crest on the back.
					var brow:=G.ball(n,Vector3(side*.92,1.34,.58),Vector3(.147,.126,.211),gild)
					brow.rotation.x=-.19
					G.ball(n,Vector3(side*.92,1.29,.752),Vector3(.112,.062,.084),gild)
					G.ball(n,Vector3(side*1.017,1.381,.674),Vector3.ONE*.027,G.mat("543b30"))
					for fork in [-1.,1.]:
						var horn:=Vector3(side*.92+fork*.061,1.42,.52)
						A.beam(n,horn,horn+Vector3(fork*.035,.13,-.09),.034,GOLD)
					for j in 9:
						var a: float=j*TAU/10.
						var q:=Vector3(side*(.66+cos(a)*.19),2.67+sin(a)*.095,-.68)
						G.ball(n,q,Vector3(.11,.065,.075),gild)
				G.ball(n,Vector3(0,2.76,-.69),Vector3(.16,.09,.079),G.mat(GOLD,.36))
			else:
				var points: Array=[]
				for i in range(13):
					var a: float=lerpf(-2.43,2.43,i/12.)
					points.append(Vector3(sin(a)*.52,1.27+.24*cos(a),-cos(a)*.47))
				G.line(n,points,.065,G.mat(WOOD))
				for x in [-.39,0.,.39]:
					A.beam(n,Vector3(x,.74,-.34),Vector3(x,1.48-absf(x)*.29,-.43),.09,WOOD)
				for x in [-.49,.49]:A.beam(n,Vector3(x,.75,.27),Vector3(x,1.14,.27),.07,WOOD)
		"jade_alcove_bed":
			table(n,2.68,4.3,.63)
			A.box(n,Vector3.UP*.78,Vector3(2.52,.28,4.09),"ead9b6")
			G.ball(n,Vector3(0,.99,-1.2),Vector3(.85,.12,.33),G.mat("c6b283"))
			for x in [-1.32,1.32]:
				for z in [-2.09,2.09]:A.beam(n,Vector3(x,.59,z),Vector3(x,2.76,z),.12,WOOD)
				A.paint(n,Vector3(x,2.55,0),Vector3(.14,.40,4.35),"wood_relief")
			for z in [-2.1,2.1]:
				A.paint(n,Vector3(0,2.59,z),Vector3(2.77,.36,.16),"wood_relief")
				for x in [-1.06,1.06]:A.paint(n,Vector3(x,1.96,z+.02),Vector3(.45,.94,.08),"swallows")
			A.paint(n,Vector3(0,1.25,-2.11),Vector3(2.67,1.22,.13),"casement")
		"jade_altar_table","jade_tea_desk":
			table(n,size_.x,size_.z,size_.y)
			for s in [-1.,1.]:
				A.box(n,Vector3(s*(size_.x*.5-.05),size_.y+.027,0),Vector3(.10,.07,size_.z),WOOD)
		"jade_curio","jade_apothecary":
			var cabinet:=kind=="jade_apothecary"
			for x in [-1.08,1.08]:A.box(n,Vector3(x,size_.y*.5,0),Vector3(.12,size_.y,.82),WOOD)
			A.box(n,Vector3(0,size_.y*.49,-.36),Vector3(2.2,size_.y*.94,.09),WOOD)
			for j in range(4):
				var y:=.16+j*(size_.y-.22)/3.
				A.box(n,Vector3(0,y,0),Vector3(2.32,.10,.87),EDGE)
				if j==3:break
				if cabinet:
					for i in range(5):
						var x: float=(i-2)*.422
						A.box(n,Vector3(x,y+.28,.06),Vector3(.395,.48,.69),WOOD)
						A.box(n,Vector3(x,y+.30,.416),Vector3(.14,.075,.025),GOLD)
				else:
					A.box(n,Vector3((-.45 if j%2==0 else .45),y+.37,0),Vector3(.09,.68,.74),WOOD)
					vase(n,Vector3(.40 if j%2==0 else -.54,y+.07,0),.65,JADE)
		"jade_censer","jade_vat","jade_scrolls","jade_blossom":
			var pigment:=JADE if kind!="jade_vat" else "864d32"
			if kind=="jade_censer":
				G.ball(n,Vector3.UP*.34,Vector3(.29,.21,.23),G.mat(GOLD,.40))
				G.cylinder(n,Vector3.UP*.51,.29,.08,G.mat(EDGE),.23)
				G.ball(n,Vector3.UP*.61,Vector3.ONE*.07,G.mat(GOLD))
				for side in [-1.,1.]:
					A.beam(n,Vector3(side*.22,.38,0),Vector3(side*.36,.57,0),.058,GOLD)
					G.cylinder(n,Vector3(side*.18,.10,0),.055,.19,G.mat(EDGE))
			else:
				vase(n,Vector3.ZERO,1.43 if kind=="jade_vat" else .92,pigment)
				if kind=="jade_scrolls":
					for i in range(5):
						var tube:=G.cylinder(n,Vector3((i%3-1)*.085,.92+(i%2)*.12,(i/3)*.10),.039,.6,G.mat("ecddb2"))
						tube.rotation.z=(i-2)*.11
				if kind=="jade_blossom":
					for i in range(4):
						var end:=Vector3((i-1.5)*.25,1.12+.32*sin(i),sin(i)*.20)
						A.beam(n,Vector3(0,.72,0),end,.032,WOOD)
						for j in range(3):G.ball(n,end+Vector3(j*.045,j*.026,0),Vector3.ONE*.044,G.mat("cf827c"))
		"jade_qin":
			table(n,2.5,1.15,.75)
			G.ball(n,Vector3(0,.85,0),Vector3(1.13,.12,.33),G.mat(WOOD,.42))
			for i in range(7):A.beam(n,Vector3(-.9,.97,(i-3)*.049),Vector3(.93,.97,(i-3)*.040),.009,"eee0b3")
			for j in range(9):G.ball(n,Vector3(-.82+j*.18,.947,-.18),Vector3.ONE*.014,G.mat(GOLD))
		"jade_loom","jade_embroidery","jade_dress":
			var loom:=kind=="jade_loom";var rack:=kind=="jade_dress"
			var width:=size_.x*.46;var top:=size_.y-.08
			for side in [-1.,1.]:
				A.box(n,Vector3(side*width,.09,0),Vector3(.20,.18,size_.z),WOOD)
				A.beam(n,Vector3(side*width,.15,.25),Vector3(side*width,top,-.24),.12,WOOD)
			for y in [.67,top]:A.box(n,Vector3(0,y,-.15),Vector3(width*2.12,.12,.12),EDGE)
			var tex: String="peony_apron" if not loom else "fish_resist"
			panel(n,Vector3(0,(top+.62)*.5,-.042),Vector2(width*(1.03 if rack else 1.65),top-.60),tex)
			if loom:
				for i in range(13):A.beam(n,Vector3((i-6)*.115,.65,.64),Vector3((i-6)*.115,1.18,-.12),.013,"e6d2a3")
		"jade_abacus","jade_brush","jade_balance","jade_sandtray":
			table(n,size_.x,size_.z,.88)
			if kind=="jade_abacus":
				A.box(n,Vector3(0,.92,.03),Vector3(1.86,.08,.89),WOOD)
				for i in range(10):
					var x: float=(i-4.5)*.161
					A.beam(n,Vector3(x,1.,-.35),Vector3(x,1.,.40),.025,EDGE)
					for j in range(5):G.ball(n,Vector3(x,1.04,(j-2)*.11+(.08 if j>i%4 else 0.)),Vector3(.066,.047,.044),G.mat("342822"))
			elif kind=="jade_brush":
				A.box(n,Vector3(-.26,.905,0),Vector3(1.33,.035,.65),"e6d7ae")
				vase(n,Vector3(.82,.88,-.19),.47,JADE)
				for i in range(4):A.beam(n,Vector3(.82,1.17,-.19),Vector3(.79+i*.046,1.48+sin(i)*.08,-.19),.026,WOOD)
				G.ball(n,Vector3(.67,.94,.31),Vector3(.23,.055,.12),G.mat("353e43"))
			elif kind=="jade_balance":
				A.beam(n,Vector3(0,.86,0),Vector3(0,1.78,0),.083,WOOD)
				A.beam(n,Vector3(-.79,1.67,0),Vector3(.79,1.67,0),.048,GOLD)
				for x in [-.71,.71]:
					for z in [-.16,.16]:A.beam(n,Vector3(x,1.66,0),Vector3(x,1.08,z),.014,EDGE)
					G.cylinder(n,Vector3(x,1.07,0),.20,.065,G.mat(GOLD),.24)
			else:
				A.box(n,Vector3.UP*.94,Vector3(2.30,.12,1.15),"c9b68c")
				for i in range(6):G.ball(n,Vector3((i-2.5)*.32,1.,sin(i)*.34),Vector3(.20,.08+i%3*.035,.12),G.mat(JADE))
		"jade_wheel","jade_clepsydra","jade_gong":
			if kind=="jade_wheel":
				G.cylinder(n,Vector3.UP*.25,.58,.5,G.mat(WOOD),.46)
				G.cylinder(n,Vector3.UP*.55,.69,.14,G.mat(EDGE))
				vase(n,Vector3.UP*.62,.88,"b97a54")
			elif kind=="jade_clepsydra":
				table(n,1.60,1.16,.5)
				for i in range(2):
					var p:=Vector3(i*.65-.34,.49+i*.51,0)
					if i==1:A.box(n,p-Vector3.UP*.26,Vector3(.58,.52,.62),WOOD)
					vase(n,p,.89,GOLD)
				A.beam(n,Vector3(-.35,.74,0),Vector3(-.35,2.04,0),.047,WOOD)
			else:
				table(n,1.70,1.1,.49)
				for x in [-.70,.70]:A.beam(n,Vector3(x,.47,0),Vector3(x,1.8,0),.10,WOOD)
				A.box(n,Vector3.UP*1.8,Vector3(1.65,.12,.16),EDGE)
				var drum:=G.cylinder(n,Vector3.UP*1.15,.54,.51,G.mat("943c31"))
				drum.rotation.x=PI/2
				var skin:=G.cylinder(n,Vector3(0,1.15,.27),.51,.04,G.mat("d5b97f"))
				skin.rotation.x=PI/2
