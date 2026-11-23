extends RefCounted
## The bench and the authority replay the same moves. Only a finished round can earn its seal.
const Games=preload("res://scripts/jade/house_games.gd")
const MAX_MOVES=96
var house: String
var recipe: Dictionary
var game: String
var values: Array=[]
var picked:=-1
var step:=0
var done:=false
var note:=""
var moves: Array=[]
func _init(id: String) -> void:
	house=id
	recipe=Games.STATIONS[id]
	game=recipe.game
	match game:
		"weights","pigment","allot","clock","abacus":values=[0,0,0]
		"wheel":values=[1,1,1]
		"seats","press":values=recipe.goal.duplicate()
		"mirror","weave":values=[0,0,0,0,0,0,0,0,0]
		"jugs":values=[0,0]
		"tune":values=[0]
		"sail":values=[recipe.goal[0]]
		"sluice":values=[0,0,0]
		"divide":values=[recipe.goal.reduce(func(a,b):return int(a)+int(b),0)]
		"tower":values=[[3,2,1],[],[]]
		"cross":values=[0,0,0,0]
func options() -> Array:
	match game:
		"weave","mirror","stitch","stars":return range(9)
		"proof":return range(str(recipe.goal[mini(step,recipe.goal.size()-1)]).length())
		"forge":return ["落槌" if house=="silversmith" else "封风口"]
		"jugs":return ["装满大瓮","装满小瓮","大倒小","小倒大","倒空大瓮","倒空小瓮"]
		"sluice":return ["上游","渠腰","田口"]
		"sail":return ["向北","向东","向南","向西"]
		"divide":return values.map(func(v):return "%d 份"%v)
		_:return recipe.labels
func play(choice: int) -> void:
	if done or moves.size()>=MAX_MOVES:return
	var count:=8 if game=="forge" else options().size()
	if choice<0 or choice>=count:return
	moves.append(choice)
	var goal: Array=recipe.goal
	note=""
	match game:
		"weights":
			values[choice]=1-int(values[choice])
			var weight:=0
			for i in range(3):weight+=int(values[i])*int(goal[i])
			done=weight==goal[3]
		"pigment","allot":
			values[choice]+=1
			if values[choice]>goal[choice]:
				values=[0,0,0]
				note="这钵色偏了，洗笔再调。" if game=="pigment" else "拨出的签多了，收回来重分。"
			done=values==goal
		"clock":
			values[choice]=(int(values[choice])+1)%6
			if choice==0:values[1]=(int(values[1])+1)%6
			done=values.slice(0,2)==goal
		"sluice":
			values[choice]=(int(values[choice])+1)%4
			done=wet_joints()==3
		"wheel","abacus":
			values[choice]=(int(values[choice])+1)%(5 if game=="wheel" else 10)
			done=values.slice(0,goal.size())==goal
		"press":
			for i in range(maxi(0,choice-1),mini(3,choice+2)):values[i]=1-int(values[i])
			done=values==[1,1,1]
		"seats":
			if picked<0:picked=choice
			else:
				var temp: int=values[choice]
				values[choice]=values[picked];values[picked]=temp;picked=-1
			done=values==[0,1,2]
		"weave","mirror":
			values[choice]=1-int(values[choice])
			done=true
			for i in range(9):
				var source:=i-i%3+2-i%3 if game=="mirror" else i
				if values[i]!=goal[source]:done=false
		"jugs":
			var cap: Array=goal.slice(0,2)
			if choice<2:values[choice]=cap[choice]
			elif choice<4:
				var a:=choice-2;var b:=1-a
				var n:=mini(values[a],cap[b]-values[b])
				values[a]-=n;values[b]+=n
			else:values[choice-4]=0
			done=values[0]==goal[2]
		"sail":
			var cell:=int(values[0])
			var move:=Vector2i([Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][choice])
			var pos:=Vector2i(cell%3,cell/3)+move
			if pos.y==0 and move==Vector2i.RIGHT:pos+=Vector2i.RIGHT
			if not Rect2i(0,0,3,3).has_point(pos) or pos.y*3+pos.x==goal[2]:note="蹭了滩，退回上一处水面。"
			else:values[0]=pos.y*3+pos.x
			done=values[0]==goal[1]
		"divide":
			var amount:=int(values[choice])
			if amount>=2:
				values[choice]=amount/2;values.insert(choice+1,amount/2)
			var sorted:=values.duplicate()
			sorted.sort();sorted.reverse()
			done=sorted==goal
		"cross":
			var bank:=int(values[3])
			if choice<3 and values[choice]!=bank:
				note="这一位在对岸。";return
			var old:=values.duplicate()
			values[3]=1-bank
			if choice<3:values[choice]=1-bank
			if values[1]==bank and (values[0]==bank or values[2]==bank):
				values=old;note="岸上乱作一团！这一趟得换个伴。"
			done=values==[1,1,1,1]
		"tower":
			if picked<0:
				if not values[choice].is_empty():picked=choice
			else:
				var source:=picked;picked=-1
				if source==choice:return
				if values[choice].is_empty() or values[choice].back()>values[source].back():
					values[choice].append(values[source].pop_back())
				else:note="下面这层太小，托不住。"
			done=values[2].size()==3
		"tune":
			values[0]=clampi(values[0]+(-1 if choice==0 else 1),-3,6)
			done=values[0]==goal[0]
		"proof":
			if recipe.labels[step][choice]!=goal[step][choice]:step+=1
			else:note="这个字和底本一样，再比比旁边。"
			done=step==goal.size()
		"forge","stitch","verse","stars","memory","melody":
			if choice==goal[step]:
				step+=1
			else:
				step=0
				note={"forge":"没赶上火候，听稳下一拍。","melody":"走了音，再从头弹一遍。","stitch":"线绕住了，从朱点重新起。","verse":"字意接不上，另拣一笺。","memory":"帘后有人走错了场，再叫一回。","stars":"星线断了，从第一颗接起。"}.get(game,"")
			done=step==goal.size()

