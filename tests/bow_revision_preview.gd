extends SceneTree
const Preview=preload("res://scripts/ui/character_preview.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var previews: Array=[]
var checks:=0
var failures: Array=[]
var shared_mesh: ArrayMesh
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
func check_volume(mesh: ArrayMesh) -> void:
	var arrays:=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	# Front and back must light as opposite faces on both wings.
	for side in [-1,1]:
		for back in [false,true]:
			var found:=false
			for index in range(vertices.size()):
				var point:=vertices[index]
				if absf(point.x-side*.2645)>.01 or absf(point.y)>.002 or (point.z<0)!=back: continue
				found=true
				check(normals[index].z*(-1 if back else 1)>.90,"Outward fabric normal: wing "+str(side)+" back="+str(back))
				break
			if not found: check(false,"Missing volumetric wing face")
	# Weld UV/normal seams to verify closed volumes, rather than paper faces.
	var welded: Dictionary={};var ids: Array[int]=[];var edges: Dictionary={}
	for point in vertices:
		var key:=Vector3i(roundi(point.x*100000),roundi(point.y*100000),roundi(point.z*100000))
		if not welded.has(key): welded[key]=welded.size()
		ids.append(welded[key])
	for index in range(0,indices.size(),3):
		var a: int=ids[indices[index]];var b: int=ids[indices[index+1]];var c: int=ids[indices[index+2]]
		if a==b or b==c or c==a: continue
		for pair in [[a,b],[b,c],[c,a]]:
			var key:=Vector2i(mini(pair[0],pair[1]),maxi(pair[0],pair[1]))
			edges[key]=int(edges.get(key,0))+1
	var bad_edges:=0
	for count_ in edges.values():
		if count_!=2: bad_edges+=1
	check(bad_edges==0,"Both loops and the knot are closed fabric volumes: bad_edges="+str(bad_edges))
func run() -> void:
	Engine.max_fps=30;root.size=Vector2i(1440,790)
	var background:=ColorRect.new();background.color=Color("e5e9db");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
	var title:=UI.label("耳边的新蝴蝶结",28);title.position=Vector2(42,24);root.add_child(title)
	for i in range(3):
		var species: String=["bunny","cat_teacher","panda"][i]
		var preview=Preview.new();preview.head_only=true;preview.species=species;preview.preview_size=Vector2i(440,620);preview.equipment={"head":"bow_rose"};preview.position=Vector2(32+i*470,90);root.add_child(preview)
		preview.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		var label:=UI.label(["兔兔","猫咪","熊猫"][i],22);label.position=Vector2(212+i*470,725);root.add_child(label)
		previews.append(preview)
	await create_timer(.5).timeout
	# Probe the actual approved skull/ear triangles, independently of the
	# accessory's fit parameters. These colliders exist only in this preview.
	for preview in previews:
		for part in preview.actor.head.find_children("*","MeshInstance3D",true,false):
			if part.name not in ["RoundHead","RoundCatHead","PlushHead","WhiteEar","RoundEar"]: continue
			var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;part.add_child(body)
			var shape:=CollisionShape3D.new();shape.shape=part.mesh.create_trimesh_shape();body.add_child(shape)
	await physics_frame
	for bow_id in ["bow_rose","bow_sage","bow_honey","bow_plaid_rose","bow_plaid_sage","bow_plaid_honey"]:
		for preview in previews:
			preview.update_equipment({"head":bow_id})
			preview.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			preview.actor.visual.rotation=Vector3.ZERO
			await physics_frame
			var actor: Node3D=preview.actor
			var ribbon: MeshInstance3D=actor.get_node("Visual/Head/Wardrobe_head/BowRibbon")
			var mount: Node3D=ribbon.get_parent()
			if shared_mesh==null:
				shared_mesh=ribbon.mesh
				check_volume(shared_mesh)
			check(ribbon.mesh==shared_mesh,"One undeformed bow mesh across species and colors: "+preview.species+" "+bow_id)
			var size: Vector3=ribbon.mesh.get_aabb().size*mount.scale
			check(size.x>.65 and size.x<.90 and size.z>.10 and size.z<.17,"Full-size loops retain modest real thickness: "+preview.species)
			check(mount.position.x<-.30 and mount.position.y>.30,"Mount remains at one ear root: "+preview.species)
			var minimum_gap:=INF
			var normal: Vector3=mount.global_basis.z.normalized()
			var vertices: PackedVector3Array=ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var space: PhysicsDirectSpaceState3D=preview.viewport.find_world_3d().direct_space_state
			for index in range(0,vertices.size(),4):
				var point: Vector3=ribbon.to_global(vertices[index])
				var query:=PhysicsRayQueryParameters3D.create(point+normal*.5,point-normal*.7,1)
				var hit:=space.intersect_ray(query)
				if not hit.is_empty(): minimum_gap=minf(minimum_gap,(point-hit.position).dot(normal))
			print("BOW_FIT ",preview.species," ",bow_id," minimum_gap=",minimum_gap," size=",size)
			check(minimum_gap>=-.015,"No material penetration into actual skull/ear triangles: "+preview.species)
			var knot: Vector3=ribbon.to_global(Vector3(0,0,-.057))
			var contact:=space.intersect_ray(PhysicsRayQueryParameters3D.create(knot+normal*.5,knot-normal*.7,1))
			var knot_gap: float=(knot-contact.position).dot(normal) if not contact.is_empty() else INF
			print("BOW_KNOT_GAP ",preview.species," ",knot_gap)
			check(knot_gap>=-.015 and knot_gap<.065,"Knot sits close to its support instead of floating: "+preview.species)
		if bow_id not in ["bow_rose","bow_plaid_sage"]: continue
		for view in [["正面",0.0],["左前",PI/4],["右前",-PI/4],["左侧",PI/2],["右侧",-PI/2],["侧后",PI*2/3]]:
			title.text="立体蝴蝶结 · "+view[0]
			for preview in previews:
				var center: Vector3=preview.actor.rig_profile.head_center+Vector3(-.11,.22,0)
				preview.portrait_camera.size=3.15 if preview.species=="bunny" else 2.65
				preview.portrait_camera.position=center+Vector3(0,0,6);preview.portrait_camera.look_at(center)
				preview.actor.visual.rotation.y=view[1]
			await create_timer(.22).timeout;await RenderingServer.frame_post_draw
			var output: String=preload("res://tests/test_support.gd").output_dir()+"/蝴蝶结-"+bow_id+"-"+view[0]+".png"
			root.get_texture().get_image().save_png(output)
	# The dressing screen uses this same full-body preview and mounting path.
	title.text="立体蝴蝶结 · 全身试穿"
	for preview in previews:
		preview.update_equipment({"head":"bow_plaid_honey","body":"overalls_honey","neck":""})
		for child in preview.actor.visual.get_children(): child.show()
		preview.actor.visual.rotation.y=PI/4
		preview.portrait_camera.size=3.55
		preview.portrait_camera.position=Vector3(0,1.5,6);preview.portrait_camera.look_at(Vector3(0,1.5,0))
	await create_timer(.22).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/蝴蝶结-全身试穿.png")
	print("BOW_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
