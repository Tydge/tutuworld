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

static func carry(actor: CharacterBody3D,boat_hand: bool) -> void:
	var grip: Vector3=actor.rig_profile.grip_offset
	grip.x=-absf(grip.x)-.13
	var cargo:=A.group(actor.left_arm,"Cargo",grip)
	A.mesh_part(cargo,"BoatRope" if boat_hand else "CarpentersParcel",func(m):
		if boat_hand:
			for j in range(5):
				var loop:=TorusMesh.new()
				loop.inner_radius=.165;loop.outer_radius=.198;loop.rings=20;loop.ring_segments=5
				var coil:=G.mesh(m,loop,Vector3(j*.021-.04,-.15,0),G.mat("99815c"))
				coil.rotation.z=PI*.5;coil.scale.x=1.19
			A.beam(m,Vector3(-.06,-.03,-.12),Vector3(.06,.03,-.08),.034,"5c4935")
		else:
			for j in range(4):
				A.paint(m,Vector3((j%2-.5)*.12,-.30+.078*(j/2),0),Vector3(.115,.071,.67-.04*j),"wood_relief")
			for z in [-.17,.17]:
				A.box(m,Vector3(0,-.26,z),Vector3(.25,.16,.035),"6d593e")
				A.beam(m,Vector3(0,-.18,z),Vector3(0,-.015,0),.024,"79684e"))