# Compass order N, E, S, W. Each downstream elbow accepts water only through a facing port.
func ports(i: int) -> Array:
	var turn:=int(values[i])
	return [turn,(turn+(2 if i==0 else 1))%4]
func wet_joints() -> int:
	var outlets: Array=[1,0,1] if house=="weir" else [1,2,1]
	var inlet:=3
	for i in 3:
		var ends:=ports(i)
		if inlet not in ends or outlets[i] not in ends:return i
		inlet=(int(outlets[i])+2)%4
	return 3

static func normalize(raw: Variant) -> Dictionary:
	var marks: Array=[]
	if raw is Dictionary and raw.get("marks") is Array:
		for id in Games.STATIONS:
			if id in raw.marks:marks.append(id)
	var letter: String=str(raw.get("letter","")) if raw is Dictionary else ""
	return {"marks":marks,"letter":letter if letter in ["hostel","post"] else ""}
static func finish(authority: RefCounted,command: Dictionary) -> Dictionary:
	var target:=str(command.get("target",""))
	var house_id:=target.get_slice(":",1)
	if authority.state.map_id!="jade" or not Games.STATIONS.has(house_id) or target!="jade:%s:Trade"%house_id:
		return authority.fail("回到玉京的案前再试。")
	if not authority.activity_access.is_valid() or not authority.activity_access.call(target,"jade_game") or not authority.job.is_empty() or authority.state.get("rest_mode","")!="":
		return authority.fail("请在这家铺子的案前操作。")
	var logbook: Dictionary=authority.state.jade_visits
	if Games.STATIONS[house_id].game=="courier":
		var sender:=str(logbook.letter)
		if sender==house_id:return authority.fail("这袋信还要送到另一处驿站。")
		if sender.is_empty():
			logbook.letter=house_id
			return {"ok":true,"message":"驿袋系好了，捎往"+("桥边的驿路茶棚。" if house_id=="hostel" else "南市旧渡驿舍。")}
		logbook.letter=""
	else:
		var history: Variant=command.get("moves")
		if not history is Array or history.size()>MAX_MOVES:return authority.fail("这回手艺还没做完。")
		var board=load("res://scripts/jade/play_board.gd").new(house_id)
		for input in history:
			if typeof(input) not in [TYPE_INT,TYPE_FLOAT] or input!=int(input) or input<0 or input>96:return authority.fail("手势不对。")
			board.play(int(input))
		if not board.done:return authority.fail("这回手艺还没做完。")
	var message: String=Games.STATIONS[house_id].end
	if house_id not in logbook.marks:
		logbook.marks.append(house_id)
		authority.state.coins+=6
		message+="  ·  初得坊印，谢礼六贝"
		if Games.TAKE_HOME.has(house_id):
			var item_id: String=Games.TAKE_HOME[house_id]
			authority.add(item_id,1)
			message+="，另收下"+str(preload("res://scripts/services/game_data.gd").item(item_id).name)
		var gifts: Dictionary={6:["jade_lamp","南津纱灯"],18:["jade_screen","折枝花鸟屏"],Games.STATIONS.size():["jade_chime","听风编磬"]}
		if gifts.has(logbook.marks.size()):
			var gift: Array=gifts[logbook.marks.size()]
			authority.add(gift[0],1)
			message+="。坊邻合赠「%s」，已收进建造仓库。"%gift[1]
	return {"ok":true,"message":message}
