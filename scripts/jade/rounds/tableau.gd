extends Control
## An instrument beside the touch surface. Coordinates in this folio are local to the illustration.
const CREAM=Color("f4e5bf")
const MUTED=Color("b9c9ad")
const GOLD=Color("e8bc76")
const JADE=Color("91c9ad")
const RED=Color("e99572")
const DARK=Color("204e4a")
const PALETTE=[Color("bd514f"),Color("4f879e"),Color("ddaa52")]
const PIECES=preload("res://assets/jade/workshop_pieces.webp")
func piece(id: int,center: Vector2,extent: Vector2) -> void:
	var cell:=Vector2(PIECES.get_size())/Vector2(4,3)
	draw_texture_rect_region(PIECES,Rect2(center-extent*.5,extent),Rect2(Vector2(id%4,id/4)*cell,cell))
var rule: RefCounted
var pulse:=0.
var flash:=-1
var stage_cast: Array=[]
var stage_pair: Array=[]
var travel:=0.
var show_faces:=false
var album: Array=[]
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(310,238)
func txt(x: float,y: float,s: String,px:=16,c:=CREAM) -> void:
	draw_string(get_theme_default_font(),Vector2(x,y),s,HORIZONTAL_ALIGNMENT_LEFT,-1,px,c)
func seg(x: float,y: float,xx: float,yy: float,c:=GOLD,width:=2.) -> void:
	draw_line(Vector2(x,y),Vector2(xx,yy),c,width,true)
func dot(x: float,y: float,r: float,c: Color) -> void:draw_circle(Vector2(x,y),r,c,true,-1,true)
func panel(x: float,y: float,w: float,h: float,c: Color) -> void:draw_rect(Rect2(x,y,w,h),c)
func tag(s: String) -> void:txt(12,22,s,14,GOLD)
func waves(x: float,y: float,w: float) -> void:
	for j in 3:
		var pts:=PackedVector2Array()
		for k in range(0,int(w),3):pts.append(Vector2(x+k,y+j*7+sin(k*.19+j)*2))
		if pts.size()>1:draw_polyline(pts,JADE,1.4,true)
