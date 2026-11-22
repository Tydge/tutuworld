extends RefCounted
## Projecting trade signs are read along the street from either direction.
const G=preload("res://scripts/geometry.gd")
const A=preload("res://scripts/jade/architecture.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const TEA:="jade_teapot_sign"
const FORGE:="jade_hammer_sign"
const CLOTH:="jade_shuttle_sign"
const KINDS:=[TEA,FORGE,CLOTH]
const FRONTAGES:={"spice":TEA,"tea":TEA,"tools":FORGE,"workshop":FORGE,"clothes":CLOTH,"stitch":CLOTH}
const BRASS:="ad8651"
const CELADON:="779c88"
const IRON:="606d73"

static func link(m: Node3D,center: Vector3,radius: float,thickness: float,tint: String) -> MeshInstance3D:
	var ring:=TorusMesh.new()
	ring.inner_radius=radius-thickness;ring.outer_radius=radius+thickness;ring.rings=20;ring.ring_segments=6
	var piece:=G.mesh(m,ring,center,G.mat(tint,.46));piece.rotation.z=PI*.5
	return piece

static func kettle(m: Node3D) -> void:
	var body:=A.group(m,"CeladonTeapot",Vector3(0,2.96,.38))
	body.scale.x=.58
	var glaze:=G.mat(CELADON,.36)
	var profile:=[Vector2(.31,0),Vector2(.47,.12),Vector2(.58,.32),Vector2(.58,.53),Vector2(.43,.70),Vector2(.34,.74)]
	for i in range(profile.size()-1):
		var lo: Vector2=profile[i];var hi: Vector2=profile[i+1]
		G.cylinder(body,Vector3.UP*(lo.y+hi.y)*.5,lo.x,hi.y-lo.y,glaze,hi.x)
	G.cylinder(body,Vector3.UP*.78,.39,.095,G.mat(BRASS,.46),.20)
	G.cylinder(body,Vector3.UP*.88,.10,.12,glaze,.073)
	link(body,Vector3(0,.40,-.57),.32,.064,CELADON)
	A.beam(body,Vector3(0,.23,.43),Vector3(0,.40,.73),.19,CELADON)
	A.beam(body,Vector3(0,.40,.73),Vector3(0,.70,.90),.135,CELADON)
	A.box(body,Vector3(0,.71,.92),Vector3(.22,.08,.19),CELADON)

static func tools_on_badge(m: Node3D,face: float) -> void:
	var head:=A.group(m,"ForgedHammer",Vector3(face*.16,3.38,.34))
	head.rotation.x=-.55
	A.beam(head,Vector3(0,-.74,0),Vector3(0,.48,0),.16,"755338")
	A.box(head,Vector3(0,.40,-.025),Vector3(.21,.40,.91),IRON)
	A.box(head,Vector3(0,.40,-.48),Vector3(.23,.44,.11),IRON)
	for side: float in [-1.,1.]:
		var arm:=A.group(m,"Tongs",Vector3(face*.23,3.14,.51))
		arm.rotation.x=.42
		A.beam(arm,Vector3(0,-.52,side*.18),Vector3(0,.19,-side*.05),.07,IRON)
		A.beam(arm,Vector3(0,.19,-side*.05),Vector3(0,.58,-side*.22),.085,IRON)
		A.beam(arm,Vector3(0,.58,-side*.22),Vector3(0,.70,-side*.12),.075,IRON)
static func ironwork(m: Node3D) -> void:
	for face in [-1.,1.]:
		for rim: bool in [true,false]:
			var disc:=CylinderMesh.new()
			disc.radial_segments=8;disc.rings=0;disc.height=.075
			disc.top_radius=.84 if rim else .766;disc.bottom_radius=disc.top_radius
			var metal:=G.mat(BRASS,.46) if rim else G.mat("ddb984")
			var badge:=G.mesh(m,disc,Vector3(face*(.037 if rim else .083),3.33,.34),metal)
			badge.rotation.z=PI*.5
		tools_on_badge(m,face)

static func weaving(m: Node3D) -> void:
	var silk:=A.finish("swallows")
	for i in range(3):
		var z: float=-.15+i*.52
		var length_: float=1.47-i*.21
		var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in range(8):
			for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
				var u:=corner.x;var v: float=(j+corner.y)/8.
				panel.set_uv(Vector2(u*.75+i*.35,v))
				panel.add_vertex(Vector3(.075*sin(v*6.+i)+.08*v,3.94-v*length_-.13*v*u,z+(u-.5)*.48))
		panel.generate_normals();G.mesh(m,panel.commit(),Vector3.ZERO,silk)
	var shuttle:=link(m,Vector3(0,4.02,.40),.33,.071,BRASS)
	shuttle.scale=Vector3(.49,1.0,2.13)
	G.cylinder(m,Vector3(0,4.02,.40),.11,.53,G.mat(BRASS,.46)).rotation.x=PI*.5

static func draw(m: Node3D,kind: String) -> void:
	A.box(m,Vector3(0,.17,-.95),Vector3(.52,.34,.52),"78674e")
	A.paint(m,Vector3(0,2.24,-.95),Vector3(.19,4.16,.20),"wood_relief")
	A.paint(m,Vector3(0,4.40,.07),Vector3(.19,.20,2.46),"wood_relief")
	A.beam(m,Vector3(0,3.53,-.94),Vector3(0,4.35,-.12),.14,"795d44")
	for end: float in [-.17,.89]:
		A.beam(m,Vector3(0,4.34,end),Vector3(0,4.08,end),.036,BRASS)
		link(m,Vector3(0,4.055,end),.079,.022,BRASS)
	A.box(m,Vector3(0,3.98,.36),Vector3(.12,.125,1.67),BRASS)
	match kind:
		TEA:
			for end: float in [-.17,.83]:A.beam(m,Vector3(0,3.95,end),Vector3(0,3.52,end),.025,BRASS)
		FORGE:
			A.beam(m,Vector3(0,3.94,-.14),Vector3(0,3.72,-.13),.035,BRASS)
			A.beam(m,Vector3(0,3.94,.86),Vector3(0,3.76,.74),.035,BRASS)

static func make(parent: Node3D,kind: String) -> void:
	A.mesh_part(parent,kind+"_frame",draw.bind(kind))
	var emblem:=A.group(parent,"Emblem")
	match kind:
		TEA:A.mesh_part(emblem,kind,kettle)
		FORGE:A.mesh_part(emblem,kind,ironwork)
		CLOTH:A.mesh_part(emblem,kind,weaving)
	P.box(parent,"TimberPost",Vector3(0,2.18,-.95),Vector3(.22,4.36,.22))
