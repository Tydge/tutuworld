extends Node3D
const G=preload("res://scripts/geometry.gd")
const DB=preload("res://scripts/services/game_data.gd")
var signature := ""
var marker: Label3D
func refresh(plot: Dictionary,needs: Dictionary) -> void:
	var progress: float=float(plot.growth)/(float(DB.crop(plot.crop).get("days",1))*3600) if plot.crop!="" else 0
	var key: String="%s:%d:%s:%s"%[plot.crop,int(progress*4),needs.water,needs.weed]
	if key==signature: return
	signature=key
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if plot.crop=="": return
	var stage:=.3+minf(1,progress)*.7
	var leaves:=G.mat("70a95c")
	var root:=Node3D.new()
	root.scale=Vector3.ONE*stage
	add_child(root)
	var color:=G.mat(DB.crop(plot.crop).color)
	for x in [-.38,.38]:
		for z in [-.33,.33]:
			var p:=Vector3(x,.12,z)
			match plot.crop:
				"carrot":
					G.ball(root,p,Vector3(.13,.20,.13),color)
					for i in range(3): G.capsule(root,p+Vector3(0,.1,0),p+Vector3(sin(i*2)*.14,.58,cos(i*2)*.14),.04,leaves)
				"lettuce":
					for i in range(5): G.ball(root,p+Vector3(sin(i*2)*.12,.1,cos(i*2)*.12),Vector3(.22,.20,.16),leaves)
				"tomato":
					G.capsule(root,p,p+Vector3(0,.85,0),.025,leaves)
					for i in range(3):
						G.ball(root,p+Vector3(sin(i*2)*.20,.45+i*.13,cos(i*2)*.17),Vector3(.16,.14,.16),color if progress>.6 else leaves)
				"pumpkin":
					for i in range(5): G.ball(root,p+Vector3(sin(i*TAU/5)*.07,.12,cos(i*TAU/5)*.07),Vector3(.22,.23,.22),color if progress>.5 else leaves)
					G.capsule(root,p+Vector3(0,.30,0),p+Vector3(.06,.47,0),.035,leaves)
				"wheat":
					var ripe := G.mat("d9b65d" if progress>.65 else "9db96a")
					for stem in range(3):
						var origin := p+Vector3((stem-1)*.13,0,sin(stem*2.0)*.09)
						var tip := origin+Vector3((stem-1)*.07,.77+stem*.08,0)
						G.capsule(root,origin,tip,.013,ripe)
						for pair in range(4):
							for side in [-1,1]:
								var grain := G.ball(root,tip+Vector3(side*.047,pair*.075,0),Vector3(.037,.072,.028),ripe)
								grain.rotation.z=side*-.48
								G.capsule(root,tip+Vector3(side*.065,pair*.075+.04,0),tip+Vector3(side*.11,pair*.075+.17,0),.003,ripe)
						G.capsule(root,origin+Vector3(0,.28,0),origin+Vector3(.19,.48,.02),.021,leaves)
	if plot.crop=="wheat": batch_wheat(root)
	if needs.weed:
		for i in range(4):
			var p:=Vector3(sin(i*2)*.7,.10,cos(i*2)*.7)
			G.capsule(self,p,p+Vector3(.14,.42,.06),.03,G.mat("8d9950"))
			G.capsule(self,p,p+Vector3(-.14,.32,-.06),.03,G.mat("8d9950"))
	marker=G.text3d(self,"可收获" if needs.ready else ("需要浇水" if needs.water else ("需要除草" if needs.weed else "")),Vector3(0,1.35,0),22,Color("f4f0d6"))
	marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.outline_size=6
	marker.outline_modulate=Color("4d795e")
func batch_wheat(root: Node3D) -> void:
	# The small grains and awns keep their detail without hundreds of draw calls per plot.
	var batches: Dictionary={}
	for part in root.get_children():
		if not part is MeshInstance3D: continue
		var key: int=part.material_override.get_instance_id()
		if not batches.has(key): batches[key]={"material":part.material_override,"surface":SurfaceTool.new()};batches[key].surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[key].surface.append_from(part.mesh,0,part.transform)
		root.remove_child(part);part.free()
	for batch in batches.values(): G.mesh(root,batch.surface.commit(),Vector3.ZERO,batch.material,"WheatCluster")
