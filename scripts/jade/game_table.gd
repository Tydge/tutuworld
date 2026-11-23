extends VBoxContainer
## A small playable tabletop. Controls operate the objects pictured on its felt or paper.
const UI=preload("res://scripts/ui/ui_kit.gd")
const Board=preload("res://scripts/jade/play_board.gd")
const INK=Color("e9daba")
const GOLD=Color("e5b56e")
const RED=Color("db846a")
const JADE=Color("8bc7b0")
const TONES=[261.63,293.66,329.63,392.,440.]
var hud: CanvasLayer
var target: String
var board: RefCounted
var surface: Control
var controls: GridContainer
var status: Label
var heading: Label
var listening:=false
var submitting:=false
var received:=false
var pulse:=0.
var flow_time:=0.
var draw_time:=0.
var seal_time:=-1.
var tile: StyleBoxFlat
var hover_tile: StyleBoxFlat
var focus_tile: StyleBoxFlat
var embossed: StyleBoxFlat
var hit_zones: Array[Rect2]=[]
var flash:=-1
var generation:=0
func start(owner_hud: CanvasLayer,id: String) -> void:
	hud=owner_hud;target=id;board=Board.new(id.get_slice(":",1))
	embossed=UI.box(Color("244845"),12,0)
	tile=UI.box(Color("e5cda0"),5,9);tile.border_color=Color("aa8254");tile.set_border_width_all(1)
	hover_tile=tile.duplicate();hover_tile.bg_color=Color("f4dca7")
	focus_tile=tile.duplicate();focus_tile.bg_color=Color.TRANSPARENT;focus_tile.border_color=Color("83523a");focus_tile.set_border_width_all(2)
	add_theme_constant_override("separation",10)
	var hint:=UI.label(board.recipe.hint,21)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	surface=Control.new();surface.custom_minimum_size=Vector2(0,213);add_child(surface)
	surface.draw.connect(paint)
	surface.gui_input.connect(touch_table)
	controls=GridContainer.new();controls.add_theme_constant_override("h_separation",8);controls.add_theme_constant_override("v_separation",5)
	var center:=CenterContainer.new();center.add_child(controls);add_child(center)
	status=UI.label("",17);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(status)
	var footer:=UI.row();add_child(footer)
	heading=UI.label("",17);heading.size_flags_horizontal=SIZE_EXPAND_FILL;footer.add_child(heading)
	if board.game in ["melody","memory","tune"]:footer.add_child(UI.button("再听一遍" if board.game!="memory" else "再看一次",demonstrate))
	if board.game!="courier":footer.add_child(UI.button("重开一局",reset))
	set_process(board.game=="forge" or (board.game=="sluice" and not hud.session.settings.reduce_motion))
	refresh()
	if board.game in ["melody","memory","tune"]:demonstrate.call_deferred()
func _process(delta: float) -> void:
	pulse=fmod(pulse+delta*4.,8.)
	flow_time+=delta
	if seal_time>=0.:seal_time=minf(.42,seal_time+delta)
	draw_time+=delta
	if draw_time<1./30.:return
	draw_time=0.;surface.queue_redraw()
	if seal_time>=.42 and board.done:set_process(false)
