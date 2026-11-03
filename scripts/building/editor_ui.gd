extends CanvasLayer
const UI=preload("res://scripts/ui/ui_kit.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const STYLES:=["original","plaster","wood","brick","stone"]
var editor: Node
var title: Label
var status: Label
var help: Label
var selection: Label
var selection_hint: Label
var selected_preview: TextureRect
var color: ColorPickerButton
var style: OptionButton
var move_button: Button
var rotate_button: Button
var delete_button: Button
var apply_button: Button
var undo_button: Button
var redo_button: Button
var root_ui: Control
var tools: Dictionary={}
var cards: Dictionary={}
var card_images: Dictionary={}
var tabs: Dictionary={}
var category:="结构"
var updating:=false
var studio: Node
var item_grid: GridContainer
var catalog_area: ScrollContainer
var appearance_panel: PanelContainer
var appearance_button: Button
var paint_row: HBoxContainer
var selected_thumb_key:=""
var selected_kind:=""
func compact(text_: String,callback: Callable,id: String="",accent: bool=false) -> Button:
	var button:=UI.button(text_,callback,accent);button.name=id if id!="" else text_;button.custom_minimum_size=Vector2(0,34);button.add_theme_font_size_override("font_size",14)
	for state in ["normal","hover","pressed","disabled"]:
		var box: StyleBoxFlat=button.get_theme_stylebox(state).duplicate();box.set_corner_radius_all(9);box.content_margin_left=9;box.content_margin_right=9;box.content_margin_top=5;box.content_margin_bottom=5;button.add_theme_stylebox_override(state,box)
	button.focus_mode=Control.FOCUS_NONE;return button
func _ready() -> void:
	layer=20;root_ui=Control.new();root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_ui.theme=UI.theme();add_child(root_ui)
	studio=preload("res://scripts/building/thumbnail_studio.gd").new();add_child(studio);studio.thumbnail_ready.connect(set_thumbnail)
	var dock:=UI.panel(Color("fff9e9",.98),20,14);dock.name="BuildDock";root_ui.add_child(dock);dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);dock.offset_left=12;dock.offset_right=-12;dock.offset_top=-280;dock.offset_bottom=-12
	var column:=UI.column(9);dock.add_child(column)
	var header:=UI.row(10);column.add_child(header);header.add_child(UI.label("东岸 · 建造与布置",18));title=UI.label("",13,UI.MUTED);header.add_child(title)

	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(spacer)
	var night:=CheckButton.new();night.name="NightPreview";night.text="夜景预览";night.add_theme_font_size_override("font_size",14);night.toggled.connect(func(value):editor.set_night_preview(value));header.add_child(night)
	var roofs:=CheckButton.new();roofs.name="ShowRoof";roofs.text="完整屋顶";roofs.add_theme_font_size_override("font_size",14);roofs.toggled.connect(func(value):editor.set_roof_visible(value));header.add_child(roofs)
	header.add_child(compact("完成 · 步行查看",func():editor.close_editor(),"FinishBuilding",true))
	var body:=UI.row(12);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var commands:=UI.column(6);commands.custom_minimum_size.x=154;body.add_child(commands)
	var tool_row:=UI.row(5);commands.add_child(tool_row)
	for data in [["选择","select"],["锤子","delete"]]:
		var button:=compact(data[0],func():editor.choose_tool(data[1]),"Tool_"+data[1]);button.toggle_mode=true;button.custom_minimum_size=Vector2(74,48)
		var icon:=preload("res://scripts/building/tool_icon.gd").new();icon.kind=data[1];icon.position=Vector2(3,10);icon.size=Vector2(24,24);button.add_child(icon);button.text="    "+data[0];button.tooltip_text="选择物件查看操作" if data[1]=="select" else "从墙开始拖动只拆墙，从地板开始只拆地板；失去支撑的附属物联动删除";tool_row.add_child(button);tools[data[1]]=button
	var history:=UI.row(5);commands.add_child(history);undo_button=compact("↶ 撤销",func():editor.undo(),"BuildUndo");redo_button=compact("↷ 重做",func():editor.redo(),"BuildRedo");history.add_child(undo_button);history.add_child(redo_button)
	commands.add_child(compact("放置整栋样板房",func():editor.place_template(),"PlaceSampleRoom"));commands.add_child(compact("清空地块",func():editor.clear_plot(),"ClearBuildPlot"))
	body.add_child(VSeparator.new())
	var catalog:=UI.column(6);catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(catalog)
	var category_row:=UI.row(5);catalog.add_child(category_row)
	for name_ in Catalog.CATEGORIES:
		var tab:=compact(name_,func():show_category(name_),"Category_"+name_);tab.toggle_mode=true;category_row.add_child(tab);tabs[name_]=tab
	catalog_area=ScrollContainer.new();catalog_area.name="CatalogScroll";catalog_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;catalog_area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;catalog.add_child(catalog_area)
	item_grid=GridContainer.new();item_grid.columns=7;item_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item_grid.add_theme_constant_override("h_separation",7);item_grid.add_theme_constant_override("v_separation",7);catalog_area.add_child(item_grid)
	for item in [["地板","floor"],["墙壁","wall"],["窗户","window"],["房门","door"],["屋顶","roof"]]:add_card(item[1],item[0],"结构")
	for id in Catalog.OBJECTS:add_card("object:"+id,Catalog.OBJECTS[id].name,Catalog.OBJECTS[id].category)
	body.add_child(VSeparator.new())
	var details:=UI.column(6);details.custom_minimum_size.x=274;body.add_child(details)
	var selected_row:=UI.row(8);details.add_child(selected_row)
	selected_preview=TextureRect.new();selected_preview.custom_minimum_size=Vector2(80,66);selected_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;selected_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;selected_row.add_child(selected_preview)
	var texts:=UI.column(3);texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_row.add_child(texts);selection=UI.label("选择一件物品",17);texts.add_child(selection);selection_hint=UI.label("从下方目录开始布置",12,UI.MUTED);selection_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_hint.custom_minimum_size.x=170;texts.add_child(selection_hint)
	var actions:=UI.row(5);details.add_child(actions)
	move_button=compact("移动",func():editor.begin_move(),"MoveBuildElement");rotate_button=compact("旋转 R",func():editor.rotate_selected(),"RotateBuildElement");delete_button=compact("删除",func():editor.delete_selected(),"DeleteBuildElement")
	for button in [move_button,rotate_button,delete_button]:button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(button)
	paint_row=UI.row(6);details.add_child(paint_row);color=ColorPickerButton.new();color.name="BuildColor";color.color=Color("eadcc5");color.edit_alpha=false;color.custom_minimum_size=Vector2(42,32);paint_row.add_child(color)
	style=OptionButton.new();style.name="BuildMaterial";style.size_flags_horizontal=Control.SIZE_EXPAND_FILL;style.custom_minimum_size.y=32;style.add_theme_font_size_override("font_size",13)
	for name_ in ["保留原样","灰泥 / 素色","木纹","砖石","石板"]:style.add_item(name_)
	for state in ["normal","hover","pressed"]:style.add_theme_stylebox_override(state,UI.box(Color("ebefdb"),8,6))
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]:style.add_theme_color_override(state,UI.INK)
	style.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,12,10));style.get_popup().add_theme_stylebox_override("hover",UI.box(Color("d9e8ce"),8,8));style.get_popup().add_theme_color_override("font_color",UI.INK)
	paint_row.add_child(style);apply_button=compact("应用外观",func():editor.paint_selected(color.color,STYLES[style.selected]),"ApplyBuildAppearance");paint_row.add_child(apply_button)
	appearance_button=compact("外观 · 选择部位",func():appearance_panel.open(editor.selected_row()),"EditFurnitureAppearance");details.add_child(appearance_button)
	appearance_panel=preload("res://scripts/building/appearance_panel.gd").new();appearance_panel.editor=editor;root_ui.add_child(appearance_panel)
	color.color_changed.connect(func(_value):if not updating:editor.brush_painted=true)
	style.item_selected.connect(func(_index):if not updating:editor.brush_painted=true)
	var footer:=UI.column(2);column.add_child(footer);status=UI.label("",13);footer.add_child(status);help=UI.label("",12,UI.MUTED);footer.add_child(help)
	catalog_area.resized.connect(resize_grid);show_category("结构");hide()
