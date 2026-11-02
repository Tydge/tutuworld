extends Control
signal authenticated
signal closed
const UI=preload("res://scripts/ui/ui_kit.gd")
var session: Node
var username: LineEdit
var password: LineEdit
var confirmation: LineEdit
var feedback: Label
var primary: Button
var switch_button: Button
var card: PanelContainer
var registering:=false
var busy:=false
var endpoint:=preload("res://scripts/services/release.gd").WORLD_URL
func _ready() -> void:
	theme=UI.theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.color=Color("294b40",.5);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	card=UI.panel(UI.CREAM,28,32);card.custom_minimum_size=Vector2(490,440);add_child(card)
	var col:=UI.column(15);card.add_child(col)
	var header:=UI.row();col.add_child(header)
	var heading:=UI.label("一起去岛上",28);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
	header.add_child(UI.button("返回",go_back))
	username=field("账号",false);col.add_child(username)
	password=field("密码（至少8位）",true);col.add_child(password)
	confirmation=field("再输入一次密码",true);col.add_child(confirmation);confirmation.hide()
	feedback=UI.label("",15,UI.MUTED);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.custom_minimum_size=Vector2(420,45);col.add_child(feedback)
	primary=UI.button("登录",submit,true);col.add_child(primary)
	switch_button=UI.button("还没有账号？注册",toggle_mode);col.add_child(switch_button)
	password.text_submitted.connect(func(_text):submit())
	confirmation.text_submitted.connect(func(_text):submit())
	hide()
func field(placeholder: String,secret: bool) -> LineEdit:
	var input:=LineEdit.new();input.placeholder_text=placeholder;input.secret=secret;input.max_length=72;input.custom_minimum_size=Vector2(420,48)
	input.add_theme_stylebox_override("normal",UI.box(Color("e9eddf"),14,12));input.add_theme_color_override("font_color",UI.INK)
	return input
func _process(_delta: float) -> void:card.position=(get_viewport_rect().size-card.size)*.5
func open() -> void:
	session.ensure_remote();username.text=session.online_username;feedback.text="";show();username.grab_focus()
	if session.online_token!="" and not session.is_online():resume()
func toggle_mode() -> void:
	if busy:return
	registering=not registering;confirmation.visible=registering
	primary.text="注册并登录" if registering else "登录"
	switch_button.text="已有账号？登录" if registering else "还没有账号？注册"
	feedback.text=""
func set_busy(value: bool) -> void:
	busy=value;primary.disabled=value;switch_button.disabled=value
func submit() -> void:
	if busy:return
	if registering and password.text!=confirmation.text:feedback.text="两次输入的密码不一样。";return
	set_busy(true);feedback.text="海风正在把消息送过去…"
	var result: Dictionary=await session.login_online("register" if registering else "login",{"username":username.text,"password":password.text},endpoint)
	set_busy(false)
	if result.get("ok",false):password.text="";confirmation.text="";hide();authenticated.emit()
	else:feedback.text=str(result.get("message","暂时没有连上，再试一次吧。"))
func resume() -> void:
	set_busy(true);feedback.text="正在接上上次的旅程…"
	var result: Dictionary=await session.login_online("resume",{"token":session.online_token},endpoint)
	set_busy(false)
	if result.get("ok",false):hide();authenticated.emit()
	else:feedback.text=str(result.get("message","请重新登录。"))
func go_back() -> void:
	if busy:return
	password.text="";confirmation.text="";hide();closed.emit()
