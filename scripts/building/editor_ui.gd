extends CanvasLayer
const UI=preload("res://scripts/ui/ui_kit.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Structures=preload("res://scripts/building/structure_catalog.gd")
const STYLES=Structures.STYLES
var floor_choice: OptionButton
var entire_choice: CheckButton
var batch_paint: CheckButton
var wall_face: OptionButton
var form_family:=""
var breadcrumb: HBoxContainer
var breadcrumb_label: Label
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
	var dock:=UI.panel(Color("fff9e9",.98),20,14);dock.name="BuildDock";root_ui.add_child(dock);dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);dock.offset_left=12;dock.offset_right=-12;dock.offset_top=-326;dock.offset_bottom=-12
	var column:=UI.column(9);dock.add_child(column)
	var header:=UI.row(8);column.add_child(header);header.add_child(UI.label("东岸 · 建造",18))
	header.add_child(compact("▼",func():editor.set_storey(editor.editing_storey-1),"FloorDown"))
	floor_choice=OptionButton.new();floor_choice.name="EditingStorey";floor_choice.add_theme_font_size_override("font_size",14)
	for level in range(4):floor_choice.add_item("%d楼"%(level+1))
	for state in ["normal","hover","pressed"]:floor_choice.add_theme_stylebox_override(state,UI.box(Color("ebefdb"),8,6))
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]:floor_choice.add_theme_color_override(state,UI.INK)
	floor_choice.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,12,10));floor_choice.get_popup().add_theme_color_override("font_color",UI.INK)
	floor_choice.tooltip_text="只选择编辑楼层，不移动角色；PageUp / PageDown也可切换"
	floor_choice.item_selected.connect(func(level):editor.set_storey(level));header.add_child(floor_choice)
	header.add_child(compact("▲",func():editor.set_storey(editor.editing_storey+1),"FloorUp"))
	entire_choice=CheckButton.new();entire_choice.name="EntireBuilding";entire_choice.text="整栋外观";entire_choice.add_theme_font_size_override("font_size",13);entire_choice.toggled.connect(func(value):editor.set_entire(value));header.add_child(entire_choice)
	title=UI.label("",12,UI.MUTED);header.add_child(title)

	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(spacer)
	var night:=CheckButton.new();night.name="NightPreview";night.text="夜景预览";night.add_theme_font_size_override("font_size",14);night.toggled.connect(func(value):editor.set_night_preview(value));header.add_child(night)
	var roofs:=CheckButton.new();roofs.name="ShowRoof";roofs.text="查看完整屋顶/墙壁";roofs.tooltip_text="关闭剖切，查看所有墙壁和完整屋顶；再次关闭可继续布置室内";roofs.add_theme_font_size_override("font_size",14);roofs.toggled.connect(func(value):editor.set_roof_visible(value));header.add_child(roofs)
	header.add_child(compact("完成 · 步行查看",func():editor.close_editor(),"FinishBuilding",true))
	var body:=UI.row(12);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var commands:=UI.column(6);commands.custom_minimum_size.x=154;body.add_child(commands)
	var tool_row:=UI.row(5);commands.add_child(tool_row)
	for data in [["选择","select"],["锤子","delete"]]:
		var button:=compact(data[0],func():editor.choose_tool(data[1]),"Tool_"+data[1]);button.toggle_mode=true;button.custom_minimum_size=Vector2(74,48)
		var icon:=preload("res://scripts/building/tool_icon.gd").new();icon.kind=data[1];icon.position=Vector2(3,10);icon.size=Vector2(24,24);button.add_child(icon);button.text="    "+data[0];button.tooltip_text="选择物件查看操作" if data[1]=="select" else "从墙开始拖动只拆墙，从地板开始只拆地板；失去支撑的附属物联动删除";tool_row.add_child(button);tools[data[1]]=button
	var history:=UI.row(5);commands.add_child(history);undo_button=compact("↶ 撤销",func():editor.undo(),"BuildUndo");redo_button=compact("↷ 重做",func():editor.redo(),"BuildRedo");history.add_child(undo_button);history.add_child(redo_button)
	commands.add_child(compact("放置整栋样板房",func():editor.place_template(),"PlaceSampleRoom"));commands.add_child(compact("两层庭院样板房",func():editor.place_template("two_storey"),"PlaceTwoStorey"));commands.add_child(compact("清空地块",func():editor.clear_plot(),"ClearBuildPlot"))
	body.add_child(VSeparator.new())
	var catalog:=UI.column(6);catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(catalog)
	var category_row:=UI.row(5);catalog.add_child(category_row)
	for name_ in Catalog.CATEGORIES:
		var tab:=compact(name_,func():show_category(name_),"Category_"+name_);tab.toggle_mode=true;category_row.add_child(tab);tabs[name_]=tab
	breadcrumb=UI.row(6);catalog.add_child(breadcrumb);breadcrumb.add_child(compact("‹ 返回结构",func():show_category("结构"),"BackToStructures"));breadcrumb_label=UI.label("",14);breadcrumb.add_child(breadcrumb_label);breadcrumb.hide()
	catalog_area=ScrollContainer.new();catalog_area.name="CatalogScroll";catalog_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;catalog_area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;catalog.add_child(catalog_area)
	item_grid=GridContainer.new();item_grid.columns=7;item_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item_grid.add_theme_constant_override("h_separation",7);item_grid.add_theme_constant_override("v_separation",7);catalog_area.add_child(item_grid)
	for item in [["地板","floor"],["墙壁","wall"],["窗户","window"],["房门","door"],["屋顶","roof"],["楼梯","stairs"],["护栏","railing"]]:add_card(item[1],item[0],"结构")
	for form in preload("res://scripts/building/stairs.gd").FORMS:add_card("stairs:"+form,preload("res://scripts/building/stairs.gd").FORMS[form],"结构/stairs")
	for family in Structures.FORMS:
		for form in Structures.FORMS[family]:add_card(family+":"+form,Structures.FORMS[family][form],"结构/"+family)
	for id in Catalog.OBJECTS:add_card("object:"+id,Catalog.OBJECTS[id].name,Catalog.OBJECTS[id].category)
	body.add_child(VSeparator.new())
	var details:=UI.column(6);details.custom_minimum_size.x=360;body.add_child(details)
	var selected_row:=UI.row(8);details.add_child(selected_row)
	selected_preview=TextureRect.new();selected_preview.custom_minimum_size=Vector2(80,66);selected_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;selected_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;selected_row.add_child(selected_preview)
	var texts:=UI.column(3);texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_row.add_child(texts);selection=UI.label("选择一件物品",17);texts.add_child(selection);selection_hint=UI.label("从下方目录开始布置",12,UI.MUTED);selection_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_hint.custom_minimum_size.x=170;texts.add_child(selection_hint)
	var actions:=UI.row(5);details.add_child(actions)
	move_button=compact("移动",func():editor.begin_move(),"MoveBuildElement");rotate_button=compact("旋转 R",func():editor.rotate_selected(),"RotateBuildElement");delete_button=compact("删除",func():editor.delete_selected(),"DeleteBuildElement")
	for button in [move_button,rotate_button,delete_button]:button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(button)
	paint_row=UI.row(6);details.add_child(paint_row);color=ColorPickerButton.new();color.name="BuildColor";color.color=Color("eadcc5");color.edit_alpha=false;color.custom_minimum_size=Vector2(42,32);paint_row.add_child(color)
	style=OptionButton.new();style.name="BuildMaterial";style.size_flags_horizontal=Control.SIZE_EXPAND_FILL;style.custom_minimum_size.y=32;style.add_theme_font_size_override("font_size",13)
	for name_ in Structures.STYLE_NAMES:style.add_item(name_)
	for state in ["normal","hover","pressed"]:style.add_theme_stylebox_override(state,UI.box(Color("ebefdb"),8,6))
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]:style.add_theme_color_override(state,UI.INK)
	style.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,12,10));style.get_popup().add_theme_stylebox_override("hover",UI.box(Color("d9e8ce"),8,8));style.get_popup().add_theme_color_override("font_color",UI.INK)
	paint_row.add_child(style)
	wall_face=OptionButton.new();wall_face.name="WallFace";wall_face.add_theme_font_size_override("font_size",13)
	for name_ in ["内侧","外侧","双面"]:wall_face.add_item(name_)
	wall_face.tooltip_text="内外由闭合房间识别；隔墙两侧都有房间时，朝向镜头的房间为内侧";paint_row.add_child(wall_face);wall_face.item_selected.connect(func(_index):refresh(editor.selected_row()))
	apply_button=compact("应用外观",func():editor.paint_selected(color.color,STYLES[style.selected]),"ApplyBuildAppearance");paint_row.add_child(apply_button)
	batch_paint=CheckButton.new();batch_paint.name="PaintMatchingRoom";batch_paint.text="同房间同款一起修改";batch_paint.button_pressed=true;batch_paint.add_theme_font_size_override("font_size",13);batch_paint.tooltip_text="仅修改本房间中颜色和纹理相同的地板或所选墙面；关闭后只改当前半米单元。未围成房间时只修改当前单元";details.add_child(batch_paint)
	appearance_button=compact("外观 · 选择部位",func():appearance_panel.open(editor.selected_row()),"EditFurnitureAppearance");details.add_child(appearance_button)
	appearance_panel=preload("res://scripts/building/appearance_panel.gd").new();appearance_panel.editor=editor;root_ui.add_child(appearance_panel)
	color.color_changed.connect(func(_value):if not updating:editor.brush_painted=true)
	style.item_selected.connect(func(_index):if not updating:editor.brush_painted=true)
	var footer:=UI.column(2);column.add_child(footer);status=UI.label("",13);footer.add_child(status);help=UI.label("",12,UI.MUTED);footer.add_child(help)
	catalog_area.resized.connect(resize_grid);show_category("结构");hide()