func resize_grid() -> void:item_grid.columns=maxi(3,int(catalog_area.size.x/104.))
func add_card(id: String,label_: String,group: String) -> void:
	var button:=compact("",func():editor.choose_tool(id),"Tool_"+id.replace(":","_"));button.toggle_mode=true;button.custom_minimum_size=Vector2(96,100);button.tooltip_text=label_;button.set_meta("category",group);item_grid.add_child(button);tools[id]=button;cards[id]=button
	var col:=VBoxContainer.new();col.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(col);col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);col.offset_left=4;col.offset_right=-4;col.offset_top=3;col.offset_bottom=-4
	var preview:=TextureRect.new();preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.custom_minimum_size.y=72;preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;col.add_child(preview);card_images[id]=preview
	var caption:=UI.label(label_,13);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(caption)
func show_category(value: String) -> void:
	category=value
	for id in cards:
		cards[id].visible=cards[id].get_meta("category")==value
		if cards[id].visible:studio.request(id.trim_prefix("object:"))
	for name_ in tabs:tabs[name_].set_pressed_no_signal(name_==value)
	catalog_area.scroll_vertical=0;resize_grid()
func set_thumbnail(id: String,texture: Texture2D) -> void:
	var tool_id: String="object:"+id if Catalog.OBJECTS.has(id) else id
	if card_images.has(tool_id):card_images[tool_id].texture=texture
	if selected_thumb_key==id:selected_preview.texture=texture
