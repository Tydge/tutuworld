extends SceneTree
const UI=preload("res://scripts/ui/ui_kit.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func mouse_at(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=Vector2(2,2);root.push_input(event,true)
func run() -> void:
	root.size=Vector2i(1440,900)
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);Engine.max_fps=30
	var game=load("res://scenes/city.tscn").instantiate();root.add_child(game);await create_timer(.8).timeout
	session.active=false;game.bunny.can_move=false;game.hud.open_panel("profile");await create_timer(.35).timeout
	var sheet: Control=game.hud.character_sheet;var bar: TabBar=sheet.pages.get_tab_bar()
	var previous_mouse: Vector2=root.get_mouse_position()
	var hovered: Array[int]=[-1];bar.tab_hovered.connect(func(index): hovered[0]=index)
	for index in [1,0]:
		var rect: Rect2=bar.get_tab_rect(index)
		Input.warp_mouse(bar.get_global_transform_with_canvas()*rect.get_center())
		await create_timer(.08).timeout
		mouse_at(bar.get_global_transform_with_canvas()*rect.get_center())
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		check(hovered[0]==index,"Mouse hovers actual tab "+str(index))
		var style: String="tab_selected" if index==bar.current_tab else "tab_hovered"
		var expected: Color=sheet.pages.get_theme_stylebox(style).bg_color
		var point: Vector2=bar.get_global_transform_with_canvas()*(rect.position+Vector2(16,16))
		var image: Image=root.get_texture().get_image();var ratio: Vector2=Vector2(image.get_size())/root.get_visible_rect().size
		var actual:=image.get_pixelv(Vector2i(point*ratio))
		var error: float=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
		print("TAB_HOVER_RENDER index=",index," color=",actual," expected=",expected," error=",error)
		check(error<.03,"Hovered background keeps game palette "+str(index))
		image.save_png(preload("res://tests/test_support.gd").output_dir()+"/交互终审-"+("技能悬停" if index==1 else "属性悬停")+".png")
	Input.warp_mouse(previous_mouse)
	game.hud.close_panel();game.hud.open_panel("settings");await process_frame
	var enabled: CheckButton=game.hud.content.find_child("FrameLimitEnabled",true,false)
	var rate: OptionButton=game.hud.content.find_child("FrameLimitRate",true,false)
	var idle: CheckButton=game.hud.content.find_child("BackgroundThrottle",true,false)
	check(enabled.button_pressed and idle.button_pressed and rate.get_item_id(rate.selected)==60,"Settings UI has requested defaults")
	enabled.button_pressed=false
	check(not session.settings.fps_limit_enabled and rate.disabled,"Limit UI switch updates saved setting and selector")
	enabled.button_pressed=true
	for index in range(3):
		rate.select(index);rate.item_selected.emit(index)
		check(session.settings.fps_limit==[60,90,120][index],"FPS selection signal updates setting "+str(index))
	idle.button_pressed=false;check(not session.settings.background_throttle,"Background switch updates setting")
	idle.button_pressed=true;check(session.settings.background_throttle,"Background switch restores setting")
	print("INTERACTION_UI_AUDIT_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
