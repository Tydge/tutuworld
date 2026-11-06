extends CanvasLayer
const UI=preload("res://scripts/ui/ui_kit.gd")
const Catalog=preload("res://scripts/building/catalog.gd")
const Structures=preload("res://scripts/building/structure_catalog.gd")
const STYLES=Structures.STYLES
var floor_choice: Label
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
var upper_floor_actions: HBoxContainer
var upper_floor_confirm: Button
var scroll_remainder:=0.
var scroll_owner:=0
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
	header.add_child(compact("▼",func():editor.set_storey(editor.view_level()-1),"FloorDown"))
	floor_choice=UI.label("1楼",14);floor_choice.name="EditingStorey";header.add_child(floor_choice)
	header.add_child(compact("▲",func():editor.set_storey(editor.view_level()+1),"FloorUp"))
	var plan_view:=compact("俯视 T",func():editor.toggle_top_down(),"TopDownView");plan_view.toggle_mode=true;plan_view.tooltip_text="正俯视平面图 / 透视 · T切换";header.add_child(plan_view)
	title=UI.label("",12,UI.MUTED);header.add_child(title)

	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(spacer)
	var night:=CheckButton.new();night.name="NightPreview";night.text="夜景预览";night.add_theme_font_size_override("font_size",14);night.toggled.connect(func(value):editor.set_night_preview(value));header.add_child(night)
	var roofs:=CheckButton.new();roofs.name="ShowRoof";roofs.text="完整墙壁";roofs.tooltip_text="开启：显示本层及下层完整墙壁；关闭：剖切本层墙壁方便选取。始终只编辑当前层；最高层向上查看整栋和屋顶。";roofs.add_theme_font_size_override("font_size",14);roofs.toggled.connect(func(value):editor.set_roof_visible(value));header.add_child(roofs)
	header.add_child(compact("完成 · 步行查看",func():editor.close_editor(),"FinishBuilding",true))
	var body:=UI.row(12);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var commands:=UI.column(6);commands.custom_minimum_size.x=154;body.add_child(commands)
	var tool_row:=UI.row(5);commands.add_child(tool_row)
	for data in [["选择","select"],["锤子","delete"]]:
		var button:=compact(data[0],func():editor.choose_tool(data[1]),"Tool_"+data[1]);button.toggle_mode=true;button.custom_minimum_size=Vector2(74,48)
		var icon:=preload("res://scripts/building/tool_icon.gd").new();icon.kind=data[1];icon.position=Vector2(3,10);icon.size=Vector2(24,24);button.add_child(icon);button.text="    "+data[0];button.tooltip_text="选择物件查看操作" if data[1]=="select" else "从墙开始拖动只拆墙，从地板开始只拆地板；失去支撑的附属物联动删除";tool_row.add_child(button);tools[data[1]]=button
	var history:=UI.row(5);commands.add_child(history);undo_button=compact("↶ 撤销",func():editor.undo(),"BuildUndo");redo_button=compact("↷ 重做",func():editor.redo(),"BuildRedo");history.add_child(undo_button);history.add_child(redo_button)
	var eyedrop_button:=compact("吸管 E",func():editor.choose_tool("eyedropper"),"Tool_eyedropper");eyedrop_button.toggle_mode=true;eyedrop_button.tooltip_text="点击家具复制同款和部位外观；点击墙地表面吸取材质";history.add_child(eyedrop_button);tools["eyedropper"]=eyedrop_button
	commands.add_child(compact("创建样板房",show_templates,"PlaceSampleRoom"))
	var upper:=compact("生成上层楼板",func():editor.choose_upper_floor(),"GenerateUpperFloor");upper.tooltip_text="点击本栋地板预览上层楼板，再确认；保留楼梯洞和已有材质。未围墙时按相连地板选取。";commands.add_child(upper)
	commands.add_child(compact("清空地块",func():editor.clear_plot(),"ClearBuildPlot"))
	body.add_child(VSeparator.new())
	var catalog:=UI.column(6);catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(catalog)
	var category_row:=UI.row(5);catalog.add_child(category_row)
	for name_ in Catalog.CATEGORIES:
		var tab:=compact(name_,func():show_category(name_),"Category_"+name_);tab.toggle_mode=true;category_row.add_child(tab);tabs[name_]=tab
	breadcrumb=UI.row(6);catalog.add_child(breadcrumb);breadcrumb.add_child(compact("‹ 返回结构",func():show_category("结构"),"BackToStructures"));breadcrumb_label=UI.label("",14);breadcrumb.add_child(breadcrumb_label);breadcrumb.hide()
	catalog_area=ScrollContainer.new();catalog_area.name="CatalogScroll";catalog_area.size_flags_vertical=Control.SIZE_EXPAND_FILL;catalog_area.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;catalog.add_child(catalog_area)
	item_grid=GridContainer.new();item_grid.columns=7;item_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item_grid.add_theme_constant_override("h_separation",7);item_grid.add_theme_constant_override("v_separation",7);catalog_area.add_child(item_grid)
	for item in [["房间","room"],["地板","floor"],["墙壁","wall"],["窗户","window"],["房门","door"],["屋顶","roof"],["楼梯","stairs"],["护栏","railing"]]:add_card(item[1],item[0],"结构")
	for form in preload("res://scripts/building/stairs.gd").FORMS:add_card("stairs:"+form,preload("res://scripts/building/stairs.gd").FORMS[form],"结构/stairs")
	for family in Structures.FORMS:
		for form in Structures.FORMS[family]:add_card(family+":"+form,Structures.FORMS[family][form],"结构/"+family)
	for sample in [["single_one","温馨小屋"],["two_storey","两层楼阁"]]:add_card("template:"+sample[0],sample[1],"样板房")
	for id in Catalog.OBJECTS:add_card("object:"+id,Catalog.OBJECTS[id].name,Catalog.OBJECTS[id].category)
	body.add_child(VSeparator.new())
	var details:=UI.column(6);details.custom_minimum_size.x=360;body.add_child(details)
	var selected_row:=UI.row(8);details.add_child(selected_row)
	selected_preview=TextureRect.new();selected_preview.custom_minimum_size=Vector2(80,66);selected_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;selected_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;selected_row.add_child(selected_preview)
	var texts:=UI.column(3);texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;selected_row.add_child(texts);selection=UI.label("选择一件物品",17);texts.add_child(selection);selection_hint=UI.label("从下方目录开始布置",12,UI.MUTED);selection_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_hint.custom_minimum_size.x=170;texts.add_child(selection_hint)
	var actions:=UI.row(5);details.add_child(actions)
	move_button=compact("移动 G",func():editor.begin_move(),"MoveBuildElement");rotate_button=compact("旋转 R",func():editor.rotate_selected(),"RotateBuildElement");delete_button=compact("删除",func():editor.delete_selected(),"DeleteBuildElement")
	for button in [move_button,rotate_button,delete_button]:button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(button)
	upper_floor_actions=UI.row(5);details.add_child(upper_floor_actions)
	upper_floor_confirm=compact("确认铺设",func():editor.confirm_upper_floor(),"ConfirmUpperFloor",true);upper_floor_actions.add_child(upper_floor_confirm)
	upper_floor_actions.add_child(compact("取消",func():editor.choose_tool("select"),"CancelUpperFloor"));upper_floor_actions.hide()
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
	if id.begins_with("template:"):editor.place_template(id.trim_prefix("template:"));return
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
	root_ui.find_child("FloorDown",true,false).disabled=editor.view_level()==0;root_ui.find_child("FloorUp",true,false).disabled=editor.roof_view
	floor_choice.text="屋顶" if editor.roof_view else "%d楼"%(editor.editing_storey+1)
	root_ui.find_child("TopDownView",true,false).set_pressed_no_signal(editor.top_down)
	root_ui.find_child("GenerateUpperFloor",true,false).disabled=editor.editing_storey>=preload("res://scripts/building/storeys.gd").MAX-1
	var upper: bool=editor.tool=="upper_floor"
	upper_floor_actions.visible=upper;upper_floor_confirm.disabled=not editor.upper_floor_locked or not editor.upper_floor_plan.get("ok",false)
	var preview_row:=row
	if preview_row.is_empty() and editor.tool in ["template","room","floor","wall","window","door","roof","stairs","railing"]:preview_row={"type":editor.tool,"form":editor.structure_form}
	if preview_row.is_empty() and editor.tool.begins_with("object:"):preview_row={"type":"object","kind":editor.tool.trim_prefix("object:")}
	selected_kind=str(preview_row.get("kind",preview_row.get("type","")))
	selection.text=Catalog.name_for(preview_row) if not preview_row.is_empty() else "选择一件物品"
	selection_hint.text=("已选中半米网格 · 可移动、改色或拆除" if row.get("type","") in ["floor","wall"] else "已选中 · 可移动、旋转或删除") if not row.is_empty() else "选择目录物品，再点击场景放置"
	if editor.tool=="room":selection_hint.text="按住左键拖出四面墙和地板 · 显示尺寸"
	elif editor.tool=="eyedropper":selection.text="吸管复制";selection_hint.text="点击家具或墙地表面，吸取同款和外观"
	if row.is_empty() and preview_row.get("type","")=="object":selection_hint.text="点击放置 · 放置后可分部位编辑外观"
	if preview_row.get("type","")=="object" and Catalog.mount(preview_row)=="wall":selection_hint.text="挂墙 · 自动朝向墙面 · 拖动可调整位置和高度"
	if row.get("kind","")=="dining_table":selection_hint.text="拖动或旋转餐桌时，配套餐椅一起移动"
	elif row.get("kind","")=="dining_chair":selection_hint.text="靠近餐桌空位自动配套 · 可单独拖动"
	if not row.is_empty() and row.get("support","")!="":selection_hint.text=("%d楼天花板"%(editor.editing_storey+1)) if str(row.support).begins_with("ceiling:") else "依附于 "+Catalog.name_for(preload("res://scripts/building/layout.gd").find(editor.layout,row.support))
	if row.get("type","")=="object" and Catalog.mount(row)=="wall":selection_hint.text="挂墙 · 高度%.2f米 · 拖动调整位置和高度"%preload("res://scripts/building/wall_mount.gd").height(row)
	selected_thumb_key=studio.variant_key(preview_row) if preview_row.get("type","")=="object" else (selected_kind+":"+Structures.form(preview_row) if selected_kind in Structures.FORMS or selected_kind=="stairs" else selected_kind)
	if selected_kind=="template":
		selected_thumb_key="template:"+editor.template_kind
		selection.text=preload("res://scripts/building/templates.gd").SAMPLE_NAMES.get(editor.template_kind,"整栋样板房")
	if upper:
		selected_kind="";selected_thumb_key="";selection.text="按本层生成上层楼板";selection_hint.text="室内按相连房间选取 · 点击地板选定范围，再确认铺设"
	selected_preview.texture=studio.cache.get(selected_thumb_key)
	if selected_kind!="":
		if preview_row.get("type","")=="object":studio.request_variant(preview_row)
		else:studio.request(selected_thumb_key)
	var furniture: bool=row.get("type","")=="object";paint_row.visible=not upper and not furniture and preview_row.get("type","")!="object";appearance_button.visible=furniture;batch_paint.visible=row.get("type","") in ["floor","wall"];wall_face.visible=row.get("type","")=="wall"
	if appearance_panel.visible:
		if row.get("id","")==appearance_panel.target_id:appearance_panel.load_part(false)
		else:appearance_panel.close()
	for button in [apply_button,move_button,delete_button]:button.disabled=row.is_empty()
	rotate_button.disabled=preview_row.get("type","") not in ["object","stairs","template"] or (preview_row.get("type","")=="object" and Catalog.mount(preview_row)=="wall");undo_button.disabled=editor.undo_stack.is_empty();redo_button.disabled=editor.redo_stack.is_empty()
	for id in tools:tools[id].set_pressed_no_signal((editor.tool==id or editor.tool+":"+editor.structure_form==id or (editor.tool=="template" and id=="template:"+editor.template_kind)))
	if not row.is_empty():
		var face: Dictionary=row
		if row.type=="wall" and wall_face.selected!=2:
			var unit: Dictionary=preload("res://scripts/building/layout.gd").unit_at(editor.layout,row.id,preload("res://scripts/building/layout.gd").rect(row).get_center())
			var edit=preload("res://scripts/building/surface_edit.gd");var plan=preload("res://scripts/building/room_plan.gd").make(preload("res://scripts/building/layout.gd").compiled(editor.layout,editor.editing_storey))
			var side: String=edit.inside_side(plan,unit,Vector2(editor.city.camera.global_position.x,editor.city.camera.global_position.z))
			if wall_face.selected==1:side="negative" if side=="positive" else "positive"
			face=Structures.surface(row,side)
		color.color=Color(face.color);style.selected=maxi(0,STYLES.find(face.style))
	var action: String={"template":"整屋跟随鼠标 · R 旋转 · 点击空地放置 · Esc 取消", "upper_floor":"点击本栋地板选定范围 · 确认后生成上层楼板 · Esc 取消", "select":"点击选中物件 · 再选移动、旋转或删除", "delete":"锤子：按起点类型拆除 · 按住拖动，松开确认 · Esc取消", "wall":"点击墙的起点和终点 · 放置后可分别装修内外墙面", "floor":"点击地板矩形的两个角", "roof":"点击屋顶矩形的两个角", "door":"点击墙面安装门", "window":"点击墙面安装窗户", "stairs":"首座楼梯按本栋轮廓补上层楼板 · 开洞和护栏同步 · R旋转", "railing":"点击护栏起点和终点", "move":"点击新位置完成移动 · Esc 取消"}.get(editor.tool,"点击放置 · R 旋转 · 台灯与摆件自动吸附台面")
	if editor.tool=="room":action="按住左键拖出房间 · 松开建造 · T俯视 · Esc取消"
	elif editor.tool=="eyedropper":action="点击家具复制同款，或吸取墙地材质 · Esc取消"
	elif editor.tool=="select":action="点击选中 · 拖动物件移动 · 拖动完整房间的墙调整大小 · G移动 / R旋转"
	if editor.tool.begins_with("object:") and Catalog.mount({"kind":editor.tool.trim_prefix("object:")})=="wall":action="点击墙面放置 · 随鼠标调整高度 · 自动朝向 · Esc取消"
	help.text=action+"   |   右键转动 · WASD / Shift+右键平移 · 滚轮缩放";updating=false
