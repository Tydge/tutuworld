extends RefCounted
const Art = preload("res://scripts/jade/architecture.gd")
const G = preload("res://scripts/geometry.gd")
const HALF_SIZES := {
	"jade_tile":Vector2(6.1,5.1), "jade_double":Vector2(12.5,8.), "jade_glazed":Vector2(8.5,6.5),
	"jade_pavilion":Vector2(6.5,4.5), "jade_bell":Vector2(5.45,5.8), "jade_stage":Vector2(6.6,5.3),
	"jade_walkway":Vector2(2.5,1.5),"jade_bridge":Vector2(4.5,1.5),"jade_veranda":Vector2(1.5,5.5)
}
static var surfaces: Dictionary = {}

static func crown(model: Node3D, form: String) -> void:
	var half: Vector2 = HALF_SIZES[form]
	match form:
		"jade_walkway":
			var mount := Art.group(model,"Rafters", Vector3.DOWN*3.32)
			preload("res://scripts/jade/garden.gd").draw_model(mount,"gallery_roof",4.62)
		"jade_bridge":
			Art.roof(model,5.68,2.05,1.8,0.,false)
		"jade_veranda":
			Art.roof(model,half.x+.65,half.y+.48,1.3,0.,false)
		"jade_pavilion":
			preload("res://scripts/jade/pavilions.gd").canopy(model, half.x, 0., half.y)
		"jade_bell":
			Art.roof(model, half.x+1.5, half.y+1.5, 2.65, 0., false)
			Art.bell_turret(model,1.25)
		"jade_stage":
			var stage=preload("res://scripts/jade/theatre.gd")
			stage.eaves(model,half,0.)
			stage.lantern_roof(model, half.x, half.y, 0.)
		_:
			var kind: String = {"jade_tile":"hall","jade_double":"palace","jade_glazed":"court"}[form]
			Art.hall_roof(model, kind, half.x, 0., half.y)

# Some city tile sheets are authored two-sided. The building cutaway shader
# culls back faces. Give those sheets a real underside, including its normals.
static func surface_mesh(mesh: Mesh, index: int, two_sided: bool) -> ArrayMesh:
	var piece := ArrayMesh.new()
	piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(index))
	if not two_sided: return piece
	var back := SurfaceTool.new()
	back.create_from(mesh,index)
	back.deindex()
	var arrays := back.commit_to_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	indices.resize(vertices.size())
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0, vertices.size(), 3):
		indices[i] = i
		indices[i+1] = i+2
		indices[i+2] = i+1
	for i in normals.size(): normals[i] = -normals[i]
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return piece

static func build(builder: RefCounted, parent: Node3D, form: String, w: float, d: float, y: float) -> void:
	# Cache one set of tile, timber and ridge meshes per silhouette. Freehand
	# roof drags can visit hundreds of different rectangles in a single edit.
	var frame: Node3D = builder.group(parent, "Eaves", Vector3.UP*(y-1. if form=="jade_veranda" else y))
	var half: Vector2 = HALF_SIZES[form]
	frame.scale = Vector3(w/(2.*half.x), clampf(minf(w/half.x, d/half.y)*.5, .3, 1.35), d/(2.*half.y))
	stamp(builder, frame, form, crown.bind(form), builder.blueprint.materials.roof)

