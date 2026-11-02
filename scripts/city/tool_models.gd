extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func make(kind: String) -> Node3D:
	var root:=Node3D.new();root.name="Tool"
	var wood:=G.mat("bd8952");var dark:=G.mat("806442");var brass:=G.mat("cfad69",.40)
	var metal:=G.mat("a5bec0",.35)
	match kind:
		"water":
			G.cylinder(root,Vector3.ZERO,.22,.36,wood,.24)
			for y in [-.14,.13]: G.cylinder(root,Vector3(0,y,0),.242,.026,brass)
			G.cylinder(root,Vector3(0,.19,0),.18,.025,dark)
			G.cylinder(root,Vector3(0,.208,0),.135,.018,G.mat("263e40"))
			G.capsule(root,Vector3(0,.03,.16),Vector3(0,.28,.56),.045,wood)
			var rose:=G.cylinder(root,Vector3(0,.28,.60),.115,.055,brass);rose.rotation.x=PI*.5
			for x in [-.06,0,.06]:
				for y in [-.04,.025]: G.ball(root,Vector3(x,.28+y,.634),Vector3(.012,.012,.006),dark)
			for side in [-1,1]: G.capsule(root,Vector3(side*.20,.03,-.10),Vector3(side*.20,.35,-.10),.035,wood)
			G.capsule(root,Vector3(-.20,.35,-.10),Vector3(.20,.35,-.10),.04,wood)
			marker(root,"GripR",Vector3(0,.35,-.10));marker(root,"Outlet",Vector3(0,.28,.665))
		"weed":
			G.cylinder(root,Vector3.ZERO,.105,.26,G.mat("669989"),.09)
			G.cylinder(root,Vector3(0,.15,0),.055,.055,brass)
			G.box(root,Vector3(0,.20,.045),Vector3(.12,.07,.18),G.mat("efe7c9"))
			G.capsule(root,Vector3(0,.20,.12),Vector3(0,.20,.21),.027,brass)
			G.box(root,Vector3(0,.13,.11),Vector3(.025,.11,.025),dark)
			G.box(root,Vector3(0,-.01,.105),Vector3(.13,.14,.014),G.mat("f5e9c9"))
			G.ball(root,Vector3(0,-.01,.119),Vector3(.035,.05,.005),G.mat("6a9672"))
			marker(root,"GripR",Vector3(0,.08,-.015));marker(root,"Outlet",Vector3(0,.20,.235))
		"gather_stone","gather_copper","gather_wood":
			G.capsule(root,Vector3(0,-.48,0),Vector3(0,.90,0),.042,wood)
			for y in [-.20,-.12,.12,.20]: G.cylinder(root,Vector3(0,y,0),.049,.028,dark)
			var head:=Node3D.new();head.name="WorkingHead";head.rotation.y=-PI*.5;root.add_child(head)
			if kind=="gather_stone":
				G.box(head,Vector3(0,.96,0),Vector3(.58,.28,.27),metal)
				for side in [-1,1]: G.box(head,Vector3(side*.30,.96,0),Vector3(.06,.25,.24),G.mat("7e999b",.42))
			elif kind=="gather_copper":
				G.capsule(head,Vector3(-.38,.82,0),Vector3(0,.98,0),.065,metal)
				G.capsule(head,Vector3(0,.98,0),Vector3(.39,.82,0),.065,metal)
				for side in [-1,1]: G.capsule(head,Vector3(side*.38,.82,0),Vector3(side*.52,.64,0),.034,metal)
			else:
				var blade:=BoxMesh.new();blade.size=Vector3(.10,.42,.42)
				var metal_copper:=G.mat("bc8857",.4)
				var blade_mesh:=G.mesh(root,blade,Vector3(0,.84,.17),metal_copper,"CopperBlade");blade_mesh.rotation.x=-.14
				G.capsule(root,Vector3(0,.64,.36),Vector3(0,1.04,.36),.025,G.mat("e2bc82",.35))
				G.box(root,Vector3(0,.85,-.08),Vector3(.12,.18,.18),metal_copper)
			marker(root,"GripR",Vector3(0,-.15,0));marker(root,"GripL",Vector3(0,.15,0))
			marker(root,"Impact",Vector3(0,.96,.33) if kind=="gather_stone" else (Vector3(0,.84,.39) if kind=="gather_wood" else Vector3(0,.64,.52)))
	return root
static func marker(parent: Node3D,id: String,p: Vector3) -> void:
	var node:=Marker3D.new();node.name=id;node.position=p;parent.add_child(node)
