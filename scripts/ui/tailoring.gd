extends RefCounted
const UI=preload("res://scripts/ui/ui_kit.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Materials=preload("res://scripts/appearance/material_catalog.gd")
const Fabric=preload("res://scripts/appearance/fabric_material.gd")
const Preview=preload("res://scripts/ui/character_preview.gd")
const SWATCHES=["eadcc0","dfae7a","c67978","a891b4","78a7ad","719684","435e75","48424d"]

var hud: CanvasLayer
var items: Array[String]=[]
var garment_buttons: Array[Button]=[]
var portraits: SubViewport
var chosen: String
var options: Array[String]
var preview: SubViewportContainer
var material: OptionButton
var base_dye: ColorPickerButton
var pattern_dye: ColorPickerButton
var pattern_row: VBoxContainer
var swatch: ColorRect
var apply: Button
var reset: Button
var status: Label
var pending:=false

func build(hud_: CanvasLayer) -> void:
	hud=hud_
	var state: Dictionary=hud.session.state()
	for id in state.inventory:
		if int(state.inventory[id])>0 and DB.item(id).get("kind","")=="clothing":items.append(id)
	items.sort_custom(func(a,b):return DB.item(a).name<DB.item(b).name)
	if items.is_empty():
		hud.content.add_child(UI.label("衣架还是空的。带一件口袋里的衣服再来。",19,UI.MUTED))
		return
	var layout:=UI.row(26);hud.content.add_child(layout)
	preview=Preview.new();preview.preview_size=Vector2i(354,460);preview.display_size=Vector2(354,460);layout.add_child(preview)
	var tools:=UI.column(12);tools.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layout.add_child(tools)
	build_garments(tools,state)
	options=Materials.choices("fabric","clothing")
	tools.add_child(UI.label("纹样",15,UI.MUTED));material=choose_field(tools,"TailorPattern")
	for id in options:material.add_item(Materials.label(id))
	material.item_selected.connect(func(_index):repaint())
	swatch=ColorRect.new();swatch.name="FabricSwatch";swatch.custom_minimum_size=Vector2(0,92)
	var shader:=Shader.new();shader.code="""
shader_type canvas_item;
uniform vec4 base_dye : source_color;
uniform vec4 pattern_dye : source_color;
uniform sampler2D ink : repeat_enable, filter_linear;
uniform bool patterned;
void fragment() {
	float mask = patterned ? texture(ink, UV * vec2(4.0, 1.0)).r * 0.78 : 0.0;
	COLOR = mix(base_dye, pattern_dye, mask);
}
"""
	var finish:=ShaderMaterial.new();finish.shader=shader;swatch.material=finish
	tools.add_child(swatch)
	var dyes:=UI.row(12);tools.add_child(dyes)
	var base_row:=UI.column(5);dyes.add_child(base_row);base_row.add_child(UI.label("布料底色 · RGB",15,UI.MUTED));base_dye=dye_button(base_row,"TailorColor")
	pattern_row=UI.column(5);dyes.add_child(pattern_row);pattern_row.add_child(UI.label("花纹颜色 · RGB",15,UI.MUTED));pattern_dye=dye_button(pattern_row,"TailorAccent")
	var chips:=UI.row(5);tools.add_child(chips)
	for hex in SWATCHES:
		var chip:=Button.new();chip.custom_minimum_size=Vector2(33,33);chip.tooltip_text="#"+hex
		for role in ["normal","hover","pressed"]:chip.add_theme_stylebox_override(role,UI.box(Color(hex).lightened(.12 if role=="hover" else 0.),9,0))
		chip.pressed.connect(func():base_dye.color=Color(hex);repaint())
		chips.add_child(chip)
	var buttons:=UI.row(10);tools.add_child(buttons)
	apply=UI.button("染好这件",func():save_design(false),true);apply.name="ApplyClothingDesign";buttons.add_child(apply)
	reset=UI.button("还原原样",func():save_design(true));buttons.add_child(reset)
	status=UI.label("拖动角色可以转身照镜子",14,UI.MUTED);tools.add_child(status)
	var selected:=0
	for id in state.equipment.values():
		if id in items:selected=items.find(id);break
	select_item(selected)
	var scroll:=tools.find_child("TailorGarment",true,false) as ScrollContainer
	scroll.ensure_control_visible.call_deferred(garment_buttons[selected])

func build_garments(parent: Control,state: Dictionary) -> void:
	var frame:=UI.panel(Color("f0efd9"),12,6)
	parent.add_child(frame)
	var scroll:=ScrollContainer.new()
	scroll.name="TailorGarment"
	scroll.custom_minimum_size.y=146
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	frame.add_child(scroll)
	var grid:=HFlowContainer.new()
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	portraits=preload("res://scripts/ui/garment_thumbnails.gd").new()
	portraits.species=state.species
	frame.add_child(portraits)
	var group:=ButtonGroup.new()
	for index in range(items.size()):
		var id:=items[index]
		var item:=DB.item(id)
		var button:=Button.new()
		button.custom_minimum_size=Vector2(68,68)
		button.toggle_mode=true
		button.button_group=group
		button.tooltip_text=item.name
		button.accessibility_name=item.name
		button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for role in ["normal","hover","pressed","hover_pressed"]:
			var selected: bool=role in ["pressed","hover_pressed"]
			var style:=UI.box(Color("dcebcf") if role!="normal" else UI.CREAM,10,0)
			style.shadow_size=0
			style.set_border_width_all(3 if selected else 1)
			style.border_color=UI.GREEN if selected else Color("d5d9c3")
			button.add_theme_stylebox_override(role,style)
		grid.add_child(button)
		var icon:=TextureRect.new()
		icon.name="GarmentPicture"
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left=5
		icon.offset_top=5
		icon.offset_right=-5
		icon.offset_bottom=-5
		portraits.request(id,state.get("clothing_designs",{}).get(id,{}),icon)
		button.pressed.connect(select_item.bind(index))
		garment_buttons.append(button)

func choose_field(parent: Control,id: String) -> OptionButton:
	var field:=OptionButton.new()
	field.name=id
	field.custom_minimum_size.y=36
	for role in ["normal","hover","pressed"]:
		field.add_theme_stylebox_override(role,UI.box(Color("dbe7ca") if role=="hover" else Color("edf0dd"),9,8))
	for role in ["font_color","font_hover_color","font_pressed_color"]:
		field.add_theme_color_override(role,UI.INK)
	parent.add_child(field)
	return field

func dye_button(parent: Control,id: String) -> ColorPickerButton:
	var button:=ColorPickerButton.new()
	button.name=id
	button.edit_alpha=false
	button.custom_minimum_size=Vector2(116,36)
	parent.add_child(button)
	var picker:=button.get_picker()
	picker.color_mode=ColorPicker.MODE_RGB
	picker.sliders_visible=true
	picker.hex_visible=true
	button.color_changed.connect(func(_value):repaint())
	return button

func select_item(index: int) -> void:
	chosen=items[index]
	garment_buttons[index].set_pressed_no_signal(true)
	var saved: Dictionary=hud.session.state().get("clothing_designs",{}).get(chosen,{})
	var defaults:=DB.item(chosen)
	base_dye.color=Color(saved.get("color",defaults.get("color","eadcc0")))
	pattern_dye.color=Color(saved.get("accent",defaults.get("accent","f7e5bc")))
	material.select(maxi(0,options.find(saved.get("pattern",defaults.get("pattern","solid")))))
	repaint()

func design() -> Dictionary:
	return {"color":base_dye.color.to_html(false),"accent":pattern_dye.color.to_html(false),"pattern":options[material.selected]}

func repaint() -> void:
	var selected:=design()
	var state: Dictionary=hud.session.state()
	var looks: Dictionary=state.get("clothing_designs",{}).duplicate()
	looks[chosen]=selected
	var worn: Dictionary=state.equipment.duplicate()
	worn[DB.item(chosen).slot]=chosen
	preview.update_character(state.species,worn,looks)
	var mask:=Fabric.texture(selected.pattern)
	var finish:=swatch.material as ShaderMaterial
	finish.set_shader_parameter("base_dye",base_dye.color)
	finish.set_shader_parameter("pattern_dye",pattern_dye.color)
	finish.set_shader_parameter("patterned",mask!=null)
	if mask!=null:finish.set_shader_parameter("ink",mask)
	pattern_row.visible=mask!=null
	apply.disabled=pending;reset.disabled=pending or not state.get("clothing_designs",{}).has(chosen)

func save_design(restore: bool) -> void:
	if pending:return
	pending=true;apply.disabled=true;reset.disabled=true
	var current:=chosen
	var args:={"target":hud.activity_target,"item":current,"restore":restore,"design":design()}
	var result: Dictionary
	if hud.session.is_online():result=await hud.session.request_online("tailor",args)
	else:
		hud.session.set_player_position(hud.city.bunny.global_position)
		result=hud.session.dispatch("tailor",args)
	if not is_instance_valid(status) or not is_instance_valid(portraits) or not portraits.is_inside_tree():return
	pending=false;status.text=str(result.get("message",""))
	if result.ok:
		var icon: TextureRect=garment_buttons[items.find(current)].get_node("GarmentPicture")
		portraits.request(current,hud.session.state().get("clothing_designs",{}).get(current,{}),icon)
	if restore and result.ok and current==chosen:select_item(items.find(current))
	else:
		apply.disabled=false;reset.disabled=not hud.session.state().get("clothing_designs",{}).has(chosen)
