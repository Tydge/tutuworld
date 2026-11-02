extends RefCounted
const G=preload("res://scripts/geometry.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Blooms=preload("res://scripts/city/meadow_blossoms.gd")
static func off_pavement(world: Node3D,point: Vector3,radius: float) -> bool:
	if Vector2(point.x,point.z).length()<10.1+radius: return false
	for lane in world.get_node("Streets").get_children():
		var floor_: StaticBody3D=lane.get_child(0)
		var size_: Vector3=floor_.get_child(0).shape.size
		var p: Vector3=lane.to_local(point)
		if absf(p.x)<size_.x*.5+.69+radius and absf(p.z)<size_.z*.5+radius: return false
	return true
static func safe(world: Node3D,p: Vector3,radius: float) -> bool:
	if not off_pavement(world,p,radius): return false
	for source in DB.resources():
		if Vector2(p.x-source.x,p.z-source.z).length()<2.4+radius: return false
	return true
static func build(builder) -> void:
	var world: Node3D=builder.world
	var rng:=RandomNumberGenerator.new();rng.seed=710423
	var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/forest_blossoms.gdshader")
	var flower_points:=PackedVector3Array();var shrub_points:=PackedVector3Array()
	var anchors: Array[Vector2]=[Vector2(-15,4),Vector2(13,-3),Vector2(-16,-7),Vector2(11,-9),Vector2(-10,20),Vector2(10,21),Vector2(27,21),Vector2(-20,4)]
	for index in range(anchors.size()):
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(20):
			var point:=Vector3(anchors[index].x+rng.randfn(0,.75),.025,anchors[index].y+rng.randfn(0,.6))
			if not builder.city_clear(point) or not safe(world,point,.3): continue
			var color: Color=[Color("fff0c0"),Color("ecc882"),Color("e8b4ae")][(index+k/8)%3]
			Blooms.bloom(st,point,color,rng,.8);flower_points.append(point)
		st.generate_normals();var mesh:=st.commit()
		if mesh.get_surface_count()>0:
			var n:=G.mesh(world,mesh,Vector3.ZERO,material,"TownFlowerPatch%02d"%index);n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if index%3==0:
			for j in range(3):
				var p:=Vector3(anchors[index].x+.55+j*.55,0,anchors[index].y-1.25)
				if not builder.city_clear(p) or not safe(world,p,.8): continue
				var r: float=.48+j*.05;var h: float=.33+j*.04
				G.ball(world,p+Vector3(0,h*.7,0),Vector3(r,h,r*.86),G.mat("669d51" if j%2 else "76ab5a"),"TownLowShrub")
				G.ball(world,p+Vector3(.18,h*1.28,.10),Vector3(r*.45,h*.35,r*.45),G.mat("86b762"),"TownShrubTips")
				shrub_points.append(p)
	world.set_meta("town_flower_centers",flower_points);world.set_meta("town_shrub_centers",shrub_points)
	print("TOWN_GARDENS flowers=",flower_points.size()," shrubs=",shrub_points.size())
