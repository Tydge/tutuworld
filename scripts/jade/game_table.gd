extends VBoxContainer
const UI=preload("res://scripts/ui/ui_kit.gd")
const Board=preload("res://scripts/jade/play_board.gd")
const Plate=preload("res://scripts/jade/rounds/play_surface.gd")
const ART=preload("res://assets/jade/workshop_almanac.webp")
const HUES=[Color("285e4a"),Color("824f46"),Color("505074"),Color("586445"),Color("385b68"),Color("835b39")]
const MATS=[Color("294d45"),Color("4f4840"),Color("41465c"),Color("414e43"),Color("314f57"),Color("514b3e")]
const TONES=[261.63,293.66,329.63,392.,440.]
var hud: CanvasLayer
var target: String
var house: String
var board: RefCounted
var illustration: Control
var surface: Control
var brief: Label
var status: Label
var note: Label
var receipt: Label
var order_sheet: Label
var controls: GridContainer
var footer: HBoxContainer
var undo_button: Button
var new_button: Button
var play_button: Button
var last_art: Button
var submitting:=false
var received:=false
var listening:=false
var cues: Array=[]
var cue: Dictionary={}
var cue_time:=0.
var phase:=0.
var drum_cycle:=0
var last_beat:=-2
var album_pos:=-1
var last_deal:=-1
var styles: Dictionary={}
var pending_message: String=""
var seal_drop:=1.