func resize_grid() -> void:item_grid.columns=maxi(3,int(catalog_area.size.x/104.))
func add_card(id: String,label_: String,group: String) -> void:
	var button:=compact("",func():choose_card(id),"Tool_"+id.replace(":","_"));button.toggle_mode=true;button.custom_minimum_size=Vector2(96,100);button.tooltip_text=label_;button.set_meta("category",group);item_grid.add_child(button);tools[id]=button;cards[id]=button
	var col:=VBoxContainer.new();col.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(col);col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);col.offset_left=4;col.offset_right=-4;col.offset_top=3;col.offset_bottom=-4
	var preview:=TextureRect.new();preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.custom_minimum_size.y=72;preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;col.add_child(preview);card_images[id]=preview
	var caption:=UI.label(label_,13);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(caption)
func choose_card(id: String) -> void:
	if Structures.FORMS.has(id) or id=="stairs":
		form_family=id;breadcrumb.show();breadcrumb_label.text={"door":"房门造型","window":"窗户造型","roof":"屋顶造型","stairs":"楼梯形状"}[id]
		for key in cards:
			cards[key].visible=cards[key].get_meta("category")=="结构/"+id
			if cards[key].visible:studio.request(key)
		catalog_area.scroll_vertical=0;resize_grid();editor.choose_tool(id+(":straight" if id=="stairs" else ":classic"))
	else:editor.choose_tool(id)