func refresh(row: Dictionary) -> void:
	updating=true
	var counts: Dictionary=preload("res://scripts/building/layout.gd").usage(editor.layout)
	title.text="%.1f㎡地面 · %.1fm墙 · %d/%d物件 · %d/%d灯"%[counts.floor_area,counts.wall_length,counts.objects,preload("res://scripts/building/layout.gd").MAX_ELEMENTS,counts.lights,preload("res://scripts/building/layout.gd").MAX_LIGHTS]
	var preview_row:=row
	if preview_row.is_empty() and editor.tool in ["template","floor","wall","window","door","roof"]:preview_row={"type":editor.tool}
	if preview_row.is_empty() and editor.tool.begins_with("object:"):preview_row={"type":"object","kind":editor.tool.trim_prefix("object:")}
	selected_kind=str(preview_row.get("kind",preview_row.get("type","")))
	selection.text=Catalog.name_for(preview_row) if not preview_row.is_empty() else "选择一件物品"
	selection_hint.text=("已选中半米网格 · 可移动、改色或拆除" if row.get("type","") in ["floor","wall"] else "已选中 · 可移动、旋转或删除") if not row.is_empty() else "选择目录物品，再点击场景放置"
	if row.is_empty() and preview_row.get("type","")=="object":selection_hint.text="点击放置 · 放置后可分部位编辑外观"
	if not row.is_empty() and row.get("support","")!="":selection_hint.text="依附于 "+Catalog.name_for(preload("res://scripts/building/layout.gd").find(editor.layout,row.support))
	selected_thumb_key=studio.variant_key(preview_row) if preview_row.get("type","")=="object" else selected_kind
	selected_preview.texture=studio.cache.get(selected_thumb_key)
	if selected_kind!="":
		if preview_row.get("type","")=="object":studio.request_variant(preview_row)
		else:studio.request(selected_kind)
	var furniture: bool=row.get("type","")=="object";paint_row.visible=not furniture and preview_row.get("type","")!="object";appearance_button.visible=furniture
	if appearance_panel.visible:
		if row.get("id","")==appearance_panel.target_id:appearance_panel.load_part(false)
		else:appearance_panel.close()
	for button in [apply_button,move_button,delete_button]:button.disabled=row.is_empty()
	rotate_button.disabled=row.get("type","")!="object";undo_button.disabled=editor.undo_stack.is_empty();redo_button.disabled=editor.redo_stack.is_empty()
	for id in tools:tools[id].set_pressed_no_signal(editor.tool==id)
	if not row.is_empty():color.color=Color(row.color);style.selected=maxi(0,STYLES.find(row.style))
	var action: String={"template":"整屋跟随鼠标 · 点击空地放置 · Esc 取消", "select":"点击选中物件 · 再选移动、旋转或删除", "delete":"锤子：按起点类型拆除 · 按住拖动，松开确认 · Esc取消", "wall":"点击墙的起点和终点 · 两面装修一致", "floor":"点击地板矩形的两个角", "roof":"点击屋顶矩形的两个角", "door":"点击墙面安装门", "window":"点击墙面安装窗户", "move":"点击新位置完成移动 · Esc 取消"}.get(editor.tool,"点击放置 · R 旋转 · 台灯与摆件自动吸附台面")
	help.text=action+"   |   右键转动 · WASD / Shift+右键平移 · 滚轮缩放";updating=false
func message(text_: String,error: bool=false) -> void:status.text=text_;status.modulate=Color("a65445") if error else Color("426e5c")
