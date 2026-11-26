extends "res://scripts/jade/rounds/round.gd"

const NOTES=["宫","商","角","徵","羽"]
const MASKS=["生","旦","净","丑"]
const SIGNALS=["靠岸","开舱","避浅","起航"]
const CODES=["短长","长短","短短长","长短短"]
const FEET=["左步","右步"]
func setup() -> void:
	theme_index=2
	match house:
		"pipa":
			labels=NOTES.duplicate();columns=5
			for k in 4+mini(2,deal%4):goal.append(rng.randi_range(0,4))
			brief="听船娘弹一小段，再按琴弦应和。看亮弦也能跟弹，错音只需重弹这一音。"
		"stage":
			columns=4
			data.actor=deal%4;var initial:=shuffled(MASKS);data.initial=initial
			data.swaps=[];var cast:=initial.duplicate();var previous:Array=[]
			for k in 3+deal%3:
				var pair:=shuffled(range(4)).slice(0,2);pair.sort()
				if pair==previous:pair[1]=(int(pair[1])+1)%4
				if pair[0]==pair[1]:pair[1]=(int(pair[1])+1)%4
				data.swaps.append(pair);swap(cast,pair[0],pair[1]);previous=pair
			goal=[cast.find(MASKS[data.actor])]
			labels=["一号幕","二号幕","三号幕","四号幕"]
			brief="认准「%s」藏在哪扇幕后，盯着换位的帘子。锣停后点它最后所在的幕。"%MASKS[data.actor]
		"fiddler":
			data.start=[rng.randi_range(-5,-2),rng.randi_range(2,5)]
			if deal%2:data.start.reverse()
			goal=[rng.randi_range(-1,1),rng.randi_range(-1,1)]
			v=[data.start[0],data.start[1]]
			labels=["松三格","松一格","紧一格","紧三格"];columns=4
			brief="比一比定音与琴弦。偏低就紧、偏高就松；远时拨三格，近时微调。两根弦都要合音。"
		"duty":
			labels=SIGNALS.duplicate();columns=4
			goal=shuffled(range(4)).slice(0,3)
			brief="码头用磬声传船令。对照案上的长短信谱，点对应旗令。三道都传准，船队就能过闸。"
		"music":
			labels=NOTES.duplicate();labels.append_array(["休止","试听","收曲"]);columns=5
			data.tonic=deal%5
			brief="作一段自己的迎宾曲，至少六拍。放一个休止，弹过三种音，最后落在「%s」。可随时试听。"%NOTES[data.tonic]
		"dojo":
			labels=FEET.duplicate();columns=2
			goal=[deal%2]
			for k in 4+deal%3:goal.append(rng.randi_range(0,1))
			data.tempo=[.82,.76,.88,.72][deal%4]
			brief="金环合上鼓心时，踏亮起的那只脚。可点脚印，或按左右方向键。偏拍后跟住下一拍即可。"
func enabled(i: int) -> bool:
	if house=="music":
		if i==6:return not v.is_empty()
		if i==7:return composition_ready()
		return v.size()<12
	return true
func composition_ready() -> bool:
	var tones:Array=[]
	for n in v:
		if n<5 and n not in tones:tones.append(n)
	return v.size()>=6 and v.back()==data.tonic and 5 in v and tones.size()>=3
func refresh() -> void:
	match house:
		"pipa":status="南渡船调　·　应和 %d / %d 音"%[step,goal.size()]
		"stage":status="找「%s」　·　共 %d 次换幕　·　随时可重看"%[MASKS[data.actor],data.swaps.size()]
		"fiddler":
			var at:=mini(step,1)
			var diff:int=v[at]-goal[at]
			status="%s弦　·　%s　·　%s"%["外" if at==0 else "内","弦音偏低" if diff<0 else ("弦音偏高" if diff>0 else "同音"),"相距较远" if absi(diff)>2 else "只差毫厘"]
		"duty":status="第 %d / 3 令　·　%s"%[mini(step+1,3),"　".join(["靠岸 短长","开舱 长短","避浅 短短长","起航 长短短"])]
		"music":
			var bars:Array=[]
			for n in v:bars.append("休" if n==5 else NOTES[n])
			status="落音 %s　·　%d / 12 拍　｜　%s"%[NOTES[data.tonic],v.size(),numbers(bars," ") if v.size() else "点磬起曲"]
		"dojo":status="第 %d / %d 拍　·　%s"%[mini(step+1,goal.size()),goal.size(),FEET[goal[mini(step,goal.size()-1)]]]
func act(i: int) -> void:
	match house:
		"pipa":
			if i!=goal[step]:wrong("这一弦走偏了，再拨当前这一音。");return
			step+=1
			if step==goal.size():win("末音落下，河对岸接上了你的船歌。")
		"stage":
			if i==goal[0]:win("帘子一揭，%s刚好踩着锣点亮相。"%MASKS[data.actor])
			else:wrong("这扇帘里没有要找的角儿。可以重看换幕。")
		"fiddler":
			v[step]=clampi(int(v[step])+int([-3,-1,1,3][i]),-8,8)
			if v[step]==goal[step]:
				step+=1
				if step==2:win("两弦齐平，琴师把弦轸轻轻压牢。")
				else:note="外弦定好了，现在调第二根。"
		"duty":
			if i==goal[step]:
				step+=1
				if step==3:win("旗手回了三声号，船队缓缓过闸。")
			else:wrong("旗语和这一串磬声对不上。可重听长短。")
		"music":
			if i==7:win("听韶台收下了这段新谱，余音穿过殿廊。")
			elif i<6:v.append(i)
		"dojo":
			var foot:=i%2;var phase:=i/2
			if foot!=goal[step]:wrong("换另一只脚，跟下一拍。");return
			if phase not in [0,1,6,7]:wrong("脚步到了，鼓心还未合上。");return
			step+=1
			if step==goal.size():win("一套梅花步收势，最后一拍踏得又轻又稳。")
