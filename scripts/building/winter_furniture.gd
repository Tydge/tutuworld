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
			P.box(n,"LecternCollision",Vector3(0,.78,0),Vector3(1.53,1.56,1.05))