func show_category(value: String) -> void:
	category=value;form_family="";breadcrumb.hide()
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
	title.text="%.0f㎡ · %d/%d物件 · %d/%d灯"%[counts.floor_area,counts.objects,preload("res://scripts/building/layout.gd").MAX_ELEMENTS,counts.lights,preload("res://scripts/building/layout.gd").MAX_LIGHTS]
	root_ui.find_child("FloorDown",true,false).disabled=editor.editing_storey==0;root_ui.find_child("FloorUp",true,false).disabled=editor.editing_storey==3
	floor_choice.select(editor.editing_storey);entire_choice.set_pressed_no_signal(editor.show_entire)
	var preview_row:=row
	if preview_row.is_empty() and editor.tool in ["template","floor","wall","window","door","roof","stairs","railing"]:preview_row={"type":editor.tool,"form":editor.structure_form}
	if preview_row.is_empty() and editor.tool.begins_with("object:"):preview_row={"type":"object","kind":editor.tool.trim_prefix("object:")}
	selected_kind=str(preview_row.get("kind",preview_row.get("type","")))
	selection.text=Catalog.name_for(preview_row) if not preview_row.is_empty() else "选择一件物品"
	selection_hint.text=("已选中半米网格 · 可移动、改色或拆除" if row.get("type","") in ["floor","wall"] else "已选中 · 可移动、旋转或删除") if not row.is_empty() else "选择目录物品，再点击场景放置"
	if row.is_empty() and preview_row.get("type","")=="object":selection_hint.text="点击放置 · 放置后可分部位编辑外观"
	if not row.is_empty() and row.get("support","")!="":selection_hint.text=("%d楼天花板"%(editor.editing_storey+1)) if str(row.support).begins_with("ceiling:") else "依附于 "+Catalog.name_for(preload("res://scripts/building/layout.gd").find(editor.layout,row.support))
	selected_thumb_key=studio.variant_key(preview_row) if preview_row.get("type","")=="object" else (selected_kind+":"+Structures.form(preview_row) if selected_kind in Structures.FORMS or selected_kind=="stairs" else selected_kind)
	selected_preview.texture=studio.cache.get(selected_thumb_key)
	if selected_kind!="":
		if preview_row.get("type","")=="object":studio.request_variant(preview_row)
		else:studio.request(selected_thumb_key)
	var furniture: bool=row.get("type","")=="object";paint_row.visible=not furniture and preview_row.get("type","")!="object";appearance_button.visible=furniture;batch_paint.visible=row.get("type","") in ["floor","wall"];wall_face.visible=row.get("type","")=="wall"
	if appearance_panel.visible:
		if row.get("id","")==appearance_panel.target_id:appearance_panel.load_part(false)
		else:appearance_panel.close()
	for button in [apply_button,move_button,delete_button]:button.disabled=row.is_empty()
	rotate_button.disabled=row.get("type","") not in ["object","stairs"];undo_button.disabled=editor.undo_stack.is_empty();redo_button.disabled=editor.redo_stack.is_empty()
	for id in tools:tools[id].set_pressed_no_signal((editor.tool==id or editor.tool+":"+editor.structure_form==id))
	if not row.is_empty():
		var face: Dictionary=row
		if row.type=="wall" and wall_face.selected!=2:
			var unit: Dictionary=preload("res://scripts/building/layout.gd").unit_at(editor.layout,row.id,preload("res://scripts/building/layout.gd").rect(row).get_center())
			var edit=preload("res://scripts/building/surface_edit.gd");var plan=preload("res://scripts/building/room_plan.gd").make(preload("res://scripts/building/layout.gd").compiled(editor.layout,editor.editing_storey))
			var side: String=edit.inside_side(plan,unit,Vector2(editor.city.camera.global_position.x,editor.city.camera.global_position.z))
			if wall_face.selected==1:side="negative" if side=="positive" else "positive"
			face=Structures.surface(row,side)
		color.color=Color(face.color);style.selected=maxi(0,STYLES.find(face.style))
	var action: String={"template":"整屋跟随鼠标 · 点击空地放置 · Esc 取消", "select":"点击选中物件 · 再选移动、旋转或删除", "delete":"锤子：按起点类型拆除 · 按住拖动，松开确认 · Esc取消", "wall":"点击墙的起点和终点 · 放置后可分别装修内外墙面", "floor":"点击地板矩形的两个角", "roof":"点击屋顶矩形的两个角", "door":"点击墙面安装门", "window":"点击墙面安装窗户", "stairs":"先铺上下层地板，再放置楼梯 · 自动开洞及护栏 · R旋转", "railing":"点击护栏起点和终点", "move":"点击新位置完成移动 · Esc 取消"}.get(editor.tool,"点击放置 · R 旋转 · 台灯与摆件自动吸附台面")
	help.text=action+"   |   右键转动 · WASD / Shift+右键平移 · 滚轮缩放";updating=false
func message(text_: String,error: bool=false) -> void:status.text=text_;status.modulate=Color("a65445") if error else Color("426e5c")
