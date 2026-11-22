extends RefCounted
## Small utensils move with the rig's grip during the matching occupation.
const G=preload("res://scripts/geometry.gd")
const A=preload("res://scripts/jade/architecture.gd")
const POSES=["forge_strike","draw_thread","plane_wood","sort_seed","read_scroll"]
static func create(grip: Node3D,offset: Vector3,pose: String) -> Node3D:
	var hand:=A.group(grip,"OccupationTool",offset);hand.set_meta("pose",pose)
	A.mesh_part(hand,"handwork_"+pose,draw.bind(pose))
	return hand
static func draw(m: Node3D,pose: String) -> void:
	match pose:
		"forge_strike":
			A.beam(m,Vector3(0,.05,-.10),Vector3(0,-.075,.35),.071,"95653f")
			A.box(m,Vector3(0,-.077,.32),Vector3(.29,.16,.15),"626c69")
			A.box(m,Vector3(.144,-.077,.32),Vector3(.031,.15,.14),"a1afa9")
		"draw_thread":
			var shuttle:=G.ball(m,Vector3(0,0,.068),Vector3(.26,.048,.09),G.mat("987047"))
			shuttle.rotation.z=-.21
			var spool:=G.cylinder(m,Vector3(.02,.024,.087),.059,.23,G.mat("9ab6ae"))
			spool.rotation.z=PI*.50-.21
		"plane_wood":
			A.paint(m,Vector3(0,-.05,.08),Vector3(.15,.105,.38),"wood_relief")
			var wedge:=A.box(m,Vector3(0,.018,.097),Vector3(.11,.14,.042),"778681")
			wedge.rotation.x=-.42
			A.beam(m,Vector3(-.15,.03,.065),Vector3(.15,.03,.065),.04,"6a523c")
		"sort_seed":
			A.beam(m,Vector3(0,0,-.10),Vector3(0,-.04,.14),.042,"8e693f")
			G.ball(m,Vector3(0,-.042,.22),Vector3(.10,.042,.12),G.mat("bc9e6e"))
		"read_scroll":
			A.box(m,Vector3(-.17,.0,.09),Vector3(.42,.012,.23),"dfcd9a")
			for edge in [-.39,.05]:
				var roll:=G.cylinder(m,Vector3(edge,.015,.09),.033,.28,G.mat("957b52"))
				roll.rotation.x=PI*.50
			for i in range(7):
				A.box(m,Vector3(i*.042-.31,.009,.10),Vector3(.008,.005,.12+.04*sin(i)),"7d7157")
