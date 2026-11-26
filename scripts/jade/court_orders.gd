extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const G=preload("res://scripts/geometry.gd")
const CASES=preload("res://scripts/jade/rounds/scholars.gd").REQUESTS
const SITES=["hostel","farmhouse","academy"]
## Personal court decisions leave an inspectable consignment at the recipient's door.
static func refresh(city: Node3D,book: Dictionary) -> void:
	var old:=city.get_node_or_null("CourtConsignments")
	if old:
		for child in old.get_children():city.targets.erase(str(child.name))
		old.free()
	if book.decree.is_empty():return
	var display:=Node3D.new();display.name="CourtConsignments";city.add_child(display)
	for key in book.decree:
		var district:=int(key);var order:int=book.decree[key]
		var house:Array=J.HOUSES.filter(func(row):return row[0]==SITES[district])[0]
		var dims:=J.dims(house[4])
		var at:=J.center(house)+Vector2(dims.x*.62,dims.z+1.6).rotated(-J.door_angle(house))
		var pack:=Node3D.new();pack.name="court_order_"+str(district);display.add_child(pack)
		pack.position=J.point(at.x,at.y);pack.rotation.y=J.door_angle(house)
		G.box(pack,Vector3(0,.19,0),Vector3(1.18,.36,.64),G.mat("916a46"))
		for x in [-.44,.44]:G.box(pack,Vector3(x,.37,0),Vector3(.045,.025,.65),G.mat("b79b64"))
		match district:
			0:
				for j in 4:
					var rope:=TorusMesh.new();rope.outer_radius=.23;rope.inner_radius=.17;rope.rings=18;rope.ring_segments=6
					G.mesh(pack,rope,Vector3(-.19,.41+j*.038,0),G.mat("b99a6c"))
			1:
				for j in 3:
					var sack:=G.ball(pack,Vector3((j-1)*.32,.54,.02),Vector3(.22,.2,.23),G.mat("b6a175"))
					sack.rotation.z=float(j-1)*.11
			2:
				for j in 4:G.box(pack,Vector3(-.13,.42+j*.052,0),Vector3(.53,.048,.37),G.mat("708f86" if j%2 else "c6b482"))
		G.box(pack,Vector3(.38,.65,.12),Vector3(.26,.37,.034),G.mat("e4c89a"))
		G.box(pack,Vector3(.38,.62,.142),Vector3(.09,.09,.012),G.mat("ad503b"))
		var news:String=CASES[order][district+4]+"。"
		city.targets[str(pack.name)]={"kind":"landmark","position":pack.position,"radius":2.2,"label":"看三坊回执","day_text":news,"night_text":news}
