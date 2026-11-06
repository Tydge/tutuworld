extends RefCounted
## Cached, opaque dish geometry; only prebuilt portion visibility changes per bite.
const G=preload("res://scripts/geometry.gd")
const Timeline=preload("res://scripts/city/meal_timeline.gd")
const IDS:=["food_carrot_soup","food_garden_salad","food_tomato_stew","food_pumpkin_soup","food_honey_wheat_cake","food_rustic_wheat_bread","food_vegetable_omelette"]
static var models: Dictionary={}
static var materials: Dictionary={}
static func material(color: String,kind: int=3) -> ShaderMaterial:
	var key:=color+str(kind)
	if not materials.has(key):
		var m:=ShaderMaterial.new();m.shader=preload("res://assets/shaders/food_surface.gdshader");m.set_shader_parameter("tint",Color(color));m.set_shader_parameter("kind",kind);materials[key]=m
	return materials[key]
static func tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color=Color.WHITE) -> void:
	for p in [a,b,c]:st.set_color(color);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func lathe(profile: Array[Vector2],segments: int=48) -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		for i in range(segments):
			var a:=i*TAU/segments;var b: float=(i+1)*TAU/segments
			var p:=Vector3(cos(a)*profile[j].x,profile[j].y,sin(a)*profile[j].x);var q:=Vector3(cos(b)*profile[j].x,profile[j].y,sin(b)*profile[j].x)
			var r:=Vector3(cos(a)*profile[j+1].x,profile[j+1].y,sin(a)*profile[j+1].x);var s:=Vector3(cos(b)*profile[j+1].x,profile[j+1].y,sin(b)*profile[j+1].x)
			tri(st,p,r,q);tri(st,q,r,s)
	st.generate_normals();return st.commit()
static func bowl_mesh() -> ArrayMesh:
	return lathe([Vector2(0,.064),Vector2(.12,.064),Vector2(.24,.11),Vector2(.305,.205),Vector2(.319,.222),Vector2(.337,.22),Vector2(.342,.208),Vector2(.297,.078),Vector2(.20,.033),Vector2(.11,.025),Vector2(0,.025)])
static func soup(id: String) -> bool:return Timeline.utensil(id)=="spoon"
static func own(node: Node,root: Node) -> void:
	for child in node.get_children():child.owner=root;own(child,root)
static func make(id: String) -> Node3D:
	if id not in IDS:id="food_pumpkin_soup"
	if not models.has(id):
		var source:=build(id);own(source,source);var packed:=PackedScene.new();packed.pack(source);source.free();models[id]=packed
	var meal: Node3D=models[id].instantiate()
	var steam:=meal.get_node_or_null("MealSteam")
	if steam!=null:
		# New per-serving instance buffer; duplicating a rendered MultiMesh can
		# synchronously read its old GPU buffer. Mesh geometry remains shared.
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=steam.multimesh.mesh;mm.instance_count=5
		steam.multimesh=mm
	return meal
static func batch(root: Node3D) -> void:
	var groups: Dictionary={}
	for part in root.get_children():
		if not part is MeshInstance3D:continue
		var key: int=part.material_override.get_instance_id()
		if not groups.has(key):groups[key]={"material":part.material_override,"parts":[]}
		groups[key].parts.append({"mesh":part.mesh,"transform":part.transform});root.remove_child(part);part.free()
	for group in groups.values():
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in group.parts:st.append_from(part.mesh,0,part.transform)
		var mesh:=G.mesh(root,st.commit(),Vector3.ZERO,group.material,"DishSurface");mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func leaf(parent: Node3D,p: Vector3,size_: Vector2,turn: float,color: String) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(10):
		for k in range(6):
			var points: Array[Vector3]=[]
			for uv in [Vector2(j/10.,k/6.),Vector2((j+1)/10.,k/6.),Vector2((j+1)/10.,(k+1)/6.),Vector2(j/10.,(k+1)/6.)]:
				var u: float=uv.x;var v: float=uv.y*2.-1.;var edge:=pow(sin(u*PI),.72)*(1.+sin(u*PI*7.)*.07)
				points.append(Vector3((u-.5)*size_.x,(.018*sin(u*PI)+.026*absf(v)*sin(u*PI*1.5))*(size_.x/.18),v*edge*size_.y*.5))
			tri(st,points[0],points[2],points[1]);tri(st,points[0],points[3],points[2])
	st.generate_normals();var node:=G.mesh(parent,st.commit(),p,material(color,2),"CurledLeaf");node.rotation.y=turn
	G.capsule(parent,p+Basis(Vector3.UP,turn)*Vector3(-size_.x*.36,.002,0),p+Basis(Vector3.UP,turn)*Vector3(size_.x*.30,.018,0),.0025,material("b3ca78",2),"LeafVein")
