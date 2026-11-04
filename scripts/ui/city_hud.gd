extends CanvasLayer
const UI=preload("res://scripts/ui/ui_kit.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Icon=preload("res://scripts/ui/item_icon.gd")
const BuffIcon=preload("res://scripts/ui/buff_icon.gd")
const CharacterSheet=preload("res://scripts/ui/character_sheet.gd")
const Ring=preload("res://scripts/ui/progress_ring.gd")
var city: Node3D
var session: Node
var root_ui: Control
var overlay: Control
var modal: PanelContainer
var content: VBoxContainer
var mode := ""
var shop := ""
var selected_seed := "seed_carrot"
var clock_card: PanelContainer
var camera_control: Control
var clock_label: Label
var coin_label: Label
var water_label: Label
var buff_icon: Control
var stamina_meter: Control
var player_status: Control
var work_gain: Label
var gain_timer:=0.0
var filters: Dictionary={}
var character_sheet: Control
var prompt: Label
var prompt_card: PanelContainer
var toast: PanelContainer
var toast_label: Label
var toast_timer := 0.0
var ring: Control
var target_point := Vector3.ZERO
var time_tip: Label
var detail_label: Label
var photo_mode := false
var menu_button: Button
var shop_tab := "buy"
var shop_preview_overrides: Dictionary={}
var shop_preview_reset: Button
var shop_grid: GridContainer
var shop_balance: Label
var shop_rows: Dictionary={}
var shop_empty: Label
var map_draw: Control
var panel_signature := ""
var bubble: PanelContainer
var bubble_name: Label
var bubble_text: Label
var bubble_hint: Label
var bubble_target: Node3D
var speech_tail: Polygon2D
var plot_history_open:=false
var plot_history_target:=""
func _ready() -> void:
	session=get_node("/root/Session")
	root_ui=Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_ui.theme=UI.theme()
	add_child(root_ui)
	var top:=UI.panel(Color("fff9e9",.95),24,15);clock_card=top
	top.anchor_left=1
	top.anchor_right=1
	top.position=Vector2(-302,26)
	top.custom_minimum_size=Vector2(274,96)
	if session.is_online():top.position.x=-388;top.custom_minimum_size.x=360
	root_ui.add_child(top)
	var top_col:=UI.column(5)
	top.add_child(top_col)
	clock_label=UI.label("",19)
	if session.is_online():clock_label.add_theme_font_size_override("font_size",15)
	coin_label=UI.label("",16,Color("a77b39"))
	top_col.add_child(clock_label)
	top_col.add_child(coin_label)
	camera_control=preload("res://scripts/ui/indoor_camera_control.gd").new();camera_control.session=session;camera_control.anchor_left=1;camera_control.anchor_right=1;root_ui.add_child(camera_control)
	water_label=UI.label("",15,Color("537f88"));top_col.add_child(water_label)
	buff_icon=BuffIcon.new()
	buff_icon.position=Vector2(28,26)
	root_ui.add_child(buff_icon)
	buff_icon.hide()
	player_status=preload("res://scripts/ui/player_status.gd").new()
	player_status.position=Vector2(24,24);root_ui.add_child(player_status)
	player_status.profile_requested.connect(func(): open_panel("profile"))
	stamina_meter=player_status.meter
	buff_icon.position=Vector2(28,144)
	work_gain=UI.label("+1 ★",20,Color("e4be71"))
	work_gain.anchor_left=.5
	work_gain.anchor_right=.5
	work_gain.anchor_top=1
	work_gain.anchor_bottom=1
	work_gain.position=Vector2(-25,-250)
	work_gain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(work_gain)
	work_gain.hide()
	var bar:=UI.panel(Color("fff9e9",.96),24,12)
	bar.anchor_left=.5
	bar.anchor_right=.5
	bar.anchor_top=1
	bar.anchor_bottom=1
	bar.position=Vector2(-400,-88)
	bar.custom_minimum_size=Vector2(800,62)
	if city.map_id=="city" and not session.is_online():bar.position.x=-460;bar.custom_minimum_size.x=920
	root_ui.add_child(bar)
	var buttons:=UI.row(10)
	bar.add_child(buttons)
	for row in [["角色  C","profile"],["背包  I","bag"],["换装  Tab","wardrobe"],["地图  M","map"],["设置  Esc","settings"]]:
		var b:=UI.button(row[0],func(): open_panel(row[1]))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	if city.map_id=="city" and not session.is_online():
		var build_button:=UI.button("建造 F6",city.open_build_mode);build_button.name="OpenBuildingEditor";build_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;buttons.add_child(build_button)
	prompt_card=UI.panel(Color("426e5c",.96),23,16)
	prompt_card.position=Vector2(0,0)
	prompt_card.custom_minimum_size=Vector2(470,57)
	root_ui.add_child(prompt_card)
	prompt=UI.label("",17,UI.CREAM)
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_card.add_child(prompt)
	prompt_card.hide()
	var hint:=UI.label("WASD 移动 · 空格 跳跃\nShift 切换跑步 · 右键视角\n滚轮缩放 · E 互动 · F 快捷互动",12,Color("f9f4dc"))
	hint.anchor_top=1
	hint.anchor_bottom=1
	hint.position=Vector2(28,-78)
	hint.add_theme_color_override("font_shadow_color",Color("315f45",.85))
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",1)
	root_ui.add_child(hint)
	toast=UI.panel(Color("fff9e9",.98),22,17)
	toast.anchor_left=.5
	toast.anchor_right=.5
	toast.position=Vector2(-300,28)
	toast.custom_minimum_size=Vector2(600,62)
	root_ui.add_child(toast)
	toast_label=UI.label("",16)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size.x=560
	toast.add_child(toast_label)
	toast.hide()
	ring=Ring.new()
	ring.hide()
	root_ui.add_child(ring)
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new()
	shade.color=Color("243f37",.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal=UI.panel(UI.CREAM,30,26)
	modal.anchor_left=.5
	modal.anchor_right=.5
	modal.anchor_top=.5
	modal.anchor_bottom=.5
	modal.position=Vector2(-480,-340)
	modal.custom_minimum_size=Vector2(960,680)
	overlay.add_child(modal)
	content=UI.column(14)
	modal.add_child(content)
	overlay.hide()
	bubble=UI.panel(Color("fff9e9",.98),20,13)
	bubble.custom_minimum_size=Vector2(310,0)
	bubble.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(bubble)
	var bubble_column:=UI.column(4)
	bubble.add_child(bubble_column)
	bubble_name=UI.label("",15,Color("b36b56"))
	bubble_text=UI.label("",17,UI.INK)
	bubble_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	bubble_text.custom_minimum_size.x=280
	bubble_column.add_child(bubble_name)
	bubble_column.add_child(bubble_text)
	bubble_hint=UI.label("E · 继续散步",12,UI.MUTED)
	bubble_column.add_child(bubble_hint)
	speech_tail=Polygon2D.new()
	speech_tail.polygon=PackedVector2Array([Vector2(-10,0),Vector2(10,0),Vector2(0,12)])
	speech_tail.color=Color("fff9e9",.98)
	bubble.add_child(speech_tail)
	bubble.hide()
	session.changed.connect(refresh_stats)
	refresh_stats()
func notify(message: String) -> void:
	toast_label.text=message
	toast_timer=4.5
	toast.show()
	if not session.settings.reduce_motion: UI.pop(toast)
func refresh_stats() -> void:
	var s: Dictionary=session.state()
	player_status.refresh(s,session.authority.stamina_max())
	var hour:=fmod(float(s.time)/3600*24,24)
	clock_label.text="第 %d 天   %02d : %02d"%[int(s.time/3600)+1,int(hour),int(fmod(hour,1)*60)]
	if session.is_online():clock_label.text=preload("res://scripts/services/island_calendar.gd").text(float(s.time))
	coin_label.text="贝壳币   %d"%s.coins
	water_label.visible=session.authority.watering_can_id()!=""
	water_label.text="%s  %d / %d"%[DB.item(session.authority.watering_can_id()).get("name","水壶"),session.authority.water_left(),DB.water_capacity(session.authority.watering_can_id())]
	buff_icon.set_effect(s.get("food_effect",{}),float(s.time))
	if overlay.visible and mode in ["bag","wardrobe","shop","kitchen","workshop","dining"]:
		var signature:=JSON.stringify([s.inventory,s.equipment,s.coins,s.skill_experience,s.get("watering_water",{})])
		if signature!=panel_signature:
			panel_signature=signature
			if mode=="shop": refresh_shop_items()
			else: rebuild()
	if overlay.visible and mode=="plot" and session.is_online() and s.plots.has(city.current_target):
		var plot: Dictionary=s.plots[city.current_target]
		var percentage:=int(float(plot.get("growth",0))/maxf(1,float(DB.crop(plot.get("crop","")).get("days",1))*3600)*100)
		var signature:=JSON.stringify([city.current_target,plot.get("crop",""),percentage,plot.get("water_stage",-1),plot.get("weed_stage",-1),plot.get("quality",0),session.online_care.get(city.current_target,{}),session.online_locks.get(city.map_id+":"+city.current_target,{})])
		if signature!=panel_signature:
			panel_signature=signature
			if plot_history_open:show_plot_history(plot_history_target)
			else:rebuild()
func _process(delta: float) -> void:
	camera_control.position=Vector2(clock_card.position.x,clock_card.position.y+clock_card.size.y+10)
	var inside: bool=preload("res://scripts/city/interior_view.gd").indoors(city,city.bunny.get_global_transform_interpolated().origin)
	camera_control.update_context(inside and not photo_mode and not overlay.visible and not city.paused and not city.preparing,delta)
	player_status.visible=not photo_mode
	prompt_card.position=Vector2((root_ui.size.x-prompt_card.size.x)*.5,root_ui.size.y-190)
	prompt_card.visible=prompt.text!="" and not photo_mode and not overlay.visible
	gain_timer=maxf(0,gain_timer-delta)
	work_gain.visible=gain_timer>0 and not photo_mode
	if gain_timer>0:
		work_gain.modulate.a=minf(1,gain_timer*2)
		work_gain.set_anchors_preset(Control.PRESET_TOP_LEFT)
		work_gain.position=player_status.position+Vector2(200,20-(1.2-gain_timer)*24)
	toast_timer-=delta
	if toast_timer<=0: toast.hide()
	else: toast.modulate.a=minf(1,toast_timer*2)
	var job: Dictionary=session.job()
	ring.visible=not job.is_empty() and job.get("verb","")!="snack" and not photo_mode
	if not job.is_empty():
		ring.progress=float(job.elapsed)/float(job.duration)
		var focus: Vector3=city.target_position(job.target)+Vector3(0,1.8,0)
		if job.verb=="snack": focus=city.bunny.position+Vector3(0,city.bunny.rig_profile.name_height+.25,0)
		elif job.verb=="gather" and job.item=="orange": focus=city.target_position(job.target)+Vector3(0,3.6,0)
		ring.position=city.camera.unproject_position(focus)-Vector2(36,36)
		ring.queue_redraw()
		var verb_name: String={"craft":"制造" if job.get("station","")=="workshop" else "烹饪","refill":"打水","eat":"用餐","snack":"吃橘子","water":"浇水","weed":"除草","plant":"播种","harvest":"收获","gather":"采集"}.get(job.verb,"动作")
		var dish: String=" · "+DB.item(job.item).name if job.verb in ["craft","eat"] else ""
		prompt.text="%s%s · %.1f 秒\nEsc 取消"%[verb_name,dish,maxf(0,float(job.duration)-float(job.elapsed))]
		prompt_card.visible=not photo_mode and not overlay.visible
	if bubble.visible and is_instance_valid(bubble_target):
		var point: Vector2=city.camera.unproject_position(bubble_target.get_global_transform_interpolated().origin+Vector3(0,bubble_target.rig_profile.dialogue_height,0))
		speech_tail.position=Vector2(bubble.size.x*.5,bubble.size.y-1)
		var viewport_size:=get_viewport().get_visible_rect().size
		bubble.position=Vector2(clampf(point.x-bubble.size.x*.5,8,viewport_size.x-bubble.size.x-8),clampf(point.y-bubble.size.y-12,8,viewport_size.y-bubble.size.y-8))
	if overlay.visible:
		overlay.position=Vector2.ZERO
		overlay.size=get_viewport().get_visible_rect().size
		modal.set_anchors_preset(Control.PRESET_TOP_LEFT)
		modal.position=(overlay.size-modal.size)*.5
	if mode=="map" and is_instance_valid(map_draw): map_draw.queue_redraw()
func gain_experience(amount: int) -> void:
	if amount>0: gain_timer=1.2; work_gain.text="+%d ★"%amount
func show_dialogue(target: Node3D, speaker: String, message: String, hint_: String="E · 继续散步") -> void:
	bubble_target=target
	bubble_name.text=speaker
	bubble_text.text=message
	bubble_hint.text=hint_
	bubble.show()
	if not session.settings.reduce_motion: UI.pop(bubble)
func hide_dialogue() -> void:
	bubble.hide()
	bubble_target=null
func set_prompt(text: String) -> void:
	prompt.text=text
	prompt_card.visible=text!="" and not overlay.visible and not photo_mode
func close_panel() -> void:
	mode=""
	shop_preview_overrides.clear()
	overlay.hide()
	if is_instance_valid(character_sheet):
		character_sheet.process_mode=Node.PROCESS_MODE_DISABLED
		character_sheet.portrait.process_mode=Node.PROCESS_MODE_DISABLED
	city.paused=false
	city.talking_npc=""
func open_panel(kind: String) -> void:
	if is_instance_valid(city.online_view) and city.online_view.chat_card.visible:city.online_view.close_chat()
	if not session.job().is_empty():
		notify("先完成动作，或按 Esc 取消。")
		return
	if city.talking_npc!="": city.end_dialogue()
	shop_preview_overrides.clear()
	mode=kind
	panel_signature=JSON.stringify([session.state().inventory,session.state().equipment,session.state().coins,session.state().skill_experience,session.state().get("watering_water",{})])
	overlay.show()
	city.paused=true
	rebuild()
	if not session.settings.reduce_motion and not city.preparing: UI.pop(modal)
func rebuild() -> void:
	shop_grid=null;shop_balance=null;shop_empty=null;shop_rows.clear()
	# Keep the preview world and its render targets alive between menus.
	if is_instance_valid(character_sheet): character_sheet.restore_portrait()
	if is_instance_valid(character_sheet) and character_sheet.get_parent()==content:
		content.remove_child(character_sheet)
		root_ui.add_child(character_sheet)
		character_sheet.hide()
		character_sheet.process_mode=Node.PROCESS_MODE_DISABLED
	UI.clear(content)
	var height:=620 if mode=="profile" else 680
	var width_: float=1100 if mode=="wardrobe" or (mode=="shop" and shop=="clothes") else 960
	modal.custom_minimum_size=Vector2(width_,height)
	modal.size=Vector2(width_,height)
	modal.position=Vector2(-width_*.5,-height*.5)
	var head:=UI.row()
	content.add_child(head)
	var titles:={"bag":session.authority.actor_name()+"的随身口袋","wardrobe":"今天穿什么？","shop":{"farm":"春芽种子商店","tools":"木木工具铺","clothes":"云朵服装店"}.get(shop,"商店"),"settings":"歇一小会儿","map":"眠风山谷" if city.map_id=="valley" else "慢慢来海岛城","dialogue":"路上遇见的邻居","plot":"照料这块小菜地","kitchen":"海风小厨房 · 今日菜谱","workshop":"铜叶工坊 · 制造道具","dining":"坐下来，好好吃一餐","profile":"我的小岛生活"}
	var title:=UI.label(titles.get(mode,""),28)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.button("返回",close_panel))
	match mode:
		"profile": build_profile()
		"bag": build_inventory(false)
		"wardrobe": build_inventory(true)
		"shop": build_shop()
		"settings": build_settings()
		"plot": build_plot()
		"kitchen": build_kitchen()
		"workshop": build_workshop()
		"dining": build_dining()
		"map": build_map()
		"dialogue":
			var speech:=UI.label(city.dialogue_text,24)
			speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			speech.custom_minimum_size=Vector2(850,360)
			content.add_child(speech)
			content.add_child(UI.label("每一位路过的邻居，都有自己的慢节奏。",16,UI.MUTED))
func build_profile() -> void:
	ensure_character_sheet()
	character_sheet.restore_portrait()
	if character_sheet.get_parent()!=null: character_sheet.get_parent().remove_child(character_sheet)
	content.add_child(character_sheet)
	character_sheet.process_mode=Node.PROCESS_MODE_INHERIT
	character_sheet.portrait.process_mode=Node.PROCESS_MODE_INHERIT
	character_sheet.show()
	character_sheet.preview.update_equipment(session.state().equipment)
	character_sheet.refresh()
func ensure_character_sheet() -> void:
	if not is_instance_valid(character_sheet):
		character_sheet=CharacterSheet.new()
		character_sheet.session=session
		root_ui.add_child(character_sheet)
		character_sheet.hide()
		character_sheet.process_mode=Node.PROCESS_MODE_DISABLED
func build_appearance_layout(worn: Dictionary) -> Control:
	ensure_character_sheet()
	var layout:=UI.row(20);content.add_child(layout)
	character_sheet.portrait.reparent(layout)
	character_sheet.portrait.process_mode=Node.PROCESS_MODE_INHERIT
	character_sheet.preview.update_equipment(worn)
	character_sheet.refresh()
	var right:=UI.column(10);right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	layout.add_child(right)
	return right
func shop_preview_equipment() -> Dictionary:
	var worn: Dictionary=session.state().equipment.duplicate()
	worn.merge(shop_preview_overrides,true)
	return worn
func try_on_clothing(id: String) -> void:
	if mode!="shop" or shop!="clothes": return
	var item:=DB.item(id)
	if item.get("kind","")!="clothing" or item.get("shop","")!="clothes": return
	var slot: String=item.slot
	if shop_preview_overrides.get(slot,"")==id: shop_preview_overrides.erase(slot)
	else: shop_preview_overrides[slot]=id
	refresh_shop_preview()
func reset_shop_preview() -> void:
	shop_preview_overrides.clear()
	refresh_shop_preview()
func refresh_shop_preview() -> void:
	if mode!="shop" or shop!="clothes" or not is_instance_valid(character_sheet): return
	var worn:=shop_preview_equipment()
	if character_sheet.preview.equipment!=worn: character_sheet.preview.update_equipment(worn)
	if is_instance_valid(shop_preview_reset): shop_preview_reset.disabled=shop_preview_overrides.is_empty()
	for button in content.find_children("*","Button",true,false):
		var id: String=button.get_meta("try_on_item","")
		if id=="": continue
		var selected: bool=shop_preview_overrides.get(DB.item(id).slot,"")==id
		button.text="试穿中" if selected else "试穿"
		button.set_pressed_no_signal(selected)
func build_filters(context: String,choices: Array,parent: Control=null) -> String:
	var selected: String=filters.get(context,"all")
	var strip:=UI.row(6)
	(parent if parent!=null else content).add_child(strip)
	for choice in choices:
		var key: String=choice[0]
		var b:=UI.button(choice[1],func(): filters[context]=key; rebuild(),selected==key)
		b.custom_minimum_size=Vector2(0,34)
		b.add_theme_font_size_override("font_size",14)
		b.set_meta("category_filter",key)
		strip.add_child(b)
	return selected
func scroll_grid(columns: int=3,parent: Control=null,width_: float=900) -> GridContainer:
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(width_,486)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	(parent if parent!=null else content).add_child(scroll)
	var grid:=GridContainer.new()
	grid.columns=columns
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	return grid
func item_card(id: String,grid: GridContainer) -> VBoxContainer:
	var card:=UI.panel(Color("f0efd9"),18,14)
	card.set_meta("item_id",id)
	card.custom_minimum_size=Vector2(280,150)
	card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_child(card)
	var c:=UI.column(7)
	card.add_child(c)
	var row:=UI.row(10)
	c.add_child(row)
	var icon:=Icon.new()
	icon.item_id=id
	icon.definition=DB.item(id)
	row.add_child(icon)
	var text:=UI.column(4)
	row.add_child(text)
	text.add_child(UI.label(DB.item(id).name,16))
	return c
func build_inventory(clothes_only: bool) -> void:
	var s: Dictionary=session.state()
	var inventory_parent: Control=content
	if clothes_only:
		inventory_parent=build_appearance_layout(s.equipment)
		var slots:=UI.row(6)
		inventory_parent.add_child(slots)
		for slot in ["head","body","neck"]:
			var id: String=s.equipment.get(slot,"")
			var button:=UI.button({"head":"头部","body":"身体","neck":"脖饰"}[slot]+(" · 空" if id=="" else " · 卸下"),func(): session.dispatch("equip",{"slot":slot,"item":""}))
			button.tooltip_text="未穿戴" if id=="" else DB.item(id).name+" · 点击卸下"
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			slots.add_child(button)

	var category:=build_filters("wardrobe" if clothes_only else "bag",[["all","全部"],["head","头饰"],["body","身体"],["neck","脖饰"]] if clothes_only else [["all","全部"],["seed","种子"],["tool","工具"],["material","材料"],["crop","农作物"],["ingredient","调料"],["food","料理"],["clothing","服饰"],["consumable","消耗品"]],inventory_parent)
	var grid:=scroll_grid(2 if clothes_only else 3,inventory_parent,650 if clothes_only else 900)
	var found:=false
	for id in s.inventory:
		var item:=DB.item(id)
		if clothes_only and item.kind!="clothing": continue
		if category!="all" and DB.category(id,clothes_only)!=category: continue
		found=true
		var c:=item_card(id,grid)
		if item.kind not in ["clothing","tool"]: c.add_child(UI.label("× %d"%s.inventory[id],14,UI.MUTED))
		if item.kind=="clothing":
			var equipped: bool=s.equipment.get(item.slot,"")==id
			var wear:=UI.button("已穿戴" if equipped else "穿戴",func(): session.dispatch("equip",{"slot":item.slot,"item":"" if equipped else id}),equipped)
			wear.set_meta("equipment_item",id)
			c.add_child(wear)
		elif item.has("edible"):
			c.add_child(UI.label("恢复 %d 点耐力"%int(item.edible.stamina),14,UI.GREEN))
			var full: bool=s.stamina>=session.authority.stamina_max()
			var eat:=UI.button("耐力已满" if full else "吃一颗 · 3 秒",func(): close_panel(); city.begin_snack(id),true)
			eat.disabled=full or not session.job().is_empty() or s.get("rest_mode","")!=""
			eat.set_meta("eat_item",id)
			c.add_child(eat)
		elif item.kind=="food":
			c.add_child(UI.label(DB.effect_summary(id),13,UI.MUTED))
			c.add_child(UI.label("到厨房旁的餐桌享用",13,Color("a47c48")))
		elif item.kind=="ingredient": c.add_child(UI.label("厨房调料 · 烹饪成功后消耗",13,UI.MUTED))
		elif item.kind=="seed": c.add_child(UI.button("已选择播种" if selected_seed==id else "设为播种种子",func(): selected_seed=id; rebuild()))
		elif item.kind=="tool":
			if DB.water_capacity(id)>0: c.add_child(UI.label("剩余水量 %d / %d · 到菜园水井装满"%[session.authority.water_left(id),DB.water_capacity(id)],13,Color("537f88")))
			var skill: String={"pickaxe":"mining","stone_hammer":"quarrying","copper_axe":"woodcutting","watering_can":"planting","copper_watering_can":"planting"}.get(id,"")
			var required:=int(item.get("required_level",1))
			c.add_child(UI.label("%s Lv.%d"%[preload("res://scripts/services/character_stats.gd").skill_name(skill).replace("技能",""),required],13,UI.MUTED if session.authority.skill_level(skill)>=required else Color("b87955")))
		else:
			var text:=UI.label("永久工具" if item.kind=="tool" else ("成功使用后消耗" if item.kind=="consumable" else "出售 / 留作材料"),13,UI.MUTED)
			c.add_child(text)
	if not found: grid.add_child(UI.label("这一格口袋还是空的。",19,UI.MUTED))
func build_shop() -> void:
	var clothes_shop: bool=shop=="clothes"
	var shop_parent: Control=build_appearance_layout(shop_preview_equipment()) if clothes_shop else content
	var top:=UI.row()
	shop_parent.add_child(top)
	shop_balance=UI.label("贝壳币 %d"%session.state().coins,16,Color("a77b39"))
	shop_balance.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(shop_balance)
	if clothes_shop:
		shop_preview_reset=UI.button("恢复当前穿搭",reset_shop_preview)
		shop_preview_reset.custom_minimum_size.y=36
		shop_preview_reset.add_theme_font_size_override("font_size",14)
		shop_preview_reset.set_meta("reset_shop_preview",true)
		top.add_child(shop_preview_reset)
	if shop=="farm":
		var buy_tab:=UI.button("购买",func(): shop_tab="buy"; rebuild(),shop_tab=="buy")
		buy_tab.set_meta("shop_tab","buy");top.add_child(buy_tab)
		var sell_tab:=UI.button("出售",func(): shop_tab="sell"; rebuild(),shop_tab=="sell")
		sell_tab.set_meta("shop_tab","sell");top.add_child(sell_tab)
	else: shop_tab="buy"
	var choices: Array=[["all","全部"],["head","头饰"],["body","身体"],["neck","脖饰"]] if shop=="clothes" else ([["all","全部"],["tool","工具"]] if shop=="tools" else [["all","全部"],["seed","种子"],["ingredient","调料"],["consumable","消耗品"],["crop","农作物"],["food","料理"],["material","材料"]])
	if shop=="farm" and shop_tab=="buy": choices=[["all","全部"],["seed","种子"],["ingredient","调料"],["consumable","消耗品"]]
	build_filters("shop_"+shop+"_"+shop_tab,choices,shop_parent)
	shop_grid=scroll_grid(2 if clothes_shop else 3,shop_parent,650 if clothes_shop else 900)
	refresh_shop_items()
func refresh_shop_items() -> void:
	if mode!="shop" or not is_instance_valid(shop_grid): return
	shop_balance.text="贝壳币 %d"%session.state().coins
	var category: String=filters.get("shop_"+shop+"_"+shop_tab,"all")
	var wanted: Array[String]=[]
	for id in DB.catalog().items:
		var item:=DB.item(id)
		if shop_tab=="buy" and item.get("shop","")!=shop: continue
		if category!="all" and DB.category(id,shop=="clothes")!=category: continue
		if shop_tab=="sell" and (int(item.get("sell",0))<=0 or session.authority.count(id)<1): continue
		wanted.append(id)
	# Ordinary trades retain the same scroll container, cards, focus and preview.
	for id in shop_rows.keys():
		if id in wanted: continue
		var card: Control=shop_rows[id].card
		shop_grid.remove_child(card);card.queue_free();shop_rows.erase(id)
	if not wanted.is_empty() and is_instance_valid(shop_empty):
		shop_grid.remove_child(shop_empty);shop_empty.queue_free();shop_empty=null
	for index in range(wanted.size()):
		var id: String=wanted[index]
		if not shop_rows.has(id): shop_rows[id]=build_shop_card(id)
		var row: Dictionary=shop_rows[id]
		if row.card.get_index()!=index: shop_grid.move_child(row.card,index)
		var item:=DB.item(id)
		var count_: int=session.authority.count(id)
		if row.has("buy"):
			var owned: bool=item.kind in ["tool","clothing"] and count_>0
			row.buy.text="已拥有" if owned else "%d 贝壳币 · 买一件"%item.price
			row.buy.disabled=owned or int(session.state().coins)<int(item.price)
			if row.has("bulk"):
				row.bulk.disabled=int(session.state().coins)<int(item.price)*5
				row.count.text="持有 %d"%count_
		else:
			row.count.text="持有 %d · 单价 %d 币"%[count_,item.sell]
			row.sell_all.text=("出售 99 份" if count_>99 else "全部出售")+" · %d 币"%(mini(99,count_)*int(item.sell))
	if wanted.is_empty() and not is_instance_valid(shop_empty):
		shop_empty=UI.label("暂时没有这一类物品。",20,UI.MUTED);shop_grid.add_child(shop_empty)
	if shop=="clothes": refresh_shop_preview()
func build_shop_card(id: String) -> Dictionary:
	var item:=DB.item(id)
	var c:=item_card(id,shop_grid)
	var row: Dictionary={"card":c.get_parent()}
	var description:=UI.label(item.description,12,UI.MUTED)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x=250
	c.add_child(description)
	if shop_tab=="buy":
		if shop=="clothes":
			var fitting:=UI.button("试穿",func(): try_on_clothing(id))
			fitting.custom_minimum_size.y=36
			fitting.add_theme_font_size_override("font_size",15)
			fitting.toggle_mode=true
			fitting.add_theme_stylebox_override("pressed",UI.box(UI.GREEN,18,12))
			fitting.add_theme_color_override("font_pressed_color",UI.CREAM)
			fitting.add_theme_color_override("font_hover_pressed_color",UI.CREAM)
			fitting.set_meta("try_on_item",id)
			c.add_child(fitting)
		var buy:=UI.button("",func(): session.dispatch("buy",{"shop":shop,"item":id}),true)
		buy.set_meta("buy_item",id);c.add_child(buy);row.buy=buy
		if item.kind in ["seed","consumable","ingredient"]:
			row.count=UI.label("",13,UI.MUTED);c.add_child(row.count)
			var bulk:=UI.button("买 5 份 · %d 币"%(item.price*5),func(): session.dispatch("buy",{"shop":shop,"item":id,"quantity":5}))
			bulk.set_meta("bulk_buy_item",id);c.add_child(bulk);row.bulk=bulk
	else:
		row.count=UI.label("",13,UI.MUTED);c.add_child(row.count)
		var sell:=UI.button("出售 1 份",func(): session.dispatch("sell",{"shop":"farm","item":id}),true)
		sell.set_meta("sell_item",id);c.add_child(sell)
		var sell_all:=UI.button("",func(): session.dispatch("sell",{"shop":"farm","item":id,"quantity":mini(99,session.authority.count(id))}))
		sell_all.set_meta("sell_all_item",id);c.add_child(sell_all);row.sell_all=sell_all
	return row
func build_plot() -> void:
	plot_history_open=false
	var id: String=city.current_target
	if not session.state().plots.has(id): close_panel(); return
	var p: Dictionary=session.state().plots[id]
	if p.crop=="":
		content.add_child(UI.label("今天种点什么？",18,UI.MUTED))
		var grid:=scroll_grid(2)
		for crop_id in DB.catalog().crops:
			var seed: String=DB.crop(crop_id).seed
			var c:=item_card(seed,grid)
			c.add_child(UI.label(DB.item(seed).description,14,UI.MUTED))
			var count_: int=session.authority.count(seed)
			var locked: String=session.authority.crop_lock_reason(crop_id)
			var b:=UI.button(locked if locked!="" else "播种 · 持有 %d"%count_,func(): selected_seed=seed; close_panel(); city.begin_action("plant",id,seed),true)
			b.disabled=count_<1 or locked!=""
			b.set_meta("plant_seed",seed)
			c.add_child(b)
	else:
		var need: Dictionary=session.authority.needs(p)
		var ratio:=clampf(float(p.growth)/(float(DB.crop(p.crop).days)*3600),0,1)
		content.add_child(UI.label("%s · 成长 %d%%"%[DB.crop(p.crop).name,int(ratio*100)],25))
		var progress:=ProgressBar.new()
		progress.value=ratio*100
		progress.custom_minimum_size.y=28
		content.add_child(progress)
		var info: String="已经成熟，可以收获啦。" if need.ready else ("缺水，成长已暂停。" if need.water else ("杂草正在抢养分，成长已暂停。" if need.weed else "正在安静地生长。"))
		content.add_child(UI.label(info,19,UI.MUTED))
		var quality:=UI.label("品质 %d / %d · 预计收获 %d"%[int(p.get("quality",0)),DB.crop_quality_max(p.crop),session.authority.crop_yield(p)],16,Color("ae8845"))
		quality.tooltip_text="细心照料有机会提升品质，收获更丰盛。"
		content.add_child(quality)
		var locked: String=session.authority.crop_lock_reason(p.crop)
		content.add_child(UI.label("水壶余量 %d / %d 次 · 菜园东侧水井可打水"%[session.authority.water_left(),DB.water_capacity(session.authority.watering_can_id())],15,Color("537f88")))
		for row in [["浇水","water",need.water],["除草 · 除草剂 × 1","weed",need.weed],["收获","harvest",need.ready]]:
			var b:=UI.button(locked if locked!="" else "%s · %.1f 秒"%[row[0],session.authority.action_duration(row[1])],func(): close_panel(); city.begin_action(row[1],id),true)
			b.disabled=not row[2] or locked!="" or online_target_busy(id) or (row[1]=="water" and session.authority.water_left()<1)
			if row[1]=="water" and session.authority.water_left()<1: b.text="先到水井打水，再来浇水"
			content.add_child(b)
	if session.is_online():content.add_child(UI.button("照料记录",func():show_plot_history(id)))
func show_plot_history(id: String) -> void:
	plot_history_open=true;plot_history_target=id
	UI.clear(content)
	content.add_child(UI.button("返回菜地",func():open_panel("plot")))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(830,420);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
	var rows:=UI.column(13);rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows)
	var history: Dictionary=session.online_care.get(id,{})
	var entries: Array=history.get("current",[]).duplicate()
	if entries.is_empty():entries=history.get("previous",[]).duplicate()
	entries.reverse()
	if entries.is_empty():rows.add_child(UI.label("这块地还没有照料记录。",17,UI.MUTED))
	for entry in entries:
		var action: String={"plant":"播种","water":"浇水","weed":"除草","harvest":"收获"}.get(str(entry.verb),str(entry.verb))
		if entry.get("quality",false):action+=" · 品质+1"
		if int(entry.get("amount",0))>0:action+=" · %s×%d"%[DB.item(entry.crop).name,int(entry.amount)]
		var label:=UI.label("%s\n%s · %s"%[preload("res://scripts/services/island_calendar.gd").text(float(entry.time)),str(entry.name),action],17)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=780;rows.add_child(label)