func _draw() -> void:
	if rule==null:return
	var scale_:float=minf(size.x/230.,size.y/188.)
	draw_set_transform((size-Vector2(230,188)*scale_)*.5,0,Vector2.ONE*scale_)
	var v:Array=rule.v;var g:Array=rule.goal;var d:Dictionary=rule.data;var h:String=rule.house
	match h:
		"farmhouse","garden":
			tag("畦下水尺" if h=="farmhouse" else "花窗 · 六枝")
			if h=="farmhouse":
				for i in 3:
					var y:=54.+i*40;seg(20,y+13,212,y+13,Color("817459"),4.)
					for n in g[i]:
						var x:float=35.+n*21;seg(x,y+11,x,y-9,MUTED);seg(x,y+2,x-7,y-4,JADE,3.)
						if n<v[i]:dot(x+6,y+8,4.,JADE)
					txt(159,y+5,rule.CROPS[i],15)
			else:
				for half in 2:
					var trunk_x:=53.+half*116.
					for k in [1,2]:
						var id:int=half*3+k
						if id in d.shadows:
							var at:=Vector2(trunk_x+(-35 if k==1 else 35),71 if k==1 else 64)
							draw_arc(at,16,0,TAU,24,JADE if id in v else RED,2.5,true)
					var root:=Vector2(53+half*116,154);var fork:=root+Vector2(0,-54)
					if half*3 in v:continue
					draw_line(root,fork,GOLD,5,true)
					for k in 3:
						var id:int=half*3+k
						if id in v:continue
						var end:=fork+Vector2([0,-35,35][k],[-61,-29,-36][k]);draw_line(fork,end,GOLD,3,true)
						for n in d.blooms[id]:dot(end.x+cos(n*2.4)*8,end.y+sin(n*2.4)*9,4,RED)
		"hostel":
			tag("驿路 · 每横竖一格一里")
			for i in 5:seg(30+i*39,35,30+i*39,151,Color(MUTED,.3));seg(30,35+i*29,186,35+i*29,Color(MUTED,.3))
			var prev:=Vector2(30,93)
			for stop in v:
				var next:=Vector2(30+d.x[stop]*39,35+d.y[stop]*29)
				draw_line(prev,Vector2(next.x,prev.y),GOLD,3,true);draw_line(Vector2(next.x,prev.y),next,GOLD,3,true);prev=next
			for i in 3:
				var x:float=30+d.x[i]*39;var y:float=35+d.y[i]*29
				dot(x,y,6,RED);txt(x-17,y-7,rule.LANDINGS[i],13)
			txt(10,117,"西门",13);txt(179,117,"东门",13)
		"post":
			tag("驿路信札");var card:Array=d.cards[mini(rule.step,4)]
			panel(19,47,190,99,CREAM);seg(19,47,113,104,Color("a59575"));seg(113,104,209,47,Color("a59575"))
			txt(33,128,card[1]+"　收",19,DARK)
			if card[3]:panel(102,55,103,28,Color("984e3e"));txt(108,75,"转 "+card[4],14)
		"guild","ferry":
			tag("两岸 · 船舱" if h=="guild" else "候潮泊位 · 三船")
			for j in (1 if h=="guild" else 3):
				var x:=32.+j*63.;var y:=90.+sin(j+1)*9
				if h=="guild":x=32+105*int(v[3])
				piece(5,Vector2(x+9,y-11),Vector2(59,57))
				if h=="ferry":txt(x-9,y+48,rule.BOATS[j],14);txt(x-3,y+69,"候" if v[j]<0 else rule.TIDE_NAMES[v[j]],14,GOLD)
			waves(11,114,205)
			if h=="guild":txt(12,155,"西岸",15);txt(174,155,"东岸",15)
		"oil":
			tag("戥秤 · 秤平即成")
			var tilt:=clampf((rule.weight()-int(d.mass))*.035,-.30,.30);var bar:=Vector2.from_angle(tilt)*78;var pivot:=Vector2(112,71)
			draw_line(pivot-bar,pivot+bar,GOLD,4,true);seg(112,62,112,147,GOLD,4)
			for side in [-1,1]:
				var end:Vector2=pivot+bar*side;draw_line(end,end+Vector2(-18,38),MUTED);draw_line(end,end+Vector2(18,38),MUTED)
				draw_arc(end+Vector2(0,25),22,.37,2.77,28,GOLD,4,true)

		"herbal":
			tag("百草谱 · 验叶")
			panel(9,31,211,104,Color("dac6a0"));panel(12,34,205,98,Color("ebd9b4"))
			var herb:Array=rule.HERBS[g[mini(rule.step,1)]]
			var thin:bool=1 in v and herb[2]=="长条"
			var width_:float=7. if thin else 16.
			var stalk:=Vector2(87,124)
			seg(stalk.x,stalk.y,103,43,Color("73815b"),2.5)
			for j in 5:
				var base:=stalk+Vector2(3*j,-14*j)
				var axis:=Vector2((1 if j%2 else -1)*(33 if not thin else 22),-28 if thin else -21)
				var normal:=axis.orthogonal().normalized()
				var leaf:=PackedVector2Array()
				for side in [-1,1]:
					for k in 13:
						var t:=k/12. if side==-1 else 1.-k/12.
						var tooth:=.74 if 1 in v and herb[2]=="锯齿" and k%2 else 1.
						leaf.append(base+axis*t+normal*side*width_*sin(t*PI)*tooth)
				draw_colored_polygon(leaf,Color("78926a") if j%2 else Color("648361"))
				draw_line(base,base+axis,Color("d3d2a0"),1.2,true)
				for k in [3,6,9]:
					var t:float=k/12.
					for side in [-1,1]:draw_line(base+axis*t,base+axis*(t+.10)+normal*side*width_*.6*sin(t*PI),Color("bec59c"),1,true)
			for k in 3:
				txt(150,64+k*25,herb[k+1] if k in v else "待"+["摸","看","闻"][k],15,DARK)
				panel(7+k*73,145,68,32,Color("899e83") if k in v else Color("d1b68d"))
				txt(15+k*73,166,rule.labels[k],15,DARK)
		"noodle","banquet":
			tag("砧板 · 下刀刻度" if h=="noodle" else "御宴 · 顺时针传盘")
			if h=="noodle":
				panel(8,52,214,108,Color("94714f"));panel(11,55,208,102,Color("b99366"))
				for j in 5:seg(16,82+j*5,214,82+j*5,CREAM,3)
				for n in range(1,d.length):
					var x:=16+n*198./int(d.length)
					if n in v:seg(x,78,x,110,Color("70503a"),4)
					seg(x,111,x,120,DARK,1);txt(x-5,139,str(n),13,DARK)

			else:
				for i in 4:
					var pos:=Vector2(110,102)+Vector2.from_angle(i*PI*.5)*61
					dot(pos.x,pos.y,24,Color("bf9b6d"));dot(pos.x,pos.y,20,Color("684f40"));txt(pos.x-5,pos.y+7,str(v[i]),20)
		"pickle","lacquer":
			tag("量瓮 · 水位" if h=="pickle" else "漆片 · 试色")
			for i in 2:
				var x:=33+i*91
				if h=="pickle":
					panel(x,47,65,94,Color("657e70"));panel(x+5,135-82.*v[i]/g[i],55,82.*v[i]/g[i],JADE);txt(x+11,165,"%d / %d"%[v[i],g[i]],15)
				else:
					var mix:Array=g if i==0 else v
					var col:=Color("aa9d7c");var total:float=mix[0]+mix[1]+mix[2]
					if total>0:col=(Color("c54632")*float(mix[0])+Color("c7a351")*float(mix[1])+Color("383b34")*float(mix[2]))/total;col.a=1
					dot(x+29,95,36,CREAM);dot(x+29,95,31,col);txt(x+12,155,"旧样" if i==0 else "试漆",17)
		"potter":
			tag("金线样坯 · 侧影")
			var body:=PackedVector2Array()
			var outline:=PackedVector2Array()
			for side in [-1,1]:
				var edge:=PackedVector2Array()
				for k in 33:
					var u:float=k/32.;var section:=0 if u<.5 else 1
					var t:=smoothstep(0.,1.,fmod(u*2.,1.) if k<32 else 1.)
					var radius:=12.+9.*lerpf(v[section],v[section+1],t)
					var target_radius:=12.+9.*lerpf(g[section],g[section+1],t)
					var yy:=52.+u*92.
					edge.append(Vector2(114+side*radius,yy))
					outline.append(Vector2(114+side*target_radius,yy))
				if side==1:edge.reverse()
				body.append_array(edge)
			draw_colored_polygon(body,Color("bf8669"))
			for k in range(4,30,3):
				var left:=body[k];var right:=body[65-k]
				draw_line(left+Vector2(3,0),right-Vector2(3,0),Color("ac785e"),1.2,true)
			var rim:=float(12+9*v[0])
			draw_set_transform((size-Vector2(230,188)*scale_)*.5+Vector2(114,52)*scale_,0,Vector2(scale_,scale_*.20))
			draw_circle(Vector2.ZERO,rim,Color("7f5548"),true,-1,true)
			draw_arc(Vector2.ZERO,rim,0,TAU,48,Color("e0aa86"),4.,true)
			draw_set_transform((size-Vector2(230,188)*scale_)*.5,0,Vector2.ONE*scale_)
			draw_polyline(outline.slice(0,33),GOLD,2,true);draw_polyline(outline.slice(33),GOLD,2,true)
			seg(62,152,166,152,MUTED,5.)
		"weave","tailorhome":
			draw_handwork()
		"drum","fiddler","dojo","duty","pipa","music","stage":draw_performance()
		"incense":
			tag("香托 · 从大到小")
			for i in 3:
				var x:=44+i*70;seg(x,51,x,147,GOLD,3)
				for j in v[i].size():
					var width_:int=5+v[i][j]*6;seg(x-width_,140-j*12,x+width_,140-j*12,RED if i==rule.picked else JADE,9)
				txt(x-16,171,rule.labels[i],15)
		"academy":
			tag("书院 · 石棋")
			for i in v[0]:dot(32+i%6*33,57+i/6*31,10,JADE if i%2 else GOLD)
		"kiln":
			tag("窑口 · 四段火谱")
			piece(9,Vector2(170,46),Vector2(64,46))
			for i in 4:
				var height_:int=10+g[i]*4;panel(19+i*49,142-height_,34,height_,RED if i==rule.step else Color("8e7960"));txt(26+i*49,164,str(g[i]),16)
		"audience":
			tag("三坊奏本 · 朱批")
			for i in 3:
				var x:=14.+i*71
				panel(x,39,61,105,CREAM);panel(x-2,37,65,5,GOLD);panel(x-2,143,65,4,GOLD)
				txt(x+4,65,d.case[i+1],12,DARK);txt(x+10,92,"%d 签"%d.cost[i],16,DARK)
				if i in v:dot(44+i*71,121,13,Color("ac543e"));txt(36+i*71,127,"准",16)
		"baihe","books","poetry","ledger":
			panel(14,24,202,139,CREAM)
			for j in 5:seg(24,47+j*23,204,47+j*23,Color("c7ad82"),1)
			match h:
				"baihe":
					for j in 4:
						var x:=12.+j*52
						panel(x,58,47,68,Color("d8aa70") if j==rule.picked else Color("d9c39c"))
						seg(x+3,63,x+44,63,Color("99734b"));txt(x+5,99,v[j],18,DARK)
				"books":
					txt(24,60,"墨本",13,DARK);txt(64,62,d.lines[mini(rule.step,2)][0],19,DARK)
					txt(24,94,"点抄本里的错字",14,DARK)
					for j in 5:
						panel(14+j*40,106,37,39,Color("dec7a0"));txt(23+j*40,134,rule.labels[j],21,DARK)
				"poetry":
					if rule.deal%6==0:piece(5,Vector2(161,94),Vector2(71,60))
					elif rule.deal%6==1:dot(168,65,15,GOLD);waves(125,118,74)
					elif rule.deal%6==2:
						waves(123,109,70);seg(145,91,155,83,DARK);seg(155,83,166,89,DARK)
					else:
						seg(137,124,171,59,DARK,2.)
						for j in 3:flower(Vector2(149+7*j,98-j*12),7,0,RED)
					txt(27,104,"".join(v)+"□".repeat(3-v.size()),27,DARK)
				"ledger":txt(31,67,"米行流水",21,DARK);txt(31,102,"%d 担　每担 %d 钱"%[d.bags,d.price],16,DARK);txt(31,138,"预付　%d 钱"%d.paid,18,DARK)

