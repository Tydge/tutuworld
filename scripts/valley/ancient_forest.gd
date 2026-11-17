extends RefCounted
## Shared tree prototypes, spatial batches and a separate cheap distant canopy.
const G=preload("res://scripts/geometry.gd")
const L=preload("res://scripts/valley/valley_layout.gd")
var rng:=RandomNumberGenerator.new()
var prototypes: Array=[]
var groups: Dictionary={}
var trees: Array=[]
var bark: ShaderMaterial
var leaves: ShaderMaterial
const DETAIL_BEGIN:=64.
const DETAIL_END:=104.
static func tube(st: SurfaceTool,points: Array,radii: Array,sides: int=12) -> void:
	var frames: Array=[]
	for k in range(points.size()):
		var tangent: Vector3=(points[mini(k+1,points.size()-1)]-points[maxi(k-1,0)]).normalized()
		var right:=tangent.cross(Vector3.FORWARD).normalized()
		if right.length()<.01:right=Vector3.RIGHT
		frames.append([right,tangent.cross(right).normalized()])
	for row in range(points.size()-1):
		for k in range(sides):
			var a: float=k*TAU/sides;var b: float=(k+1)*TAU/sides
			for pair in [[row,a],[row+1,a],[row,b],[row,b],[row+1,a],[row+1,b]]:
				var n:=int(pair[0]);var angle: float=pair[1];var ripple: float=1.+.07*sin(angle*5+n*.7)
				st.set_uv(Vector2(angle/TAU*2.,points[n].y*.20));st.set_color(Color.WHITE)
				st.add_vertex(points[n]+(frames[n][0]*cos(angle)+frames[n][1]*sin(angle))*radii[n]*ripple)
static func atlas_uv(u: float,v: float,index: int) -> Vector2:
	var origin:=Vector2(0. if index<2 else .5,0. if index in [0,2] else .5)
	return origin+Vector2(.008,.008)+Vector2(u,v)*.484
func conifer(st: SurfaceTool,index: int,low: bool,shadow: bool=false) -> void:
	var levels:=13;var branches:=9;var segments:=1 if shadow else (2 if low else 4)
	for level in range(levels):
		var u: float=level/float(levels-1);var y:=7.+u*17.;var radius:=6.4*pow(1.-u*.93,.80)
		for branch in range(branches):
			var angle: float=branch*TAU/branches+level*1.37+index*.8
			var out:=Vector3(cos(angle),0,sin(angle));var side: Vector3=(Vector3(-out.z,0,out.x)*.74+Vector3.UP*(.68 if branch%2 else -.68)).normalized()
			var length_: float=radius*(.83+.20*sin(branch*3.7+level));var width: float=length_*.33
			for segment in range(segments):
				for pair in [[segment,0],[segment+1,0],[segment,1],[segment,1],[segment+1,0],[segment+1,1]]:
					var t: float=pair[0]/float(segments);var v: float=pair[1]
					var center:=Vector3(0,y,0)+out*(.12+length_*t)+Vector3.UP*(.35*sin(t*PI)-t*.85)
					st.set_color(Color.WHITE*(.83+.16*u+.03*sin(branch+level)));st.set_uv(atlas_uv(t,v,index))
					st.add_vertex(center+side*(v*2.-1.)*width)
func broadleaf(st: SurfaceTool,index: int,low: bool) -> void:
	var clusters:=15;var planes:=3 if low else 5
	for cluster in range(clusters):
		var a: float=cluster*2.399+index;var r:=0. if cluster==0 else 4.8*sqrt(cluster/float(clusters))
		var center:=Vector3(cos(a)*r,18.8+sin(cluster*2.7)*3.4+(1.8 if cluster==0 else 0.),sin(a)*r)
		var size_:=Vector2(4.1,3.0)*(1.+.15*cos(cluster*1.6))
		for plane in range(planes):
			var angle: float=a+plane*TAU/planes
			var right:=Vector3(cos(angle),0,sin(angle));var up:=Vector3(0,.85,0)+Vector3(-right.z,0,right.x)*(.35 if plane%2 else -.35)
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				st.set_color(Color.WHITE*(.86+.1*sin(cluster*1.2)*sin(plane*.7)));st.set_uv(atlas_uv(corner.x,corner.y,index))
				st.add_vertex(center+right*(corner.x*2.-1.)*size_.x+up*(corner.y*2.-1.)*size_.y)
