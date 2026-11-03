extends "res://scripts/city/home_builder.gd"
## Standalone buildable objects. Existing packed town homes retain their furniture.
func discard(node: Node) -> void:
	node.get_parent().remove_child(node);node.free()
func build_item(n: Node3D,kind: String) -> void:
	if kind in ["tea_service", "field_journal", "pressed_leaves", "ceramic_vases", "woven_basket", "moon_mobile", "petal_armchair", "floor_lamp", "lotus_pendant", "canopy_bed", "cloud_bed", "rose_arch", "lily_pond"]:
		preload("res://scripts/building/new_furniture.gd").build(self,n,kind)
		preload("res://scripts/building/appearance.gd").prepare(n,kind,self)
		preload("res://scripts/city/seating.gd").ensure(n,int(preload("res://scripts/building/catalog.gd").OBJECTS[kind].get("seats",1)))
		return
	match kind:
		"bed":
			build_bed(n);discard(n.get_node("Bedside"))
		"desk":
			build_desk(n)
			for child in n.get_children():
				if str(child.name) in ["Chair","SeatAnchor","ExitAnchor","CeramicPlant"] or (child is MeshInstance3D and child.position.y>1.145):discard(child)
		"tea_table":
			build_tea_table(n)
			for child in n.get_children():
				if child is MeshInstance3D and child.position.y>.735:discard(child)
		"hearth":
			build_hearth(n)
			var fire:=SpotLight3D.new();fire.name="FixtureFireLight";fire.position=Vector3(0,.92,.48);fire.rotation=Vector3(-.20,PI,0);fire.light_color=Color("ffb866");fire.light_energy=2.5;fire.spot_range=5.;fire.spot_angle=72.;fire.spot_attenuation=1.0;fire.shadow_enabled=false;fire.distance_fade_enabled=true;fire.distance_fade_begin=22.;fire.distance_fade_length=16.;n.add_child(fire);preload("res://scripts/city/fire_flicker.gd").attach(fire)
			for child in n.get_children():
				if str(child.name)=="CeramicPlant" or (child is MeshInstance3D and child.position.y>1.83):discard(child)
		"forest_cabinet":
			preload("res://scripts/city/forest_furniture.gd").build(self,n,kind);discard(n.get_node("CeramicPlant"))
		"sofa":build_sofa(n)
		"bookshelf":
			var oak:=material("bd9c70",1)
			for x in [-.7,.7]:rounded(n,Vector3(x,1.17,0),Vector3(.13,2.34,.6),.035,oak)
			for y in [.12,.82,1.52,2.26]:rounded(n,Vector3(0,y,0),Vector3(1.5,.12,.65),.025,oak)
			block(n,Vector3(0,1.15,-.28),Vector3(1.4,2.3,.07),material("aa8f65"));P.box(n,"BookshelfCollision",Vector3(0,1.17,0),Vector3(1.6,2.34,.7))
		"bedside":
			rounded(n,Vector3(0,.4,0),Vector3(.74,.8,.70),.06,material("d1b58a",1));G.ball(n,Vector3(0,.55,.37),Vector3.ONE*.035,G.mat("b79758",.4));P.box(n,"BedsideCollision",Vector3(0,.4,0),Vector3(.74,.8,.70))
		"chair":
			var oak:=material("c6a779",1)
			for x in [-.35,.35]:
				for z in [-.32,.32]:G.capsule(n,Vector3(x,.06,z),Vector3(x,.64,z),.055,oak)
			rounded(n,Vector3(0,.68,0),Vector3(.92,.16,.88),.08,material("839f8a"));rounded(n,Vector3(0,1.07,-.37),Vector3(.92,.72,.13),.06,oak)
			P.box(n,"ChairCollision",Vector3(0,.65,0),Vector3(.98,1.30,.95));group(n,"SeatAnchor",Vector3(0,.78,0));group(n,"ExitAnchor",Vector3(-1.1,.20,.6))
		"table_lamp":
			G.cylinder(n,Vector3(0,.06,0),.20,.05,G.mat("c8a16c"));G.cylinder(n,Vector3(0,.26,0),.035,.38,G.mat("b59b66"))
			G.cylinder(n,Vector3(0,.54,0),.31,.33,G.mat("efe0ad",.8,.1),.18);bulb(n,Vector3(0,.40,0),.10)
			var light:=OmniLight3D.new();light.name="FixtureLight";light.position=Vector3(0,.34,0);light.light_color=Color("ffd8a3");light.light_energy=1.4;light.omni_range=5.;light.omni_attenuation=1.6;light.shadow_enabled=true;n.add_child(light)
		"pendant":
			G.cylinder(n,Vector3(0,.81,0),.18,.06,material("a88b57"));G.cylinder(n,Vector3(0,.54,0),.025,.55,material("a88b57"))
			G.cylinder(n,Vector3(0,.22,0),.48,.30,G.mat("e9d4a2",.85,.12),.24);bulb(n,Vector3(0,.08,0),.13)
			var light:=OmniLight3D.new();light.name="FixtureLight";light.position=Vector3(0,-.03,0);light.light_color=Color("ffe3b5");light.light_energy=2.8;light.omni_range=8.;light.omni_attenuation=1.5;light.shadow_enabled=true;n.add_child(light)
		"small_plant":pot(n,Vector3.ZERO,.65)
		"book":
			rounded(n,Vector3(0,.035,0),Vector3(.66,.07,.43),.025,material("6d9c95"));block(n,Vector3(0,.085,0),Vector3(.56,.025,.35),material("e9dfc6"))
		"standing_book":rounded(n,Vector3(0,.26,0),Vector3(.15,.52,.40),.016,material("789b8d"))
		"letter":
			block(n,Vector3(0,.015,0),Vector3(.74,.025,.52),material("eee5cb"))
			for i in range(4):block(n,Vector3(-.05,.03,-.13+i*.065),Vector3(.44,.004,.010),material("b2ac91"))
		"cup":
			var ceramic:=G.mat("efe4ca",.55);G.cylinder(n,Vector3(0,.08,0),.14,.16,ceramic,.16);G.cylinder(n,Vector3(0,.165,0),.12,.012,G.mat("9a6948"));G.ball(n,Vector3(.17,.09,0),Vector3(.08,.06,.055),ceramic)
		"clock":
			var body:=G.cylinder(n,Vector3(0,.30,0),.27,.09,material("a58c60"));body.rotation.x=PI*.5
			var face:=G.cylinder(n,Vector3(0,.30,.056),.23,.015,G.mat("eee4c8"));face.rotation.x=PI*.5
			G.capsule(n,Vector3(0,.30,.075),Vector3(0,.45,.075),.014,material("576d60"));G.capsule(n,Vector3(0,.30,.077),Vector3(.14,.23,.077),.014,material("576d60"))
		"flowerbed":preload("res://scripts/city/plaza_flowerbed.gd").build(n,Vector3(0,-.18,0),0)
		"fountain":preload("res://scripts/city/plaza_fountain.gd").build(n,Vector3(0,-.18,0),false)
		_:preload("res://scripts/city/forest_furniture.gd").build(self,n,kind)
	preload("res://scripts/building/appearance.gd").prepare(n,kind,self)
	preload("res://scripts/city/seating.gd").ensure(n,int(preload("res://scripts/building/catalog.gd").OBJECTS[kind].get("seats",1)))
func bulb(n: Node3D,p: Vector3,radius: float) -> void:
	var material_:=StandardMaterial3D.new();material_.albedo_color=Color("ffe8ba");material_.emission_enabled=true;material_.emission=Color("ffd69a");material_.emission_energy_multiplier=1.5
	var mesh:=G.ball(n,p,Vector3.ONE*radius,material_,"Bulb");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