func online_target_busy(id: String) -> bool:
	if not session.is_online():return false
	var lock: Dictionary=session.online_locks.get(city.map_id+":"+id,{})
	return not lock.is_empty() and str(lock.get("owner",""))!=session.active_character_id
func build_kitchen() -> void:
	content.add_child(UI.label("把今天的收获煮成一餐。",15,UI.MUTED))
	var category:=build_filters("kitchen",[["all","全部"],["soup","暖汤"],["salad","沙拉"],["stew","炖菜"],["baked","烘焙"],["meal","简餐"]])
	var grid:=scroll_grid(2)
	for id in DB.catalog().recipes:
		var recipe:=DB.recipe(id)
		if recipe.station!="kitchen": continue
		if category!="all" and DB.food_category(recipe.output)!=category: continue
		var c:=item_card(recipe.output,grid)
		c.add_child(UI.label("%.1f 秒 · 烹饪 Lv.%d"%[float(recipe.seconds)/session.authority.multiplier("cook"),int(recipe.get("required_level",1))],14,Color("a57c43")))
		c.add_child(UI.label(DB.effect_summary(recipe.output),15,UI.INK))
		var enough:=true
		for ingredient in recipe.ingredients:
			var owned: int=session.authority.count(ingredient)
			var needed: int=recipe.ingredients[ingredient]
			enough=enough and owned>=needed
			c.add_child(UI.label("%s    %d / %d"%[DB.item(ingredient).name,owned,needed],14,UI.MUTED if owned>=needed else Color("b96c59")))
		var locked: String=session.authority.recipe_lock_reason(id)
		var b:=UI.button(locked if locked!="" else ("开始烹饪" if enough else "材料还不够"),func(): close_panel(); city.begin_cooking(id),true)
		b.tooltip_text="烹饪经验 +%d"%int(recipe.get("skill_experience",1))
		b.disabled=not enough or locked!=""
		b.set_meta("recipe",id)
		c.add_child(b)