func prototype(index: int,low: bool,shadow: bool=false) -> Dictionary:
	var trunk:=SurfaceTool.new();trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown:=SurfaceTool.new();crown.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array=[];var radii: Array=[]
	for k in range(9):
		var y: float=k*(3. if index<2 else 2.65);points.append(Vector3((sin(k*.43+index)-sin(float(index)))*.5,y,(cos(k*.37+index)-cos(float(index)))*.35));radii.append(lerpf(.78,.10,k/8.))
	tube(trunk,points,radii,6 if shadow else (8 if low else 14))
	if not low:
		for root in range(7):
			var a: float=root*TAU/7+index;var out:=Vector3(cos(a),0,sin(a))
			tube(trunk,[out*2.5+Vector3(0,-.42,0),out*1.2+Vector3(0,.25,0),Vector3(0,1.35,0)],[.12,.32,.48],6)
		for branch in range(6 if index<2 else 9):
			var a: float=branch*2.399+index;var y: float=9.+branch*1.3;var out:=Vector3(cos(a),0,sin(a))
			tube(trunk,[Vector3(0,y,0),out*2.+Vector3(0,y+1.2,0),out*(4.2 if index<2 else 5.)+Vector3(0,y+1.6,0)],[.20,.12,.025],6)
	if index<2:conifer(crown,index,low,shadow)
	else:broadleaf(crown,index,low)
	trunk.generate_normals();crown.generate_normals();trunk.index();crown.index()
	return {"trunk":trunk.commit(),"leaves":crown.commit()}
func add_batch(parent: Node3D,rows: Array,mesh: Mesh,material: Material,label_: String,far: bool) -> void:
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=rows.size()
	var center:=Vector3.ZERO
	for row in rows:center+=row.transform.origin
	center/=rows.size()
	for i in range(rows.size()):
		var transform_: Transform3D=rows[i].transform;transform_.origin-=center
		mm.set_instance_transform(i,transform_);mm.set_instance_color(i,rows[i].tint)
		var world_transform: Transform3D=rows[i].transform;var normal:=L.normal_at(world_transform.origin.x,world_transform.origin.z)
		var scale_: float=world_transform.basis.x.length();var local_x: float=-normal.dot(world_transform.basis.x)/(normal.y*scale_);var local_z: float=-normal.dot(world_transform.basis.z)/(normal.y*scale_)
		mm.set_instance_custom_data(i,Color(local_x*.5+.5,local_z*.5+.5,0,1))
	var node:=MultiMeshInstance3D.new();node.name=label_;node.position=center;node.multimesh=mm;node.material_override=material
	# The shader transitions each tree, not a whole spatial group. Visibility
	# ranges are conservative coarse culling only, with room for every root.
	var center_of_bounds:=mm.get_aabb().get_center();var radius:=0.
	for i in range(mm.instance_count):radius=maxf(radius,mm.get_instance_transform(i).origin.distance_to(center_of_bounds))
	node.visibility_range_begin=maxf(0.,DETAIL_BEGIN-radius-2.) if far else 0.
	node.visibility_range_end=0. if far else DETAIL_END+radius+2.
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
func lod_material(original: ShaderMaterial,mode: int) -> ShaderMaterial:
	var material: ShaderMaterial=original.duplicate();material.set_shader_parameter("forest_lod",mode)
	material.set_shader_parameter("forest_detail_begin",DETAIL_BEGIN);material.set_shader_parameter("forest_detail_end",DETAIL_END)
	return material
