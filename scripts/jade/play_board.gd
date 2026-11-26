extends RefCounted
## One reproducible deal for the player and the authority. The receipt advances only that shop.
const Games=preload("res://scripts/jade/house_games.gd")
const MAX_MOVES=160
const WATER=preload("res://scripts/jade/rounds/waterways.gd")
const CRAFT=preload("res://scripts/jade/rounds/workshop.gd")
const MARKET=preload("res://scripts/jade/rounds/market.gd")
const BOOK=preload("res://scripts/jade/rounds/scholars.gd")
const MUSIC=preload("res://scripts/jade/rounds/performance.gd")
var house: String
var serial: int
var variant: int
var deal_base: int
var moves: Array=[]
var rule: RefCounted

func _init(id: String,round_number:=0,edition:=0,first_deal:=-1) -> void:
	house=id;serial=round_number;variant=edition
	deal_base=serial if first_deal<0 else first_deal
	match id:
		"weir","farmhouse","sail","guild","ferry","hostel","post","archive":rule=WATER.new()
		"basket","weave","stitch","carver","tailorhome","paper","lacquer","potter","silversmith","kiln":rule=CRAFT.new()
		"oil","herbal","pastry","noodle","banquet","ledger","pickle","garden","incense":rule=MARKET.new()
		"drum","baihe","caligraphy","poetry","books","academy","audience","chamber":rule=BOOK.new()
		"pipa","stage","fiddler","duty","music","dojo":rule=MUSIC.new()
	rule.prepare(id,deal_base+variant)

func play(input: int) -> bool:
	if rule.done or moves.size()>=MAX_MOVES or input<0:return false
	var button:=input
	if house=="dojo":
		if input>=16:return false
		button=input%2
	if button>=rule.labels.size() or not rule.enabled(button):return false
	if house=="music" and button==6:return false # Audition is playback only.
	rule.note=""
	rule.act(input)
	rule.refresh()
	moves.append(input)
	return true

func undo() -> void:
	if moves.is_empty():return
	var prefix:=moves.slice(0,-1)
	moves=[]
	rule=rule.get_script().new()
	rule.prepare(house,deal_base+variant)
	for n in prefix:play(n)

static func safe_number(value: Variant,maximum: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and value>=0 and value<=maximum and value==int(value)

static func normalize(raw: Variant) -> Dictionary:
	var journal:={"marks":[],"letter":"","rounds":{},"next_deals":{},"prints":[],"song":[],"decree":{}}
	if not raw is Dictionary:return journal
	var ids: Array=Games.STATIONS.keys()+Games.PERFORMANCES.keys()
	for h in ids:
		if raw.get("next_deals") is Dictionary and safe_number(raw.next_deals.get(h),2000000000):journal.next_deals[h]=int(raw.next_deals[h])
		if raw.get("rounds") is Dictionary and safe_number(raw.rounds.get(h),100000000):journal.rounds[h]=int(raw.rounds[h])
		if Games.STATIONS.has(h) and raw.get("marks") is Array and h in raw.marks:
			journal.marks.append(h)
			if not journal.rounds.has(h):journal.rounds[h]=1
	if raw.get("letter") in ["post","hostel"]:journal.letter=raw.letter
	if raw.get("prints") is Array:
		for sheet in raw.prints.slice(-6):
			var clean:=clean_print(sheet)
			if clean.size():journal.prints.append(clean)
	if raw.get("song") is Array and raw.song.size()<=12 and raw.song.all(func(n):return safe_number(n,5)):
		journal.song=raw.song.map(func(n):return int(n))
	if raw.get("decree") is Dictionary:
		for key in ["0","1","2"]:
			if safe_number(raw.decree.get(key),3):journal.decree[key]=int(raw.decree[key])
	return journal

static func clean_print(sheet: Variant) -> Array:
	if not sheet is Array or sheet.size()>8:return []
	var clean: Array=[]
	for layer in sheet:
		if not layer is Array or layer.size()!=3 or not safe_number(layer[0],8) or not safe_number(layer[1],2) or not safe_number(layer[2],2):return []
		clean.append([int(layer[0]),int(layer[1]),int(layer[2])])
	return clean

static func finish(authority: RefCounted,command: Dictionary) -> Dictionary:
	var target:=str(command.get("target",""))
	var id:=target.get_slice(":",1)
	var native:=Games.PERFORMANCES.has(id)
	if authority.state.map_id!="jade" or not target.begins_with("jade:") or Games.entry(id).is_empty() or (not native and target!="jade:%s:Trade"%id):
		return authority.fail("回到玉京的案前再试。")
	if not authority.activity_access.is_valid() or not authority.activity_access.call(target,"jade_game") or not authority.job.is_empty() or authority.state.get("rest_mode","")!="":
		return authority.fail("请在这家铺子的案前操作。")
	var journal:Dictionary=authority.state.jade_visits
	var turn:int=journal.rounds.get(id,0)
	if not safe_number(command.get("round"),100000000) or int(command.round)!=turn:return authority.fail("这局已经交过，打开新局再来。")
	if not safe_number(command.get("variant",0),9999):return authority.fail("题签有误。")
	var history: Variant=command.get("moves")
	if not history is Array or history.size()>MAX_MOVES:return authority.fail("这回手艺还没做完。")
	var board=load("res://scripts/jade/play_board.gd").new(id,turn,int(command.get("variant",0)),int(journal.next_deals.get(id,turn)))
	for action in history:
		if not safe_number(action,MAX_MOVES) or not board.play(int(action)):return authority.fail("这局的手势对不上题签。")
	if not board.rule.done:return authority.fail("这回手艺还没做完。")
	journal.rounds[id]=turn+1
	journal.next_deals[id]=(int(board.rule.deal)+1)%2000000000
	var message:String=board.rule.ending
	if id=="paper":
		journal.prints.append(board.rule.data.layers.duplicate(true))
		if journal.prints.size()>6:journal.prints.pop_front()
		authority.add("jade_flower_paper",1);message+=" 成品已入建造仓库，可挂自家墙上。"
	if id=="music":journal.song=board.rule.v.duplicate()
	if id=="audience":
		journal.decree={}
		for district in board.rule.v:journal.decree[str(district)]=board.rule.deal%4
	if id in ["hostel","post"]:
		if journal.letter!="" and journal.letter!=id:
			journal.letter="";message+=" 来信已交到收件人手上。"
		elif journal.letter=="":
			journal.letter=id;message+=" 另捎一袋信去"+("驿路茶棚。" if id=="hostel" else "旧渡驿舍。")
	if not native and id not in journal.marks:
		journal.marks.append(id)
		authority.state.coins+=6
		message+="　初得坊印 · 六贝"
		if Games.TAKE_HOME.has(id):
			var item_id:String=Games.TAKE_HOME[id];authority.add(item_id,1)
			message+="，另收下"+str(preload("res://scripts/services/game_data.gd").item(item_id).name)
		var gifts:Dictionary={6:["jade_lamp","南津纱灯"],18:["jade_screen","折枝花鸟屏"],Games.STATIONS.size():["jade_chime","听风编磬"]}
		if gifts.has(journal.marks.size()):
			var gift:Array=gifts[journal.marks.size()];authority.add(gift[0],1);message+="。坊邻合赠「%s」。"%gift[1]
	elif not native:
		authority.state.coins+=2;message+="　回访谢礼 · 两贝"
	return {"ok":true,"message":message}
