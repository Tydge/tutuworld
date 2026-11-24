extends RefCounted
const G=preload("res://scripts/geometry.gd")
const J=preload("res://scripts/jade/layout.gd")
const A=preload("res://scripts/jade/architecture.gd")
static func lamplight(world: Node3D,wick: Vector3,colour: Color,reach: float) -> void:
	var light:=OmniLight3D.new()
	light.name="LanternPool";light.position=wick;light.light_color=colour
	light.omni_range=reach;light.light_specular=.42;light.shadow_enabled=false
	light.distance_fade_enabled=true;light.distance_fade_begin=104.;light.distance_fade_length=64.
	light.set_meta("street_lamp",true);world.add_child(light)
static func build(builder: SceneTree) -> void:
	var world: Node3D=builder.world
	# Doubled walls, dressed bases and sloped walks make the north terraces read from below.
	for z in [J.PALACE_GATE_Z,-122.,-156.]:
		for side in [-1.,1.]:
			for i in range(12):
				if z==J.PALACE_GATE_Z and i<2:continue
				var x: float=side*(12.7+i*4.15);var p:=J.point(x,z)+Vector3.UP*.06
				builder.fixture(world,"jade_rail",p)
				var plinth:=A.paint(world,p+Vector3(0,-1.15,.03),Vector3(4.146,2.30,1.),"masonry")
				plinth.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for z in range(-184,-87,4):
		for side in [-1,1]:
			if z> -143 and z< -126:continue
			var p:=J.point(side*80.,z)
			builder.fixture(world,"jade_gallery",p,PI*.5,3.988)
	# Thirteen street posts and seven shop or palace thresholds share the original light budget.
	var door_lights: Dictionary={"ferry":-1.,"tavern":1.,"farm":-1.,"spice":1.,"tools":-1.,"tea":1.,"audience":1.}
	for h in J.HOUSES:
		var room:=world.get_node(("Shop_" if J.shops().has(h[0]) else "Hall_")+h[0]) as Node3D
		if door_lights.has(h[0]):
			var size:=A.dims(h[4])
			var wick:=A.facade_lantern(size.x,size.y,size.z,door_lights[h[0]])
			lamplight(world,room.to_global(wick),Color("ffad69"),9.)
		if h[3]< -80:continue
		var d:=A.dims(h[4]);var front:=room.get_node("Front") as Node3D
		var shop: bool=h[5] in ["tailor","shop","work","tavern","tea","smith","inn"]
		var signs:=preload("res://scripts/jade/shop_signs.gd")
		if signs.FRONTAGES.has(h[0]):
			var forge: bool=signs.FRONTAGES[h[0]]==signs.FORGE
			var mount:=Vector3(d.x-2.05,0,d.z+2.39) if forge else Vector3(d.x-.85,0,d.z+1.32)
			# The cloth pole reaches above the sewing house's lower second-floor landing.
			if h[0]=="stitch":mount.x=-mount.x
			builder.fixture(front,signs.FRONTAGES[h[0]],mount,.41 if forge else 0.)
		elif shop:
			var bracket:=Vector3(d.x-.7,3.5,d.z+.8)
			A.beam(front,bracket,bracket+Vector3(0,0,1.85),.11,"785139")
			A.paint(front,bracket+Vector3(0,-.86,1.32),Vector3(.085,1.66,.95),"brocade" if h[3]>90 else "swallows")
			var plaque:=A.box(front,bracket+Vector3(.059,-.82,1.32),Vector3(.022,1.30,.48),"efe1ba")
			var banner:=G.text3d(front,str(h[1]).substr(0,1)+"\n"+str(h[1]).substr(1,1),plaque.position+Vector3(.025,0,0),52,Color("342d28"));banner.rotation.y=PI/2
		if h[5] in ["shop","tailor","inn","tavern","work"] and not preload("res://scripts/jade/shopfront.gd").FRONT_GOODS.has(h[0]):
			for side in [-1.,1.]:
				var eave:=A.paint(front,Vector3(side*d.x*.66,2.65,d.z+.86),Vector3(d.x*.56,.09,1.22),"swallows" if h[5]=="tailor" else "brocade");eave.rotation.x=.14
				if h[5]!="tailor":continue
				for j in range(3):
					var roll:=G.cylinder(front,Vector3(side*d.x*.66+(j-1)*.37,.78,d.z+.65),.18,1.25,A.finish("swallows" if j%2 else "brocade"));roll.rotation.x=PI/2
		if h[0] in ["ledger","carver","sail","pickle"]:
			builder.fixture(front,"jade_goods",Vector3(-d.x*.70,0,d.z+.58))
		if h[5] in ["inn","study","tailor","court"]:
			var interior:=room.get_node("Furnishing") as Node3D
			var divider: Node3D=builder.fixture(interior,"jade_screen",Vector3(-d.x*.54,0,-d.z*.33),PI*.5)
			divider.scale.x=.92 if h[5]=="inn" else .76
	quarters(builder)
	for point_ in [Vector2(-5.8,151),Vector2(5.65,156),Vector2(-5.7,87),Vector2(5.4,80),Vector2(5.75,47),Vector2(-5.8,32)]:
		var x: float=J.lane(point_.y)+point_.x
		builder.tree_at_jade(x,point_.y,0 if point_.y<60. else (3 if point_.x>0. else 2))
	for side in [-1,1]:
		for i in range(14):
			var x: float=-210.+i*31.+4.8*sin(i*1.91)
			if J.BRIDGES.any(func(bridge_):return absf(x-bridge_)<12.):continue
			var z: float=J.river_z(x)+side*(21.+2.8*sin(i*4.6))
			if J.HOUSES.any(func(h):return J.center(h).distance_to(Vector2(x,z))<15.):continue
			builder.tree_at_jade(x,z,0 if i%3!=1 else 3)
			if i%3==0:builder.fixture(world,"jade_bamboo",J.point(x+3.,z+side*.68),x*.11)
	# Connect the northern palace wings with garden courts, groves and real narrow covered walks.
	for i in range(11):
		for side in [-1.,1.]:
			var x: float=side*(20.+i*4.2);builder.fixture(world,"jade_gallery",J.point(x,-184.),0.,4.188)
	for bz in [-159.,-136.,-109.]:
		for side in [-1,1]:
			builder.fixture(world,"jade_basin",J.point(side*10.,bz))
	for p in [Vector2(-59,-151),Vector2(-43,-142),Vector2(43,-143),Vector2(56,-151),Vector2(-74,-111),Vector2(72,-108),Vector2(13,-62),Vector2(-13,-63)]:
		builder.tree_at_jade(p.x,p.y,1 if p.x<0 else 2)