func build_workshop() -> void:
	content.add_child(UI.label("把采集的材料做成工具。完成时扣材料，取消不消耗。",15,UI.MUTED))
	content.add_child(UI.label("制造 Lv.%d · 速度加成 +%d%%"%[session.authority.skill_level("manufacturing"),roundi(session.authority.bonus("manufacture")*100)],17,UI.GREEN))
	var grid:=scroll_grid(2)
	for id in DB.catalog().recipes:
		var recipe:=DB.recipe(id)
		if recipe.station!="workshop": continue
		var c:=item_card(recipe.output,grid)
		if DB.water_capacity(recipe.output)>0: c.add_child(UI.label("装满可浇水 %d 次"%DB.water_capacity(recipe.output),15,UI.GREEN))
		c.add_child(UI.label("%.1f 秒 · 制造 Lv.%d · 经验 +%d"%[float(recipe.seconds)/session.authority.multiplier("manufacture"),int(recipe.get("required_level",1)),int(recipe.get("skill_experience",1))],14,Color("a57c43")))
		var enough:=true
		for ingredient in recipe.ingredients:
			var owned: int=session.authority.count(ingredient);var needed: int=recipe.ingredients[ingredient]
			enough=enough and owned>=needed
			c.add_child(UI.label("%s    %d / %d"%[DB.item(ingredient).name,owned,needed],15,UI.MUTED if owned>=needed else Color("b96c59")))
		var locked: String=session.authority.recipe_lock_reason(id)
		var owned: bool=session.authority.count(recipe.output)>0
		var b:=UI.button("已拥有" if owned else (locked if locked!="" else ("开始制造" if enough else "材料还不够")),func(): close_panel();city.begin_manufacturing(id),true)
		b.disabled=owned or not enough or locked!="" or online_target_busy(city.current_target)
		b.set_meta("recipe",id);c.add_child(b)