func start(owner_hud: CanvasLayer,id: String) -> void:
	hud=owner_hud;target=id;house=id.get_slice(":",1)
	var serial:=int(hud.session.state().jade_visits.rounds.get(house,0))
	board=Board.new(house,serial,0,int(hud.session.state().jade_visits.next_deals.get(house,serial)))
	add_theme_constant_override("separation",8)
	surface=Control.new();surface.custom_minimum_size.y=120;add_child(surface)
	surface.draw.connect(paint_banner)
	brief=UI.label("",18,Color("fff5dd"));brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brief.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;brief.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.add_child(brief);brief.anchor_right=.52;brief.anchor_bottom=1;brief.offset_left=18;brief.offset_right=-6;brief.offset_top=4;brief.offset_bottom=-4
	var field:=UI.panel(MATS[board.rule.theme_index],6,10);add_child(field)
	var row:=UI.row(12);field.add_child(row)
	illustration=Plate.new();row.add_child(illustration)
	illustration.pressed_object.connect(press)
	var right:=UI.column(4);right.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(right)
	status=UI.label("",16,Color("f3e5bd"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;right.add_child(status)
	order_sheet=UI.label("",16,Color("d1d7ba"));order_sheet.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;right.add_child(order_sheet)
	controls=GridContainer.new();controls.size_flags_vertical=SIZE_SHRINK_CENTER;controls.size_flags_horizontal=SIZE_EXPAND_FILL
	controls.add_theme_constant_override("h_separation",4);controls.add_theme_constant_override("v_separation",4);right.add_child(controls)
	note=UI.label("",16);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	footer=UI.row(8);add_child(footer)
	receipt=UI.label("",14);receipt.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(receipt)
	play_button=UI.button("重听",demonstrate);footer.add_child(play_button)
	last_art=UI.button("翻花笺册",show_keepsake);footer.add_child(last_art)
	undo_button=UI.button("撤一步",undo);footer.add_child(undo_button)
	new_button=UI.button("换题",next_round,true);footer.add_child(new_button)
	for item in [play_button,last_art,undo_button,new_button]:item.custom_minimum_size.y=36
	var fills:={"plain":Color("e9d6b0"),"on":Color("e8b776"),"dark":Color("a8b09a")}
	for key in fills:
		styles[key]=UI.box(fills[key],5,3);styles[key].shadow_size=0
	styles.focus=UI.box(Color.TRANSPARENT,5,0);styles.focus.border_color=Color("a3542b");styles.focus.set_border_width_all(3);styles.focus.shadow_size=0
	styles.hover=UI.box(Color("fff0c7"),5,3);styles.hover.shadow_size=0
	begin()
func paint_banner() -> void:
	var w:=surface.size.x;var h:=surface.size.y
	var tex:=Vector2(ART.get_size());var strip:=Vector2(tex.x/2.,tex.y/3.)
	var index:int=board.rule.theme_index
	var area:=Rect2(Vector2(index%2,index/2)*strip,strip)
	# Keep the artisan fully visible. The rules occupy the painted side of the spread.
	surface.draw_rect(Rect2(0,0,w,h),HUES[index])
	var art_width:=minf(w,h*strip.x/strip.y*1.34)
	surface.draw_texture_rect_region(ART,Rect2(w-art_width,0,art_width,h),area)
	var left:=w-art_width
	var opaque:Color=HUES[index];var clear:=Color(opaque,0)
	var stop:=maxf(left,w*.49);var edge:=maxf(stop+2,w*.64)
	surface.draw_rect(Rect2(left,0,stop-left,h),opaque)
	surface.draw_polygon(PackedVector2Array([Vector2(stop,0),Vector2(edge,0),Vector2(edge,h),Vector2(stop,h)]),PackedColorArray([opaque,clear,clear,opaque]))
	surface.draw_line(Vector2(2,1),Vector2(w-2,1),Color("d5ae70"),2)
	if received:
		var side:=lerpf(62.,42.,seal_drop)
		var seal:=Rect2(Vector2(w-30,h-28)-Vector2.ONE*side*.5,Vector2.ONE*side)
		surface.draw_rect(seal,Color("a84436"))
		surface.draw_rect(seal.grow(-3),Color("f7d7ad"),false,1.5)
		surface.draw_string(get_theme_default_font(),seal.position+Vector2(0,side*.70),"成",HORIZONTAL_ALIGNMENT_CENTER,side,24,Color("ffebc9"))
func begin() -> void:
	cues.clear();cue.clear();listening=false;received=false;submitting=false;pending_message="";album_pos=-1
	phase=.45;drum_cycle=0;last_beat=-2;illustration.rule=board.rule;illustration.flash=-1;illustration.album=[]
	illustration.stage_pair=[];illustration.show_faces=false
	brief.text=board.rule.brief;last_deal=board.rule.deal
	set_process(house=="dojo");refresh();surface.queue_redraw()
	if house in ["pipa","stage","duty","fiddler"]:demonstrate.call_deferred()
func next_round() -> void:
	if submitting:return
	if board.rule.done and not received and int(hud.session.state().jade_visits.rounds.get(house,0))==board.serial:
		submit();return
	var number:=int(hud.session.state().jade_visits.rounds.get(house,0))
	var base:=int(hud.session.state().jade_visits.next_deals.get(house,number))
	var edition:=maxi(0,last_deal+1-base)%10000
	board=Board.new(house,number,edition,base);begin()
func undo() -> void:
	if submitting or received or listening or board.moves.is_empty():return
	board.undo();illustration.rule=board.rule;illustration.album=[];album_pos=-1
	pending_message="已撤回上一步。";refresh()
func show_keepsake() -> void:
	if listening or submitting:return
	var journal:Dictionary=hud.session.state().jade_visits
	if house=="paper" and not journal.prints.is_empty():
		album_pos=(album_pos+1)%(journal.prints.size()+1)
		illustration.album=journal.prints[album_pos] if album_pos<journal.prints.size() else []
		pending_message="花笺册 · 第 %d 张，落印即回到新纸。"%(album_pos+1) if not illustration.album.is_empty() else "手中这张新纸。"
		refresh()
	elif house=="music" and journal.song.size():play_score(journal.song)
func _process(delta: float) -> void:
	if listening:
		advance_rehearsal(delta)
	if house!="dojo" or board.rule.done:return
	var previous:=phase;phase=fposmod(phase+delta/float(board.rule.data.tempo),1.)
	if phase<previous:
		drum_cycle+=1;hud.city.play_tone(155,.09,.12)
	illustration.pulse=phase if not hud.session.settings.reduce_motion else (0. if beat_open() else .48)
	illustration.queue_redraw()
func beat_open() -> bool:return int(phase*8) in [0,1,6,7]

func keys(group: Node,index: int,offset: int) -> void:
	var b:=Button.new()
	b.focus_mode=Control.FOCUS_ALL;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal=SIZE_EXPAND_FILL;b.custom_minimum_size=Vector2(0,37)
	b.add_theme_font_size_override("font_size",16)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:b.add_theme_color_override(state,Color("253c36"))
	b.add_theme_stylebox_override("focus",styles.focus);b.add_theme_stylebox_override("hover",styles.hover);b.add_theme_stylebox_override("pressed",styles.on)
	b.pressed.connect(press.bind(index+offset));group.add_child(b)
func refresh() -> void:
	var r=board.rule;var journal:Dictionary=hud.session.state().jade_visits
	var opts:Array=r.labels
	var on_object:int=illustration.count_objects()
	var main_count:int=opts.size()-on_object
	controls.columns=maxi(1,mini(main_count,3 if house=="paper" else int(r.columns)))
	if controls.get_child_count()!=main_count:
		UI.clear(controls)
		for i in main_count:keys(controls,i,on_object)
	for i in range(on_object,opts.size()):
		var b:Button=controls.get_child(i-on_object)
		b.text=str(opts[i])
		b.disabled=r.done or listening or submitting or not r.enabled(i)
		var skin=styles.on if r.active(i) else styles.plain
		b.add_theme_stylebox_override("normal",skin);b.add_theme_stylebox_override("disabled",styles.dark if not r.enabled(i) else skin)
		b.tooltip_text=b.text
	controls.visible=main_count>0
	illustration.update_objects(r.done or listening or submitting)
	order_sheet.text=order_text(r)
	order_sheet.visible=not order_sheet.text.is_empty()
	status.text=r.status
	note.text=pending_message if not pending_message.is_empty() else str(r.note)
	if note.text.is_empty():
		note.text="纸面可直接落印 · 成品收进自己的花笺册" if house=="paper" else ("这袋信的收件处已圈在舆图上。" if house in ["hostel","post"] and journal.letter!="" else " ")
	if board.moves.size()>=Board.MAX_MOVES and not r.done:note.text="这张题签已经写满，可以撤一步或换题。"
	receipt.text="坊印 %d / 38　·　此处完成 %d 回"%[journal.marks.size(),journal.rounds.get(house,0)]
	undo_button.disabled=submitting or listening or received or board.moves.is_empty()
	new_button.text="再来一局" if received else ("再交一次" if r.done and not submitting else "换题")
	new_button.disabled=submitting
	play_button.visible=house in ["pipa","duty","stage","fiddler"]
	play_button.text="重看换幕" if house=="stage" else "再听一遍"
	play_button.disabled=received or submitting or listening
	last_art.visible=(house=="paper" and journal.prints.size()>0) or (house=="music" and journal.song.size()>0)
	last_art.text="翻花笺册" if house=="paper" else "听上回的曲"
	illustration.queue_redraw()
func order_text(r: RefCounted) -> String:
	match house:
		"weir":
			var lines:Array=[]
			for code in ["R","M","F"]:
				lines.append({"R":"稻田","M":"桑田","F":"鱼塘"}[code]+"　"+("已通水" if r.data.map.find(code) in r.v else "待引水"))
			return "\n".join(lines)
		"carver":
			var lines:Array=[]
			for y in 3:
				var marks:=""
				for x in 3:marks+="朱　" if int(r.data.mask)&(1<<(y*3+x)) else "白　"
				lines.append(marks)
			return "纸上印蜕\n"+"\n".join(lines)
		"basket":return "行数在左，列数在上。\n分别读每一组连续挑起的篾条。"
		"stitch":return "灰线待缝，朱线已缝。\n直接点布面上的针孔。"
		"chamber":return "北 ↑　　东 →\n从最后一颗已连的星接着走。"
		"sail":return "浮标装货，再进港。\n点相邻水格，顺风多行一格。"
		"archive":return "甲、乙是界碑。\n对照两段里程，直接点仓址。"
		"caligraphy":return "顺序先上排，再下排。\n点空格边的字片挪动。"
		"silversmith":return "银钉能挡珠，花心是落点。\n点直线上带圈的停靠处。"
		"pastry":return "炭口留空，一副模占两格。\n点选起模处，再点相邻一格。"
		"potter":return "在坯身上下拖泥，或用推泥手势。"
		"audience":return "点奏本拨款，再点一次可收回。"
		"hostel":return "点图上的三处驿站，依次取信。"
		"post":
			var routes:Array=[]
			for i in 3:routes.append(r.DISTRICTS[i]+"　"+"、".join(r.ADDRESSES[i]))
			return "\n".join(routes)
		"herbal":return "验过药样，点对应的药屉。"
		"farmhouse":return "点要开闸的田畦。"
		"baihe":return "先点一签，再点另一签换位。"
		"tailorhome":return "直接点最上层那股绣线。"
		"garden":return "直接点枝梢下剪，也可剪主干。"
		"books":return "翻页时会自动夹好勘误笺。"
		"pipa":return "点琴弦应和。数字 1～5 也能拨弦。"
		"music":return "直接点青磬谱曲。"
		"stage":return "锣停后，直接点戏幕。"
		"dojo":return "点桩落脚　·　← 左　→ 右"
		"banquet":return "点击盘中点心，顺着转盘分席。"
		"oil":return "直接点秤下的砝码，上秤或取下。"
		"noodle":return "直接点砧板刻度，下刀或收刀。"
		"incense":return "点托提起香环，再点落处。"
	return ""
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or board.rule.done:return
	var idx:int=event.keycode-KEY_1
	if house=="ledger" and event.keycode==KEY_0:idx=10
	elif house=="ledger" and event.keycode==KEY_BACKSPACE:idx=9
	elif house=="dojo" and event.keycode in [KEY_LEFT,KEY_RIGHT]:idx=int(event.keycode==KEY_RIGHT)
	elif event.keycode<KEY_1 or event.keycode>KEY_9:return
	if idx>=0 and idx<board.rule.labels.size():
		press(idx);get_viewport().set_input_as_handled()
func press(i: int) -> void:
	if submitting or received or listening or board.rule.done or i<0 or i>=board.rule.labels.size():return
	if not hud.city.activity_access(target,"jade_game"):hud.close_panel();return
	if house=="music" and i==6:
		play_score(board.rule.v.duplicate());return
	var beat:=drum_cycle+int(phase>=.5)
	if house=="dojo" and beat==last_beat:
		note.text="这一拍已踩稳，等下一声鼓。";return
	var before:int=board.rule.step
	var input:=i+2*int(phase*8) if house=="dojo" else i
	if not board.play(input):return
	if house=="dojo" and board.rule.step!=before:last_beat=beat
	pending_message="";illustration.album=[];album_pos=-1;illustration.feedback(i,hud.session.settings.reduce_motion)
	var prop:Node3D=hud.city.targets[target].node
	var dir:Vector3=prop.global_position-hud.city.bunny.global_position
	hud.city.bunny.set_visual_heading(atan2(dir.x,dir.z))
	hud.city.bunny.play_action(["refill","draw_thread","bell","read_scroll","sort_seed","cook"][board.rule.theme_index],.44)
	if house in ["pipa","music"] and i<5:tone(TONES[i])
	elif house=="fiddler":tone(300.*pow(1.065,board.rule.v[mini(before,1)]))
	else:tone(176. if not board.rule.note.is_empty() else 340.+board.rule.step*24.)
	refresh()
	if board.rule.done:submit()
	elif house=="duty" and board.rule.step!=before:demonstrate()
	elif house=="fiddler" and board.rule.step!=before:demonstrate()
func tone(hz: float,duration:=.25) -> void:hud.city.play_tone(hz,duration,.12)
func play_score(notes: Array) -> void:
	if listening or notes.is_empty():return
	for n in notes:
		cues.append({"duration":.38,"flash":n,"hz":TONES[n] if n<5 else 0.,"line":"试听曲谱"})
	start_rehearsal()

func demonstrate() -> void:
	if not is_inside_tree() or submitting or listening or board.rule.done:return
	var r=board.rule
	match house:
		"stage":
			illustration.stage_cast=r.data.initial.duplicate()
			cues.append({"duration":1.35,"faces":true,"line":"记住「%s」的位置。"%r.MASKS[r.data.actor]})
			for pair in r.data.swaps:
				cues.append({"duration":.7,"pair":pair,"line":"第 %d 幕和第 %d 幕换位。"%[pair[0]+1,pair[1]+1]})
		"pipa":
			for n in r.goal:
				cues.append({"duration":.40,"flash":n,"hz":TONES[n],"line":"听弦　"+str(r.NOTES[n])})
				cues.append({"duration":.12})
		"duty":
			for symbol in r.CODES[r.goal[r.step]]:
				cues.append({"duration":.56 if symbol=="长" else .22,"flash":2,"hz":392.,"line":"听号　"+symbol})
				cues.append({"duration":.16})
		"fiddler":
			cues.append({"duration":.56,"hz":300.*pow(1.065,r.goal[r.step]),"line":"定音"})
			cues.append({"duration":.56,"hz":300.*pow(1.065,r.v[r.step]),"line":"手中这根弦"})
	start_rehearsal()

func start_rehearsal() -> void:
	if cues.is_empty():return
	listening=true;cue={};set_process(true);refresh();advance_rehearsal(0.)

func advance_rehearsal(delta: float) -> void:
	cue_time-=delta
	if cue.is_empty() or cue_time<=0.:
		if cue.has("pair"):
			board.rule.swap(illustration.stage_cast,cue.pair[0],cue.pair[1])
		illustration.travel=0.;illustration.stage_pair=[]
		if cues.is_empty():
			cue={};listening=false;illustration.flash=-1;illustration.show_faces=false
			set_process(house=="dojo");refresh();return
		cue=cues.pop_front();cue_time=cue.duration
		illustration.flash=cue.get("flash",-1);illustration.show_faces=cue.get("faces",false)
		illustration.stage_pair=cue.get("pair",[])
		note.text=cue.get("line"," ")
		if cue.get("hz",0.)>0.:tone(cue.hz,clampf(float(cue.duration)-.04,.12,.49))
	if cue.has("pair") and not hud.session.settings.reduce_motion:
		illustration.travel=smoothstep(0.,1.,1.-cue_time/float(cue.duration))
	illustration.queue_redraw()
func submit() -> void:
	if submitting or received or not hud.city.activity_access(target,"jade_game"):return
	submitting=true;refresh()
	var args:={"target":target,"round":board.serial,"variant":board.variant,"moves":board.moves.duplicate()}
	var result:Dictionary
	if hud.session.is_online():result=await hud.session.request_online("jade_visit",args)
	else:
		hud.session.set_player_position(hud.city.bunny.global_position);result=hud.session.dispatch("jade_visit",args)
	if not is_inside_tree():return
	submitting=false;received=result.get("ok",false);pending_message=str(result.get("message",""))
	if hud.toast_label.text==pending_message:
		hud.toast_timer=0.;hud.toast.hide()
	if received:
		seal_drop=1.;surface.queue_redraw()
		if house=="audience":hud.city.refresh_court_orders()
		tone(523.25,.4)
		if not hud.session.settings.reduce_motion:
			var seal_tween:=create_tween();seal_tween.tween_method(func(t:float):seal_drop=t;surface.queue_redraw(),0.,1.,.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			var sparkle:=preload("res://scripts/city/reward_sparkle.gd").new();hud.city.add_child(sparkle)
			sparkle.global_position=hud.city.targets[target].node.global_position+Vector3.UP*1.25
	refresh()
