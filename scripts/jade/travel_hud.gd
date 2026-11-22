extends RefCounted
## Keep the walking lane visible while retaining the ordinary mouse and keyboard controls.
const UI=preload("res://scripts/ui/ui_kit.gd")
static func arrange(bar: PanelContainer,buttons: HBoxContainer) -> void:
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bar.custom_minimum_size=Vector2(528,46)
	bar.offset_right=-22.;bar.offset_bottom=-17.
	bar.offset_left=bar.offset_right-528.;bar.offset_top=bar.offset_bottom-46.
	var lacquer:=UI.box(Color("273932db"),5,3)
	lacquer.border_width_top=1;lacquer.border_color=Color("ceb98a")
	lacquer.shadow_size=3;lacquer.shadow_offset=Vector2(0,2)
	bar.add_theme_stylebox_override("panel",lacquer)
	buttons.add_theme_constant_override("separation",1)
	var clear:=StyleBoxEmpty.new()
	var hover:=UI.box(Color("55685c"),4,2);hover.shadow_size=0
	var press:=UI.box(Color("6c5440"),4,2);press.shadow_size=0
	var focus:=hover.duplicate() as StyleBoxFlat
	focus.draw_center=false;focus.set_border_width_all(1);focus.border_color=Color("eed9a0")
	for item: Button in buttons.get_children():
		item.custom_minimum_size=Vector2(75,39)
		item.add_theme_font_size_override("font_size",16)
		item.add_theme_stylebox_override("normal",clear);item.add_theme_stylebox_override("disabled",clear)
		item.add_theme_stylebox_override("hover",hover);item.add_theme_stylebox_override("pressed",press);item.add_theme_stylebox_override("focus",focus)
		for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
			item.add_theme_color_override(state,Color("fff2d7"))
		item.add_theme_color_override("font_disabled_color",Color("c0bfb2"))
