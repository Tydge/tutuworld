extends RefCounted
const A=preload("res://scripts/jade/architecture.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
const G=preload("res://scripts/geometry.gd")
const HEIGHT:=4.55
const HALF:=6.0
const RUN:=9.1
static func make(n: Node3D,mirrored: bool=false) -> void:
	n.set_script(preload("res://scripts/jade/gallery_view.gd"));n.set_process(false)
	var hand: float=-1. if mirrored else 1.
	A.mesh_part(n,"street_gallery"+str(mirrored),draw.bind(hand))
	var cover:=A.group(n,"Canopy")
	A.mesh_part(cover,"street_roof",func(m):A.roof(m,5.68,2.05,1.8,HEIGHT+2.92,false))
	for edge in [-1,1]:
		var face:=A.group(n,"NorthFace" if edge==-1 else "SouthFace")
		A.mesh_part(face,"street_eave"+str(edge),func(m):
			for x in [-3.45,0.,3.45]:
				A.column(m,Vector3(x,HEIGHT+1.42,edge*1.18),.14,2.84)
				A.paint(m,Vector3(x,HEIGHT+2.62,edge*1.22),Vector3(3.46,.38,.42),"cloud_beam"))
	G.solid_box(n,Vector3(0,HEIGHT-.17,0),Vector3(2*HALF+2.3,.34,2.58)).collision_layer=8
	for side in [-1,1]:
		var wing: String="West" if side<0 else "East"
		for rails in [false,true]:
			var part:=A.group(n,wing+("Rails" if rails else "Flight"))
			A.mesh_part(part,"Gallery"+str(part.name)+str(mirrored),flight.bind(side,hand,rails))
		var start:=Vector3(side*HALF,.07,side*hand*(RUN+1.2));var end:=Vector3(side*HALF,HEIGHT,side*hand*2.05)
		var landing:=Vector3(side*HALF,HEIGHT-.13,side*hand*1.53);G.solid_box(n,landing,Vector3(2.16,.26,1.70)).collision_layer=8
		var delta:=end-start;var ramp:=G.solid_box(n,(start+end)*.5-Vector3.UP*.12,Vector3(2.16,.24,delta.length()))
		ramp.rotation.x=-atan((end.y-start.y)/(end.z-start.z));ramp.collision_layer=8
		for z in [-1.28,1.28]:P.cylinder(n,"GalleryPillar",Vector3(side*(HALF-1.9),2.18,z),.20,4.36)
		P.box(n,"Balustrade",Vector3(-side*hand*.94,HEIGHT+.46,side*1.25),Vector3(2*HALF-.5,.91,.12))
	preload("res://scripts/jade/sight_geometry.gd").bake_room(n,["WestRails","EastRails","WestFlight","EastFlight"])
	n.set("hand",hand)

static func draw(m: Node3D,hand: float) -> void:
	for i in range(17):
		A.paint(m,Vector3((i-8)*.95,HEIGHT-.10,0),Vector3(.946,.20,2.60),"lacquer")
	for edge in [-1,1]:
		A.paint(m,Vector3(0,HEIGHT-.40,edge*1.22),Vector3(2*HALF+2.3,.61,.26),"cloud_beam")
		for j in [-3,-2,-1,0,1,2,3]:
			var x: float=j*2.24
			if j!=edge*hand*3:
				A.box(m,Vector3(x,HEIGHT+.83,edge*1.25),Vector3(2.24,.11,.15),"814d38")
				A.box(m,Vector3(x,HEIGHT+.39,edge*1.25),Vector3(2.24,.09,.13),"88543b")
				for k in [-1,0,1]:
					A.box(m,Vector3(x+k*.65,HEIGHT+.39,edge*1.25),Vector3(.077,.79,.093),"9d6142")
		for side in [-1,1]:
			var x: float=side*(HALF-1.9)
			A.column(m,Vector3(x,HEIGHT*.50,edge*1.22),.21,HEIGHT)
			G.cylinder(m,Vector3(x,.22,edge*1.22),.31,.44,G.mat("96907e"))
			A.beam(m,Vector3(x,HEIGHT-1.22,edge*1.22),Vector3(x-side*1.55,HEIGHT-.42,edge*1.22),.19,"82482f")
		for k in [-1,1]:
			A.lantern(m,Vector3(k*3.45,HEIGHT-1.04,edge*1.34),.72)

static func flight(m: Node3D,side: int,hand: float,rails: bool) -> void:
	var start:=Vector3(side*HALF,.07,side*hand*(RUN+1.2))
	var end:=Vector3(side*HALF,HEIGHT,side*hand*2.05)
	if rails:
		for edge in [-1,1]:
			var line:=Vector3(edge*1.02,.94,0)
			A.beam(m,start+line,end+line,.105,"715242")
			A.beam(m,start+line-Vector3.UP*.45,end+line-Vector3.UP*.45,.077,"875a48")
			for k in range(7):
				A.column(m,start.lerp(end,k/6.)+Vector3(edge*1.02,.45,0),.055,.90)
		return
	A.paint(m,Vector3(side*HALF,HEIGHT-.10,side*hand*1.53),Vector3(2.16,.2,1.70),"lacquer")
	for edge in [-1.,1.]:
		var stringer:=Vector3(edge*.96,-.17,0)
		A.beam(m,start+stringer,end+stringer,.23,"64433b")
	for j in range(26):
		var q:=start.lerp(end,(j+.5)/26.)
		var depth:=absf(end.z-start.z)/26.
		A.paint(m,q-Vector3.UP*.10,Vector3(2.16,.2,depth+.025),"lacquer")
		A.box(m,q+Vector3(0,-.006,side*hand*depth*.45),Vector3(2.17,.038,.042),"a5805d")
