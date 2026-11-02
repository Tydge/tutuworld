extends RefCounted
## Props collide with actors (layer 4), while the follow camera uses world layer 1.
static func box(parent: Node3D,id: String,position_: Vector3,size_: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.name=id
	body.collision_layer=4
	body.collision_mask=0
	body.position=position_
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size_
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)
static func cylinder(parent: Node3D,id: String,position_: Vector3,radius: float,height: float) -> void:
	var body:=StaticBody3D.new()
	body.name=id
	body.collision_layer=4
	body.collision_mask=0
	body.position=position_
	var collision:=CollisionShape3D.new()
	var shape:=CylinderShape3D.new()
	shape.radius=radius
	shape.height=height
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)
static func build(world: Node3D) -> void:
	for lamp_ in world.get_node("Streetlights").get_children(): cylinder(lamp_,"PoleCollision",Vector3(0,1.4,0),.23,2.8)
	for node in world.find_children("SidewalkBoard*","Node3D",true,false): box(node,"BoardCollision",Vector3(0,.7,0),Vector3(1.0,1.4,.44))
	for building in world.get_children():
		if building.has_meta("walk_in_shop"): continue
		if str(building.name).begins_with("Shop_") or str(building.name) in ["Kitchen","PostOffice","Cafe"]:
			for side in [-1,1]: box(building,"PlanterCollision",Vector3(side*3.0,.37,3.7),Vector3(.95,.74,.85))
	for x in [-8,8]:
		for z in [-7,7]: cylinder(world.get_node("CentralPark"),"FlowerbedCollision",Vector3(x,.27,z),1.58,.54)
	box(world.get_node("CentralPark/WelcomeSign"),"WelcomeSignCollision",Vector3(0,.9,0),Vector3(3.65,1.8,.22))
	var farm: Node3D=world.get_node("EastFarm")
	box(farm,"BackFenceCollision",Vector3(30,.58,-9.6),Vector3(20.15,1.16,.20))
	for x in [20,40]: box(farm,"SideFenceCollision",Vector3(x,.58,.15),Vector3(.20,1.16,19.5))
	for x in [24,36]: box(farm,"FrontFenceCollision",Vector3(x,.58,9.9),Vector3(8,1.16,.20))
	box(farm.get_node("PottingCorner"),"TableCollision",Vector3(0,.42,0),Vector3(2.2,.84,.85))
	box(farm.get_node("GardenSign"),"GardenSignCollision",Vector3(0,.8,0),Vector3(2.35,1.6,.22))
	cylinder(farm.get_node("Scarecrow"),"ScarecrowCollision",Vector3(0,.9,0),.29,1.8)
	for i in range(3): cylinder(farm,"RainBarrelCollision",Vector3(41+i*.65,.4,-10),.28,.8)
	box(world.get_node("Kitchen/CookingCounter"),"CounterCollision",Vector3(0,.55,0),Vector3(3.85,1.10,1.02))
	var dining: Node3D=world.get_node("DiningTable")
	cylinder(dining,"TableCollision",Vector3(0,.55,0),1.06,1.10)
	box(dining.get_node("DiningChair"),"ChairCollision",Vector3(0,.61,0),Vector3(.98,1.22,.90))
	box(dining.get_node("DiningSign"),"DiningSignCollision",Vector3(0,.74,0),Vector3(1.2,1.48,.14))
	var beach: Node3D=world.get_node("SouthBeach")
	for node in beach.get_children():
		if str(node.name).begins_with("Parasol"):
			cylinder(node,"ParasolCollision",Vector3(0,1.3,0),.10,2.6)
			cylinder(node,"TableCollision",Vector3(0,.31,1.5),.43,.62)
			for child in node.get_children():
				if str(child.name).begins_with("LoungeChair"): box(child,"ChairCollision",Vector3(0,.35,-.18),Vector3(.88,.70,1.96))
	for z in [33.0,36.5,40.0,43.5]:
		for x in [11.4,14.6]: cylinder(beach,"PierPostCollision",Vector3(x,.61,z),.15,1.22)
	box(beach.get_node("SandCastle"),"CastleCollision",Vector3(0,.43,0),Vector3(1.1,.86,1.1))
