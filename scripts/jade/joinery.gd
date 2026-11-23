extends RefCounted
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
static func upper_floor(n: Node3D,w: float,h: float,d: float) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	var deck: Node3D=art.group(n,"UpperFloor")
	var roof: Node3D=art.group(n.get_node("Exterior"),"UpperRoof")
	art.mesh_part(roof,"balcony_roof"+str(w),func(m):art.roof(m,w+1.5,d+1.5,2.65,h+3.25,false))
	for side in [-1,1]:
		var wall: Node3D=art.group(n.get_node("West" if side<0 else "East"),"UpperSide")
		wall.transform=wall.get_parent().transform.affine_inverse()
		art.mesh_part(wall,"side_gallery"+str(w)+str(side),func(m):
			art.paint(m,Vector3(side*(w-.75),h+1.44,-.15),Vector3(.23,2.9,2*d-1.8),"lime")
			for j in [-1,0,1]:
				var window: Node3D=art.group(m,"InwardWindow",Vector3(side*(w-.90),h+1.69,j*d*.46))
				window.rotation.y=-side*PI*.5;art.lattice(window,Vector3.ZERO,d*.44,1.56)
			art.paint(m,Vector3(side*(w-.90),h+.37,0),Vector3(.11,.66,2*d-1.8),"lacquer"))
	var back: Node3D=art.group(n.get_node("Rear"),"UpperBack");back.transform=back.get_parent().transform.affine_inverse()
	art.mesh_part(back,"gallery_back"+str(w),func(m):
		for j in range(3):art.lattice(m,Vector3((j-1)*w*.49,h+1.65,-d+.6),w*.46,2.7))
	var front: Node3D=art.group(n.get_node("Front"),"UpperFront")
	art.mesh_part(front,"balustrade"+str(w),func(m):
		for i in range(-2,3):
			var x:=w*i*.45
			art.column(m,Vector3(x,h+1.56,d+.45),.14,3.12)
			art.paint(m,Vector3(x,h+2.93,d+.45),Vector3(w*.45-.004,.35,.42),"cloud_beam")
		for j in range(6):
			var x: float=(j-2.5)*w/3.
			art.box(m,Vector3(x,h+.87,d+.88),Vector3(w/3.,.12,.16),"835037")
			art.box(m,Vector3(x,h+.43,d+.88),Vector3(.10,.86,.12),"a36b43"))
	for face in ["Front","Rear"]:
		var eave:=n.get_node(face) as Node3D
		var awning:=art.paint(eave,Vector3(0,h-.12,d+.63),Vector3(w*2+.8,.16,1.56),"tiles") as MeshInstance3D;awning.rotation.x=.16
	art.mesh_part(deck,"upper_boards"+str(w),func(m):
		for j in range(12):
			for k in range(3):
				art.paint(m,Vector3((k-1)*(2*w+1.2)/3.,h-.13,(j-5.5)*(2*d+1.98)/12.),Vector3((2*w+1.2)/3.-.006,.26,(2*d+1.98)/12.-.007),"lacquer"))
	G.solid_box(deck,Vector3(0,h-.15,0),Vector3(2*w+1.2,.30,2*d+1.98)).collision_layer=8
	for side in [-1,1]:
		P.box(deck,"GalleryWall",Vector3(side*(w-.75),h+1.5,-.15),Vector3(.22,3.,2*d-1.8))
	P.box(deck,"Back",Vector3(0,h+1.5,-d+.6),Vector3(w*1.5,3.,.2))
	P.box(deck,"Rail",Vector3(0,h+.50,d+.88),Vector3(w*2.,1.,.18))
	var run:=2.*d+1.;var x:=w+1.86
	var stair: Node3D=art.group(n,"OutsideStair");var start:=Vector3(x,.08,-d-1.)
	var a:=start;var b:=start+Vector3(0,h,run)
	art.mesh_part(stair,"OutsideFlight"+str(Vector3(w,h,d)),func(m):
		for i in range(24):
			var t: float=(i+.5)/24.
			G.box(m,start+Vector3(0,h*t-.08,t*run),Vector3(2.35,.16,run/24.),art.finish("lacquer"))
		art.beam(m,a+Vector3(1.13,.94,0),b+Vector3(1.13,.94,0),.13,"95653d")
		for i in range(7):
			var pos:=a.lerp(b,i/6.)+Vector3(1.13,.49,0);art.box(m,pos,Vector3(.12,.98,.12),"864a37"))
	var slope:=G.solid_box(stair,(a+b)*.5-Vector3.UP*.13,Vector3(2.35,.25,a.distance_to(b)));slope.rotation.x=-atan2(h,run);slope.collision_layer=8
	# The outer landing starts at the edge of the existing upper boards.
	var deck_edge:=w+.6
	var outer_edge:=w+2.85
	var landing:=Vector3((deck_edge+outer_edge)*.5,h,d+.28)
	art.box(deck,landing-Vector3.UP*.13,Vector3(outer_edge-deck_edge,.26,1.6),"8d5a3e")
	# The short return beyond the deck's front edge also belongs to the landing.
	art.box(deck,Vector3((w-.95+deck_edge)*.5,h-.13,d+1.035),Vector3(deck_edge-(w-.95),.26,.09),"8d5a3e")
	G.solid_box(deck,Vector3(w+.95,h-.13,d+.28),Vector3(3.8,.26,1.6)).collision_layer=8
static func veranda(n: Node3D,kind: String,w: float,h: float,d: float) -> void:
	var art=load("res://scripts/jade/architecture.gd")
	var frame: Node3D=art.group(n.get_node("Exterior"),"CourtGallery")
	var left:=kind in ["cloister","forge","cottage"];var width:=3.3 if left else w*1.8
	var center:=Vector3(-w-1.35,0,1.6) if left else Vector3(0,0,d+1.8)
	var depth:=d+2.2 if left else 2.
	art.mesh_part(frame,"veranda_"+kind,func(m):
		var wing: Node3D=art.group(m,"Wing",center)
		art.roof(wing,width*.5+.65,depth+.48,1.3,h*.76,false)
		art.paint(wing,Vector3(0,.025,0),Vector3(width+.4,.10,2*depth),"masonry")
		for sx in [-1,1]:
			for sz in [-1,0,1]:
				var p:=Vector3(sx*width*.5,h*.38,sz*depth)
				G.cylinder(wing,p,.13,h*.76,art.finish("lacquer"))
				G.cylinder(wing,Vector3(p.x,.16,p.z),.20,.32,G.mat("b1a38a")))
	for sx in [-1,1]:
		for sz in [-1,0,1]:P.cylinder(n,"ColonnadePost",center+Vector3(sx*width*.5,h*.37,sz*depth),.14,h*.74)
