extends RefCounted
const G = preload("res://scripts/geometry.gd")
const DB = preload("res://scripts/services/game_data.gd")
const Fabric=preload("res://scripts/city/fabric_library.gd")
const Bow=preload("res://scripts/city/bow_accessory.gd")
static var trouser_meshes: Dictionary={}
static func clear_slot(bunny: Node3D, slot: String) -> void:
	for node in bunny.find_children("Wardrobe_"+slot+"*","Node3D",true,false):
		node.get_parent().remove_child(node)
		node.queue_free()
static func apply(bunny: Node3D, equipment: Dictionary,looks: Dictionary={}) -> void:
	for slot in ["head","body","neck"]:
		clear_slot(bunny,slot)
		var id: String=equipment.get(slot,"")
		var item := DB.item(id)
		if item.is_empty() or item.get("slot","")!=slot: continue
		if looks.has(id):
			item=item.duplicate()
			for key in ["color","accent","pattern"]:
				if looks[id].has(key): item[key]=looks[id][key]
		var material: Material=Fabric.material(item)
		var rig: Resource=bunny.rig_profile
		var root := Node3D.new()
		root.name="Wardrobe_"+slot
		if slot=="head":
			bunny.get_node("Visual/Head").add_child(root)
			if item.style=="bow":
				Bow.build(root,rig,item)
			else:
				root.position=rig.hat_offset
				root.scale=rig.headwear_scale
				root.rotation.z=.10
				G.ball(root,Vector3.ZERO,Vector3(.62,.155,.53),material)
				G.cylinder(root,Vector3(0,.16,0),.035,.10,material)
		elif slot=="neck":
			bunny.get_node("Visual").add_child(root)
			root.position=rig.neck_center
			build_neck(root,rig,item,material)
		else:
			bunny.get_node("Visual").add_child(root)
			if item.style=="apron":
				build_apron(root,rig,item)
				continue
			var cloth: Material=Fabric.material(item,item.style)
			G.ball(root,rig.body_center,rig.body_radii+Vector3(.018,.014,.018),cloth)
			if item.style=="overalls":
				for side in [-1,1]:
					var x: float=side*rig.body_radii.x*.5
					var front: float=rig.body_center.z+rig.body_radii.z
					G.capsule(root,Vector3(x,rig.body_center.y+.01,front+.008),Vector3(x,rig.body_center.y+rig.body_radii.y*.60,front-.035),.027,material)
					G.ball(root,Vector3(x,rig.body_center.y+.05,front+.025),Vector3.ONE*.027,G.mat("e8d69a"))
				for limb_name in ["LeftLeg","RightLeg"]:
					var sleeve := Node3D.new()
					sleeve.name="Wardrobe_body_leg"
					bunny.get_node("Visual/"+limb_name).add_child(sleeve)
					G.mesh(sleeve,trouser_leg(rig),Vector3.ZERO,material,"TrouserLeg")
			else:
				for y in [-.10,.02,.14]: G.ball(root,rig.body_center+Vector3(rig.body_radii.x*.35,y,rig.body_radii.z+.005),Vector3.ONE*.018,G.mat("e8d69a"))

static func trouser_leg(rig: Resource) -> ArrayMesh:
	var key:=str(rig.leg_end)+str(rig.leg_radius)+str(rig.sleeve_radius)+str(rig.sleeve_length)
	if trouser_meshes.has(key): return trouser_meshes[key]
	var axis: Vector3=rig.leg_end.normalized()
	var across:=Vector3.RIGHT;var forward:=axis.cross(across).normalized()
	var radius_: float=maxf(rig.sleeve_radius,rig.leg_radius+.025)
	var length_: float=rig.sleeve_length
	# Open upper leg blends into the hips; a turned hem gives a clean cuff.
	var profile: Array[Vector2]=[Vector2(-.10,radius_),Vector2(length_-.025,radius_),Vector2(length_-.008,radius_+.003),Vector2(length_+.004,radius_),Vector2(length_+.007,radius_-.012),Vector2(length_-.006,radius_-.015),Vector2(length_-.025,radius_-.015)]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(profile.size()-1):
		for column in range(48):
			for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
				var index: int=row+corner.x
				var angle: float=(column+corner.y)*TAU/48.0
				var radial:=across*sin(angle)+forward*cos(angle)
				var tangent: Vector2=profile[mini(index+1,profile.size()-1)]-profile[maxi(0,index-1)]
				st.set_normal((radial*tangent.x-axis*tangent.y).normalized())
				st.set_uv(Vector2((column+corner.y)/48.0,profile[index].x))
				st.add_vertex(axis*profile[index].x+radial*profile[index].y)
	var mesh:=st.commit();trouser_meshes[key]=mesh;return mesh

