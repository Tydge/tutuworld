extends SceneTree
const S=preload("res://scripts/services/session.gd")
var checks:=0
var failures: Array[String]=[]
var session: Node
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func find_button(node: Node,key: String,value: String) -> Button:
	for child in node.get_children():
		if child is Button and child.get_meta(key,"")==value: return child
		var nested:=find_button(child,key,value)
		if nested!=null: return nested
	return null
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=S.new();session.name="Session";root.add_child(session)
	for species in ["bunny","cat_teacher"]:
		session.create_character("换装兔" if species=="bunny" else "换装猫",species,"vest_sage")
		for id in ["beret_plaid_rose","apron_honey","bell_blue"]: session.authority.add(id,1)
		game=load("res://scenes/city.tscn").instantiate();root.add_child(game)
		await create_timer(.8).timeout
		session.state().time=1800;game.update_lighting();game.hud.open_panel("wardrobe")
		await create_timer(.3).timeout
		var preview: Control=game.hud.character_sheet.preview
		var preview_id: int=preview.get_instance_id()
		check(preview.is_visible_in_tree() and preview.actor.rig_profile.species_id==species,"Wardrobe has a live full-body preview: "+species)
		check(absf(preview.actor.left_arm.rotation.z)<.10 and absf(preview.actor.right_arm.rotation.z)<.10,"Preview stays relaxed instead of mistaking the display stage for a jump")
		check(root.get_visible_rect().encloses(game.hud.modal.get_global_rect()),"Wardrobe fits the viewport")
		for id in ["beret_plaid_rose","apron_honey","bell_blue"]:
			var button:=find_button(game.hud.content,"equipment_item",id)
			check(button!=null,"Owned garment has a wear button: "+id)
			if button==null: continue
			button.pressed.emit();await create_timer(.4).timeout
			check(preview.equipment==session.state().equipment and preview.get_instance_id()==preview_id and preview.is_visible_in_tree(),"Wearing refreshes the same preview immediately")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/换装实时预览-"+species+".png")
		var filter:=find_button(game.hud.content,"category_filter","head");filter.pressed.emit();await create_timer(.2).timeout
		check(preview.get_instance_id()==preview_id and preview.is_visible_in_tree(),"Filtering preserves the preview world")
		var worn:=find_button(game.hud.content,"equipment_item","beret_plaid_rose");worn.pressed.emit();await create_timer(.4).timeout
		check(session.state().equipment.head=="" and preview.equipment.head=="","Clicking worn item removes it in the preview")
		game.hud.close_panel();await process_frame
		check(not preview.can_process(),"Closing wardrobe suspends preview animation as well as rendering")
		game.hud.open_panel("profile");await create_timer(.2).timeout
		check(preview.get_instance_id()==preview_id and preview.is_visible_in_tree() and preview.can_process() and preview.equipment==session.state().equipment,"Character and wardrobe reuse one portrait world")
		game.hud.open_panel("bag");await create_timer(.2).timeout
		check(not preview.is_visible_in_tree(),"Closed portrait stops rendering")
		game.hud.close_panel();game.bunny.position=Vector3(0,.3,7);game.bunny.reset_physics_interpolation();await create_timer(.4).timeout
		Input.action_press("jump");await physics_frame;Input.action_release("jump");await create_timer(.18).timeout
		check(not game.bunny.is_on_floor() and game.bunny.left_arm.rotation.z<-.20 and game.bunny.right_arm.rotation.z>.20,"Jump opens both arms: "+species)
		check(not game.bunny.mood_label.text.contains("!"),"Jump has no exclamation mark")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/跳跃展臂-"+species+".png")
		game.queue_free();await process_frame;await process_frame
	print("WARDROBE_JUMP_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