func message(text_: String,error: bool=false) -> void:status.text=text_;status.modulate=Color("a65445") if error else Color("426e5c")

func show_templates() -> void:
	category="样板房";form_family="template";breadcrumb.show();breadcrumb_label.text="整栋样板房 · 选择后点击空地放置"
	for id in cards:
		cards[id].visible=cards[id].get_meta("category")=="样板房"
		if cards[id].visible:studio.request(id)
	for name_ in tabs:tabs[name_].set_pressed_no_signal(false)
	catalog_area.scroll_vertical=0;resize_grid()

func pointer_over_ui(point_: Vector2) -> bool:
	for panel in [root_ui.get_node("BuildDock"),appearance_panel]:
		if panel.is_visible_in_tree() and panel.get_global_rect().has_point(point_):return true
	var hovered:=get_viewport().gui_get_hovered_control()
	return hovered!=null and root_ui.is_ancestor_of(hovered) and hovered.get_global_rect().has_point(point_)
func scroll_at(point_: Vector2) -> ScrollContainer:
	var control: Node=get_viewport().gui_get_hovered_control()
	while control!=null and control!=root_ui:
		if control is ScrollContainer and control.is_visible_in_tree() and control.get_global_rect().has_point(point_):return control
		control=control.get_parent()
	if catalog_area.is_visible_in_tree() and catalog_area.get_global_rect().has_point(point_):return catalog_area
	return null
func route_scroll(event: InputEvent) -> bool:
	if not preload("res://scripts/services/camera_zoom.gd").accepts(event):return false
	# Gestures carry their own viewport-local position. The live mouse position or
	# previous GUI hover can differ after Retina resizing or focus changes.
	var point_: Vector2=event.position
	if not pointer_over_ui(point_):return false
	var scroll:=scroll_at(point_)
	if scroll!=null and not event is InputEventMagnifyGesture:
		var amount: float=event.delta.y if event is InputEventPanGesture else (1. if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1.)*(event.factor if is_finite(event.factor) and event.factor>0. else 1.)
		if scroll_owner!=scroll.get_instance_id():scroll_owner=scroll.get_instance_id();scroll_remainder=0.
		var delta:=amount*48.+scroll_remainder;var whole:=roundi(delta);scroll_remainder=delta-whole
		scroll.scroll_vertical+=whole
	return true
