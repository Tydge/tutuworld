extends HBoxContainer
const UI=preload("res://scripts/ui/ui_kit.gd")
const Stats=preload("res://scripts/services/character_stats.gd")
const Preview=preload("res://scripts/ui/character_preview.gd")
const Icon=preload("res://scripts/ui/item_icon.gd")
const DB=preload("res://scripts/services/game_data.gd")
var session: Node
var character_name: Label
var experience: Label
var values: Dictionary={}
var skill_controls: Dictionary={}
var attribute_lines: Dictionary={}
var clock:=0.0
var pages: TabContainer
var preview: Control
var portrait: PanelContainer
func _ready() -> void:
	add_theme_constant_override("separation",22)
	portrait=UI.panel(Color("e9edda"),26,14)
	portrait.custom_minimum_size=Vector2(328,450)
	add_child(portrait)
	var left:=UI.column(8)
	portrait.add_child(left)
	preview=Preview.new()
	preview.preview_size=Vector2i(300,374)
	preview.species=session.settings.player_species
	preview.equipment=session.state().equipment.duplicate()
	left.add_child(preview)
	character_name=UI.label("",22)
	character_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(character_name)
	experience=UI.label("",20,Color("a28043"))
	experience.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(experience)
	var right:=UI.column(10)
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(right)
	pages=TabContainer.new()
	pages.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pages.size_flags_vertical=Control.SIZE_EXPAND_FILL
	pages.add_theme_stylebox_override("panel",UI.box(Color("f1f0de"),20,18))
	pages.add_theme_stylebox_override("tab_selected",UI.box(Color("dce6cd"),14,12))
	pages.add_theme_stylebox_override("tab_unselected",UI.box(Color("efeeda"),14,12))
	pages.add_theme_stylebox_override("tab_hovered",UI.box(Color("e0e9d2"),14,12))
	pages.add_theme_stylebox_override("tab_focus",StyleBoxEmpty.new())
	pages.add_theme_stylebox_override("tab_disabled",UI.box(Color("efeeda"),14,12))
	pages.add_theme_color_override("font_hovered_color",UI.INK)
	pages.add_theme_color_override("font_selected_color",UI.INK)
	pages.add_theme_color_override("font_unselected_color",UI.MUTED)
	right.add_child(pages)
	var stats:=UI.column(10)
	stats.name="属性"
	pages.add_child(stats)
	for row in Stats.ROWS:
		var line:=UI.row(14)
		stats.add_child(line)
		var name_:=UI.label(row[1],17)
		name_.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(name_)
		var number:=UI.label("+0%",17)
		line.add_child(number)
		values[row[0]]=number
		attribute_lines[row[0]]={"line":line,"name":name_}
	var skills:=UI.column(10)
	skills.name="技能"
	pages.add_child(skills)
	for skill in Stats.SKILLS:
		var card:=UI.panel(Color("e7ead6"),16,10)
		skills.add_child(card)
		var line:=UI.row(12)
		card.add_child(line)
		var icon:=Icon.new()
		icon.item_id=skill[2]
		icon.definition=DB.item(skill[2])
		line.add_child(icon)
		var detail:=UI.column(5)
		detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(detail)
		var title_row:=UI.row(8)
		detail.add_child(title_row)
		var title:=UI.label(skill[1],17)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var xp:=UI.label("0 / 100",12,UI.MUTED)
		title_row.add_child(xp)
		var progress:=ProgressBar.new()
		progress.custom_minimum_size.y=7
		progress.show_percentage=false
		progress.add_theme_stylebox_override("background",UI.box(Color("d8dfc9"),4,0))
		progress.add_theme_stylebox_override("fill",UI.box(Color("81ae98"),4,0))
		detail.add_child(progress)
		var level:=UI.label("Lv.1",17,UI.MUTED)
		level.set_meta("skill",skill[0])
		line.add_child(level)
		skill_controls[skill[0]]={"level":level,"xp":xp,"progress":progress}
		var description: String=Stats.skill_description(skill[0])
		card.tooltip_text=description
		for node in card.find_children("*","Control",true,false): node.tooltip_text=description
	refresh()
func restore_portrait() -> void:
	if not is_instance_valid(portrait) or portrait.get_parent()==self: return
	portrait.reparent(self)
	move_child(portrait,0)
func refresh() -> void:
	character_name.text=session.authority.actor_name()
	experience.text="经验  %d"%int(session.state().experience)
	for key in values:
		var percent:=roundi(session.authority.bonus(key)*100)
		values[key].text=("+" if percent>=0 else "")+str(percent)+"%"
		values[key].add_theme_color_override("font_color",UI.GREEN if percent>0 else UI.MUTED)
		var sources: Array=session.authority.bonus_sources(key)
		var lines := PackedStringArray()
		for source in sources: lines.append("%s  %s%d%%"%[source.name,"+" if float(source.value)>=0 else "",roundi(float(source.value)*100)])
		var tip := "\n".join(lines) if not lines.is_empty() else "暂无额外加成"
		values[key].tooltip_text=tip
		attribute_lines[key].line.tooltip_text=tip
		attribute_lines[key].name.tooltip_text=tip
	for key in skill_controls:
		var controls: Dictionary=skill_controls[key]
		var progress: Dictionary=Stats.skill_progress(int(session.state().get("skill_experience",{}).get(key,0)))
		controls.level.text="Lv.%d"%progress.level
		controls.xp.text="已满级" if progress.level==Stats.MAX_LEVEL else "%d / %d"%[progress.current,progress.required]
		controls.progress.max_value=maxi(1,progress.required)
		controls.progress.value=1 if progress.level==Stats.MAX_LEVEL else progress.current
func _process(delta: float) -> void:
	clock+=delta
	if clock>.25:
		clock=0
		refresh()
