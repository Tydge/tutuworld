extends Control
signal closed
signal play_requested(character_id: String)
signal account_switch_requested
const Animals=preload("res://scripts/characters/animal_catalog.gd")
const UI=preload("res://scripts/ui/ui_kit.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Preview=preload("res://scripts/ui/character_preview.gd")
const Icon=preload("res://scripts/ui/item_icon.gd")
var session: Node
var card: PanelContainer
var heading: Label
var portrait_name: Label
var portrait_subtitle: Label
var preview: Control
var right: VBoxContainer
var name_input: LineEdit
var error_label: Label
var primary: Button
var clothing_grid: GridContainer
var mode:="choose"
var selected_id:=""
var draft_name:=""
var draft_species:="bunny"
var draft_item:="bow_rose"
var clothing_category:="head"
var busy:=false
var account_button: Button
func _ready() -> void:
	theme=UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new()
	shade.color=Color("284b40",.47)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card=UI.panel(UI.CREAM,32,28)
	card.custom_minimum_size=Vector2(1100,680)
	add_child(card)
	var layout:=UI.column(18)
	card.add_child(layout)
	var header:=UI.row()
	layout.add_child(header)
	heading=UI.label("今天，谁来岛上散步？",28)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(UI.button("返回",go_back))
	account_button=UI.button("切换账号",func():
		if busy:return
		busy=true;await session.logout_online();busy=false;hide();account_switch_requested.emit())
	header.add_child(account_button);account_button.hide()
	var body:=UI.row(28)
	layout.add_child(body)
	var portrait:=UI.panel(Color("e5ead5"),26,14)
	portrait.custom_minimum_size=Vector2(340,540)
	body.add_child(portrait)
	var left:=UI.column(8)
	portrait.add_child(left)
	portrait_name=UI.label("",25)
	portrait_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(portrait_name)
	preview=Preview.new()
	preview.preview_size=Vector2i(312,414)
	left.add_child(preview)
	portrait_subtitle=UI.label("",15,UI.MUTED)
	portrait_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(portrait_subtitle)
	var hint:=UI.label("拖动角色，转一转看看",13,UI.MUTED)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(hint)
	right=UI.column(14)
	right.custom_minimum_size=Vector2(648,540)
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_child(right)
	hide()
func _process(_delta: float) -> void:
	card.position=(get_viewport_rect().size-card.size)*.5
func open() -> void:
	busy=false
	account_button.visible=session.is_online()
	show()
	var roster: Array=session.character_list()
	if roster.is_empty(): begin_create()
	else:
		selected_id=session.active_character_id if session.characters.has(session.active_character_id) else roster[0].id
		show_roster()
	if not session.settings.reduce_motion: UI.pop(card)
func go_back() -> void:
	if busy: return
	if mode=="create" and not session.characters.is_empty(): show_roster()
	else: hide(); closed.emit()
func show_roster() -> void:
	mode="choose"
	heading.text="今天，谁来岛上散步？"
	UI.clear(right)
	var roster: Array=session.character_list()
	if not session.characters.has(selected_id): selected_id=roster[0].id
	var row:=UI.row()
	right.add_child(row)
	var title:=UI.label("小岛上的你",22)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(UI.button("＋ 新建角色",begin_create))
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(640,360)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list:=UI.column(12)
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in roster:
		var id: String=entry.id
		var species_name: String=Animals.display_name(entry.species)
		var b:=UI.button("%s   ·   %s   ·   经验 %d"%[entry.character_name,species_name,entry.experience],func(): selected_id=id; show_roster(),id==selected_id)
		b.set_meta("character_id",id)
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y=76
		list.add_child(b)
	error_label=UI.label("",15,Color("b36959"))
	error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	right.add_child(error_label)
	primary=UI.button("出发，去岛上走走",choose_existing,true)
	primary.custom_minimum_size.y=60
	right.add_child(primary)
	var selected: Dictionary=session.characters[selected_id]
	portrait_name.text=selected.character_name
	portrait_subtitle.text="%s  ·  经验 %d"%[Animals.display_name(selected.species),selected.experience]
	preview.update_character(selected.species,selected.equipment)
func begin_create() -> void:
	mode="create"
	draft_name=""
	draft_species="bunny"
	draft_item="bow_rose"
	clothing_category="head"
	build_create()
	focus_name.call_deferred()
func build_create() -> void:
	heading.text="认识一位新的小岛邻居"
	UI.clear(right)
	right.add_child(UI.label("你的名字",19))
	name_input=LineEdit.new()
	name_input.custom_minimum_size.y=50
	name_input.max_length=12
	name_input.placeholder_text="给自己取个名字（1～12 字）"
	name_input.text=draft_name
	name_input.add_theme_stylebox_override("normal",UI.box(Color("e9edda"),16,12))
	name_input.add_theme_stylebox_override("focus",UI.box(Color("dce8ce"),16,12))
	name_input.add_theme_color_override("font_color",UI.INK)
	name_input.add_theme_color_override("caret_color",UI.INK)
	name_input.text_changed.connect(func(value): draft_name=value; error_label.text=""; refresh_draft())
	name_input.text_submitted.connect(func(_value): if not primary.disabled: create_new())
	right.add_child(name_input)
	var species_row:=UI.row(10)
	right.add_child(species_row)
	for species_id in Animals.ids():
		var id: String=species_id
		var b:=UI.button(Animals.display_name(id),func(): draft_species=id; build_create(),draft_species==id)
		b.set_meta("species_id",id)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		species_row.add_child(b)
	right.add_child(UI.label("带一件喜欢的初始服饰",19))
	var categories:=UI.row(8)
	right.add_child(categories)
	for entry in [["head","头部"],["neck","脖子"],["body","身体"]]:
		var slot: String=entry[0]
		var b:=UI.button(entry[1],func(): clothing_category=slot; build_create(),clothing_category==slot)
		b.set_meta("starter_category",slot)
		b.custom_minimum_size.y=36
		categories.add_child(b)
	clothing_grid=GridContainer.new()
	clothing_grid.columns=3
	clothing_grid.add_theme_constant_override("h_separation",12)
	right.add_child(clothing_grid)
	for id in DB.starter_clothes():
		var item:=DB.item(id)
		if item.slot!=clothing_category: continue
		var item_id: String=id
		var b:=UI.button("",func(): draft_item=item_id; build_create(),draft_item==id)
		b.set_meta("starter_item",id)
		b.custom_minimum_size=Vector2(208,122)
		clothing_grid.add_child(b)
		var center:=VBoxContainer.new()
		center.mouse_filter=Control.MOUSE_FILTER_IGNORE
		b.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.offset_top=8
		center.alignment=BoxContainer.ALIGNMENT_CENTER
		var icon:=Icon.new()
		icon.item_id=id
		icon.definition=item
		icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		center.add_child(icon)
		var name_:=UI.label(item.name,14,UI.CREAM if draft_item==id else UI.INK)
		name_.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		name_.mouse_filter=Control.MOUSE_FILTER_IGNORE
		center.add_child(name_)
	var choice:=UI.label("已选："+DB.item(draft_item).name+"  ·  初始服饰共 1 件",14,UI.MUTED)
	right.add_child(choice)
	error_label=UI.label("",15,Color("b36959"))
	error_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	right.add_child(error_label)
	primary=UI.button("创建并出发",create_new,true)
	primary.custom_minimum_size.y=58
	right.add_child(primary)
	refresh_draft()
func refresh_draft() -> void:
	portrait_name.text=draft_name.strip_edges() if draft_name.strip_edges()!="" else "新的小岛邻居"
	portrait_subtitle.text=Animals.display_name(draft_species)
	preview.update_character(draft_species,{DB.item(draft_item).slot:draft_item})
	primary.disabled=session.valid_name(draft_name)!="" or busy
func create_new() -> void:
	if busy or primary.disabled: return
	busy=true
	primary.disabled=true
	var result: Dictionary
	if session.is_online():result=await session.create_online_character(draft_name,draft_species,draft_item)
	else:result=session.create_character(draft_name,draft_species,draft_item)
	if not result.ok:
		busy=false
		error_label.text=result.message
		refresh_draft()
		return
	primary.text="海风正在等你…"
	play_requested.emit(result.id)
func choose_existing() -> void:
	if busy: return
	busy=true
	primary.disabled=true
	var result: Dictionary
	if session.is_online():result=await session.select_online_character(selected_id)
	else:result=session.select_character(selected_id)
	if not result.ok:
		busy=false
		primary.disabled=false
		error_label.text=result.message
		return
	primary.text="海风正在等你…"
	play_requested.emit(selected_id)
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		go_back()
		get_viewport().set_input_as_handled()

func focus_name() -> void:
	if visible and mode=="create" and is_instance_valid(name_input) and name_input.is_inside_tree(): name_input.grab_focus()
