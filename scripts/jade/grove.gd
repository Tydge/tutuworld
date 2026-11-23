extends RefCounted
## Real branch forks terminate in individual willow blades, plum petals or ginkgo fans.
const Forest=preload("res://scripts/valley/ancient_forest.gd")
const G=preload("res://scripts/geometry.gd")
static var meshes: Dictionary={}
static var canopy_shadows: Dictionary={}
static var spray_material: ShaderMaterial
static var bark_by_species: Array[ShaderMaterial] = []
static var leaf_material: ShaderMaterial
const LEAF_LENGTH:=[.24,.16,.17,.25]
const LEAF_WIDTH:=[.025,.049,.083,.070]
static func blade(st: SurfaceTool,p: Vector3,axis: Vector3,width: float,color_: Color,fan: bool) -> void:
	var right:=Vector3(-axis.z,.04,axis.x).normalized()*width
	var center:=p+axis*.52+Vector3.UP*width*.22
	var rim: Array=[p,p+axis*.36+right*.82,p+axis*.80+right*(1. if fan else .51),p+axis-right*.09,p+axis*.77-right*(1. if fan else .57),p+axis*.32-right*.78]
	if fan:
		rim=[p,p+axis*.53+right*.58,p+axis*.86+right,p+axis*.99+right*.56,p+axis*.84,p+axis*.98-right*.57,p+axis*.85-right,p+axis*.52-right*.58]
	for k in range(rim.size()):
		for v in [center,rim[k],rim[(k+1)%rim.size()]]:
			st.set_color(color_.lightened(.045 if v==center else 0.).srgb_to_linear());st.set_normal((Vector3.UP-axis.normalized()*.23).normalized());st.add_vertex(v)