func build_dining() -> void:
	content.add_child(UI.label("坐下，慢慢享用。",15,UI.MUTED))
	var category:=build_filters("dining",[["all","全部"],["soup","暖汤"],["salad","沙拉"],["stew","炖菜"],["baked","烘焙"],["meal","简餐"]])
	var grid:=scroll_grid(2)
	var found:=false
	for id in session.state().inventory:
		var item:=DB.item(id)
		if item.kind!="food" or (category!="all" and DB.food_category(id)!=category): continue
		found=true
		var c:=item_card(id,grid)
		c.add_child(UI.label("口袋里有 %d 份"%session.authority.count(id),14,UI.MUTED))
		c.add_child(UI.label(DB.effect_summary(id),16,UI.INK))
		var full: bool=item.get("effect",{}).is_empty() and int(item.get("stamina_restore",0))>0 and session.state().stamina>=session.authority.stamina_max()
		var eat:=UI.button("耐力已满" if full else "入座享用 · 6 秒",func(): close_panel(); city.begin_dining(id),true)
		eat.disabled=full
		c.add_child(eat)
	if not found:
		grid.add_child(UI.label("口袋里还没有料理。\n先去旁边的料理台做一道吧。\n调料在春芽种子商店有售。",20,UI.MUTED))
func build_settings() -> void:
	var scroll:=ScrollContainer.new();scroll.name="SettingsScroll"
	scroll.custom_minimum_size=Vector2(0,490)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var options:=UI.column(14);options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(options)
	options.add_child(UI.label("海岛的时间继续缓缓流动。",16,UI.MUTED))
	if session.is_online():
		options.add_child(UI.button("脱离卡住",func():
			close_panel()
			var result: Dictionary=await session.request_online("unstuck")
			if not result.get("ok",false):notify(str(result.get("message","稍等一下再试吧。")))
			else:
				var p: Array=session.state().player_position;city.bunny.stand_up(Vector3(float(p[0]),float(p[1]),float(p[2])));city.sleep_active=false;city.nap_active=false;city.finish_action()))
	options.add_child(UI.label("室内视角",17))
	var view:=OptionButton.new();view.name="IndoorViewSetting"
	for label_ in preload("res://scripts/city/interior_view.gd").NAMES:view.add_item(label_)
	view.selected=int(session.settings.interior_view_mode);view.item_selected.connect(func(index):session.set_setting("interior_view_mode",index));options.add_child(view)
	var sound:=CheckButton.new()
	sound.text="环境声音"
	sound.button_pressed=session.settings.sound
	sound.toggled.connect(func(v): session.set_setting("sound",v))
	options.add_child(sound)
	options.add_child(UI.label("音量",17))
	var volume:=HSlider.new()
	volume.min_value=0
	volume.max_value=1
	volume.step=.01
	volume.value=session.settings.volume
	volume.value_changed.connect(func(v): session.set_setting("volume",v))
	options.add_child(volume)
	preload("res://scripts/ui/audio_credits.gd").add_to(options)
	var full:=CheckButton.new()
	full.text="全屏显示"
	full.button_pressed=session.settings.fullscreen
	full.toggled.connect(func(v): session.set_setting("fullscreen",v))
	options.add_child(full)
	preload("res://scripts/city/render_budget.gd").add_control(options,session)
	preload("res://scripts/city/frame_pacer.gd").add_controls(options,session)
	var motion:=CheckButton.new()
	motion.text="减少界面动效"
	motion.button_pressed=session.settings.reduce_motion
	motion.toggled.connect(func(v): session.set_setting("reduce_motion",v))
	options.add_child(motion)
	var automatic:=CheckButton.new();automatic.text="自动下载更新并重启";automatic.button_pressed=session.settings.get("auto_update",true)
	automatic.toggled.connect(func(value):session.set_setting("auto_update",value));options.add_child(automatic)
	options.add_child(UI.button("返回标题检查更新",func():city.return_to_title()))
	if session.can_adjust_time():
		var clock_control:=preload("res://scripts/ui/time_controls.gd").new()
		clock_control.session=session;options.add_child(clock_control)

	options.add_child(UI.label("C 角色 · I 背包 · Tab 换装 · M 地图\nE 互动  ·  F 快捷互动  ·  Esc 返回 / 取消动作  ·  F2 取景  ·  F12 拍照",15,UI.MUTED))
	options.add_child(UI.button("保存并回到标题界面",func(): session.save_game(); city.return_to_title()))
	options.add_child(UI.button("保存并退出游戏",func(): session.save_game(); get_tree().quit()))
