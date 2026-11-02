extends "res://scripts/city/home_builder.gd"
const Tools=preload("res://scripts/city/tool_models.gd")
static func build_shop(world: Node3D,kind: String,title: String,p: Vector3,wall_color: String,roof_color: String) -> Node3D:
	var builder=load("res://scripts/city/shop_builder.gd").new()
	return pack_module(world,builder.construct_shop(world,kind,title,p,wall_color,roof_color),"res://scenes/shop_"+kind+".scn")
func construct_shop(world: Node3D,kind: String,title: String,p: Vector3,wall_color: String,roof_color: String) -> Node3D:
	floor_y=.18;height=4.4;thickness=.24
	blueprint={"schema":1,"id":"shop_"+kind,"size":[9.6,8.0],"floor_height":floor_y,"wall_height":height,"wall_thickness":thickness,"roof_rise":1.65,"chimney":false,
		"materials":{"plaster":wall_color,"trim":"f3e7ce","roof":roof_color,"panel":"94ae9d"},"walls":[
		{"id":"south","a":[-4.8,4.0],"b":[4.8,4.0],"openings":[{"type":"window","offset":1.1,"width":1.4,"bottom":1.1,"height":2.1},{"type":"door","offset":4.8,"width":3.8,"bottom":0.0,"height":3.6},{"type":"window","offset":8.5,"width":1.4,"bottom":1.1,"height":2.1}]},
		{"id":"east","a":[4.8,4.0],"b":[4.8,-4.0],"openings":[{"type":"window","offset":3.0,"width":2.0,"bottom":1.2,"height":2.0}]},
		{"id":"north","a":[4.8,-4.0],"b":[-4.8,-4.0],"openings":[]},
		{"id":"west","a":[-4.8,-4.0],"b":[-4.8,4.0],"openings":[{"type":"window","offset":5.0,"width":2.0,"bottom":1.2,"height":2.0}]}]}
	root=Node3D.new();root.name="Shop_"+kind;root.set_script(load("res://scripts/city/seabreeze_home.gd"));root.assembling=true
	root.floor_size=Vector2(9.6,8);root.floor_level=floor_y;root.wall_height=height;root.roof_rise=1.65;root.position=p
	root.set_meta("buildable_reference",true);root.set_meta("walk_in_shop",kind);root.set_meta("shop",kind);root.set_meta("building_definition",blueprint)
	world.add_child(root)
	var structure:=group(root,"Structure");build_floor(group(structure,"Floor"))
	var walls:=group(structure,"Walls")
	for wall in blueprint.walls: build_wall(walls,wall)
	build_roof(group(structure,"Roof"))
	var furniture:=group(root,"Furnishing",Vector3(0,floor_y,0))
	counter(furniture,kind)
	for side in [-1,1]: shelf(furniture,Vector3(side*3.9,0,-1.65),side)
	match kind:
		"farm": seed_display(furniture)
		"tools": tool_display(furniture)
		"clothes": clothing_display(furniture)
	var exterior:=group(root,"Exterior")
	rounded(exterior,Vector3(0,.10,4.45),Vector3(4.2,.20,1.0),.045,material("c8b894"))
	floor_collision(exterior,Vector3(0,.005,4.45),Vector3(4.2,.39,1.0))
	var hood:=group(root,"PorchCanopy")
	var awning:=block(hood,Vector3(0,3.64,4.55),Vector3(7.8,.13,1.40),material(roof_color));awning.rotation.x=.13
	for i in range(12):
		var stripe:=block(hood,Vector3(-3.6+i*.65,3.723,4.55),Vector3(.26,.025,1.42),material("f8eacb"));stripe.rotation.x=.13
		rounded(hood,Vector3(-3.6+i*.65,3.46,5.23),Vector3(.27,.23,.09),.025,material("f8eacb"))
	var sign:=group(hood,"ShopSign",Vector3(0,4.02,4.20))
	rounded(sign,Vector3.ZERO,Vector3(6.8,.56,.16),.04,material("e5ce9c"))
	G.text3d(sign,title,Vector3(0,0,.095),31,Color("416c5b"))
	for side in [-1,1]: pot(exterior,Vector3(side*3.5,.04,4.7),1.0)
	group(root,"MerchantAnchor",Vector3(0,floor_y,-2.72));group(root,"Entrance",Vector3(0,floor_y,5.1))
	build_shop_lights(group(root,"Lighting"))
	for wall in walls.get_children(): bake_section(wall)
	for section in [structure.get_node("Floor"),structure.get_node("Roof"),furniture,exterior,hood,root.get_node("Lighting")]: bake_section(section)
	return root
func counter(n: Node3D,kind: String) -> void:
	var stand:=group(n,"SalesCounter",Vector3(0,-.25,0))
	var tone: String={"farm":"789a78","tools":"b18a61","clothes":"c68c8b"}[kind]
	rounded(stand,Vector3(0,.52,-1.15),Vector3(5.30,1.04,1.05),.065,material(tone),"Counter")
	rounded(stand,Vector3(0,1.08,-1.15),Vector3(5.50,.14,1.15),.06,material("cead7a",1),"Countertop")
	for x in [-1.70,0.0,1.70]: rounded(stand,Vector3(x,.53,-.60),Vector3(1.5,.72,.025),.04,material(tone).duplicate())
	P.box(stand,"CounterCollision",Vector3(0,.54,-1.15),Vector3(5.4,1.08,1.12))
	var cash:=group(stand,"Till",Vector3(1.8,1.16,-1.15))
	rounded(cash,Vector3(0,.12,0),Vector3(.55,.24,.42),.04,material("e6d9ba"));block(cash,Vector3(0,.31,-.03),Vector3(.38,.23,.06),material("557b6d"))
	block(cash,Vector3(0,.325,.008),Vector3(.26,.11,.012),G.mat("accdbb",.6,.05))
	var rug:=Fabric.material({"color":"aab69b","accent":"e9dabc","pattern":"sprig","pattern_scale":3.2})
	rounded(n,Vector3(0,.012,1.7),Vector3(3.9,.025,2.6),.01,rug,"EntryRug")
