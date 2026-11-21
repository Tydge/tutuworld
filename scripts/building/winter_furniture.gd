extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")

static func build(b: RefCounted,n: Node3D,kind: String) -> void:
	var oak: Material=b.material("a47a51",1)
	var cream: Material=b.material("f1dfbc")
	match kind:
		"bread_case":
			b.rounded(n,Vector3(0,.54,0),Vector3(2.65,1.08,1.05),.06,oak)
			b.rounded(n,Vector3(0,1.08,0),Vector3(2.72,.10,1.12),.035,cream)
			for side in [-1.,1.]:
				b.block(n,Vector3(side*1.28,1.38,-.12),Vector3(.08,.55,.84),oak)
			b.block(n,Vector3(0,1.65,-.12),Vector3(2.65,.08,.9),oak)
			for x in [-.86,0.,.86]:
				G.ball(n,Vector3(x,1.25,.04),Vector3(.37,.16,.30),b.material("cb9050"),"MilkLoaf")
				for cut in [-.12,.12]:
					var score:=G.ball(n,Vector3(x+cut,1.388,.06),Vector3(.030,.013,.105),cream)
					score.rotation.y=-.36
			P.box(n,"CaseCollision",Vector3(0,.84,0),Vector3(2.72,1.68,1.12))
		"tile_stove":
			var glaze: Material=b.material("678b83")
			b.rounded(n,Vector3(0,.12,0),Vector3(1.55,.24,1.16),.07,cream)
			for row in range(4):
				for col in range(3):
					b.rounded(n,Vector3((col-1)*.48,.42+row*.42,0),Vector3(.47,.41,1.04),.035,glaze)
			b.rounded(n,Vector3(0,1.95,0),Vector3(1.55,.14,1.16),.05,cream)
			b.rounded(n,Vector3(0,.81,.54),Vector3(.86,.68,.09),.085,b.material("514c46"))
			b.block(n,Vector3(0,.73,.60),Vector3(.47,.09,.07),cream)
			G.cylinder(n,Vector3(0,2.24,-.24),.18,.44,b.material("514c46"))
			b.group(n,"ActivityAnchor",Vector3(0,0,1.01))
			P.box(n,"StoveCollision",Vector3(0,1.22,0),Vector3(1.55,2.44,1.16))
		"atlas_stand":
			b.rounded(n,Vector3(0,.08,0),Vector3(1.38,.16,1.02),.04,oak)
			b.block(n,Vector3(0,.70,0),Vector3(.27,1.30,.30),oak)
			var rest: Node3D=b.group(n,"ReadingSurface",Vector3(0,1.39,0))
			rest.rotation.x=.23
			b.rounded(rest,Vector3.ZERO,Vector3(1.53,.10,1.02),.04,oak)
			for side in [-1.,1.]:
				var pages: Node3D=b.group(rest,"Pages",Vector3(side*.32,.12,0))
				pages.rotation.z=-side*.08
				b.rounded(pages,Vector3.ZERO,Vector3(.65,.09,.82),.025,cream)
				for j in range(3):
					b.block(pages,Vector3(0,.049,-.2+j*.18),Vector3(.39-j*.045,.008,.025),b.material("708c87"))
			b.group(n,"ActivityAnchor",Vector3(0,0,.86))
			P.box(n,"LecternCollision",Vector3(0,.78,0),Vector3(1.53,1.56,1.05))
		"clothing_rack":
			var brass:=G.mat("c7a165",.42,.22)
			var linen:=preload("res://scripts/appearance/fabric_material.gd").material({"color":"6e9991","accent":"f5dfbc","pattern":"sprig","pattern_scale":6.})
			b.rounded(n,Vector3(0,.07,0),Vector3(1.14,.14,.70),.065,oak,"FormBase")
			G.cylinder(n,Vector3(0,.60,0),.054,1.03,brass,-1.,"FormPole")
			G.ball(n,Vector3(0,1.43,0),Vector3(.40,.55,.31),linen,"FormLinen")
			G.cylinder(n,Vector3(0,1.96,0),.104,.16,oak,-1.,"FormNeck")
			G.ball(n,Vector3(0,2.08,0),Vector3(.115,.073,.115),brass,"FormFinial")
			var tape: Node3D=b.group(n,"TailorTape",Vector3(.19,1.65,.26));tape.rotation.z=-.44
			G.box(tape,Vector3(0,-.11,0),Vector3(.064,.42,.014),cream,"MeasuringTape")
			for i in range(9):
				G.box(tape,Vector3(.008,-.30+i*.044,.01),Vector3(.026 if i%2==0 else .015,.008,.005),oak,"TapeMark")
			for i in range(3):
				G.cylinder(n,Vector3(-.38+i*.1,.19,.24),.05,.11,G.mat(["c87e76","75a092","e4b771"][i]))
			b.group(n,"ActivityAnchor",Vector3(0,0,.65))
			P.box(n,"FormCollision",Vector3(0,1.0,0),Vector3(.85,2.,.68))
		"bread_oven":
			var terracotta: Material=b.material("b66e52")
			var iron: Material=b.material("504c48")
			b.rounded(n,Vector3(0,.16,0),Vector3(2.23,.32,1.30),.065,oak,"OvenBase")
			for row in range(4):
				for tile in range(4):
					var brick: Material=b.material(["bd7759","c78361","b66e52"][(row*2+tile)%3])
					b.rounded(n,Vector3((tile-1.5)*.53,.38+row*.33,0),Vector3(.52,.322,1.26),.036,brick,"FireBrick")
			G.ball(n,Vector3(0,1.48,0),Vector3(1.05,.47,.61),terracotta,"OvenDome")
			b.rounded(n,Vector3(0,1.04,.64),Vector3(1.19,.68,.105),.12,iron,"IronDoor")
			b.rounded(n,Vector3(0,1.04,.701),Vector3(.92,.12,.025),.04,G.mat("a94a34",.35,.50),"EmberWindow")
			G.capsule(n,Vector3(-.27,1.23,.76),Vector3(.27,1.23,.76),.035,oak,"DoorPull")
			G.cylinder(n,Vector3(.58,1.93,-.29),.17,.48,iron,-1.,"Flue")
			b.block(n,Vector3(.58,2.05,-.29),Vector3(.45,.085,.40),iron,"FlueCap")
			var glow:=OmniLight3D.new();glow.name="FixtureFireLight";glow.position=Vector3(0,1.06,.81);glow.light_color=Color("ff9762");glow.light_energy=1.0;glow.omni_range=2.4;n.add_child(glow)
			preload("res://scripts/city/fire_flicker.gd").attach(glow)
			b.group(n,"ActivityAnchor",Vector3(0,0,1.06))
			P.box(n,"OvenCollision",Vector3(0,.98,0),Vector3(2.2,1.96,1.3))
		"quilt_chest":
			var blue: Material=b.material("7b97a1",1)
			var trim: Material=b.material("bf9567",1)
			var iron:=G.mat("b29b67",.46,.22)
			b.rounded(n,Vector3(0,.37,0),Vector3(1.65,.66,.75),.055,blue,"PaintedChest")
			b.rounded(n,Vector3(0,.73,0),Vector3(1.70,.14,.82),.063,trim,"Lid")
			for side in [-1.,1.]:
				b.rounded(n,Vector3(side*.63,.09,0),Vector3(.24,.18,.62),.045,trim,"Foot")
				b.rounded(n,Vector3(side*.56,.39,.38),Vector3(.12,.55,.075),.028,trim,"Binding")
			G.ball(n,Vector3(0,.50,.423),Vector3(.068,.081,.028),iron,"Latch")
			var quilt:=preload("res://scripts/appearance/fabric_material.gd").material({"color":"be7973","accent":"efcfaa","pattern":"tartan","pattern_scale":4.},"","furniture")
			b.rounded(n,Vector3(.13,.875,.08),Vector3(1.08,.14,.56),.056,quilt,"FoldedQuilt")
			for i in range(8):G.capsule(n,Vector3(-.28+i*.112,.89,.33),Vector3(-.28+i*.112,.815,.414),.011,cream,"QuiltFringe")
			P.box(n,"ChestCollision",Vector3(0,.47,0),Vector3(1.7,.95,.83))
		"snow_lantern":
			var frame:=G.mat("a98254",.47,.24)
			var wax:=G.mat("f3dfb3",.7)
			b.rounded(n,Vector3(0,.06,0),Vector3(.52,.12,.52),.045,frame,"LanternFoot")
			b.rounded(n,Vector3(0,.60,0),Vector3(.52,.08,.52),.045,frame,"LanternLid")
			for x in [-.203,.203]:
				for z in [-.203,.203]:
					G.box(n,Vector3(x,.33,z),Vector3(.034,.52,.034),frame,"OpenLattice")
			G.cylinder(n,Vector3(0,.235,0),.088,.25,wax,-1.,"Wax")
			b.bulb(n,Vector3(0,.39,0),.05)
			G.capsule(n,Vector3(-.105,.67,0),Vector3(.105,.67,0),.023,frame,"Handle")
			var light:=OmniLight3D.new();light.name="FixtureLight";light.position=Vector3(0,.38,0);light.light_color=Color("ffbe82");light.light_energy=.95;light.omni_range=2.8;n.add_child(light)
			preload("res://scripts/city/fire_flicker.gd").attach(light)
		"post_stamp":
			var seal: Material=b.material("a45f59")
			b.rounded(n,Vector3(0,.10,0),Vector3(.71,.2,.63),.045,oak,"StampBase")
			b.rounded(n,Vector3(0,.53,0),Vector3(.32,.91,.33),.043,oak,"StampPost")
			b.rounded(n,Vector3(0,.98,0),Vector3(.83,.13,.65),.057,cream,"StampShelf")
			b.rounded(n,Vector3(-.22,1.08,.07),Vector3(.29,.06,.30),.028,seal,"InkPad")
			G.cylinder(n,Vector3(.18,1.105,.04),.124,.10,seal,-1.,"RubberStamp")
			G.ball(n,Vector3(.18,1.23,.04),Vector3(.087,.098,.087),oak,"StampHandle")
			b.group(n,"ActivityAnchor",Vector3(0,0,.60))
			P.box(n,"PostCollision",Vector3(0,.58,0),Vector3(.73,1.16,.62))
