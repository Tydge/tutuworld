extends SceneTree
const Preview=preload("res://scripts/ui/character_preview.gd")
const DB=preload("res://scripts/services/game_data.gd")
var previews: Array=[]
var failures: Array[String]=[]
var output:=preload("res://tests/test_support.gd").output_dir()

func _initialize() -> void:call_deferred("run")
func capture(id: String) -> void:
	for preview in previews:preview.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	for i in range(5):await process_frame;RenderingServer.force_draw()
	var frames: Array[Image]=[]
	for preview in previews:frames.append(preview.viewport.get_texture().get_image())
	var size_:=frames[0].get_size()
	var sheet:=Image.create_empty(size_.x*3,size_.y,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("eeeade"))
	for i in range(frames.size()):
		frames[i].convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(frames[i],Rect2i(Vector2i.ZERO,size_),Vector2i(size_.x*i,0))
	sheet.save_png(output+"/"+id+".png")

func run() -> void:
	root.size=Vector2i(1260,515)
	var bg:=ColorRect.new();bg.color=Color("eeeade");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
	for i in range(3):
		var preview:=Preview.new();preview.preview_size=Vector2i(420,515);preview.position.x=420*i
		preview.species="cat_teacher";preview.head_only=true;root.add_child(preview)
		preview.actor.visual.rotation.y=[0.,.62,1.45][i];previews.append(preview)
	await capture("cat-three-views")
	var variants: Array=[]
	for id in DB.catalog().items:
		if DB.item(id).get("shop_map","")=="icefield":variants.append(id)
	if variants.size()!=18:failures.append("Expected eighteen winter variants")
	for i in range(3):
		var preview: Control=previews[i];preview.head_only=false
		for child in preview.actor.visual.get_children():child.show()
		preview.portrait_camera.size=3.6
		preview.portrait_camera.position=Vector3(1.15,1.9,6);preview.portrait_camera.look_at(Vector3(0,1.55,0))
		var species: String=["bunny","cat_teacher","panda"][i]
		for id in variants:
			var slot: String=DB.item(id).slot
			preview.update_character(species,{slot:id})
			var mount: Node3D=preview.actor.get_node(("Visual/Head/" if slot=="head" else "Visual/")+"Wardrobe_"+slot)
			if mount.find_children("*","MeshInstance3D",true,false).is_empty():failures.append(species+"/"+id)
	for combo in [["pompom_cap","loop_cowl","duffle"],["winter_rosette","kerchief","capelet"]]:
		for i in range(3):
			var preview: Control=previews[i];var suffix: String=["_pine","_frost","_berry"][i]
			preview.update_equipment({"head":combo[0]+suffix,"neck":combo[1]+suffix,"body":combo[2]+suffix})
			preview.actor.visual.rotation.y=.32
		await capture(combo[2])
	print("WINTER_COSTUME_FITTING_RESULT ","PASS" if failures.is_empty() else "FAIL"," fits=",variants.size()*3," failures=",failures)
	quit(0 if failures.is_empty() else 1)
