extends VBoxContainer
## Recent server-wide messages are held only in the current online session.
const UI = preload("res://scripts/ui/ui_kit.gd")
const FADE_MS := 1800.
var session: Node
var feed: PanelContainer
var lines: VBoxContainer
var composer: PanelContainer
var input: LineEdit
var font: Font
var expires: Array[int] = []

func setup(owner_session: Node) -> void:
	session = owner_session
	name = "WorldChat"
	anchor_top = .30
	anchor_bottom = 1.
	offset_left = 24
	offset_bottom = -109
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",5)
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji"])
	font = load("res://assets/fonts/NotoSansSC.ttf").duplicate()
	font.fallbacks = [emoji]

	feed = UI.panel(Color("fffaed",.95),16,12)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed)
	var column := UI.column(6)
	feed.add_child(column)
	var heading := UI.row(8)
	column.add_child(heading)
	var channel := UI.label("世界聊天",14,UI.GREEN)
	channel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(channel)
	var shortcut := UI.label("Enter 发言",12,UI.MUTED)
	heading.add_child(shortcut)
	lines = UI.column(4)
	column.add_child(lines)
	for control in feed.find_children("*","Control",true,false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed.hide()

	composer = UI.panel(UI.CREAM,14,7)
	add_child(composer)
	input = LineEdit.new()
	input.placeholder_text = "向全服说句话…"
	input.max_length = 120
	input.add_theme_font_override("font",font)
	input.add_theme_font_size_override("font_size",16)
	input.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	var row := UI.row(6)
	composer.add_child(row)
	row.add_child(UI.label("世界",14,UI.GREEN))
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	row.add_child(UI.label("↵ 发送",12,UI.MUTED))
	composer.hide()
	composer.visibility_changed.connect(func():shortcut.visible = not composer.visible)
	resize_chat()
	get_parent().resized.connect(resize_chat)
	session.prune_chat(Time.get_ticks_msec())
	for entry in session.recent_chat:add_line(entry)
	session.world_chat_received.connect(add_line)

func resize_chat() -> void:
	offset_right = offset_left+clampf(get_parent().size.x*.29,255.,390.)

func add_line(entry: Dictionary) -> void:
	if expires.size()>=session.CHAT_LIMIT:remove_oldest()
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font",font)
	label.add_theme_font_size_override("normal_font_size",16)
	label.add_theme_constant_override("line_separation",2)
	label.push_color(Color("8d5a35") if entry.id==session.active_character_id else Color("396b55"))
	label.add_text(str(entry.name)+"　")
	label.pop()
	label.push_color(UI.INK)
	label.add_text(str(entry.text))
	label.pop()
	lines.add_child(label)
	expires.append(entry.expires)
	feed.show()
	feed.modulate.a = 1.

func remove_oldest() -> void:
	var first := lines.get_child(0)
	lines.remove_child(first)
	first.queue_free()
	expires.pop_front()

func _process(_delta: float) -> void:
	if expires.is_empty():return
	var now := Time.get_ticks_msec()
	while not expires.is_empty() and expires.front()<=now:remove_oldest()
	session.prune_chat(now)
	feed.visible = not expires.is_empty()
	if expires.is_empty():return
	# Let the newest full message fit. Older rows yield on a burst of long text.
	var newest := expires.size()-1
	var height_left := maxf(135.,get_parent().size.y*.28)
	var fits := true
	for i in range(newest,-1,-1):
		var line: RichTextLabel = lines.get_child(i)
		height_left -= line.get_combined_minimum_size().y+4.
		fits = fits and (i==newest or height_left>=0.)
		line.visible = fits
		line.modulate.a = clampf((expires[i]-now)/FADE_MS,0.,1.)
	feed.modulate.a = clampf((expires.back()-now)/FADE_MS,0.,1.)