static func stamp(builder: RefCounted, frame: Node3D, key: String, draw: Callable, dye: String = "") -> void:
	if not surfaces.has(key):
		var staging := Node3D.new()
		Art.mesh_part(staging, "editable_" + key, draw)
		var mesh: Mesh = staging.get_child(0).mesh
		var parts: Array = []
		for i in mesh.get_surface_count():
			var source: Material = mesh.surface_get_material(i)
			var piece := surface_mesh(mesh, i, source is StandardMaterial3D and source.cull_mode == BaseMaterial3D.CULL_DISABLED)
			parts.append([piece, source])
		surfaces[key] = parts
		staging.free()
	for part in surfaces[key]:
		var source: Material = part[1]
		var mat: ShaderMaterial = builder.material(source.albedo_color.to_html(false) if source is StandardMaterial3D else ("bf4434" if source == Art.shade("silk") else "eadbb9")).duplicate()
		if source is StandardMaterial3D and source.albedo_texture:
			mat.set_shader_parameter("pattern", 10)
			mat.set_shader_parameter("joinery_texture", source.albedo_texture)
			mat.set_shader_parameter("joinery_uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y))
			if source.albedo_texture in [preload("res://assets/jade/tiles.png"), preload("res://assets/jade/amber_tiles.png")]:
				mat.set_shader_parameter("tint", Color(dye) if dye != "" else source.albedo_color)
		if key == "column" and source is StandardMaterial3D and source.albedo_texture == preload("res://assets/jade/lacquer.png"):
			mat.set_shader_parameter("tint", Color(dye))
		if key in ["lattice","jade_shop_window","jade_smith_window"] and source is StandardMaterial3D and source.albedo_color.to_html(false) == Art.WOOD:
			mat.set_shader_parameter("tint", Color(dye))
		mat.set_shader_parameter("roughness_value", source.roughness if source is StandardMaterial3D else .85)
		var face := G.mesh(frame, part[0], Vector3.ZERO, mat, "Joinery")
		face.set_meta("prebatched", true)


static func eave_unit(m: Node3D) -> void:
	var panel:=Art.paint(m,Vector3(0,0,.62),Vector3(3.,.16,1.62),"tiles")
	panel.rotation.x=.22
	for i in [-1.,0.,1.]:
		Art.beam(m,Vector3(i,.12,-.12),Vector3(i,-.22,1.46),.10,"79553c")

static func curtain(m: Node3D) -> void:
	Art.paint(m,Vector3.ZERO,Vector3(3.,3.36,.18),"crane_panel")

static func wall_eave(b: RefCounted, n: Node3D, width: float, painted_back: bool) -> void:
	var bays:=maxi(1,roundi(width/3.))
	for i in bays:
		var x: float=(i+.5)*width/bays-width*.5
		var eave: Node3D=b.group(n,"TiledAwning",Vector3(x,b.floor_y+b.height,0))
		eave.scale.x=width/(bays*3.)
		stamp(b,eave,"eave_unit",eave_unit)
		if painted_back:
			var panel: Node3D=b.group(n,"Backdrop",Vector3(x,b.floor_y+1.96,-.20))
			panel.scale.x=width/(bays*3.)
			panel.rotation.y=PI
			stamp(b,panel,"stage_back",curtain)

static func column(m: Node3D) -> void:
	Art.column(m, Vector3.UP*2.2, .18, 4.4)
	preload("res://scripts/jade/brackets.gd").place(m, Vector3.UP*3.85, Art.finish("wood_relief"))

static func lattice(m: Node3D) -> void:
	Art.lattice(m, Vector3.ZERO, 2.2, 2.)
	var inside := Art.group(m, "Inside", Vector3(0,0,-.04))
	inside.rotation.y = PI
	Art.lattice(inside, Vector3.ZERO, 2.2, 2.)

static func shop_window(m: Node3D, forge: bool) -> void:
	preload("res://scripts/jade/shopfront.gd").display_bay(m,Vector3.ZERO,2.2,2.,forge)
	var inside:=Art.group(m,"Inside",Vector3(0,0,-.04))
	inside.rotation.y=PI
	Art.lattice(inside,Vector3.ZERO,2.2,2.)

static func portal(m: Node3D) -> void:
	Art.paint(m, Vector3(0, 3.86, .24), Vector3(3.12,.64,.22), "wood_relief")
	Art.box(m, Vector3(0, 3.86, .37), Vector3(2.72,.49,.08), Art.JADE)
	for side in [-1., 1.]:
		Art.lantern(m, Vector3(side*1.82, 3.15, .48), .66)
		Art.paint(m, Vector3(side*1.63, 1.86, .18), Vector3(.32, 2.9, .08), "crane_panel")

static func wood_beam(builder: RefCounted) -> ShaderMaterial:
	if not builder.materials.has("cloud_beam"):
		var m: ShaderMaterial = builder.material("d4b58e").duplicate()
		m.set_shader_parameter("pattern",10)
		m.set_shader_parameter("joinery_texture",preload("res://assets/jade/cloud_beam.png"))
		m.set_shader_parameter("joinery_uv_scale",Vector2(3,2))
		builder.materials["cloud_beam"] = m
	return builder.materials["cloud_beam"]

## Each grid wall owns a straight bay and half of each adjoining diagonal bay.
## Intersect with the row's painted interval so splitting a finish keeps the octagon intact.
static func pavilion_bays(b: RefCounted, n: Node3D, length_: float, outline: Array, entrance: bool, dye: String) -> void:
	var stations: Array=[-length_*.5,length_*.5]
	var path: Array=[Vector2(stations[0],0),Vector2(stations[1],0)]
	if not outline.is_empty():
		var half: float=outline[0]*.5
		var center: float=outline[2]
		var corner: float=half*(.54 if outline[4] else .51)
		var inset: float=outline[1]*(.49 if outline[4] else .46)*.25*outline[3]
		var tip: float=(half+corner)*.5
		stations=[center-half,center-corner,center+corner,center+half]
		path=[Vector2(center-tip,inset),Vector2(center-corner,0),Vector2(center+corner,0),Vector2(center+tip,inset)]
	for i in range(path.size()-1):
		var low:=maxf(stations[i],-length_*.5)
		var high:=minf(stations[i+1],length_*.5)
		if high-low<.001:continue
		var start: Vector2=path[i].lerp(path[i+1],inverse_lerp(stations[i],stations[i+1],low))
		var end: Vector2=path[i].lerp(path[i+1],inverse_lerp(stations[i],stations[i+1],high))
		var mid: Vector2=(start+end)*.5
		var width:=start.distance_to(end)
		var bay: Node3D=b.group(n,"PavilionBay",Vector3(mid.x,b.floor_y,mid.y))
		bay.rotation.y=-(end-start).angle()
		b.block(bay,Vector3.UP*(b.height-.22),Vector3(width,.44,.38),wood_beam(b),"CrownBeam")
		if not entrance or (path.size()>2 and i!=1):
			b.block(bay,Vector3.UP*.56,Vector3(width,1.12,.24),b.material(dye),"SillWall",true)
			b.block(bay,Vector3.UP*1.16,Vector3(width,.12,.34),b.material("805439"),"Handrail")
			var panel: Node3D=b.group(bay,"Lattice",Vector3.UP*(b.height*.64))
			panel.scale=Vector3(width*.84/2.2,.52,1.)
			stamp(b,panel,"lattice",lattice,dye)
	for i in range(path.size()):
		if path.size()>2 and i in [0,path.size()-1]:continue
		if stations[i]<-length_*.5-.001 or stations[i]>=length_*.5-.001:continue
		var at: Vector2=path[i]
		var post: Node3D=b.group(n,"PavilionPier",Vector3(at.x,b.floor_y,at.y))
		stamp(b,post,"column",column,dye)
		preload("res://scripts/city/prop_collisions.gd").box(post,"PierCollision",Vector3.UP*b.height*.5,Vector3(.36,b.height,.36))
