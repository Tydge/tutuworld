extends RefCounted
static func build(b,n: Node3D,kind: String) -> void:
	var wood=b.material("b58c60",1)
	if kind=="dining_table":
		for x in [-1.32,1.32]:
			for z in [-.62,.62]:b.rounded(n,Vector3(x,.52,z),Vector3(.14,1.04,.14),.025,wood)
		b.rounded(n,Vector3(0,.94,0),Vector3(2.9,.20,1.47),.03,wood)
		b.rounded(n,Vector3(0,1.08,0),Vector3(3.2,.12,1.8),.055,b.material("d0ad7e",1))
		b.P.box(n,"TableCollision",Vector3(0,.57,0),Vector3(3.2,1.14,1.8))
	else:
		for x in [-.35,.35]:
			for z in [-.34,.34]:b.G.capsule(n,Vector3(x,.04,z),Vector3(x,.67,z),.052,wood)
		b.rounded(n,Vector3(0,.64,0),Vector3(.96,.13,.94),.06,wood)
		b.rounded(n,Vector3(0,.745,0),Vector3(.87,.11,.83),.07,b.material("91aa94"))
		for x in [-.35,.35]:b.rounded(n,Vector3(x,1.08,-.39),Vector3(.10,.84,.10),.025,wood)
		b.rounded(n,Vector3(0,1.26,-.39),Vector3(.85,.42,.10),.045,wood)
		b.P.box(n,"ChairCollision",Vector3(0,.75,0),Vector3(.98,1.5,.98))
		b.group(n,"SeatAnchor",Vector3(0,.80,0));b.group(n,"ExitAnchor",Vector3(0,.02,-1.25))
