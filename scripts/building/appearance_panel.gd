extends PanelContainer
const UI=preload("res://scripts/ui/ui_kit.gd")
const A=preload("res://scripts/building/appearance.gd")
var editor: Node
var target_id:=""
var slot:=""
var parts: OptionButton
var materials: OptionButton
var color: ColorPickerButton
var accent: ColorPickerButton
var accent_box: VBoxContainer
var accent_label: Label
var color_label: Label
var material_ids: Array=[]
var slot_ids: Array=[]
var updating:=false
func _ready() -> void:
	name="FurnitureAppearancePanel";set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);offset_left=-392;offset_right=-26;offset_top=-712;offset_bottom=-292;custom_minimum_size=Vector2(366,420);add_theme_stylebox_override("panel",UI.box(UI.CREAM,16,14))
	var column:=UI.column(9);add_child(column);var header:=UI.row(7);column.add_child(header);var title:=UI.label("家具外观 · 分部位编辑",17);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title);var close_button:=UI.button("关闭",close);close_button.name="CloseFurnitureAppearance";header.add_child(close_button)
	column.add_child(UI.label("部位",13,UI.MUTED));parts=OptionButton.new();parts.name="AppearancePart";column.add_child(parts);parts.item_selected.connect(func(index):slot=slot_ids[index];load_part())
	var row:=UI.row(8);column.add_child(row)
	var base_box:=UI.column(4);row.add_child(base_box);color_label=UI.label("颜色",12,UI.MUTED);base_box.add_child(color_label)
	color=ColorPickerButton.new();color.name="PartColor";color.edit_alpha=false;color.custom_minimum_size=Vector2(50,34);base_box.add_child(color)
	accent_box=UI.column(4);row.add_child(accent_box);accent_label=UI.label("花纹色",12,UI.MUTED);accent_box.add_child(accent_label)
	accent=ColorPickerButton.new();accent.name="PartPatternColor";accent.edit_alpha=false;accent.custom_minimum_size=Vector2(50,34);accent_box.add_child(accent)
	var material_box:=UI.column(4);material_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(material_box);material_box.add_child(UI.label("材质 / 纹理",12,UI.MUTED))
	materials=OptionButton.new();materials.name="PartMaterial";materials.size_flags_horizontal=Control.SIZE_EXPAND_FILL;material_box.add_child(materials)
	color.color_changed.connect(func(_value):preview());accent.color_changed.connect(func(_value):preview());materials.item_selected.connect(func(_index):update_channels();preview())
	var actions:=UI.row(7);column.add_child(actions);actions.add_child(UI.button("应用当前部位",apply_part,true));actions.get_child(0).name="ApplyPartAppearance";var reset:=UI.button("恢复该部位",func():editor.reset_appearance(slot));reset.name="ResetAppearancePart";actions.add_child(reset)
	var presets:=OptionButton.new();presets.name="AppearancePreset";presets.add_item("整套配色预设…")
	for id in A.presets():presets.add_item(A.presets()[id].name)
	presets.item_selected.connect(func(index):
		if index>0:editor.apply_appearance_preset(A.presets().keys()[index-1]);presets.select(0))
	for option in [parts,materials,presets]:style_option(option)
	column.add_child(presets);var all:=UI.button("恢复整件原始外观",func():editor.reset_appearance(""));all.name="ResetAllAppearance";column.add_child(all);column.add_child(UI.label("只改变当前部位 · 其他部位保留原样",12,UI.MUTED));hide()
func open(row: Dictionary) -> void:
	target_id=row.id;parts.clear();slot_ids.clear()
	for definition in A.parts(row.kind):parts.add_item(definition.name);slot_ids.append(definition.id)
	if not slot in slot_ids:slot=slot_ids[0]
	parts.select(slot_ids.find(slot));show();load_part()
func load_part(show_hint: bool=true) -> void:
	var row:=preload("res://scripts/building/layout.gd").find(editor.layout,target_id)
	if row.is_empty():close();return
	updating=true;var definition:=A.part(row.kind,slot);var appearance: Dictionary=row.get("appearance",{}).get(slot,{})
	color.color=Color(appearance.get("color",row.color if row.painted and not row.get("appearance",{}).has(slot) else definition.colors[0]));material_ids=A.allowed(definition);materials.clear()
	for id in material_ids:materials.add_item(A.Catalog.label(id))
	materials.select(maxi(0,material_ids.find(appearance.get("material","original"))))
	var info: Dictionary=editor.appearance_channels(slot,material_ids[materials.selected]);accent.color=Color(appearance.get("accent",info.accent.to_html(false)));update_channels();updating=false
	editor.restore_appearance_preview()
	if show_hint:editor.highlight_appearance_part(slot)
	else:editor.clear_highlight()
func preview() -> void:
	if updating or not visible:return
	editor.clear_highlight();editor.preview_appearance(slot,color.color,material_ids[materials.selected],accent.color if accent_box.visible else null)
func update_channels() -> void:
	var info: Dictionary=editor.appearance_channels(slot,material_ids[materials.selected]);accent_box.visible=info.enabled;accent_label.text=info.label;color_label.text="底色" if info.enabled else "颜色"
func apply_part() -> void:editor.paint_appearance(slot,color.color,material_ids[materials.selected],accent.color if accent_box.visible else null)
func close() -> void:
	if not visible:return
	hide();editor.restore_appearance_preview();editor.clear_highlight()

func style_option(option: OptionButton) -> void:
	option.add_theme_font_size_override("font_size",14)
	for state in ["normal","hover","pressed"]:option.add_theme_stylebox_override(state,UI.box(Color("ebefdb"),9,8))
	for state in ["font_color","font_hover_color","font_pressed_color","icon_normal_color"]:option.add_theme_color_override(state,UI.INK)
	option.get_popup().add_theme_stylebox_override("panel",UI.box(UI.CREAM,12,10));option.get_popup().add_theme_stylebox_override("hover",UI.box(Color("d9e8ce"),8,8));option.get_popup().add_theme_color_override("font_color",UI.INK)