static func quarters(builder: SceneTree) -> void:
	# Short, staggered enclosures leave views through the windows and openings on each street.
	var courts: Array=[
		[Vector2(89,-23),Vector2(102,-19)],[Vector2(110,-18),Vector2(130,-17)],[Vector2(132,-18),Vector2(136,-38)],[Vector2(135,-48),Vector2(130,-57)],[Vector2(119,-58),Vector2(103,-57)],
		[Vector2(-100,-27),Vector2(-95,-26)],[Vector2(-93,-27),Vector2(-90,-41)],[Vector2(-124,-32),Vector2(-131,-40)],[Vector2(-131,-41),Vector2(-130,-54)],
		[Vector2(-38,-62),Vector2(-18,-60)],[Vector2(18,-64),Vector2(37,-64)],[Vector2(46,-65),Vector2(72,-61)],
		[Vector2(-59,101),Vector2(-54,100)],[Vector2(-37,104),Vector2(-35,117)],[Vector2(-62,120),Vector2(-53,124)],
		[Vector2(47,63),Vector2(57,72)],[Vector2(60,72),Vector2(69,72)],[Vector2(50,126),Vector2(49,134)],
		[Vector2(-52,-148),Vector2(-37,-150)],[Vector2(39,-151),Vector2(59,-148)],[Vector2(65,-146),Vector2(74,-139)]]
	for row in courts:
		var start: Vector2=row[0];var end: Vector2=row[1];var dir:=end-start;var count:=maxi(1,roundi(dir.length()/4.65))
		for i in range(count):
			var k:=start.lerp(end,(i+.5)/count)
			var wall: Node3D=builder.fixture(builder.world,"jade_court_wall",J.point(k.x,k.y),-dir.angle())
			wall.scale.x=dir.length()/(4.65*count)
	for p in [Vector2(103,-23),Vector2(101,-25),Vector2(119,-25),Vector2(126,-51),Vector2(129,-49),Vector2(115,-53),Vector2(116,-52),Vector2(-129,-58),Vector2(-132,-56),Vector2(-128,-60),Vector2(-98,-31),Vector2(62,-146),Vector2(60,-147),Vector2(-53,-149),Vector2(-49,-147),Vector2(44,59),Vector2(-30,73),Vector2(-32,77),Vector2(52,64),Vector2(-36,120),Vector2(31,115),Vector2(-70,72),Vector2(-39,33),Vector2(40,26)]:
		builder.fixture(builder.world,"jade_bamboo",J.point(p.x,p.y),fmod(p.x*2.4,TAU))
