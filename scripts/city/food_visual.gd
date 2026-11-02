extends RefCounted
const G=preload("res://scripts/geometry.gd")
static func bowl_mesh() -> ArrayMesh:
	var profile: Array[Vector2]=[Vector2(0,.055),Vector2(.14,.06),Vector2(.26,.12),Vector2(.305,.19),Vector2(.34,.19),Vector2(.30,.055),Vector2(.20,.025),Vector2(0,.025)]
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=40
	for ring in range(profile.size()):
		for i in range(segments+1):
			var a:=float(i)/segments*TAU
			st.add_vertex(Vector3(cos(a)*profile[ring].x,profile[ring].y,sin(a)*profile[ring].x))
	for ring in range(profile.size()-1):
		for i in range(segments):
			var k:=ring*(segments+1)+i
			for index in [k,k+segments+1,k+1,k+1,k+segments+1,k+segments+2]: st.add_index(index)
	st.generate_normals()
	return st.commit()
static func make(id: String) -> Node3D:
	var root:=Node3D.new()
	root.name="Meal"
	var ceramic:=G.mat("f7ebce",.48)
	G.cylinder(root,Vector3(0,.025,0),.38,.045,ceramic)
	var rim:=TorusMesh.new()
	rim.inner_radius=.32
	rim.outer_radius=.38
	rim.rings=32
	rim.ring_segments=8
	G.mesh(root,rim,Vector3(0,.05,0),G.mat("6d9e99",.55))
	var food:=Node3D.new()
	food.name="Food"
	root.add_child(food)
	if id=="food_honey_wheat_cake":
		for i in range(3):
			var p:=Vector3(sin(i*TAU/3)*.12,.095+i*.023,cos(i*TAU/3)*.10)
			G.cylinder(food,p,.14,.065,G.mat("ce984d",.65))
			G.cylinder(food,p+Vector3(0,.036,0),.125,.008,G.mat("edc471",.58))
			G.ball(food,p+Vector3(.025,.045,0),Vector3(.075,.009,.048),G.mat("ce922d",.33))
	elif id=="food_rustic_wheat_bread":
		G.ball(food,Vector3(0,.16,0),Vector3(.27,.145,.19),G.mat("bf8544",.65))
		G.ball(food,Vector3(0,.18,.015),Vector3(.245,.12,.173),G.mat("d9aa61",.7))
		for i in range(3):
			G.capsule(food,Vector3(-.13+i*.12,.279,-.075),Vector3(-.18+i*.12,.279,.065),.012,G.mat("f4dfb2",.8))
	elif id=="food_vegetable_omelette":
		G.cylinder(food,Vector3(0,.08,0),.29,.06,G.mat("e8c36f",.6))
		for i in range(8):
			var p:=Vector3(sin(i*2.4)*.20,.116,cos(i*2.4)*.18)
			G.ball(food,p,Vector3(.035,.014,.026),G.mat("c5694e" if i%2 else "6c9656"))
	elif id=="food_garden_salad":
		for i in range(10):
			var p:=Vector3(sin(i*2.4)*.20,.09+i%3*.018,cos(i*2.4)*.20)
			var leaf:=G.ball(food,p,Vector3(.13,.045,.09),G.mat("8cb966" if i%2 else "5d9e61"))
			leaf.rotation.y=i*1.7
		for i in range(4): G.ball(food,Vector3(sin(i*2)*.17,.15,cos(i*2)*.16),Vector3(.065,.05,.065),G.mat("dc715b"))
	else:
		G.mesh(root,bowl_mesh(),Vector3.ZERO,ceramic,"SoupBowl")
		var color: String={"food_carrot_soup":"e89c4c","food_tomato_stew":"c8684d","food_pumpkin_soup":"e7b05d"}.get(id,"e7b05d")
		G.cylinder(food,Vector3(0,.195,0),.30,.012,G.mat(color,.55))
		if id=="food_pumpkin_soup":
			for i in range(28):
				var t:=float(i)/28
				var u:=float(i+1)/28
				var a:=Vector3(sin(t*TAU*1.5)*.18*(1-t),.207,cos(t*TAU*1.5)*.18*(1-t))
				var b:=Vector3(sin(u*TAU*1.5)*.18*(1-u),.207,cos(u*TAU*1.5)*.18*(1-u))
				G.capsule(food,a,b,.009,G.mat("f6e4b8"))
		for i in range(5):
			var a:=i*2.4
			if id=="food_tomato_stew": G.box(food,Vector3(sin(a)*.17,.21,cos(a)*.17),Vector3(.075,.045,.065),G.mat("e5b571"))
			elif id=="food_carrot_soup": G.cylinder(food,Vector3(sin(a)*.17,.21,cos(a)*.17),.035,.012,G.mat("f0b571"))
		for i in range(3):
			var leaf:=G.ball(food,Vector3(-.05+i*.035,.215,.035),Vector3(.055,.008,.025),G.mat("6c9a56"))
			leaf.rotation.y=i*.7
	var groups: Dictionary={}
	for part in food.get_children():
		if part is MeshInstance3D:
			var key: int=part.material_override.get_instance_id()
			if not groups.has(key): groups[key]={"material":part.material_override,"parts":[]}
			groups[key].parts.append({"mesh":part.mesh,"transform":part.transform})
			food.remove_child(part)
			part.free()
	for group in groups.values():
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group.parts: st.append_from(part.mesh,0,part.transform)
		G.mesh(food,st.commit(),Vector3.ZERO,group.material,"FoodPortion")
	for part in root.find_children("*","GeometryInstance3D",true,false): part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