func build(builder) -> void:
	rng.seed=903117
	bark=ShaderMaterial.new();bark.shader=preload("res://assets/shaders/ancient_bark.gdshader");bark.set_shader_parameter("bark_texture",preload("res://assets/terrain/warm_tree_bark_v1.png"))
	leaves=ShaderMaterial.new();leaves.shader=preload("res://assets/shaders/ancient_foliage.gdshader");leaves.set_shader_parameter("foliage_atlas",preload("res://assets/terrain/woodland/foliage_atlas_v1.png"))
	var near_materials:={"trunk":lod_material(bark,1),"leaves":lod_material(leaves,1)}
	var far_materials:={"trunk":lod_material(bark,2),"leaves":lod_material(leaves,2)}
	for i in range(4):
		var near:=prototype(i,false);var collider:=CylinderShape3D.new();collider.radius=.80;collider.height=6.;prototypes.append({"near":near,"far":prototype(i,true),"shadow":prototype(i,true,true),"collision":collider})
	var root:=Node3D.new();root.name="AncientForest";root.set_meta("buildable_reference",true);builder.world.add_child(root)
	for attempt in range(2400):
		var p:=Vector3(rng.randf_range(-102,102),0,rng.randf_range(-91,95));p.y=L.height_at(p.x,p.z)
		if not builder.nature_clear(p) or L.in_overlook_vista(p) or L.normal_at(p.x,p.z).y<.74:continue
		if Vector2(p.x/30.,(p.z-L.BRIDGE_Z)/11.).length()<1.:continue
		if absf(p.x-L.river_x(p.z))-L.river_half_width(p.z)<4.5 or L.path_distance(p.x,p.z)<4.8:continue
		var clear:=true
		for other in trees:
			if Vector2(other.x-p.x,other.z-p.z).length()<7.8:clear=false;break
		if not clear:continue
		trees.append(p)
		var index:=rng.randi_range(0,3);var scale_:=rng.randf_range(.74,1.32);var key:=str(Vector2i(floori(p.x/48),floori(p.z/48)))+":"+str(index)
		if not groups.has(key):groups[key]={"index":index,"rows":[]}
		var transform_:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_),p)
		groups[key].rows.append({"transform":transform_,"tint":Color.WHITE*rng.randf_range(.94,1.06)})
		var body:=StaticBody3D.new();body.name="AncientTrunk";body.collision_layer=4;body.collision_mask=0;body.transform=transform_;root.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=prototypes[index].collision;collision.position.y=3.;body.add_child(collision)
		if trees.size()>=215:break
	var young_count:=0
	for attempt in range(1800):
		var p:=Vector3(rng.randf_range(-98,98),0,rng.randf_range(-84,88));p.y=L.height_at(p.x,p.z)
		if not builder.nature_clear(p) or L.in_overlook_vista(p) or L.normal_at(p.x,p.z).y<.74 or L.path_distance(p.x,p.z)<6.0:continue
		if absf(p.x-L.river_x(p.z))-L.river_half_width(p.z)<3.:continue
		var clear:=true
		for other in trees:
			if Vector2(other.x-p.x,other.z-p.z).length()<4.4:clear=false;break
		if not clear:continue
		trees.append(p);young_count+=1
		var index:=rng.randi_range(0,3);var scale_:=rng.randf_range(.27,.48);var key:=str(Vector2i(floori(p.x/48),floori(p.z/48)))+":"+str(index)
		if not groups.has(key):groups[key]={"index":index,"rows":[]}
		var transform_:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_),p)
		groups[key].rows.append({"transform":transform_,"tint":Color.WHITE*rng.randf_range(.94,1.04)})
		var body:=StaticBody3D.new();body.name="YoungTrunk";body.collision_layer=4;body.collision_mask=0;body.transform=transform_;root.add_child(body)
		var collision:=CollisionShape3D.new();collision.shape=prototypes[index].collision;collision.position.y=3.;body.add_child(collision)
		if young_count>=110:break
	var shadow_groups: Dictionary={}
	for entry in groups.values():
		var variant: Dictionary=prototypes[entry.index]
		for far in [false,true]:
			var meshes: Dictionary=variant.far if far else variant.near
			var materials: Dictionary=far_materials if far else near_materials
			add_batch(root,entry.rows,meshes.trunk,materials.trunk,"DistantTrunks" if far else "AncientTrunks",far)
			add_batch(root,entry.rows,meshes.leaves,materials.leaves,"DistantCanopy" if far else "LayeredCanopy",far)
		for row in entry.rows:
			var origin: Vector3=row.transform.origin
			var key:=str(Vector2i(floori(origin.x/128.),floori(origin.z/128.)))+":"+str(entry.index)
			if not shadow_groups.has(key):shadow_groups[key]={"index":entry.index,"rows":[]}
			shadow_groups[key].rows.append(row)
	# Coarse shadow quadrants avoid small-cell submissions without sending the
	# entire forest's triangles to every near shadow split.
	for entry in shadow_groups.values():
		for part in ["trunk","leaves"]:
			add_batch(root,entry.rows,prototypes[entry.index].shadow[part],bark if part=="trunk" else leaves,"ForestShadow",true)
			var caster: MultiMeshInstance3D=root.get_child(-1)
			caster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;caster.visibility_range_begin=0.;caster.visibility_range_end=0.
	builder.world.set_meta("ancient_tree_count",trees.size());builder.world.set_meta("tree_height_range",Vector2(6.1,34.));builder.world.set_meta("forest_prototypes",4)
	builder.world.set_meta("forest_render_revision",2)
	backdrop_trees(builder)
	print("ANCIENT_FOREST trees=",trees.size()," spatial_groups=",groups.size())
func backdrop_trees(builder) -> void:
	var holder:=Node3D.new();holder.name="WoodedRidges";holder.set_meta("buildable_reference",true);builder.world.add_child(holder)
	var background: Dictionary={};var positions: Array[Vector3]=[]
	for attempt in range(1800):
		var angle:=rng.randf()*TAU;var radius:=rng.randf_range(110,153)
		if sin(angle)>.65:continue
		var p:=Vector3(cos(angle)*radius,L.backdrop_height(radius,angle)-.4,sin(angle)*radius*.88)
		var clear:=true
		for other in positions:
			if Vector2(p.x-other.x,p.z-other.z).length()<7.8:clear=false;break
		if not clear:continue
		positions.append(p)
		var index:=rng.randi_range(0,3);var size_:=rng.randf_range(.65,1.08);var key:=str(floori(angle/TAU*8))+":"+str(index)
		if not background.has(key):background[key]={"index":index,"rows":[]}
		background[key].rows.append({"transform":Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size_),p),"tint":Color.WHITE})
		if positions.size()>=240:break
	for entry in background.values():
		for part in ["trunk","leaves"]:
			add_batch(holder,entry.rows,prototypes[entry.index].far[part],bark if part=="trunk" else leaves,"RidgeTrees",true)
			var node: MultiMeshInstance3D=holder.get_child(-1);node.visibility_range_begin=0.;node.visibility_range_end=0.;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.world.set_meta("ridge_tree_count",positions.size())
