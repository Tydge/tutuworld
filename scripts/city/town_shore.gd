extends RefCounted
## Replace only the three original terrain cylinders, including their 16-sided
## packed MultiMesh instances. Core streets, buildings, farm and props stay put.
const G=preload("res://scripts/geometry.gd")
const SEGMENTS:=256
const REVISION:=1
const LEVEL:=-.03
static func can_walk(p: Vector3) -> bool:
	# The old 52m circle clipped the visible beach and stopped the player at the
	# pier end. Follow the continuous dry shore, with room for the actor's feet.
	var flat:=Vector2(p.x,p.z/.88)
	return flat.length()<dry_radius(flat.angle())-.55
static func dry_radius(angle: float) -> float:
	var east:=1.-smoothstep(.70,1.22,absf(wrapf(angle,-PI,PI)))
	return 56.-1.6*east+sin(angle*5.+.6)*.16*east
static func profile(angle: float) -> Array[Vector3]:
	var east:=1.-smoothstep(.70,1.22,absf(wrapf(angle,-PI,PI)))
	var wave: float=(sin(angle*3.0+.4)*.19+sin(angle*7.0-1.1)*.10)*east
	var grass: float=55.-2.55*east+wave
	var dry:=dry_radius(angle)
	return [Vector3(52.,LEVEL,0),Vector3(grass,LEVEL,0),Vector3(grass+.72,-.075,.75),Vector3(dry,lerpf(-.34,-.58,east),1),Vector3(56.75+wave*.5,-1.65,1)]
static func point(angle: float,entry: Vector3) -> Vector3:return Vector3(cos(angle)*entry.x,entry.y,sin(angle)*entry.x*.88)
static func vertex(st: SurfaceTool,p: Vector3,sand: float) -> void:
	st.set_color(Color(1,1,1,sand));st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func triangle(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,sa: float,sb: float,sc: float) -> void:
	vertex(st,a,sa);vertex(st,b,sb);vertex(st,c,sc)
static func make_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		var a: float=i*TAU/SEGMENTS;var b: float=(i+1)*TAU/SEGMENTS;var left:=profile(a);var right:=profile(b)
		triangle(st,Vector3(0,LEVEL,0),point(a,left[0]),point(b,right[0]),0.,0.,0.)
		for j in range(left.size()-1):
			triangle(st,point(a,left[j]),point(a,left[j+1]),point(b,right[j+1]),left[j].z,left[j+1].z,right[j+1].z)
			triangle(st,point(a,left[j]),point(b,right[j+1]),point(b,right[j]),left[j].z,right[j+1].z,right[j].z)
	st.generate_normals();return st.commit()
static func foam_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for col in range(128):
		for row in range(8):
			for step in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var u: float=(col+step.x)/128.;var v: float=(row+step.y)/8.;var angle:=lerpf(.14*PI,.86*PI,u)
				st.set_uv(Vector2(u,v));st.add_vertex(point(angle,Vector3(lerpf(55.6,59.2,v),-1.425,0)))
	st.generate_normals();return st.commit()
static func terrain_kind(t: Transform3D) -> int:
	for i in range(3):
		var y: float=[-.18,-.33,-.90][i];var radius: float=[55.,56.,55.][i];var height_: float=[.3,.3,1.4][i]
		if t.origin.distance_to(Vector3(0,y,0))<.02 and absf(t.basis.x.length()-radius)<.05 and absf(t.basis.z.length()-radius*.88)<.05 and absf(t.basis.y.length()-height_)<.02:return i
	return -1
static func ensure(world: Node3D) -> void:
	if int(world.get_meta("town_shore_revision",0))>=REVISION:return
	var removed:=0
	for node in world.find_children("*","MultiMeshInstance3D",true,false):
		var mm: MultiMesh=node.multimesh
		if mm==null or not mm.mesh is CylinderMesh:continue
		var keep: Array[Transform3D]=[];var changed:=false
		for i in range(mm.instance_count):
			if terrain_kind(node.global_transform*mm.get_instance_transform(i))>=0:changed=true;removed+=1
			else:keep.append(mm.get_instance_transform(i))
		if not changed:continue
		if keep.is_empty():node.hide();continue
		var replacement:=MultiMesh.new();replacement.transform_format=MultiMesh.TRANSFORM_3D;replacement.mesh=mm.mesh;replacement.instance_count=keep.size()
		for i in range(keep.size()):replacement.set_instance_transform(i,keep[i])
		node.multimesh=replacement
	# The unbatched generator remains supported without regenerating other scenery.
	for node in world.get_node("Island").get_children():
		if node is MeshInstance3D and node.mesh is CylinderMesh:
			var shape: CylinderMesh=node.mesh;var t: Transform3D=node.global_transform;t.basis=t.basis.scaled_local(Vector3(shape.bottom_radius,shape.height,shape.bottom_radius))
			if terrain_kind(t)>=0:node.hide();removed+=1
	# The former south-beach fan floated above the new shore at its eastern tip.
	# Its sand footprint is now shaded on this same continuous terrain surface.
	for node in world.find_children("*","MeshInstance3D",true,false):
		var box: AABB=node.global_transform*node.get_aabb()
		if box.size.distance_to(Vector3(76,0,30))<.05 and box.get_center().distance_to(Vector3(0,.02,34))<.05:node.hide()
		var material: Material=node.material_override
		if not material is ShaderMaterial or absf(box.get_center().x)>.05 or box.size.x<100.:continue
		var shader_path: String=material.shader.resource_path
		if shader_path=="res://assets/shaders/beach_sand.gdshader" and box.position.z>18.:node.hide()
		elif shader_path=="res://assets/shaders/shore_foam.gdshader":node.mesh=foam_mesh();node.transform=Transform3D.IDENTITY
	var body: StaticBody3D=world.get_node("Island/GroundCollision");body.transform=Transform3D.IDENTITY
	for child in body.get_children():body.remove_child(child);child.free()
	var root:=Node3D.new();root.name="TownNaturalShore";world.add_child(root)
	var mesh:=make_mesh();var material:=ShaderMaterial.new();material.shader=preload("res://assets/shaders/town_shore.gdshader");material.set_shader_parameter("lawn_texture",preload("res://assets/terrain/spring_lawn_v1.png"));material.set_shader_parameter("sand_texture",preload("res://assets/terrain/fine_beach_sand_v1.png"))
	var surface:=G.mesh(root,mesh,Vector3.ZERO,material,"GrassDuneAndWetSand");surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.collision_layer=8;body.collision_mask=0
	var part:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(mesh.get_faces());part.shape=shape;body.add_child(part)
	root.set_meta("replaced_terrain_cylinders",removed);world.set_meta("town_shore_revision",REVISION)