static func garnish(parent: Node3D,y: float) -> void:
	for i in range(3):leaf(parent,Vector3(-.025+i*.025,y,.035),Vector2(.073,.036),i*.9,"68984d")
static func salad(parent: Node3D,bites: int) -> void:
	var amount: int=[14,9,4][bites]
	for i in range(amount):
		var a:=i*2.399;var p:=Vector3(sin(a)*(.055+(i%4)*.035),.073+(i%4)*.023,cos(a)*(.045+(i%4)*.035))
		leaf(parent,p,Vector2(.22+(i%3)*.015,.135),a,["75a84f","58914b","91b85b"][i%3])
	for i in range([4,3,1][bites]):
		var a:=i*2.+.4;var p:=Vector3(sin(a)*.18,.14,cos(a)*.17)
		G.ball(parent,p,Vector3(.066,.045,.062),material("cc5942",1),"TomatoSkin")
		G.cylinder(parent,p+Vector3(0,.027,0),.050,.008,material("e4815d",1),-1,"TomatoCut")
		for j in range(4):G.ball(parent,p+Vector3(sin(j*1.57)*.029,.035,cos(j*1.57)*.027),Vector3(.006,.002,.009),material("f4d790",5),"TomatoSeed")
static func bread(parent: Node3D,bites: int) -> void:
	var cut: float=[1.,.24,-.38][bites];var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(28):
		for j in range(24):
			var points: Array[Vector3]=[]
			for uv in [Vector2(i/28.,j/24.),Vector2((i+1)/28.,j/24.),Vector2((i+1)/28.,(j+1)/24.),Vector2(i/28.,(j+1)/24.)]:
				var x:=lerpf(-1.,cut,uv.x);var a: float=uv.y*PI;var bulge:=sqrt(maxf(0.,1.-x*x));var z:=cos(a)*.205*bulge
				var y:=.075+sin(a)*.235*bulge;var seam:=absf(fposmod(x*.30+z*.30+.195,.13)-.065)
				y-=.016*(1.-smoothstep(.003,.014,seam))*smoothstep(.12,.20,y)
				points.append(Vector3(x*.30,y,z))
			tri(st,points[0],points[2],points[1]);tri(st,points[0],points[3],points[2])
	st.generate_normals();G.mesh(parent,st.commit(),Vector3.ZERO,material("c99350",0),"ScoredCrust")
	if bites>0:
		var face:=SurfaceTool.new();face.begin(Mesh.PRIMITIVE_TRIANGLES);var bulge:=sqrt(1.-cut*cut)
		for j in range(32):
			var a:=j*PI/32.;var b: float=(j+1)*PI/32.
			tri(face,Vector3(cut*.30,.075,0),Vector3(cut*.30,.075+sin(a)*.227*bulge,cos(a)*.199*bulge),Vector3(cut*.30,.075+sin(b)*.227*bulge,cos(b)*.199*bulge))
		face.generate_normals();G.mesh(parent,face.commit(),Vector3(.001,0,0),material("f0d3a1",5),"SoftCutCrumb")
		for i in range(12):
			var a:=i*2.399;var p:=Vector3(cut*.30+.002,.105+(i%3)*.045*bulge,sin(a)*.13*bulge)
			G.ball(parent,p,Vector3(.0015,.004+(i%2)*.002,.007),material("ccad7f",5),"CrumbAirPocket")
