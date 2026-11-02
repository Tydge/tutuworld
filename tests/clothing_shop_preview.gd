extends SceneTree
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
const HUD=preload("res://scripts/ui/city_hud.gd")
class ShopStage extends Node3D:
	var map_id:="city"
	var paused:=false
	var preparing:=true
	var talking_npc:=""
	func end_dialogue() -> void: talking_npc=""
var session: Node
var hud: CanvasLayer
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func button(key: String,value: String) -> Button:
	return find_button(hud.content,key,value)
func find_button(node: Node,key: String,value: String) -> Button:
	for child in node.get_children():
		if child is Button and str(child.get_meta(key,""))==value: return child
		var nested:=find_button(child,key,value)
		if nested!=null: return nested
	return null
func click(key: String,value: String) -> void:
	var found:=button(key,value)
	check(found!=null and not found.disabled,"Available UI action: "+key+" "+value)
	if found!=null and not found.disabled: found.pressed.emit()
	await create_timer(.12).timeout
func run() -> void:
	root.size=Vector2i(1600,1000)
	var background:=ColorRect.new();background.color=Color("a4bba9");background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session=S.new();session.name="Session";root.add_child(session);Engine.max_fps=30
	for species in (["panda"] if OS.get_cmdline_user_args().has("--panda-only") else ["bunny","cat_teacher"]):
		session.create_character("试衣"+load("res://scripts/characters/animal_catalog.gd").display_name(species),species,"vest_sage")
		session.state().coins=1000
		var shop: Vector2=DB.shops().clothes;session.set_player_position(Vector3(shop.x,.18,shop.y+2.3))
		var original_worn: Dictionary=session.state().equipment.duplicate(true)
		var original_items: Dictionary=session.state().inventory.duplicate(true)
		var original_money: int=session.state().coins
		var stage:=ShopStage.new();root.add_child(stage)
		hud=HUD.new();hud.city=stage;stage.add_child(hud);hud.shop="clothes";hud.open_panel("shop")
		await create_timer(.4).timeout
		var preview: Control=hud.character_sheet.preview
		var preview_id: int=preview.get_instance_id()
		check(preview.is_visible_in_tree() and preview.actor.rig_profile.species_id==species and preview.equipment==original_worn,"Shop opens with current character and actual outfit: "+species)
		check(root.get_visible_rect().encloses(hud.modal.get_global_rect()),"Shop layout fits the screen")
		check(hud.shop_preview_reset.disabled,"Restore button starts disabled")
		# Dragging the real preview must survive trying, filtering and buying.
		var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=preview.get_global_rect().get_center();Input.parse_input_event(press)
		await process_frame
		var before_yaw: float=preview.actor.visual.rotation.y
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(28,0);preview._gui_input(motion)
		press.pressed=false;Input.parse_input_event(press)
		check(absf(preview.actor.visual.rotation.y-before_yaw)>.2,"Shop character rotates by dragging")
		var yaw_: float=preview.actor.visual.rotation.y
		await click("try_on_item","beret_plaid_rose")
		await click("try_on_item","apron_honey")
		await click("try_on_item","bell_blue")
		check(preview.equipment=={"head":"beret_plaid_rose","body":"apron_honey","neck":"bell_blue"},"Can combine unowned clothes across all three slots")
		check(session.state().equipment==original_worn and session.state().inventory==original_items and session.state().coins==original_money,"Trying clothes never equips, buys or charges them")
		check(preview.actor.has_node("Visual/Head/Wardrobe_head") and preview.actor.has_node("Visual/Wardrobe_body") and preview.actor.has_node("Visual/Wardrobe_neck"),"All trial garments are actually attached to the displayed model")
		await click("category_filter","head")
		var trial:=button("try_on_item","beret_plaid_sage")
		var scroll: ScrollContainer=trial.get_parent().get_parent().get_parent().get_parent()
		scroll.ensure_control_visible(trial);await create_timer(.12).timeout
		var scroll_y:=scroll.scroll_vertical
		await click("try_on_item","beret_plaid_sage")
		check(preview.equipment.head=="beret_plaid_sage" and preview.equipment.body=="apron_honey","Same-slot trial replaces only that slot")
		check(scroll.scroll_vertical==scroll_y and preview.get_instance_id()==preview_id and is_equal_approx(preview.actor.visual.rotation.y,yaw_),"Trying preserves the scroll position, model instance and rotation")
		await click("try_on_item","beret_plaid_sage")
		check(preview.equipment.head==original_worn.head and preview.equipment.neck=="bell_blue","Clicking a trial again restores the worn item in that slot")
		await click("try_on_item","beret_plaid_rose")
		await click("category_filter","body")
		check(button("try_on_item","apron_honey")!=null and button("try_on_item","bow_rose")==null and preview.equipment.neck=="bell_blue","Categories filter the shop while retaining the whole trial outfit")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(preload("res://tests/test_support.gd").output_dir()+"/服装商店试穿-"+species+".png")
		var price: int=DB.item("apron_honey").price
		var purchase_scroll: ScrollContainer=hud.shop_grid.get_parent()
		purchase_scroll.ensure_control_visible(button("buy_item","apron_honey"));await create_timer(.15).timeout
		var purchase_position:=purchase_scroll.scroll_vertical
		var purchase_scroll_id:=purchase_scroll.get_instance_id()
		var purchase_button_id:=button("buy_item","apron_honey").get_instance_id()
		check(purchase_position>20,"Clothes purchase starts genuinely scrolled down")
		await click("buy_item","apron_honey")
		check(purchase_scroll.scroll_vertical==purchase_position and hud.shop_grid.get_parent().get_instance_id()==purchase_scroll_id,"Buying keeps the exact scroll position and scroll container")
		check(button("buy_item","apron_honey").get_instance_id()==purchase_button_id,"Buying updates the original button instead of rebuilding its card")
		check(session.authority.count("apron_honey")==1 and session.state().coins==original_money-price,"Buying the previewed garment charges the exact price and adds it once")
		check(session.state().equipment==original_worn and preview.equipment.body=="apron_honey","Buying retains the trial without changing the worn outfit")
		check(button("buy_item","apron_honey").disabled and button("buy_item","apron_honey").text=="已拥有","Owned clothing shows the owned purchase state")
		check(preview.get_instance_id()==preview_id and is_equal_approx(preview.actor.visual.rotation.y,yaw_),"Purchase refresh reuses the rotated preview")
		await click("reset_shop_preview","true")
		check(preview.equipment==original_worn and hud.shop_preview_reset.disabled,"Restore returns all three slots to current clothing")
		session.state().coins=0;session.changed.emit();await process_frame
		await click("category_filter","head")
		check(button("buy_item","beret_plaid_sage").disabled and not button("try_on_item","beret_plaid_sage").disabled,"Insufficient money disables buying while allowing trials")
		await click("try_on_item","beret_plaid_sage")
		check(preview.equipment.head=="beret_plaid_sage" and session.state().coins==0,"Trying remains free with no money")
		hud.close_panel();await process_frame
		check(hud.shop_preview_overrides.is_empty() and not preview.is_visible_in_tree() and not preview.can_process(),"Closing discards trials and suspends the preview")
		hud.open_panel("wardrobe");await create_timer(.15).timeout
		check(preview.get_instance_id()==preview_id and preview.equipment==original_worn,"Shop trials do not leak into the actual wardrobe preview")
		hud.shop="clothes";hud.open_panel("shop");await create_timer(.15).timeout
		check(preview.equipment==original_worn and hud.shop_preview_overrides.is_empty(),"Reopening starts from the actual worn outfit")
		hud.close_panel();stage.queue_free();await process_frame;await process_frame
	print("CLOTHING_SHOP_PREVIEW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
