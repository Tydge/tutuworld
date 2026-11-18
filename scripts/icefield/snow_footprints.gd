extends Node3D
## One bounded draw, no nodes/decals added while exploring. Marks vanish in 22 s.
const Layout=preload("res://scripts/icefield/icefield_layout.gd")
const CAPACITY:=192
const LIFETIME:=22.
var city: Node3D
var marks:=MultiMesh.new()
var material:=ShaderMaterial.new()
var elapsed:=0.
var timer:=0.
var cursor:=0
var emitted:=0
var tracks: Dictionary={}
func _ready() -> void:
	marks.transform_format=MultiMesh.TRANSFORM_3D;marks.use_custom_data=true
	var plane:=PlaneMesh.new();plane.size=Vector2(.27,.27);marks.mesh=plane;marks.instance_count=CAPACITY
	for i in range(CAPACITY):marks.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,-100,0)));marks.set_instance_custom_data(i,Color(0,0,0,0))
	material.shader=load("res://assets/shaders/snow_footprint.gdshader")
	var draw:=MultiMeshInstance3D.new();draw.name="PooledFootprints";draw.multimesh=marks;draw.material_override=material;draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;draw.custom_aabb=AABB(Vector3(-185,-8,-165),Vector3(370,65,330));add_child(draw)
func _process(delta: float) -> void:
	elapsed+=delta;material.set_shader_parameter("clock",elapsed);timer+=delta
	if timer<.07:return
	timer=0.
	var actors: Array=[city.bunny];actors.append_array(city.npcs)
	for actor: CharacterBody3D in actors:
		if not is_instance_valid(actor) or actor.seated or actor.sleeping:continue
		var p:=actor.position;var id:=actor.get_instance_id()
		if not tracks.has(id):tracks[id]={"point":p,"side":1.};continue
		var track: Dictionary=tracks[id];var motion: Vector3=p-track.point;motion.y=0.
		var distance_:=motion.length()
		if distance_>3. or not actor.is_on_floor():track.point=p;continue
		if distance_<.57:continue
		track.point=p;track.side=-float(track.side)
		if Layout.is_ice(p) or p.x>Layout.shore_x(p.z)+3. or absf(p.y-Layout.height_at(p.x,p.z))>.16:continue
		var forward:=motion.normalized();var right:=Vector3(forward.z,0,-forward.x)
		var foot:=p+right*float(track.side)*.16
		foot.y=Layout.height_at(foot.x,foot.z)+.018
		var up:=Layout.normal_at(foot.x,foot.z);right=forward.cross(up).normalized();var back:=right.cross(up).normalized()
		marks.set_instance_transform(cursor,Transform3D(Basis(right,up,back),foot))
		marks.set_instance_custom_data(cursor,Color(elapsed,LIFETIME,0,1))
		cursor=(cursor+1)%CAPACITY;emitted+=1