static func textured_spray(st: SurfaceTool,variant: int,stem: Vector3,tip: Vector3,half_width: float) -> void:
	var axis:=tip-stem
	var across:=Vector3(-axis.z,.06,axis.x).normalized()*half_width
	for corner: Vector2 in [Vector2.ZERO,Vector2.DOWN,Vector2.RIGHT,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
		st.set_uv((Vector2(variant%2,variant/2)+Vector2(.012+.976*corner.x,.988-.976*corner.y))*.5)
		st.set_normal((axis.normalized()*.30+Vector3.UP).normalized())
		st.add_vertex(stem+axis*corner.y+across*(2.*corner.x-1.))
static func model(variant: int,far: bool) -> ArrayMesh:
	var key:=Vector2i(variant,int(far))
	if meshes.has(key):return meshes[key]
	if bark_by_species.is_empty():
		for tint in ["716857","68564e","85725d","685f50"]:
			var bark := ShaderMaterial.new()
			bark.shader = preload("res://assets/shaders/ancient_bark.gdshader")
			bark.set_shader_parameter("follow_game_camera",true)
			bark.set_shader_parameter("use_instance_slope",false)
			bark.set_shader_parameter("bark_color",Color(tint))
			bark.set_shader_parameter("bark_texture",preload("res://assets/terrain/warm_tree_bark_v1.png"))
			bark_by_species.append(bark)
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
	var lean := Vector3(-.11 + .12 * variant,0,.15 * cos(variant*1.78))
	for i in range(1,trunk.size()):
		trunk[i] += lean * sin(i*.57)
	Forest.tube(wood,trunk,[.45,.27,.22,.14,.06],10)
	if not far:
		for i in range(6):
			var heading := Vector3(cos(i*2.4+variant),0,sin(i*2.4+variant))
			var spread := .65 + .28*sin(i*1.7+variant)
			Forest.tube(wood,[Vector3.UP*.43+heading*.21,heading*.36+Vector3.UP*.11,heading*spread-Vector3.UP*.12],[.15,.14,.035],6)
	var palette: Array=[["476a44","8fac63"],["b85e72","f4c9cd"],["a58436","e7c964"],["386854","80a76c"]][variant]
	for j in range(11):
		var a:=j*2.39996+variant*.37;var out:=Vector3(cos(a),0,sin(a))
		var band:=1+j%3
		var origin: Vector3=trunk[band].lerp(trunk[band+1],.22+.35*fposmod(j*.438,1.));var bend:=origin+out*(1.1+.2*(j%3))+Vector3.UP*(.55+.10*j)
		var tip:=bend+out*(.8+.22*(j%4))+Vector3.UP*(.65+.19*(j%4))
		var turn := Vector3(-out.z,.24,out.x) * (.16 * sin(j*2.1+variant))
		Forest.tube(wood,[origin,origin.lerp(bend,.43)+turn,bend,bend.lerp(tip,.56)-turn*.62,tip],[.137,.115,.084,.053,.021],6)
		for k in range(6):
			var az:=a+(k-2.5)*.69;var d:=Vector3(cos(az),0,sin(az))
			var twig:=bend.lerp(tip,.32+k*.11)
			var elbow:=twig+d*.62+Vector3.UP*.46
			var end:=elbow+d*(1.+.22*(k%3))+Vector3.UP*(-1.8 if variant==0 else .38*sin(j*1.9+k))
			Forest.tube(wood,[twig,elbow,end],[.038,.021,.006],4)
			if not far or k%2==0:
				var rise: float=-1.21 if variant==0 else .68+.32*sin(j+k)
				var crown:=elbow+d*(1.21 if far else .96)+Vector3.UP*rise
				textured_spray(sprays,variant,twig.lerp(elbow,.67),crown,.76 if far else .52)
				if not far:
					var turned:=d.rotated(Vector3.UP,-.84 if (k+j)%2==0 else .91)
					var base:=elbow.lerp(end,.53)
					textured_spray(sprays,variant,base,base+turned*.81+Vector3.UP*(rise*.84),.46)
			if far:continue # The distant crown uses the textured sprays and physical limbs.
			for m in range(6):
				var t: float=(m+.5)/8.;var at:=elbow.lerp(end,t)
				for side in [-1,1]:
					var dir:=d.rotated(Vector3.UP,side*.82)
					var leaf:=Color(palette[0]).lerp(Color(palette[1]),rnd.randf_range(.12,1.))
					blade(greens,at,dir*LEAF_LENGTH[variant]+Vector3.UP*(-.13 if variant==0 else .04),LEAF_WIDTH[variant],Color("73835c") if variant==1 else leaf,variant==2)
					if variant==1:
						for petal in range(5):
							var phi:=petal*TAU/5.+j;blade(greens,at+dir*.15,Vector3(cos(phi)*.069,.032,sin(phi)*.069),.035,leaf,false)
	wood.generate_normals();wood.index();wood.set_material(bark_by_species[variant])
	var result:=wood.commit()
	if not far:greens.index();greens.set_material(leaf_material);greens.commit(result)
	sprays.set_material(spray_material);sprays.index();sprays.commit(result)
	meshes[key]=result;return result
# Branches and the full textured crown cast one continuous shadow through both visual LODs.
# Individual leaf blades are smaller than shadow-map texels outside the immediate canopy.
static func canopy_shadow(variant: int) -> ArrayMesh:
	if not canopy_shadows.has(variant):
		var near_tree:=model(variant,false)
		var shadow:=ArrayMesh.new()
		for surface: int in [0,2]:
			shadow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,near_tree.surface_get_arrays(surface))
		shadow.surface_set_material(1,spray_material)
		canopy_shadows[variant]=shadow
	return canopy_shadows[variant]

static func place(n: Node3D,variant: int,city_grove: bool=false) -> void:
	if variant==4:preload("res://scripts/jade/temple_pine.gd").place(n);return
	for far in [false,true]:
		var m:=G.mesh(n,model(variant,far),Vector3.ZERO,null,"DistantFoliage" if far else "LeafSprays")
		if far or city_grove:m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if far:m.visibility_range_begin=72.;m.visibility_range_end=330.
		else:m.visibility_range_end=72.
	if city_grove:
		var caster:=G.mesh(n,canopy_shadow(variant),Vector3.ZERO,null,"CanopyShadow")
		caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	preload("res://scripts/city/prop_collisions.gd").cylinder(n,"Trunk",Vector3.UP*1.5,.29,3.)
