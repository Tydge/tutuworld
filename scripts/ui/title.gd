extends Node3D
const UI=preload("res://scripts/ui/ui_kit.gd")
const Updates=preload("res://scripts/services/update_client.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
var session: Node
var updater: Node
var status: Label
var progress: ProgressBar
var check_button: Button
var download_button: Button
var start_button: Button
var settings_card: Control
var actor: CharacterBody3D
var clock := 0.0
var launching := false
var title_sky: ShaderMaterial
var clouds: Array[Node3D]=[]
var cloud_origins: Array[Vector3]=[]
var characters_ready:=false
var character_menu: Control
var title_camera: Camera3D
var multiplayer_button: Button
var login_panel: Control
var auto_restart_pending:=false
func _ready() -> void:
	preload("res://scripts/city/render_budget.gd").ensure(self)
	session=get_node("/root/Session")
	session.active=false
	var map: Node3D=load("res://scenes/city_map.tscn").instantiate()
	preload("res://scripts/city/scenery_polish.gd").apply(map)
	add_child(map)
	title_sky=map.get_node("Atmosphere").environment.sky.sky_material
	for node in map.get_children():
		if str(node.name).begins_with("Cloud"):
			clouds.append(node)
			cloud_origins.append(node.position)
	for node in map.get_children():
		if str(node.name).begins_with("Tree") and node.position.z>8: node.hide()
	for lamp_ in map.get_node("Streetlights").get_children():
		if lamp_.position.distance_to(Vector3(10,0,20))<8: lamp_.hide()
	actor=preload("res://scripts/characters/animal_factory.gd").create(session.settings.get("player_species","bunny"))
	add_child(actor)
	actor.position=Vector3(7.5,.1,15.5)
	actor.scale=Vector3.ONE*1.22
	actor.visual.rotation.y=.15
	Outfit.apply(actor,session.state().equipment)
	var camera:=Camera3D.new()
	title_camera=camera
	camera.current=true
	camera.fov=42
	add_child(camera)
	camera.position=Vector3(10.5,5.0,25)
	camera.look_at(Vector3(4,1.55,12))
	var canvas:=CanvasLayer.new()
	add_child(canvas)
	var root:=Control.new()
	root.theme=UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	var left:=UI.panel(Color("fff9e9",.95),36,34)
	left.position=Vector2(56,60)
	left.custom_minimum_size=Vector2(472,730)
	root.add_child(left)
	var col:=UI.column(18)
	left.add_child(col)
	col.add_child(UI.label("慢 慢 来 海 岛 城",18,Color("ac935f")))
	var logo:=UI.label("兔兔的世界",56)
	var logo_font:=FontVariation.new()
	logo_font.base_font=load("res://assets/fonts/NotoSansSC-Bold.ttf")
	logo.add_theme_font_override("font",logo_font)
	logo.add_theme_color_override("font_shadow_color",Color("d1c38d",.65))
	logo.add_theme_constant_override("shadow_offset_x",2)
	logo.add_theme_constant_override("shadow_offset_y",3)
	logo.rotation=-.018
	col.add_child(logo)
	col.add_child(UI.label("和喜欢的一切，慢慢相遇。",19,UI.MUTED))
	var space:=Control.new()
	space.custom_minimum_size.y=38
	col.add_child(space)
	start_button=UI.button("开始游戏",start_game,true)
	start_button.custom_minimum_size.y=64
	start_button.add_theme_font_size_override("font_size",23)
	col.add_child(start_button)
	var multi:=UI.button("多人游戏",start_multiplayer)
	multiplayer_button=multi
	multi.custom_minimum_size.y=58
	col.add_child(multi)
	col.add_child(UI.button("设置",func(): settings_card.show(); UI.pop(settings_card)))
	col.add_child(UI.button("退出游戏",func(): session.save_game(); get_tree().quit()))
	var spacer:=Control.new()
	spacer.custom_minimum_size.y=30
	col.add_child(spacer)
	var description:=UI.label("在公园散步，在菜园等一颗小苗。\n去商店挑件新衣，也和邻居聊聊天。\n今天的岛上，也有许多小小的美好。",16,UI.MUTED)
	description.add_theme_constant_override("line_spacing",8)
	col.add_child(description)
	col.add_child(UI.label("海岛城 %s  ·  资源版本 %d"%[preload("res://scripts/services/release.gd").VERSION,session.installed_build],13,Color("a59b81")))
	var update_card:=UI.panel(Color("fff9e9",.96),26,23)
	update_card.anchor_left=1
	update_card.anchor_right=1
	update_card.anchor_top=1
	update_card.anchor_bottom=1
	update_card.position=Vector2(-494,-245)
	update_card.custom_minimum_size=Vector2(438,185)
	root.add_child(update_card)
	var ucol:=UI.column(10)
	update_card.add_child(ucol)
	ucol.add_child(UI.label("海岛邮局 · 游戏更新",19))
	status=UI.label("正在准备…",14,UI.MUTED)
	status.custom_minimum_size=Vector2(385,46)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ucol.add_child(status)
	progress=ProgressBar.new()
	progress.custom_minimum_size.y=9
	progress.show_percentage=false
	progress.hide()
	ucol.add_child(progress)
	var buttons:=UI.row()
	ucol.add_child(buttons)
	check_button=UI.button("检查更新",func(): updater.check_updates())
	check_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	buttons.add_child(check_button)
	download_button=UI.button("下载更新",func():
		if updater.state=="ready": updater.restart()
		elif updater.state=="downloading": updater.cancel_download()
		elif updater.state=="installer": open_installer()
		else: updater.download_update(),true)
	download_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	buttons.add_child(download_button)
	updater=Updates.new()
	updater.current_build=session.installed_build
	add_child(updater)
	updater.status_changed.connect(refresh_update)
	character_menu=preload("res://scripts/ui/character_menu.gd").new()
	character_menu.session=session
	root.add_child(character_menu)
	character_menu.play_requested.connect(launch_character)
	character_menu.closed.connect(func():
		if session.is_online():await session.leave_online()
		refresh_update())
	login_panel=preload("res://scripts/ui/online_login.gd").new();login_panel.session=session;root.add_child(login_panel)
	login_panel.authenticated.connect(func():character_menu.open())
	character_menu.account_switch_requested.connect(func():login_panel.open())
	settings_card=build_settings(root)
	settings_card.hide()
	refresh_update()
	if not session.test_mode: updater.check_updates.call_deferred()
	else: updater.set_status("latest","测试模式 · 本地内容已就绪。")
	await character_menu.preview.warm_models()
	characters_ready=true
	refresh_update()
func _process(delta: float) -> void:
	clock+=delta
	title_sky.set_shader_parameter("drift",clock)
	for i in range(clouds.size()): clouds[i].position=cloud_origins[i]+Vector3(sin(clock*.035+i)*4.5,0,cos(clock*.025+i)*1.0)
	if is_instance_valid(title_camera):
		title_camera.position.x=10.5+sin(clock*.13)*.16
		title_camera.look_at(Vector3(4,1.55,12))
	if is_instance_valid(actor): actor.visual.rotation.y=.10+sin(clock*.25)*.08
func refresh_update() -> void:
	status.text=updater.message
	progress.visible=updater.state=="downloading"
	progress.value=updater.progress*100
	check_button.disabled=updater.state in ["checking","downloading"]
	download_button.disabled=updater.state not in ["available","ready","downloading","installer"]
	download_button.text={"ready":"重启并应用更新","downloading":"取消下载","installer":"下载安装包"}.get(updater.state,"下载更新")
	start_button.disabled=updater.state=="downloading" or launching or not characters_ready
	if not launching: start_button.text="开始游戏" if characters_ready else "正在准备角色…"
	multiplayer_button.disabled=launching or not characters_ready or updater.state=="downloading"
	multiplayer_button.text="多人游戏" if updater.state=="latest" else "多人游戏 · 需最新版本"
	if not session.test_mode and session.settings.get("auto_update",true) and not launching:
		if updater.state=="available":updater.download_update.call_deferred()
		elif updater.state=="ready" and not auto_restart_pending:auto_restart_pending=true;restart_after_update()
func restart_after_update() -> void:
	status.text="更新已就绪，正在重新启程…"
	await get_tree().create_timer(2).timeout
	if not launching and session.settings.get("auto_update",true):updater.restart()
	auto_restart_pending=false
func start_multiplayer() -> void:
	if launching or not characters_ready:return
	if updater.state!="latest":
		if updater.state=="available":updater.download_update()
		elif updater.state=="ready":updater.restart()
		elif updater.state=="installer":open_installer()
		else:updater.check_updates()
		return
	login_panel.open()
func open_installer() -> void:
	var platform:="macos" if OS.get_name()=="macOS" else "windows"
	var url: String=updater.manifest.get("installers",{}).get(platform,"")
	if url.begins_with(Updates.BASE_URL): OS.shell_open(url)
func start_game() -> void:
	if launching or not characters_ready: return
	character_menu.open()
func launch_character(_id: String) -> void:
	if launching: return
	launching=true
	start_button.text="正在走进眠风山谷…" if session.state().get("map_id","city")=="valley" else "正在走进海岛城…"
	start_button.disabled=true
	await get_tree().process_frame
	await get_tree().create_timer(.12).timeout
	get_tree().change_scene_to_file(session.scene_path())
func build_settings(parent: Control) -> Control:
	var overlay:=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new()
	shade.color=Color("26473c",.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card:=UI.panel(UI.CREAM,30,30)
	card.anchor_left=.5
	card.anchor_right=.5
	card.anchor_top=.5
	card.anchor_bottom=.5
	card.position=Vector2(-260,-270)
	card.custom_minimum_size=Vector2(520,540)
	overlay.add_child(card)
	var col:=UI.column(22)
	card.add_child(col)
	col.add_child(UI.label("把旅程调成喜欢的样子",25))
	var sound:=CheckButton.new()
	sound.text="环境声音"
	sound.button_pressed=session.settings.sound
	sound.toggled.connect(func(v): session.set_setting("sound",v))
	col.add_child(sound)
	col.add_child(UI.label("音量",17))
	var slider:=HSlider.new()
	slider.min_value=0
	slider.max_value=1
	slider.step=.01
	slider.value=session.settings.volume
	slider.value_changed.connect(func(v): session.set_setting("volume",v))
	col.add_child(slider)
	var fullscreen:=CheckButton.new()
	fullscreen.text="全屏显示"
	fullscreen.button_pressed=session.settings.fullscreen
	fullscreen.toggled.connect(func(v): session.set_setting("fullscreen",v))
	col.add_child(fullscreen)
	preload("res://scripts/city/render_budget.gd").add_control(col,session)
	preload("res://scripts/city/frame_pacer.gd").add_controls(col,session)
	var reduce:=CheckButton.new()
	reduce.text="减少界面动效"
	reduce.button_pressed=session.settings.reduce_motion
	reduce.toggled.connect(func(v): session.set_setting("reduce_motion",v))
	col.add_child(reduce)
	var automatic:=CheckButton.new();automatic.text="自动下载更新并重启";automatic.button_pressed=session.settings.get("auto_update",true)
	automatic.toggled.connect(func(value):session.set_setting("auto_update",value));col.add_child(automatic)
	col.add_child(UI.button("准备好啦",func(): overlay.hide(),true))
	return overlay