func flower(p: Vector2,r: float,motif: int,col: Color) -> void:
	if motif==0:
		for j in 5:
			var petal:=p+Vector2.from_angle(j*TAU/5.)*r*.6;draw_circle(petal,r*.45,col,true,-1,true)
		draw_circle(p,r*.25,GOLD,true,-1,true)
	elif motif==1:
		for k in 3:
			var leaf:=p+Vector2((k-1)*r*.5,0);draw_line(leaf+Vector2(-r*.25,r*.7),leaf+Vector2(r*.3,-r*.7),col,r*.23,true)
	else:
		for k in 3:draw_arc(p+Vector2(0,(k-1)*r*.36),r,-2.65,-.5,16,col,2,true)

func draw_handwork() -> void:
	var h:String=rule.house;var d:Dictionary=rule.data;var v:Array=rule.v
	match h:
		"weave":
			tag("旧锦 · 断口")
			for k in rule.goal.size()+2+rule.step:
				var pattern:int=rule.goal[(k+int(d.offset))%rule.goal.size()]
				for j in 2:
					var on:=pattern in ([0,2] if j==0 else [1,2])
					panel(18+k*20,63+j*31,18,28,GOLD if on else Color("607e79"))
			txt(18,153,"左综 ▮·　右综 ·▮",17)
		"tailorhome":
			tag("绣线 · 交叉口")
			for i in 5:
				if i in v:continue
				var hue:Color=[RED,Color("89a4d4"),GOLD,JADE,CREAM][i]
				var y:=42+i*25;seg(52,y,202,y,hue,5);txt(10,y+5,rule.THREADS[i],14)
				for top in d.above[i]:
					if top in v:continue
					var x:float=71+top*25;seg(x,y-8,x,y+8,DARK,9);seg(x,y-8,x,y+8,[RED,Color("89a4d4"),GOLD,JADE,CREAM][top],5)