static func neck_band(radii: Vector2,width: float,thickness: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		for j in range(8):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var angle: float=(i+corner.x)/64.0*TAU
				var section: float=(j+corner.y)/8.0*TAU
				st.set_uv(Vector2((i+corner.x)/64.0,(j+corner.y)/8.0))
				st.set_normal(Vector3(sin(angle)*cos(section),sin(section),cos(angle)*cos(section)))
				st.add_vertex(Vector3(sin(angle)*(radii.x+cos(section)*thickness),sin(section)*width,cos(angle)*(radii.y+cos(section)*thickness)))
	return st.commit()
static func build_neck(root: Node3D,rig: Resource,item: Dictionary,material: Material) -> void:
	var scarf: bool=item.style=="scarf"
	var fabric: Material=Fabric.material(item)
	var ring:=G.mesh(root,neck_band(rig.neck_radii,.073 if scarf else .038,.032 if scarf else .022),Vector3.ZERO,fabric,"ScarfWrap" if scarf else "BellBand")
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var front: float=rig.neck_radii.y+.035
	if scarf:
		G.ball(root,Vector3(-rig.neck_radii.x*.45,-.025,front),Vector3(.105,.09,.065),fabric,"ScarfKnot")
		for i in range(2):
			var tail:=Node3D.new()
			tail.position=Vector3(-rig.neck_radii.x*.45+i*.045,-.055,front+.018)
			tail.rotation.z=-.16+i*.36
			root.add_child(tail)
			G.box(tail,Vector3(0,-.09,0),Vector3(.102,.23-i*.045,.044),fabric,"ScarfTail")
			for j in range(4): G.capsule(tail,Vector3(-.036+j*.024,-.20+i*.045,0),Vector3(-.036+j*.024,-.235+i*.045,0),.009,material,"Fringe")
	else:
		var gold:=G.mat("efc34d",.36)
		var dark_gold:=G.mat("926628",.45)
		G.cylinder(root,Vector3(0,-.052,front+.014),.035,.072,gold,-1,"BellLoop")
		var center:=Vector3(0,-.14,front+.044)
		G.ball(root,center,Vector3.ONE*.105,gold,"GoldenBell")
		G.ball(root,center+Vector3(0,0,.102),Vector3(.022,.026,.009),dark_gold,"BellHole")
		G.capsule(root,center+Vector3(0,-.022,.103),center+Vector3(0,-.076,.075),.008,dark_gold,"BellSlit")

static func build_apron(root: Node3D,rig: Resource,item: Dictionary) -> void:
	var trim:=G.mat(item.get("accent","f7e5bc"))
	var r: Vector3=rig.body_radii
	var center: Vector3=rig.body_center
	# A tailored cloth panel keeps a broad, gently curved hem instead of
	# inheriting the taper at the bottom of the animal's round belly.
	G.mesh(root,apron_panel(r),center,Fabric.material(item,"drape"),"ApronCloth")
	for side in [-1,1]:
		var x: float=side*r.x*.34
		G.capsule(root,center+Vector3(x,r.y*.28,r.z+.018),center+Vector3(x,r.y*.87,r.z*.46),.025,trim,"ApronStrap")
	var belt:=G.mesh(root,neck_band(Vector2(r.x+.014,r.z+.018),.026,.012),center+Vector3(0,.015,0),trim,"ApronWaistTie")
	belt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fabric: Material=Fabric.material(item)
	G.ball(root,center+Vector3(0,-r.y*.25,r.z+.049),Vector3(r.x*.42,r.y*.24,.025),fabric,"ApronPocket")
	G.capsule(root,center+Vector3(-r.x*.36,-r.y*.04,r.z+.075),center+Vector3(r.x*.36,-r.y*.04,r.z+.075),.008,trim,"PocketHem")
	for side in [-1,1]:
		G.capsule(root,center+Vector3(0,.02,-r.z-.025),center+Vector3(side*.11,-.13,-r.z-.04),.023,trim,"BackTie")

static func apron_point(r: Vector3,u: float,t: float) -> Vector3:
	var skirt:=t>.40
	var f:=clampf((t-.40)/.60,0,1)
	var width: float=lerpf(.46,.94,t/.40) if not skirt else lerpf(.94,1.02,f)
	var x:=u*r.x*width
	var y:=lerpf(.71,-.88,t)*r.y
	# Round the lower corners a little while keeping a recognizable hem.
	y+=smoothstep(.80,1.0,absf(u))*smoothstep(.82,1.0,t)*r.y*.09
	var body_z: float=r.z*sqrt(maxf(0,1-pow(x/r.x,2)-pow(y/r.y,2)))+.025
	var hanging_z: float=(r.z+.035)*sqrt(maxf(.06,1-pow(x/(r.x*1.10),2)))
	var z: float=maxf(body_z,hanging_z*smoothstep(0,.25,f)) if skirt else body_z
	z+=sin(u*PI*3)*sin(f*PI*.5)*.008 if skirt else 0.0
	return Vector3(x,y,z)
static func apron_panel(r: Vector3) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(20):
		for col in range(24):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var u: float=(col+corner.x)/24.0
				var t: float=(row+corner.y)/20.0
				st.set_uv(Vector2(u,t))
				st.add_vertex(apron_point(r,u*2-1,t))
	st.generate_normals()
	return st.commit()