static func omelette(parent: Node3D,bites: int,pancake: bool=false,center: Vector3=Vector3.ZERO,radius: float=.29) -> void:
	var angle: float=[TAU,TAU*2./3.,TAU/3.][bites];var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var a: float=i*angle/64.;var b: float=(i+1)*angle/64.
		var ra:=radius*(1.+sin(a*7.)*.028+cos(a*11.)*.016);var rb:=radius*(1.+sin(b*7.)*.028+cos(b*11.)*.016)
		var p:=Vector3(cos(a)*ra,.085,sin(a)*ra*.89);var q:=Vector3(cos(b)*rb,.085,sin(b)*rb*.89)
		var top:=Vector3(0,.125 if not pancake else .105,0)
		tri(st,top,q,p);tri(st,p,q,q-Vector3.UP*.045);tri(st,p,q-Vector3.UP*.045,p-Vector3.UP*.045)
	if bites>0:
		for a in [0.,angle]:
			var edge:=Vector3(cos(a)*radius,.085,sin(a)*radius*.89);tri(st,Vector3(0,.125,0),edge,edge-Vector3.UP*.045);tri(st,Vector3(0,.125,0),edge-Vector3.UP*.045,Vector3(0,.04,0))
	st.generate_normals();G.mesh(parent,st.commit(),center,material("d9ae64" if pancake else "e6bd62",1),"GoldenPancake" if pancake else "IrregularOmelette")
	if not pancake:
		for i in range(15):
			var a: float=fposmod(i*2.399,TAU)
			if a>angle:continue
			var p:=Vector3(cos(a)*(.10+(i%3)*.05),.119,sin(a)*(.10+(i%3)*.05)*.89)
			var chunk:=G.box(parent,p,Vector3(.025,.015,.021),material("bb6443" if i%2 else "64914e",1),"SauteedVegetable");chunk.rotation.y=i*.8
static func pancakes(parent: Node3D,bites: int) -> void:
	for i in range(3-bites):
		var p:=Vector3(sin(i*2.)*.04,i*.047,cos(i*2.)*.025)
		omelette(parent,1 if bites==2 else 0,true,p,.205)
		if i==2-bites:
			G.ball(parent,p+Vector3(.02,.119,.015),Vector3(.092,.006,.075),material("cc9437",4),"HoneyGlaze")
			G.box(parent,p+Vector3(-.02,.132,-.016),Vector3(.055,.018,.044),material("f3d68c",3),"ButterPat")
static func soup_food(parent: Node3D,id: String,bites: int) -> void:
	var level: float=[.192,.151,.103][bites];var radius: float=[.300,.275,.210][bites]
	var color: String={"food_carrot_soup":"e69d4e","food_tomato_stew":"c86543","food_pumpkin_soup":"e9b45a"}[id]
	G.cylinder(parent,Vector3(0,level,0),radius,.009,material(color,4),-1,"SoupLiquid")
	if id=="food_pumpkin_soup":
		for i in range(32):
			var t:=i/32.;var u: float=(i+1)/32.;var a:=Vector3(sin(t*TAU*1.6)*radius*.61*(1-t),level+.007,cos(t*TAU*1.6)*radius*.61*(1-t));var b:=Vector3(sin(u*TAU*1.6)*radius*.61*(1-u),level+.007,cos(u*TAU*1.6)*radius*.61*(1-u))
			G.capsule(parent,a,b,.006,material("f5e3b3",4),"CreamSwirl")
	else:
		for i in range(7-bites*2):
			var a:=i*2.399;var p:=Vector3(sin(a)*radius*.57,level+.012,cos(a)*radius*.57)
			if id=="food_carrot_soup":G.cylinder(parent,p,.033,.014,material("f2b36c",1),-1,"CarrotSlice")
			else:G.ball(parent,p,Vector3(.037,.024,.031),material("dfac6c" if i%2 else "b64f39",1),"StewedVegetable")
	garnish(parent,level+.012)
