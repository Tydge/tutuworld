extends SceneTree
const Preview=preload("res://scripts/ui/character_preview.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var previews: Array=[]
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok: failures.append(label_);print("FAIL ",label_)
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
	for bow_id in ["bow_rose","bow_plaid_sage"]:
		for preview in previews:
			preview.update_equipment({"head":bow_id})
			preview.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			var center: Vector3=preview.actor.rig_profile.head_center+Vector3(-.11,.22,0)
			preview.portrait_camera.size=3.15 if preview.species=="bunny" else 2.65
			preview.portrait_camera.position=center+Vector3(0,0,6)
			preview.portrait_camera.look_at(center)
			var actor: Node3D=preview.actor
			var ribbon: MeshInstance3D=actor.get_node("Visual/Head/Wardrobe_head/BowRibbon")
			var mount: Node3D=ribbon.get_parent()
			var minimum_gap:=999.0
			for vertex in ribbon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var point: Vector3=mount.position+vertex
				var radii: Vector3=actor.rig_profile.head_radii
				var radius:=1-pow(point.x/radii.x,2)-pow(point.y/radii.y,2)
				if radius>0:
					var gap: float=point.z-preload("res://scripts/city/bow_accessory.gd").support_z(point.x,point.y,actor.rig_profile)
					minimum_gap=minf(minimum_gap,gap)
					check(gap>=.014,"Ribbon outside head "+str(preview.species))
			check(minimum_gap<.032,"Ribbon support touches head rather than floating "+str(preview.species))
			check(ribbon.mesh.get_aabb().size.x>.60,"Bow remains larger than old design after fifteen percent reduction "+str(preview.species))
		for angle in [0.0,-.65,.65]:
			for preview in previews: preview.actor.visual.rotation.y=angle
			await create_timer(.22).timeout;await RenderingServer.frame_post_draw
			var output: String=preload("res://tests/test_support.gd").output_dir()+"/蝴蝶结-"+bow_id+"-"+str(angle)+".png"
			root.get_texture().get_image().save_png(output)
	print("BOW_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