func draw_performance() -> void:
	var h:String=rule.house;var d:Dictionary=rule.data
	match h:
		"drum":
			tag("更鼓 · 联动双环")
			for j in 2:
				var p:=Vector2(62+j*102,98);draw_arc(p,39,0,TAU,50,CREAM,2,true)
				for k in 6:
					var at:=p+Vector2.from_angle(k*TAU/6-PI*.5)*35;dot(at.x,at.y,3,RED if rule.goal[j]==k else MUTED)
				draw_line(p,p+Vector2.from_angle(rule.v[j]*TAU/6-PI*.5)*31,GOLD,4,true)
		"stage":
			tag("枕河戏台 · 换幕")
			for i in 4:
				var x:=31.+i*54
				if stage_pair.size()==2 and i in stage_pair:x+=54.*(int(stage_pair[1-stage_pair.find(i)])-i)*travel
				panel(x-18,62,39,71,Color("8b493f"));seg(x-18,65,x+21,65,GOLD,3);txt(x-9,108,stage_cast[i] if show_faces and stage_cast.size()==4 else "幕",19)
			seg(9,139,222,139,GOLD,4)
		"dojo":
			tag("梅花桩 · 等金环收拢")
			for i in 2:
				var at:=Vector2(65+i*99,100);draw_circle(at,24,Color("846447"));draw_arc(at,24,0,TAU,48,GOLD,2,true)
				if i==rule.goal[mini(rule.step,rule.goal.size()-1)]:draw_arc(at,24+minf(pulse,1.-pulse)*62.,0,TAU,55,JADE,4,true)
				txt(at.x-9,at.y+6,"左" if i==0 else "右",20)
		"fiddler":
			tag("试弦 · 音高")
			var j:=mini(rule.step,1)
			for i in 2:
				var n:int=rule.goal[j] if i==0 else rule.v[j];var line:=PackedVector2Array()
				for k in 179:line.append(Vector2(36+k,67+i*64+sin(k*.1*pow(1.1,n))*10))
				draw_polyline(line,GOLD if i==0 else JADE,2,true);txt(8,70+i*64,"定" if i==0 else "弦",16)
		"duty","pipa","music":
			tag({"duty":"钟楼 · 船令","pipa":"琴社 · 五弦","music":"听韶 · 青铜编磬"}[h])
			if h=="duty":
				piece(11,Vector2(113,102),Vector2(137,128))
				if flash>=0:draw_arc(Vector2(114,115),62,.2,2.9,42,GOLD,2,true)
				return
			for i in 5:
				var x:=22+i*44;var ht:=32+i*6
				seg(x+12,43,x+12,62,MUTED)
				if h=="pipa":seg(x+12,45,x+12,143,RED if flash==i else GOLD,4 if flash==i else 2)
				else:draw_colored_polygon(PackedVector2Array([Vector2(x+9,59),Vector2(x+25,67),Vector2(x+19,68+ht),Vector2(x-3,64+ht)]),RED if flash==i else GOLD)
				txt(x+4,162,["宫","商","角","徵","羽"][i],15)