func touch_table(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT or board.done:return
	for i in hit_zones.size():
		if hit_zones[i].has_point(event.position):press(i);surface.accept_event();return
func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or board.done:return
	var i: int=event.keycode-KEY_1
	if i>=0 and i<board.options().size():
		press(i);get_viewport().set_input_as_handled()
func gesture() -> void:
	var poses: Dictionary={"forge":"forge_strike","weave":"draw_thread","stitch":"draw_thread","mirror":"draw_thread","pigment":"cook","jugs":"refill","wheel":"plane_wood","proof":"read_scroll","verse":"read_scroll","clock":"bell","melody":"bell","tune":"bell","memory":"bell","weights":"sort_seed","divide":"cook","sluice":"plane_wood","allot":"read_scroll"}
	var prop: Node3D=hud.city.targets[target].node
	var direction: Vector3=prop.global_position-hud.city.bunny.global_position
	hud.city.bunny.set_visual_heading(atan2(direction.x,direction.z))
	hud.city.bunny.play_action(poses.get(board.game,"sort_seed"),.58)
func reset() -> void:
	if submitting:return
	received=false
	generation+=1;listening=false;flash=-1;seal_time=-1.
	set_process(board.game=="forge" or (board.game=="sluice" and not hud.session.settings.reduce_motion))
	board=Board.new(board.house);refresh()
	if board.game in ["melody","memory","tune"]:demonstrate()
func demonstrate() -> void:
	if listening or submitting or board.done:return
	listening=true;var token:=generation
	var notes: Array=board.recipe.goal if board.game!="tune" else [board.recipe.goal[0],board.values[0]]
	for i in notes.size():
		if not is_inside_tree() or token!=generation:return
		flash=int(notes[i])
		if board.game=="tune":tone(300.*pow(1.085,flash))
		else:tone(TONES[flash])
		status.text=("定音" if i==0 else "琴弦") if board.game=="tune" else ("看牌" if board.game=="memory" else "听弦")
		surface.queue_redraw()
		await get_tree().create_timer(.6).timeout
		if not is_inside_tree() or token!=generation:return
		flash=-1;surface.queue_redraw()
		await get_tree().create_timer(.12).timeout
	if not is_inside_tree() or token!=generation:return
	listening=false;flash=-1;refresh()
func tone(hz: float) -> void:
	hud.city.play_tone(hz,.30,.15)
func press(i: int) -> void:
	if listening or submitting or board.moves.size()>=Board.MAX_MOVES and not board.done:return
	if board.game=="courier" or board.done:submit();return
	if not hud.city.activity_access(target,"jade_game"):hud.close_panel();return
	var choice:=int(pulse) if board.game=="forge" else i
	board.play(choice)
	gesture()
	if board.game=="tune":tone(300.*pow(1.085,board.values[0]))
	elif board.game=="melody":tone(TONES[i])
	else:tone(152. if not board.note.is_empty() else 330.+board.step*34.)
	refresh()
	if board.done:submit()
func submit() -> void:
	if submitting or not hud.city.activity_access(target,"jade_game"):return
	submitting=true
	var args:={"target":target,"moves":board.moves.duplicate()}
	var result: Dictionary
	if hud.session.is_online():result=await hud.session.request_online("jade_visit",args)
	else:
		hud.session.set_player_position(hud.city.bunny.global_position)
		result=hud.session.dispatch("jade_visit",args)
	if not is_inside_tree():return
	submitting=false
	if result.ok:
		received=true
		hud.city.play_tone(523.,.4,.15)
		if not hud.session.settings.reduce_motion:
			var sparkle:=preload("res://scripts/city/reward_sparkle.gd").new()
			hud.city.add_child(sparkle)
			sparkle.global_position=hud.city.targets[target].node.global_position+Vector3.UP*1.25
		board.done=true
		if board.game=="courier":board.note=str(result.message)
		if board.house in hud.session.state().jade_visits.marks:
			seal_time=.42 if hud.session.settings.reduce_motion else 0.
			set_process(true)
		refresh()
		status.text=result.message
	else:
		refresh()
		status.text=str(result.message)
func refresh() -> void:
	UI.clear(controls)
	var opts: Array=board.options()
	if board.game=="courier":
		var sender:=str(hud.session.state().jade_visits.letter)
		opts=["接过驿袋" if sender=="" else ("查看送信去处" if sender==board.house else "把驿袋递过去")]
	if board.done:opts=[] if received or submitting else ["再交一次"]
	controls.columns=3 if grid_game() else maxi(1,mini(6,opts.size()))
	for i in opts.size():
		var key:=caption(i,opts[i])
		var b:=UI.button(key,press.bind(i));b.custom_minimum_size=Vector2(90 if grid_game() else 106,39)
		b.add_theme_stylebox_override("normal",tile)
		b.add_theme_stylebox_override("hover",hover_tile)
		b.add_theme_stylebox_override("focus",focus_tile)
		b.tooltip_text="%d　%s"%[i+1,key]
		b.add_theme_font_size_override("font_size",18);controls.add_child(b)
	if board.done and board.game!="courier":status.text=board.recipe.end
	else:status.text=board.note if board.moves.size()<Board.MAX_MOVES else "这一局绕得有些远了。可以重开，再换个走法。"
	var marks: Array=hud.session.state().jade_visits.marks
	heading.text=("已钤坊印" if board.house in marks else "初成谢礼　六贝")+("　·　玉京坊印 %d / %d"%[marks.size(),Board.Games.STATIONS.size()])
	surface.queue_redraw()
func grid_game() -> bool:return board.game in ["weave","stitch","mirror","stars"]
func caption(i: int,v: Variant) -> String:
	if board.done:return str(v)
	if board.game in ["weave","mirror"]:return ["经","纬"][board.values[i]] if board.game=="weave" else ["白","朱"][board.values[i]]
	if board.game in ["stitch","stars"]:return str(i+1)
	if board.game=="seats":return board.recipe.labels[board.values[i]]
	if board.game=="proof":return board.recipe.goal[board.step][i]
	return str(v)
func word(p: Vector2,s: String,size_: int=22,color:=INK) -> void:
	surface.draw_string(get_theme_default_font(),p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size_,color)
func circle(p: Vector2,r: float,c: Color) -> void:surface.draw_circle(p,r,c,true,-1,true)
func stroke(a: Vector2,b: Vector2,c: Color,width:=3.) -> void:surface.draw_line(a,b,c,width,true)
func dots(index: int) -> Vector2:return Vector2(index%3,index/3)*44.
func paint() -> void:
	var w:=surface.size.x;var mid:=w*.5;var paper:=surface.size
	surface.draw_style_box(embossed,Rect2(Vector2.ZERO,paper))
	surface.draw_rect(Rect2(Vector2(8,8),paper-Vector2(16,16)),Color("9b8866"),false,1.)
	for x in [11.,w-11.]:
		for y in [11.,paper.y-11.]:
			var dx:=1. if x<mid else -1.
			var dy:=1. if y<paper.y*.5 else -1.
			var corner:=Vector2(x,y)
			surface.draw_polyline(PackedVector2Array([corner+Vector2(0,27*dy),corner+Vector2(0,9*dy),corner+Vector2(16*dx,9*dy),corner+Vector2(16*dx,16*dy),corner+Vector2(9*dx,16*dy),corner+Vector2(9*dx,0),corner+Vector2(27*dx,0)]),Color("968768"),1.4,true)
	hit_zones.clear()
	var goal: Array=board.recipe.goal;var v: Array=board.values
	var cy:=105.
	match board.game:
		"weave","mirror","stitch","stars","sail":
			var two: bool=board.game in ["weave","mirror"]
			var base:=Vector2(mid-(190. if two else 44.),52.)
			for side in (2 if two else 1):
				var origin:=base+Vector2(280*side,0.)
				for i in 9:
					var p:=origin+dots(i)
					if (two and side==1) or (not two and board.game!="sail"):hit_zones.append(Rect2(p-Vector2(21,21),Vector2(42,42)))
					if two:
						var on: bool=bool(goal[i] if side==0 else v[i])
						surface.draw_rect(Rect2(p-Vector2(19,19),Vector2(38,38)),RED if on else Color("dac799"))
						if board.game=="weave":
							for j in [-8.,0.,8.]:
								var axis:=Vector2(16,0) if on else Vector2(0,16)
								var at:=p+(Vector2(0,j) if on else Vector2(j,0))
								stroke(at-axis,at+axis,Color("927554"),2.)
					elif board.game=="sail":
						circle(p,17.,JADE if i!=goal[2] else Color("886c58"))
						word(p+Vector2(-9,6),"舟" if i==v[0] else ("旗" if i==goal[1] else ("礁" if i==goal[2] else "≈")),17,Color("214544"))
					else:
						circle(p,13.,GOLD if i in goal else Color("67867b"))
						word(p+Vector2(-5,6),str(i+1),15,Color("294642"))
				if two:word(origin+Vector2(4,129),"底样" if side==0 else "手中",19)
			if board.game in ["stitch","stars"]:
				for i in range(1,goal.size()):stroke(base+dots(goal[i-1]),base+dots(goal[i]),GOLD if i<board.step else Color("779487"),2.)
				word(Vector2(26,186),"起式   "+"  →  ".join(goal.map(func(n):return str(int(n)+1))),18)
			if board.game=="sail":word(Vector2(24,185),"北岸顺东风，向东多漂一格",18)
		"forge":
			hit_zones.append(Rect2(0,0,w,200))
			var begin:=mid-248.
			for i in 8:surface.draw_rect(Rect2(begin+i*62,82,58,40),GOLD if i==goal[mini(board.step,2)] else Color("526c59"))
			circle(Vector2(begin+(pulse+.02)*62.,cy),10.,Color.WHITE)
			word(Vector2(mid-63.,166),"%s　%d / 3"%["火候" if board.house=="kiln" else "落槌",board.step],20)
		"melody","memory","tune":
			var notes: Array=["宫","商","角","徵","羽"] if board.game!="memory" else board.recipe.labels
			if board.game=="tune":
				for j in 5:stroke(Vector2(mid-205,62+j*20),Vector2(mid+205,62+j*20),GOLD if j==2 else JADE,2.)
				word(Vector2(mid-58,182),"弦轸　%+d"%v[0],21)
			else:
				for i in notes.size():
					var p:=Vector2(mid+(i-(notes.size()-1)*.5)*78,cy)
					hit_zones.append(Rect2(p-Vector2(32,32),Vector2(64,64)))
					circle(p,30.,GOLD if i==flash else Color("42665c"))
					word(p+Vector2(-12,9),str(notes[i]),24)
				word(Vector2(24,183),"入拍　%d / %d"%[board.step,goal.size()],18)
		"weights":
			var mass:=0
			for i in 3:mass+=v[i]*goal[i]
			var tilt:=clampf((mass-goal[3])*.09,-.45,.45)
			var beam:=Vector2.from_angle(tilt)*125.
			var pivot:=Vector2(mid,83);stroke(pivot-Vector2(0,40),pivot+Vector2(0,77),GOLD,6.)
			stroke(pivot-beam,pivot+beam,INK,4.)
			for side in [-1,1]:
				var end: Vector2=pivot+beam*side;stroke(end,end+Vector2(0,30),GOLD,2.);stroke(end+Vector2(-24,30),end+Vector2(24,30),GOLD,5.)
			word(Vector2(mid-82,188),"%d 钱　/　%d 钱"%[mass,goal[3]],20)
		"sluice":
			var direction:= -1. if board.house=="weir" else 1.
			var wet: int=board.wet_joints()
			var first:=Vector2(mid-62,cy-direction*28)
			var tiles: Array=[first,first+Vector2(76,0),first+Vector2(76,64*direction)]
			var source:=first-Vector2(119,0)
			var field: Vector2=tiles[2]+Vector2(134,0)
			circle(source,25.,Color("5c9b95"))
			for row in 3:
				var y:=source.y-10.+row*9.
				var drift:=sin(flow_time*1.7+row)*3.
				stroke(Vector2(source.x-12+drift,y),Vector2(source.x+10+drift,y),JADE,2.)
			for row in 3:
				var root_: Vector2=field+Vector2(-14.+row*14.,9)
				stroke(root_,root_+Vector2(-4,-14),JADE,2.);stroke(root_,root_+Vector2(8,-18),Color("c7ce85"),2.)
				stroke(root_+Vector2(-6,5),root_+Vector2(6,0),Color("8b8666"),3.)
			stroke(source+Vector2(21,0),first-Vector2(32,0),JADE,10.)
			stroke(tiles[2]+Vector2(34,0),tiles[2]+Vector2(112,0),JADE if wet==3 else GOLD,9.)
			for i in 3:
				var at: Vector2=tiles[i]
				hit_zones.append(Rect2(at-Vector2(34,30),Vector2(68,60)))
				surface.draw_rect(Rect2(at-Vector2(34,30),Vector2(68,60)),Color("6f533d"))
				surface.draw_rect(Rect2(at-Vector2(32,28),Vector2(64,56)),Color("b89059"),false,2.)
				for peg in [Vector2(-26,-22),Vector2(26,22)]:circle(at+peg,2.5,Color("ceb27c"))
				for port in board.ports(i):
					var delta:=Vector2.from_angle((port-1)*PI/2.)*31.
					stroke(at,at+delta,Color("382e23"),17.)
					stroke(at,at+delta,JADE if i<wet else Color("d2b88e"),10.)
					if i<wet:circle(at+delta*fposmod(flow_time*.72+i*.28,1.),2.2,Color("d6eee1"))
			word(source+Vector2(-18,49),"来水",18,JADE);word(field+Vector2(-18,46),"田口",18,GOLD)
		"jugs","wheel","tower","divide","allot","pigment","abacus","clock","seats","press","cross":
			var count:=v.size()
			if board.game in ["abacus","clock"]:count=2
			for i in count:
				var x:=mid+(i-(count-1)*.5)*minf(130.,(w-80.)/count)
				var p:=Vector2(x,cy)
				if board.game!="jugs":hit_zones.append(Rect2(x-38,45,76,120))
				match board.game:
					"jugs":
						var frac: float=float(v[i])/goal[i];surface.draw_rect(Rect2(x-38,58,76,90),INK,false,3)
						surface.draw_rect(Rect2(x-34,145-82*frac,68,82*frac),JADE)
						word(Vector2(x-8,180),str(v[i]),20)
					"tower":
						stroke(p-Vector2(0,50),p+Vector2(0,46),GOLD,4.)
						for j in v[i].size():
							var radius: float=12.+9.*v[i][j]
							stroke(p+Vector2(-radius,40-j*17),p+Vector2(radius,40-j*17),RED if i==board.picked else JADE,13.)
					"wheel":
						var radius: float=12.+10.*v[i]
						for j in 4:stroke(p+Vector2(-radius,j*8),p+Vector2(radius,j*8),Color("c38961"),7.)
						word(Vector2(x-27,176),"%s · %d"%[board.recipe.labels[i],v[i]],17)
					"abacus":
						stroke(p-Vector2(0,53),p+Vector2(0,53),GOLD,3.)
						for j in 9:circle(Vector2(x,46+j*11+(15 if j>=v[i] else 0)),5.5,JADE if j<v[i] else GOLD)
						word(Vector2(x-29,181),"%s · %d"%[board.recipe.labels[i],v[i]],18)
					"clock":
						surface.draw_arc(p,34,0,TAU,44,INK,2.,true)
						var sides:=6
						stroke(p,p+Vector2.from_angle(v[i]*TAU/sides-PI*.5)*30.,JADE,5.)
						word(Vector2(x-32,175),"对位 %d"%goal[i],17)
						word(p+Vector2(37,5),str(v[i]),16)
					_:
						var label_:=str(v[i])
						if board.game=="seats":label_=board.recipe.labels[v[i]]
						if board.game=="cross":label_=["菜","兔","鹅","舟"][i]+(" · 西" if v[i]==0 else " · 东")
						if board.game=="press":label_="花" if v[i]==1 else "○"
						circle(p,36.,Color("906854") if board.picked==i else Color("4c7166"))
						word(p+Vector2(-label_.length()*10.,7),label_,20)
						if board.game in ["pigment","allot"]:word(Vector2(x-49,177),"%s　%d"%[board.recipe.labels[i],v[i]],17)
		"proof":
			word(Vector2(45,76),"底本",18,JADE);word(Vector2(mid-100,93),board.recipe.labels[mini(board.step,2)],35)
			word(Vector2(45,154),"抄本",18,RED);word(Vector2(mid-100,162),goal[mini(board.step,2)],35)
		"verse":
			var phrase: String="".join(goal.slice(0,board.step).map(func(i):return board.recipe.labels[i]))
			word(Vector2(mid-80,120),phrase+"　".repeat(goal.size()-board.step),36)
			stroke(Vector2(mid-115,141),Vector2(mid+115,141),GOLD,2.)
		"courier":
			surface.draw_rect(Rect2(mid-72,55,144,94),Color("d6bc8c"))
			stroke(Vector2(mid-72,55),Vector2(mid,113),Color("8f7457"));stroke(Vector2(mid,113),Vector2(mid+72,55),Color("8f7457"))
			circle(Vector2(mid,107),14.,RED)
			var letter:=str(hud.session.state().jade_visits.letter)
			word(Vector2(mid-88,183),"驿袋尚空" if letter=="" else ("送往驿路茶棚" if letter=="hostel" else "送往旧渡驿舍"),20)
	if seal_time>=0.:
		var land:=clampf(seal_time/.25,0.,1.)
		var side:=lerpf(63.,48.,1.-pow(1.-land,3.))
		var seal:=Rect2(Vector2(w-71.-side*.5,42.-side*.5),Vector2.ONE*side)
		var vermilion:=Color("dd735a")
		vermilion.a=.3+.7*land
		surface.draw_rect(seal,vermilion,false,3.,true)
		surface.draw_rect(seal.grow(-4.),vermilion,false,1.,true)
		word(seal.get_center()+Vector2(-18,7),"坊印",18,vermilion)
