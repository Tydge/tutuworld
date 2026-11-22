extends RefCounted
const A=preload("res://scripts/jade/architecture.gd")
const G=preload("res://scripts/geometry.gd")
const P=preload("res://scripts/city/prop_collisions.gd")
static func build(n: Node3D,w: float,h: float,d: float) -> void:
	# Two open galleries, a glazed skirt around each floor and a high crown over the stage.
	var roof:=A.group(n,"Exterior")
	var faces: Dictionary={}
	for name_ in ["Front","Rear","West","East"]:faces[name_]=A.group(n,name_)
	var upper:=A.group(n,"UpperFloor")
	for level in range(2):
		var y:=level*h;var span:=Vector2(w,d)*(1.-level*.11)
		for face in ["Front","Rear","West","East"]:
			var frame:=A.group(faces[face],"StageBay",Vector3.UP*y)
			frame.rotation.y={"Front":0.,"Rear":PI,"West":-PI/2.,"East":PI/2.}[face]
			var length_:=span.x if face in ["Front","Rear"] else span.y
			var depth:=span.y if face in ["Front","Rear"] else span.x
			A.mesh_part(frame,"auditorium_%d_"%level+face,func(m):
				for j in [-1.,-.50,.50,1.]:
					var pos:=Vector3(j*length_,h*.5,depth)
					A.column(m,pos,.21,h);G.cylinder(m,pos-Vector3.UP*(h*.5-.21),.28,.42,G.mat("9c8f78"))
					for sign_ in [-1,1]:A.beam(m,pos+Vector3(0,h*.5-.85,0),pos+Vector3(sign_*.74,h*.5-.25,.12),.17,"9c5d3b")
				for j in range(4):
					A.paint(m,Vector3((j-1.5)*length_*.5,h-.18,depth+.09),Vector3(length_*.5,.51,.50),"cloud_beam")
				if face=="Rear" and level==0:
					A.paint(m,Vector3(0,h*.43,depth),Vector3(length_*1.62,h*.86,.21),"crane_panel")
				if level==1:
					for j in range(-5,6):
						if face=="East" and j>1:continue
						A.box(m,Vector3(j*length_*.17,.56,depth),Vector3(.07,.98,.12),"8f5037")
						A.box(m,Vector3(j*length_*.17,.99,depth),Vector3(length_*.18,.12,.16),"8e6042")
				if face=="Front":
					for edge in [-1.,1.]:A.lantern(m,Vector3(edge*length_*.8,h-.87,depth+.48),.80))
			if face=="Rear" and level==0:P.box(frame,"Backdrop",Vector3(0,h*.43,depth),Vector3(length_*1.62,h*.86,.21))
			for j in [-1.,-.50,.50,1.]:P.cylinder(frame,"Post",Vector3(j*length_,h*.5,depth),.20,h)
			if level==1 and face!="East":P.box(frame,"UpperRail",Vector3(0,.45,depth),Vector3(length_*2.,.9,.15))
		A.mesh_part(roof,"playhouse_eave"+str(level),func(m):
			for face in range(4):
				var side:=A.group(m,"Canopy",Vector3.UP*((level+1)*h));side.rotation.y=face*PI/2.
				var length_: float=span.x if face%2==0 else span.y;var depth: float=span.y if face%2==0 else span.x
				var awning:=A.paint(side,Vector3(0,.05,depth+.67),Vector3(length_*2.+2.48,.19,2.21),"tiles");awning.rotation.x=.27
				for j in range(-6,7):A.beam(side,Vector3(j*length_/6.,.26,depth-.15),Vector3(j*length_/6.,-.24,depth+1.59),.10,"7a5740"))
	A.mesh_part(roof,"playhouse_lantern",func(m):
		var loft:=A.group(m,"RoofLantern",Vector3.UP*(2.*h))
		for side in [-1,1]:
			A.paint(loft,Vector3(side*w*.57,1.44,0),Vector3(.20,2.88,d*1.25),"lacquer")
			A.paint(loft,Vector3(0,1.44,side*d*.61),Vector3(w*1.14,2.88,.18),"lacquer")
			for j in [-1,0,1]:A.lattice(loft,Vector3(j*w*.35,1.54,side*d*.64),w*.30,1.78)
		A.roof(loft,w*.91,d*.90,2.92,2.91,false))
	var slab:=Vector3(w*2.+.7,.27,d*2.+.6)
	A.paint(upper,Vector3(0,h-.135,0),slab,"lacquer")
	G.solid_box(upper,Vector3(0,h-.135,0),slab).collision_layer=8
	var x:=w+1.39;var start:=Vector3(x,.08,-d-.95);var end:=Vector3(x,h+.05,d-1.60)
	var stair:=A.group(n,"OutsideStair")
	for j in range(24):
		var pos:=start.lerp(end,(j+.5)/24.);A.paint(stair,pos-Vector3.UP*.11,Vector3(2.15,.23,(end.z-start.z)/24.+.04),"lacquer")
	var ramp:=G.solid_box(stair,(start+end)*.5-Vector3.UP*.12,Vector3(2.15,.24,start.distance_to(end)));ramp.rotation.x=-atan2(h,end.z-start.z);ramp.collision_layer=8
	A.beam(stair,start+Vector3(1.02,.91,0),end+Vector3(1.02,.91,0),.12,"874a30")
	for j in range(6):A.column(stair,start.lerp(end,j/5.)+Vector3(1.02,.45,0),.055,.89)
	var landing:=Vector3(w+.65,h-.12,d-.23);A.paint(upper,landing,Vector3(3.25,.24,2.35),"lacquer")
	G.solid_box(upper,landing,Vector3(3.25,.24,2.35)).collision_layer=8