func shelf(n: Node3D,p: Vector3,side: int) -> void:
	var s:=group(n,"SideShelf",p)
	for y in [.18,.95,1.72]: rounded(s,Vector3(0,y,0),Vector3(1.2,.11,2.6),.03,material("c5a16f",1))
	for z in [-1.18,1.18]:
		for x in [-.48,.48]: rounded(s,Vector3(x,.89,z),Vector3(.11,1.8,.11),.02,material("a68058"))
	P.box(s,"ShelfCollision",Vector3(0,.85,0),Vector3(1.24,1.70,2.65))
	pot(s,Vector3(0,1.8,-.85*side),.60)
func seed_display(n: Node3D) -> void:
	var dyes: Array=["d68a54","78a066","c77b68","d2aa55"]
	for side in [-1,1]:
		for row in range(3):
			for i in range(4):
				var pos:=Vector3(side*3.9,.37+row*.77,-2.55+i*.52)
				rounded(n,pos,Vector3(.65,.30,.38),.04,material("d9bf88"),"SeedBox")
				for k in range(2):
					var pack:=group(n,"SeedPacket",pos+Vector3((k-.5)*.26,.24,.02))
					block(pack,Vector3.ZERO,Vector3(.22,.32,.045),material("f1e2ba"))
					G.ball(pack,Vector3(0,.015,.031),Vector3(.065,.09,.012),material(dyes[i]))
	for i in range(3): rounded(n,Vector3(-1.65+i*.56,1.01,-1.15),Vector3(.37,.22,.28),.06,material("d8b57e"),"CounterSeedBag")
	wall_poster(n,"四季的种子",Vector3(0,3.50,-3.83),"739e7e")
func tool_display(n: Node3D) -> void:
	wall_poster(n,"认真生活的小工具",Vector3(0,3.45,-3.83),"b79a70")
	for i in range(3):
		var kind: String=["gather_stone","gather_copper","water"][i]
		var tool:=Tools.make(kind);tool.position=Vector3(-2.4+i*2.4,2.12,-3.57);tool.scale=Vector3.ONE*.68;n.add_child(tool)
	for side in [-1,1]:
		for i in range(3):
			var tool:=Tools.make("water" if i%2 else "weed");tool.position=Vector3(side*3.9,1.0,-2.35+i*.65);tool.scale=Vector3.ONE*.75;n.add_child(tool)
	var display:=Tools.make("water");display.position=Vector3(-1.3,1.11,-1.10);n.add_child(display)
func clothing_display(n: Node3D) -> void:
	wall_poster(n,"把喜欢的颜色穿上",Vector3(0,3.40,-3.83),"c98d8c")
	for i in range(3):
		var x: float=-2.5+i*2.5;var color: String=["c8767a","629184","dfb660"][i]
		var beret:=G.cylinder(n,Vector3(x,2.5,-3.55),.36,.13,Fabric.material({"color":color,"accent":"f4e4bf","pattern":"tartan","pattern_scale":9.0}));beret.rotation.x=PI*.35
		G.capsule(n,Vector3(x,2.58,-3.49),Vector3(x+.03,2.70,-3.43),.035,material(color))
	for side in [-1,1]:
		var model:=group(n,"DressForm",Vector3(side*3.8,0,.95))
		G.cylinder(model,Vector3(0,.06,0),.40,.12,material("a68561"));G.cylinder(model,Vector3(0,.53,0),.035,1.0,material("b49d76"))
		G.ball(model,Vector3(0,1.25,0),Vector3(.34,.51,.24),Fabric.material({"color":"c8767a" if side<0 else "629184","accent":"f8e7c4","pattern":"sprig"}))
		G.ball(model,Vector3(0,1.79,0),Vector3(.10,.08,.10),material("c5a879"))
		P.cylinder(model,"MannequinCollision",Vector3(0,.83,0),.42,1.66)
	for side in [-1,1]:
		for i in range(3): rounded(n,Vector3(side*3.9,.30+i*.16,-1.2),Vector3(.88,.13,.60),.035,Fabric.material({"color":["c8767a","629184","dfb660"][i],"accent":"f4e4bf","pattern":"tartan","pattern_scale":8.0}),"FoldedClothes")
func wall_poster(n: Node3D,title: String,p: Vector3,color: String) -> void:
	rounded(n,p,Vector3(4.3,.64,.12),.045,material(color));G.text3d(n,title,p+Vector3(0,0,.075),25,Color("fff2d6"))
func build_shop_lights(n: Node3D) -> void:
	var fixture:=group(n,"Pendant",Vector3(-2.45,4.13,-.40))
	G.cylinder(fixture,Vector3(0,.16,0),.025,.50,material("ad9062"))
	G.cylinder(fixture,Vector3(0,-.10,0),.46,.28,G.mat("f3ddb0",.85,.12),.22)
	var key:=SpotLight3D.new();key.name="RoomKey";key.position=Vector3(0,3.65,-.2);key.rotation.x=-PI*.5;key.light_color=Color("ffe4bb");key.spot_range=9;key.spot_angle=72;key.shadow_enabled=true;key.shadow_blur=1.8;n.add_child(key)
	var fill:=OmniLight3D.new();fill.name="RoomFill";fill.position=Vector3(0,2.3,2.2);fill.light_color=Color("e7e6c7");fill.omni_range=6.0;fill.shadow_enabled=false;n.add_child(fill)
