extends Node
## Rendering policy is independent of simulation time and transport.
const UI=preload("res://scripts/ui/ui_kit.gd")
const BACKGROUND_FPS=20
var background:=false
var session: Node
static func ensure(context: Node) -> void:
	var root:=context.get_tree().root
	if root.has_meta("frame_pacer"): return
	root.set_meta("frame_pacer",true)
	var pacer=load("res://scripts/city/frame_pacer.gd").new();pacer.name="FramePacer"
	root.add_child.call_deferred(pacer)
static func add_controls(parent: Control,owner_: Node) -> void:
	var row:=UI.row(12);parent.add_child(row)
	var enabled:=CheckButton.new();enabled.name="FrameLimitEnabled";enabled.text="限制帧率"
	enabled.button_pressed=owner_.settings.get("fps_limit_enabled",true)
	enabled.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(enabled)
	var rate:=OptionButton.new();rate.name="FrameLimitRate";rate.custom_minimum_size=Vector2(160,44)
	for fps in [60,90,120]: rate.add_item(str(fps)+" FPS",fps)
	rate.select(maxi(0,[60,90,120].find(int(owner_.settings.get("fps_limit",60)))))
	rate.disabled=not enabled.button_pressed
	for state in ["normal","hover","pressed"]: rate.add_theme_stylebox_override(state,UI.box(Color("e2e9d2"),14,10))
	for state in ["font_color","font_hover_color","font_pressed_color"]: rate.add_theme_color_override(state,UI.INK)
	rate.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	rate.add_theme_stylebox_override("disabled",UI.box(Color("e8e6d8"),14,10));rate.add_theme_color_override("font_disabled_color",UI.MUTED)
	var popup:=rate.get_popup();popup.add_theme_stylebox_override("panel",UI.box(UI.CREAM,16,12));popup.add_theme_stylebox_override("hover",UI.box(UI.GREEN,10,8))
	popup.add_theme_color_override("font_color",UI.INK);popup.add_theme_color_override("font_hover_color",UI.CREAM)
	row.add_child(rate)
	enabled.toggled.connect(func(v): rate.disabled=not v;owner_.set_setting("fps_limit_enabled",v))
	rate.item_selected.connect(func(index): owner_.set_setting("fps_limit",rate.get_item_id(index)))
	var idle:=CheckButton.new();idle.name="BackgroundThrottle";idle.text="后台降低帧率"
	idle.tooltip_text="切到其他应用时以 20 FPS 绘制，游戏时间照常流动。"
	idle.button_pressed=owner_.settings.get("background_throttle",true)
	idle.toggled.connect(func(v): owner_.set_setting("background_throttle",v));parent.add_child(idle)
func _ready() -> void:
	session=get_node("/root/Session")
	session.settings_changed.connect(func(_key): apply())
	apply()
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: set_background(true)
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: set_background(false)
func set_background(value: bool) -> void:
	background=value;apply()
func desired_fps() -> int:
	if not is_instance_valid(session): return 60
	var cap:=int(session.settings.get("fps_limit",60)) if session.settings.get("fps_limit_enabled",true) else 0
	if background and session.settings.get("background_throttle",true): return mini(cap,BACKGROUND_FPS) if cap>0 else BACKGROUND_FPS
	return cap
func apply() -> void:
	if not is_instance_valid(session): return
	# QA runners own their explicit cap; ordinary game settings never uncap them.
	if session.test_mode and not OS.get_cmdline_user_args().has("--frame-policy-test"): return
	Engine.max_fps=desired_fps()