func build_map() -> void:
	if city.map_id=="valley": build_valley_map();return
	var east_building: bool=not session.is_online()
	content.add_child(UI.label("北 · 商业街     东 · 菜园"+("与建造园 · 东庭两层样板房" if east_building else "")+"     南 · 沙滩     西 · 住宅
散步寻找石灰石、铜矿与树枝 · 公园有四棵橘子树",17,UI.MUTED))
	map_draw=Control.new()
	map_draw.custom_minimum_size=Vector2(890,480)
	content.add_child(map_draw)
	map_draw.draw.connect(func():
		var center:=Vector2(445,238)
		map_draw.draw_set_transform(center-Vector2(53.5*3.65,0) if east_building else center,0,Vector2(3.65,3.25) if east_building else Vector2(4.6,4.1))
		if east_building:
			map_draw.draw_rect(preload("res://scripts/building/site.gd").PAD,Color("a8c68c"));map_draw.draw_rect(preload("res://scripts/building/site.gd").CONNECTOR,Color("eee4c8"))
			map_draw.draw_line(Vector2(97,29),Vector2(159,29),Color("eee4c8"),1.2)
			map_draw.draw_rect(Rect2(131,2.5,16,15),Color("eadcc5"));map_draw.draw_rect(Rect2(131,2.5,16,12),Color("688d81"))
		map_draw.draw_circle(Vector2.ZERO,55,Color("a8c68c"))
		map_draw.draw_rect(Rect2(-36,28,72,13),Color("e4cc94"))
		map_draw.draw_rect(Rect2(-39,-31,70,12),Color("d7b99c"))
		map_draw.draw_rect(Rect2(20,-10,22,24),Color("a39466"))
		map_draw.draw_rect(Rect2(-48,-9,20,36),Color("b7b8a3"))
		map_draw.draw_circle(Vector2.ZERO,11,Color("e2d6b5"))
		map_draw.draw_line(Vector2(0,-39),Vector2(0,32),Color("eee4c8"),4)
		map_draw.draw_line(Vector2(-42,13),Vector2(43,13),Color("eee4c8"),3)
		map_draw.draw_line(Vector2(-42,-13),Vector2(43,-13),Color("eee4c8"),3)
		var p: Vector3=city.bunny.position
		map_draw.draw_circle(Vector2(p.x,p.z),1.7,Color("fff8e0"))
		map_draw.draw_circle(Vector2(p.x,p.z),1.1,Color("ca7f66")))
func toggle_photo() -> void:
	photo_mode=not photo_mode
	root_ui.visible=not photo_mode

func build_valley_map() -> void:
	content.add_child(UI.label("沿小溪过桥 · 石阶通往高处林地 · 北边是潘达的小屋\n南岸码头可以免费坐船回城",17,UI.MUTED))
	map_draw=Control.new();map_draw.custom_minimum_size=Vector2(890,480);content.add_child(map_draw)
	map_draw.draw.connect(func():
		map_draw.draw_set_transform(Vector2(445,218),0,Vector2(4.6,3.8))
		map_draw.draw_circle(Vector2.ZERO,50,Color("8fb27c"))
		map_draw.draw_rect(Rect2(-40,-40,80,31),Color("719963"))
		map_draw.draw_rect(Rect2(-32,-40,66,13),Color("5c865b"))
		map_draw.draw_rect(Rect2(-22,33,17,19),Color("9fb77d"))
		var river:=PackedVector2Array()
		for z in range(-44,62): river.append(Vector2(sin(z*.07)*2,z))
		map_draw.draw_polyline(river,Color("76bab4"),5.5,true)
		map_draw.draw_line(Vector2(-6,5),Vector2(6,5),Color("e4c08b"),3.4,true)
		for x in [-18,22]:
			for z in [-9,-27]: map_draw.draw_rect(Rect2(x-2.5,z-3,5,6),Color("d9c49a"))
		map_draw.draw_rect(Rect2(9.5,-27,5,6),Color("d9c49a"))
		map_draw.draw_rect(Rect2(6,-41,12,10),Color("e6d7b5"))
		map_draw.draw_rect(Rect2(-14,45.3,11.2,3.8),Color("d8b987"))
		map_draw.draw_circle(preload("res://scripts/valley/valley_layout.gd").dock("valley"),1.5,Color("ede0bf"))
		var point: Vector3=city.bunny.position
		map_draw.draw_circle(Vector2(point.x,point.z),1.7,Color("fff8e0"))
		map_draw.draw_circle(Vector2(point.x,point.z),1.0,Color("ca7f66")))