static func build(id: String) -> Node3D:
	var root:=Node3D.new();root.name="Meal";root.set_meta("item",id);root.set_meta("utensil",Timeline.utensil(id));root.set_meta("portion",0)
	var plate:=lathe([Vector2(0,.035),Vector2(.24,.035),Vector2(.33,.052),Vector2(.38,.068),Vector2(.40,.062),Vector2(.38,.045),Vector2(.25,.015),Vector2(0,.015)])
	G.mesh(root,plate,Vector3.ZERO,material("f3e8cf"),"CeramicPlate")
	var rim:=TorusMesh.new();rim.inner_radius=.353;rim.outer_radius=.383;rim.rings=48;rim.ring_segments=8;G.mesh(root,rim,Vector3(0,.060,0),material("638e82"),"PaintedRim")
	if soup(id):G.mesh(root,bowl_mesh(),Vector3.ZERO,material("f2e4c6"),"SoupBowl")
	batch(root)
	var food:=Node3D.new();food.name="Food";root.add_child(food)
	for bites in range(4):
		var stage:=Node3D.new();stage.name="Portion%d"%bites;food.add_child(stage);stage.visible=bites==0
		if bites==3:continue
		if soup(id):soup_food(stage,id,bites)
		elif id=="food_garden_salad":salad(stage,bites)
		elif id=="food_rustic_wheat_bread":bread(stage,bites)
		elif id=="food_vegetable_omelette":omelette(stage,bites)
		else:pancakes(stage,bites)
		batch(stage)
	if soup(id):
		var steam:=MultiMeshInstance3D.new();steam.name="MealSteam";var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;var puff:=SphereMesh.new();puff.radius=1.;puff.height=2.;puff.radial_segments=8;puff.rings=4;mm.mesh=puff;mm.instance_count=5;steam.multimesh=mm
		var m:=G.mat("f0e5ce").duplicate();m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.albedo_color=Color("f5ead6",.13);m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;steam.material_override=m;steam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(steam)
	for part in root.find_children("*","GeometryInstance3D",true,false):part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root
static func set_portion(meal: Node3D,bites: int) -> void:
	bites=clampi(bites,0,3)
	if int(meal.get_meta("portion",-1))!=bites:
		meal.set_meta("portion",bites)
		for stage in meal.get_node("Food").get_children():stage.visible=str(stage.name)=="Portion%d"%bites
	var steam:=meal.get_node_or_null("MealSteam")
	if steam!=null:steam.visible=bites<3
static func animate(meal: Node3D,elapsed: float,duration: float=6.) -> void:
	var phase:=Timeline.sample(elapsed,duration);set_portion(meal,phase.bites)
	var steam:=meal.get_node_or_null("MealSteam")
	if steam==null:return
	for i in range(5):
		var t:=fposmod(elapsed*.32+i*.21,1.);var size_:=sin(t*PI)*.022
		steam.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(size_,size_*1.8,size_)),Vector3(sin(t*4+i)*.055,.24+t*.32,cos(t*3+i)*.05)))
static func bite_model(id: String) -> Node3D:
	var root:=Node3D.new();root.name="Mouthful"
	if id=="food_garden_salad":leaf(root,Vector3.ZERO,Vector2(.095,.05),.4,"7da653");G.ball(root,Vector3(.025,.01,0),Vector3(.024,.016,.020),material("d16a4d",1))
	elif id=="food_vegetable_omelette":G.ball(root,Vector3.ZERO,Vector3(.055,.024,.038),material("e8bd64",1))
	elif id in ["food_honey_wheat_cake","food_rustic_wheat_bread"]:
		G.ball(root,Vector3.ZERO,Vector3(.075,.040,.052),material("c59150",0));G.ball(root,Vector3(0,.013,-.025),Vector3(.063,.023,.027),material("ecd1a0",5))
	else:
		var color: String={"food_carrot_soup":"e69d4e","food_tomato_stew":"c86543","food_pumpkin_soup":"e9b45a"}.get(id,"e9b45a")
		G.ball(root,Vector3.ZERO,Vector3(.048,.012,.059),material(color,4))
	batch(root);return root
