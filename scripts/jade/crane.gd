extends RefCounted
const G=preload("res://scripts/geometry.gd")
const Forest=preload("res://scripts/valley/ancient_forest.gd")
static func draw(parent: Node3D) -> void:
	var a=load("res://scripts/jade/architecture.gd")
	a.paint(parent,Vector3.UP*.19,Vector3(1.94,.38,1.9),"masonry")
	a.paint(parent,Vector3.UP*.62,Vector3(1.55,.50,1.51),"lotus_marble")
	a.paint(parent,Vector3.UP*.94,Vector3(1.76,.16,1.72),"lotus_marble")
	var copper:=G.mat("8d9270",.64);copper.metallic=.21
	var brass:=G.mat("ab8252",.47);brass.metallic=.54
	var bronze:=SurfaceTool.new();bronze.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.,1.]:
		var x: float=side*.156;var foot:=Vector3(x,1.05,side*.12)
		Forest.tube(bronze,[foot,Vector3(x,1.53,.035),Vector3(x,1.86,-.04),Vector3(x,2.34,.025)],[.038,.033,.045,.039],7)
		for k in [-1,0,1]:Forest.tube(bronze,[foot,foot+Vector3(.094*k,-.015,.13),foot+Vector3(k*.143,-.026,.25)],[.023,.018,.009],5)
	Forest.tube(bronze,[Vector3(0,2.49,.31),Vector3(.012,2.75,.52),Vector3(.035,3.13,.67),Vector3(.09,3.46,.57),Vector3(.12,3.69,.39),Vector3(.11,3.77,.28)],[.19,.128,.095,.081,.072,.09],10)
	bronze.generate_normals();G.mesh(parent,bronze.commit(),Vector3.ZERO,copper)
	var body:=G.ball(parent,Vector3(0,2.40,-.065),Vector3(.36,.34,.69),copper);body.rotation.x=-.23
	G.ball(parent,Vector3(.11,3.76,.25),Vector3(.107,.111,.172),copper)
	var beak:=G.cylinder(parent,Vector3(.11,3.70,-.08),.064,.50,brass,.006);beak.rotation.x=-1.33
	for side in [-1,1]:
		G.ball(parent,Vector3(.11+side*.085,3.79,.21),Vector3(.024,.021,.023),G.mat("493e2e"))
		for j in range(7):
			var wing:=G.ball(parent,Vector3(side*(.22+.054*sin(j*.46)),2.46-j*.017,-.06-j*.08),Vector3(.086,.15,.54-j*.013),copper);wing.rotation.x=-.25-j*.047
	var crest:=G.ball(parent,Vector3(.11,3.837,.277),Vector3(.071,.052,.093),brass);crest.rotation.x=-.32
static func make(n: Node3D) -> void:
	var a=load("res://scripts/jade/architecture.gd");a.mesh_part(n,"BronzeCrane",draw)
	preload("res://scripts/city/prop_collisions.gd").box(n,"Pedestal",Vector3.UP*.51,Vector3(1.8,1.02,1.76))
