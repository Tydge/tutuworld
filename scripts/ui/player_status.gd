extends PanelContainer
const Animals=preload("res://scripts/characters/animal_catalog.gd")
signal profile_requested
const UI=preload("res://scripts/ui/ui_kit.gd")
var portrait: Control
var meter: Control
var name_label: Label
var experience_label: Label
var stamina_label: Label
var last_species:=""
var last_equipment: Dictionary={}
var last_sleeping:=false
func _ready() -> void:
	custom_minimum_size=Vector2(326,108)
	add_theme_stylebox_override("panel",UI.box(Color("fff8e5",.97),24,12))
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text="查看角色  C"
	var row:=UI.row(12);add_child(row)
	var frame:=UI.panel(Color("d0b87f"),42,3);frame.custom_minimum_size=Vector2(84,84);row.add_child(frame)
	portrait=preload("res://scripts/ui/character_preview.gd").new()
	portrait.head_only=true;portrait.preview_size=Vector2i(168,168);portrait.display_size=Vector2(78,78)
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mask:=ShaderMaterial.new();mask.shader=load("res://assets/shaders/avatar_mask.gdshader");portrait.material=mask
	frame.add_child(portrait)
	var col:=UI.column(3);col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(col)
	name_label=UI.label("",18);col.add_child(name_label)
	experience_label=UI.label("",12,UI.MUTED);col.add_child(experience_label)
	var detail:=UI.row(8);col.add_child(detail)
	detail.add_child(UI.label("耐力",12,Color("648276")))
	stamina_label=UI.label("100 / 100",12,Color("647963"));detail.add_child(stamina_label)
	meter=preload("res://scripts/ui/stamina_meter.gd").new();col.add_child(meter)
func refresh(state: Dictionary,maximum: float) -> void:
	name_label.text=str(state.get("character_name","")).strip_edges()
	if name_label.text=="": name_label.text=Animals.display_name(str(state.get("species","bunny")))
	experience_label.text="经验  %d"%int(state.get("experience",0))
	stamina_label.text="%d / %d"%[int(state.stamina),int(maximum)]
	meter.set_fraction(float(state.stamina)/maximum)
	var species: String=state.get("species","bunny")
	var worn: Dictionary=state.equipment
	if species!=last_species or last_equipment!=worn:
		portrait.update_character(species,worn);last_species=species;last_equipment=worn.duplicate()
	var sleeping: bool=state.get("rest_mode","")=="sleep"
	if sleeping!=last_sleeping:
		portrait.actor.eyes.scale.y=.045 if sleeping else 1.0
		portrait.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		last_sleeping=sleeping
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		profile_requested.emit();accept_event()
