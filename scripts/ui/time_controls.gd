extends VBoxContainer
const UI=preload("res://scripts/ui/ui_kit.gd")
var session: Node
var hours: SpinBox
var minutes: SpinBox
var heading: Label
var feedback: Label
func _ready() -> void:
	name="TestingTimeControls"
	add_theme_constant_override("separation",8)
	if not session.can_adjust_time(): hide();return
	heading=UI.label("",17);add_child(heading)
	var row:=UI.row(10);add_child(row)
	hours=field(23);hours.name="Hours";row.add_child(hours)
	row.add_child(UI.label(":",22))
	minutes=field(59);minutes.name="Minutes";row.add_child(minutes)
	var now: int=int(floor(fposmod(float(session.state().time),3600.0)*1440.0/3600.0+.00001))
	hours.value=now/60;minutes.value=now%60
	var apply_button:=UI.button("调到此刻",apply_selected,true);apply_button.name="ApplyTime";row.add_child(apply_button)
	var presets:=UI.row(6);add_child(presets)
	for entry in [["清晨 06:00",6],["正午 12:00",12],["黄昏 18:00",18],["夜晚 22:00",22]]:
		var hour: int=entry[1]
		var button:=UI.button(entry[0],func(): apply_time(hour,0))
		button.name="Time%02d"%hour;button.add_theme_font_size_override("font_size",14)
		presets.add_child(button)
	feedback=UI.label("只调当天时刻，不快进作物或工作。",14,UI.MUTED);add_child(feedback)
	session.changed.connect(refresh)
	refresh()
func field(maximum: int) -> SpinBox:
	var spin:=SpinBox.new();spin.min_value=0;spin.max_value=maximum;spin.step=1
	spin.custom_minimum_size=Vector2(84,44)
	var edit:=spin.get_line_edit();edit.alignment=HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_stylebox_override("normal",UI.box(Color("ebefdb"),12,9))
	edit.add_theme_stylebox_override("focus",UI.box(Color("d9e8ce"),12,9))
	edit.add_theme_color_override("font_color",UI.INK)
	return spin
func refresh() -> void:
	visible=session.can_adjust_time()
	var time: float=session.state().time
	var moment: int=int(floor(fposmod(time,3600.0)*1440.0/3600.0+.00001))
	heading.text="当天时间 · 单人测试     第 %d 天 %02d:%02d"%[int(floor(time/3600))+1,moment/60,moment%60]
func apply_selected() -> void:
	# Only commit a field actively being edited. Applying an unfocused field can
	# read its old LineEdit text before a programmatic SpinBox update is drawn.
	if hours.get_line_edit().has_focus(): hours.apply()
	if minutes.get_line_edit().has_focus(): minutes.apply()
	apply_time(int(hours.value),int(minutes.value))
func apply_time(hour: int,minute: int) -> void:
	var result: Dictionary=session.set_testing_time(hour,minute)
	feedback.text=result.message
	if result.ok:
		hours.value=hour;minutes.value=minute
		refresh()
