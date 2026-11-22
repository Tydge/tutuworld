extends RefCounted
## Real branch forks terminate in individual willow blades, plum petals or ginkgo fans.
const Forest=preload("res://scripts/valley/ancient_forest.gd")
const G=preload("res://scripts/geometry.gd")
static var meshes: Dictionary={}
static var spray_material: ShaderMaterial
static var timber: ShaderMaterial
static var leaf_material: ShaderMaterial
static func blade(st: SurfaceTool,p: Vector3,axis: Vector3,width: float,color_: Color,fan: bool) -> void:
	var right:=Vector3(-axis.z,.04,axis.x).normalized()*width
	var center:=p+axis*.52+Vector3.UP*width*.22
	var rim: Array=[p,p+axis*.36+right*.82,p+axis*.80+right*(1. if fan else .51),p+axis-right*.09,p+axis*.77-right*(1. if fan else .57),p+axis*.32-right*.78]
	for k in range(6):
		for v in [center,rim[k],rim[(k+1)%6]]:
			st.set_color(color_.lightened(.045 if v==center else 0.).srgb_to_linear());st.set_normal((Vector3.UP-axis.normalized()*.23).normalized());st.add_vertex(v)
static func model(variant: int,far: bool) -> ArrayMesh:
	var key:=Vector2i(variant,int(far))
	if meshes.has(key):return meshes[key]
	if timber==null:
		timber=ShaderMaterial.new();timber.shader=preload("res://assets/shaders/ancient_bark.gdshader")
		timber.set_shader_parameter("follow_game_camera",true)
		timber.set_shader_parameter("bark_texture",preload("res://assets/terrain/warm_tree_bark_v1.png"))
		leaf_material=ShaderMaterial.new();leaf_material.shader=preload("res://assets/shaders/jade_foliage.gdshader")
		leaf_material.set_shader_parameter("follow_game_camera",true)
	var wood:=SurfaceTool.new();wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	if spray_material==null:
		spray_material=ShaderMaterial.new();spray_material.shader=leaf_material.shader
		spray_material.set_shader_parameter("follow_game_camera",true)
		spray_material.set_shader_parameter("foliage",preload("res://assets/jade/leaf_sprays.png"));spray_material.set_shader_parameter("bough",true)
	var sprays:=SurfaceTool.new();sprays.begin(Mesh.PRIMITIVE_TRIANGLES)
	var greens:=SurfaceTool.new();greens.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rnd:=RandomNumberGenerator.new();rnd.seed=1621+variant*81
	var trunk: Array=[Vector3(0,-.12,0),Vector3(.12,1.,0),Vector3(-.19,2.2,.16),Vector3(.23,3.42,.31),Vector3(.35,4.25,.18)]
	Forest.tube(wood,trunk,[.34,.27,.22,.14,.06],8)
	var palette: Array=[["476a44","8fac63"],["b85e72","f4c9cd"],["a58436","e7c964"],["386854","80a76c"]][variant]
	for j in range(11):
		var a:=j*2.39996+variant*.37;var out:=Vector3(cos(a),0,sin(a))
		var origin: Vector3=trunk[2+j%2];var bend:=origin+out*(1.1+.2*(j%3))+Vector3.UP*(.55+.10*j)
		var tip:=bend+out*(.8+.22*(j%4))+Vector3.UP*(.65+.19*(j%4))
		Forest.tube(wood,[origin,bend,tip],[.135,.084,.021],5)
		for k in range(6):
			var az:=a+(k-2.5)*.69;var d:=Vector3(cos(az),0,sin(az))
			var twig:=bend.lerp(tip,.32+k*.11)
			var elbow:=twig+d*.62+Vector3.UP*.46
			var end:=elbow+d*(1.+.22*(k%3))+Vector3.UP*(-1.8 if variant==0 else .38*sin(j*1.9+k))
			Forest.tube(wood,[twig,elbow,end],[.038,.021,.006],4)
			if not far or k%2==0:
				var axis:=Vector3(d.x*.62,.88,d.z*.62).normalized()
				var cross:=Vector3(-d.z,.1,d.x).normalized();var width:=1.1 if far else .88
				for c in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
					sprays.set_uv((Vector2(variant%2,variant/2)+Vector2(.012+.976*c.x,.988-.976*c.y))*.5)
					sprays.set_normal((d*.45+Vector3.UP*.85).normalized());sprays.add_vertex(twig+axis*c.y*2.25+cross*(c.x-.5)*2.*width)
			if far:continue # The distant crown uses the textured sprays and physical limbs.
			for m in range(6):
				var t: float=(m+.5)/(3. if far else 8.);var at:=elbow.lerp(end,t)
				for side in [-1,1]:
					var dir:=d.rotated(Vector3.UP,side*.82)
					var leaf:=Color(palette[0]).lerp(Color(palette[1]),rnd.randf_range(.12,1.))
					var sz:=1.32 if far else 1.
					blade(greens,at,(dir*(.43 if variant!=1 else .27)+Vector3.UP*(-.32 if variant==0 else .10))*sz,.05 if variant==0 else .14*sz,Color("73835c") if variant==1 else leaf,variant==2)
					if variant==1:
						for petal in range(5):
							var phi:=petal*TAU/5.+j;blade(greens,at+dir*.23,Vector3(cos(phi)*.14,.065,sin(phi)*.14)*sz,.067*sz,leaf,true)
	wood.generate_normals();wood.index();wood.set_material(timber)
	var result:=wood.commit()
	if not far:greens.index();greens.set_material(leaf_material);greens.commit(result)
	sprays.set_material(spray_material);sprays.index();sprays.commit(result)
	meshes[key]=result;return result
static func place(n: Node3D,variant: int) -> void:
	if variant==4:preload("res://scripts/jade/temple_pine.gd").place(n);return
	for far in [false,true]:
		var m:=G.mesh(n,model(variant,far),Vector3.ZERO,null,"DistantFoliage" if far else "LeafSprays")
		if far:m.visibility_range_begin=72.;m.visibility_range_end=330.;m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:m.visibility_range_end=72.
	preload("res://scripts/city/prop_collisions.gd").cylinder(n,"Trunk",Vector3.UP*1.5,.29,3.)
