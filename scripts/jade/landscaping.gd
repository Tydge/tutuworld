extends RefCounted
const J=preload("res://scripts/jade/layout.gd")
const G=preload("res://scripts/geometry.gd")
const A=preload("res://scripts/jade/architecture.gd")
const Paint=preload("res://scripts/jade/court_ground.gd")
const WOODLAND=preload("res://scripts/valley/woodland_groundcover.gd")
# Sample the same road and gravel geometry as the terrain shader once during baking.
static func planting_mask(tree: SceneTree) -> Image:
	var view:=SubViewport.new()
	view.size=Vector2i(Paint.SIZE,Paint.SIZE)
	view.disable_3d=true
	tree.root.add_child(view)
	var swatch:=ColorRect.new()
	swatch.size=Vector2(view.size)
	var material:=ShaderMaterial.new()
	material.shader=preload("res://assets/shaders/jade_planting_mask.gdshader")
	swatch.material=material
	view.add_child(swatch)
	view.render_target_update_mode=SubViewport.UPDATE_ONCE
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var mask:=view.get_texture().get_image()
	view.free()
	return mask

static func planting(builder: SceneTree,district: Image,mask: Image) -> void:
	var shrub:=WOODLAND.blade_mesh()
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/shaders/woodland_grass.gdshader")
	var fade:=Vector2(54.,88.)
	mat.set_shader_parameter("blade_fade",fade)
	var rng:=RandomNumberGenerator.new();rng.seed=78403
	var features: Array=[]
	var blocked: Array=[]
	const BASES={"jade_court_wall":Vector2(2.325,.25),"jade_palace_wall":Vector2(2.,.39),"jade_peony":Vector2(2.31,.93),"jade_iris":Vector2(2.31,.93)}
	for prop in builder.world.get_children():
		var kind: String=prop.get_meta("furniture_kind","")
		if BASES.has(kind):
			var half: Vector2=BASES[kind]*Vector2(prop.scale.x,prop.scale.z)+Vector2.ONE*.35
			blocked.append([Vector2(prop.position.x,prop.position.z),prop.rotation.y,half])
		if prop.has_meta("grove") or kind in ["jade_court_wall","jade_rockery","jade_pool","jade_bamboo"]:
			features.append(prop.position)
	var corridors: Array=[[Vector2(106,-19),Vector2(111,-23)],[Vector2(111,-23),Vector2(119,-32)],[Vector2(119,-32),Vector2(119,-39)],[Vector2(-116,-30),Vector2(-123,-40)]]
	for point in [Vector2(121,-40),Vector2(127,-44),Vector2(124,-51),Vector2(118,-51),Vector2(115,-33),Vector2(103,-24),Vector2(-121,-49),Vector2(-117,-34),Vector2(-98,-28)]:
		for i in range(8):
			var phi:=i*2.399;features.append(J.point(point.x+cos(phi)*2.8,point.y+sin(phi)*2.8))
	var bins: Dictionary={}
	for center: Vector3 in features:
		for i in range(32):
			var a:=rng.randf()*TAU;var r:=rng.randf_range(.55,4.7)
			var p:=center+Vector3(cos(a)*r,0,sin(a)*r)
			if J.LOT_ORIGINS.any(func(q):return Rect2(q,Vector2(24,20)).grow(.80).has_point(Vector2(p.x,p.z))):continue
			if absf(p.x-J.lane(p.z))<40. and p.z>39. and p.z<193.:continue
			var flat:=Vector2(p.x,p.z)
			var cell:=Vector2i(Paint.coord(p.x),Paint.coord(p.z))
			if mask.get_pixelv(cell).r<.5:continue
			var surface:=district.get_pixelv(cell)
			if maxf(surface.a,maxf(surface.r,surface.g))>.12:continue
			if blocked.any(func(row):var off: Vector2=(flat-row[0]).rotated(row[1]).abs()-row[2];return maxf(off.x,off.y)<0.):continue
			if corridors.any(func(path):return Geometry2D.get_closest_point_to_segment(flat,path[0],path[1]).distance_squared_to(flat)<3.1):continue
			if absf(p.x-J.lane(p.z))<8.4 or absf(p.z-J.river_z(p.x))<11.7 or not J.can_walk(p):continue
			if J.HOUSES.any(func(h):return (J.center(h)-Vector2(p.x,p.z)).length_squared()<82.):continue
			if J.FIELD_BOUNDS.grow(.65).has_point(Vector2(p.x,p.z)):continue
			p.y=J.terrain_floor(p)+.008
			var key:=Vector2i(floori(p.x/18.),floori(p.z/18.))
			if not bins.has(key):bins[key]=[]
			bins[key].append([p,rng.randf()*TAU,rng.randf_range(.72,1.75),Color("778456").lerp(Color("a5a573"),rng.randf())])
	for key: Vector2i in bins:
		var rows: Array=bins[key];var origin: Vector3=rows[0][0]
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=shrub;mm.instance_count=rows.size()
		for i in range(rows.size()):
			var row: Array=rows[i];mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,row[1]).scaled(Vector3.ONE*row[2]),row[0]-origin));mm.set_instance_color(i,row[3])
		var patch:=MultiMeshInstance3D.new();patch.name="BankHerbs";patch.position=origin;patch.multimesh=mm;patch.material_override=mat;patch.visibility_range_end=fade.y+mm.get_aabb().size.length()*.5;patch.visibility_range_end_margin=0.;patch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;builder.world.add_child(patch)
	# Low broken bands of water-worn stone follow the living edge of each river, below the towpath.
	var rock:=preload("res://scripts/jade/water_garden.gd").natural_stone()
	for chunk in range(-11,11):
		for side in [-1.,1.]:
			var bank:=SurfaceTool.new();bank.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(30):
				var x:=chunk*20.+rng.randf()*20.;var z: float=J.river_z(x)+side*rng.randf_range(7.8,12.2)
				if absf(x)<123.:continue
				var p:=Vector3(x,J.raw_height(x,z)+.16,z);var radius:=rng.randf_range(.28,1.34);var tall:=rng.randf_range(.21,.84)
				var tilt:=rng.randf();var last:=Vector3.ZERO
				for k in range(8):
					var a:=k*TAU/7.+tilt
					var q:=p+Vector3(cos(a)*radius,.07*sin(a*2.),sin(a)*radius*.69)
					if k>0:
						for v in [last,q,p+Vector3(radius*.14,tall,.08),last,p-Vector3.UP*.26,q]:
							bank.set_uv(Vector2(v.x+.3*v.z,v.y+.4*v.z)*.67);bank.add_vertex(v)
					last=q
			if absf(chunk*20.+10.)>110.:
				bank.index();bank.generate_normals();G.mesh(builder.world,bank.commit(),Vector3.ZERO,rock,"BankShingle")
static func quays(builder: SceneTree) -> void:
	for row in J.TERRACES:
		var side: float=row[0]
		for iz in range(int(row[1])+2,int(row[2])-2,2):
			var z:=iz+1.;var curb:=J.lane(z)+side*8.7
			var h:=J.raw_height(curb+side*2.8,z);var low:=J.raw_height(curb-side*2.,z)
			if h-low<.26 or J.HOUSES.any(func(house):return house[3]>50 and absf(house[3]-z)<2.25 and house[2]*side>0 and absf(house[2])<21.):continue
			# Both ends follow the same lane samples as the neighbouring section.
			var x0:=J.lane(z-1.)+side*8.7
			var x1:=J.lane(z+1.)+side*8.7
			var base:=A.group(builder.world,"StreetRevetment",Vector3((x0+x1)*.5,(h+low)*.5-.13,z))
			base.basis=Basis(Vector3.RIGHT,Vector3.UP,Vector3((x1-x0)*.5,0,1))
			var thickness:=h-low+.26
			A.paint(base,Vector3.DOWN*.0375,Vector3(.54,thickness-.075,1.998),"masonry")
			A.paint(base,Vector3(0,thickness*.5,0),Vector3(.73,.15,1.998),"stone_relief")
