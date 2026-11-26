extends "res://scripts/jade/rounds/round.gd"

# Each budget admits both a frugal two-field canal and a longer branch to the fish pond.
const CANALS=[
	["桑堤","...R.#S...##..#..M#.F...",9],["北岸",".F.##R...#.......MS..#..",10],
	["石梁",".....#S.#..R..#.M...#F##",10],["芦湾","F.....#.#..R.....MS...##",10],
	["稻埂","S...R..#.....#.F#.##..#M",10],["曲堤","....R.#F..##.#.M..S...#.",9],
	["石汊","S...R#..##...#.F#.#...M.",11],["东陂","#....#....R..##M.FS..#..",9]]
const WIND=["北","东","南","西"]
const LANDINGS=["春漆作","织户院","南货行"]
const DISTRICTS=["南市","西坊","宫城"]
const ADDRESSES=[["杏仁油坊","旧渡驿舍","南津帆作"],["临川书院","刻印作","溪石窑"],["含章殿","栖梧宫","听韶台"]]
const TIDE_NAMES=["卯","辰","巳","午","未","申"]
const BOATS=["粮船","盐船","客船"]
const CROPS=["苗圃","桑垄","菜畦"]

func setup() -> void:
	theme_index=4
	match house:
		"weir":
			theme_index=0
			var plan: Array=CANALS[deal%CANALS.size()]
			data={"name":plan[0],"map":plan[1],"wood":plan[2]}
			v=[str(plan[1]).find("S")]
			grid(6,24)
			brief="从泉眼旁点地铺渠，让稻、桑两田喝上水。余料可修堤，也能绕路补鱼塘。"
		"farmhouse":
			theme_index=0
			goal=[0,0,0]
			# Night rain is public. Each daylight watering irrigates exactly one plot.
			var sun:=shuffled([0,1,2,deal%3])
			data.rain=choose([[1,0,1],[0,1,0],[1,1,0],[0,0,1]])
			for i in 3:goal[i]=data.rain[i]+sun.count(i)
			data.turns=[1,2,1,2] if deal%2==0 else [2,1,2,1]
			for i in 4:goal[sun[i]]+=data.turns[i]-1
			v=[0,0,0]
			labels=CROPS.duplicate()
			brief="轮流开四次闸，每次把当轮的来水全给一畦。给夜雨留出空位，让三畦恰好浇足。"
		"sail":
			var rocks: Array=[5,10] if deal%2==0 else [6,9]
			data.wind=[1,2,3,0][deal%4]
			data.reefs=rocks
			var corners:=shuffled([0,3,12,15])
			v=[corners[0]];goal=[corners[1],corners[2]]
			grid(4,16)
			brief="点船边的水面掌舵。顺风多走一格，先靠浮标取货，再进港。礁石会挡船。"
		"guild":
			var cargo: Array=choose([["菜筐","小兔","馋鹅"],["稻谷","麻雀","花猫"],["豆苗","青虫","黄雀"],["鱼干","小猫","猎犬"]])
			labels=shuffled(cargo);labels.append("空船返回")
			data.middle=labels.find(cargo[1]);data.cargo=cargo
			var shore:=deal%2
			v=[shore,shore,shore,shore];goal=[1-shore]
			var outer:=labels.find(cargo[0 if rng.randi()%2 else 2])
			match deal%4:
				1:v[data.middle]=goal[0]
				2:v[data.middle]=goal[0];v[outer]=goal[0];v[3]=goal[0]
				3:v[outer]=goal[0]
			brief="把全员送往%s。每趟可带一位。船工离开后，%s与%s、%s与%s不能独处。"%["东岸" if goal[0] else "西岸",cargo[0],cargo[1],cargo[1],cargo[2]]
			columns=4
		"ferry":
			var slots:=shuffled(range(6)).slice(0,3)
			# Two boats share both windows. The third must take its exclusive tide.
			var shared: Array=[slots[0],slots[1]]
			data.offers=[shared.duplicate(),shared.duplicate(),shared.duplicate()]
			data.offers[deal%2]=[slots[2],choose(shared)]
			for pair in data.offers:pair.sort()
			v=[-1,-1,-1]
			labels=TIDE_NAMES.duplicate();columns=6
			brief="一潮只泊一艘。按船单从上到下点选潮时，给后面的船也留一个可用泊位。"
		"hostel":
			# A small road atlas. Letter pickups may be visited in any order.
			data.x=shuffled([1,2,3]);data.y=shuffled([0,2,4])
			var totals: Array=[]
			for order in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:totals.append(route_length(order,true))
			data.limit=totals.min()
			labels=LANDINGS.duplicate()
			brief="替脚夫排取信路线。从西门出发，三家各走一次，最后到东门装袋。沿街横走、直走各算一里。"
		"post":
			data.cards=[];data.misfiled=0
			var districts:=shuffled([0,1,2,deal%3,(deal+1)%3])
			var revised:=shuffled(range(5)).slice(0,2+deal%2)
			for i in 5:
				var original:int=districts[i]
				var redirect:=i in revised
				var dest: int=(original+rng.randi_range(1,2))%3 if redirect else original
				data.cards.append([original,choose(ADDRESSES[original]),dest,redirect,choose(ADDRESSES[dest])])
			labels=DISTRICTS.duplicate()
			brief="认封面的铺名，对照坊册把信投进驿袋。若盖了改寄朱签，要按新铺名投。每趟有五封。"
		"archive":
			theme_index=3
			grid(4,16)
			var corners: Array=shuffled([0,3,12,15])
			data.beacons=[corners[0],corners[1]]
			if distance(corners[0],corners[1],4)==6:data.beacons[1]=corners[2]
			goal=shuffled(range(16)).filter(func(i):return i not in data.beacons).slice(0,1)
			brief="残图只留下两段里程。横竖走一格算一里，找出同时符合两块界碑的旧仓位置。"

func distance(a: int,b: int,width: int) -> int:
	return absi(a%width-b%width)+absi(a/width-b/width)
func route_length(order: Array,finish: bool) -> int:
	var last:=Vector2i(0,2)
	var total:=0
	for i in order:
		var point:=Vector2i(data.x[i],data.y[i])
		total+=absi(last.x-point.x)+absi(last.y-point.y);last=point
	if finish:total+=absi(last.x-4)+absi(last.y-2)
	return total
func water_ok() -> bool:return str(data.map).find("R") in v and str(data.map).find("M") in v
func landing(i: int) -> int:
	var at:=int(v[0])
	if i not in neighbors(at,4,16) or i in data.reefs:return -1
	var dir: int=WIND.find("东") if i==at+1 else (3 if i==at-1 else (2 if i>at else 0))
	if dir==data.wind:
		var extra:=i+(i-at)
		if extra in neighbors(i,4,16) and extra not in data.reefs:return extra
	return i
func enabled(i: int) -> bool:
	match house:
		"weir":
			if i==24:return water_ok()
			if i in v or data.map[i]=="#" or v.size()>data.wood:return false
			for n in neighbors(i,6,24):
				if n in v:return true
			return false
		"farmhouse":return step<4
		"sail":return landing(i)>=0
		"guild":return i==3 or v[i]==v[3]
		"ferry":return step<3 and i not in v and i in data.offers[step]
		"hostel":return i not in v
		"archive":return i not in data.beacons
	return true
func active(i: int) -> bool:
	match house:
		"weir","hostel","ferry":return i in v
		"sail":return i==v[0]
	return false
func refresh() -> void:
	match house:
		"weir":
			labels=[]
			for i in 24:labels.append({"S":"泉眼","R":"稻田","M":"桑田","F":"鱼塘","#":"岩"}.get(data.map[i],"水" if i in v else ("＋" if enabled(i) else "·")))
			labels.append("交水簿")
			status="%s　·　余料 %d 份　·　通田 %d / 2"%[data.name,int(data.wood)-v.size()+1,int(data.map.find("R") in v)+int(data.map.find("M") in v)]
		"farmhouse":
			status="来水 %s　｜　夜雨 %s"%[numbers(data.turns," → "),numbers(data.rain," / ")]
			labels=[]
			for i in 3:labels.append("%s　%d / %d"%[CROPS[i],v[i],goal[i]])
			if step<4:status+="　｜　本轮 %d 份"%data.turns[step]
		"sail":
			labels=[]
			for i in 16:labels.append("舟" if i==v[0] else ("礁" if i in data.reefs else ("浮标" if i==goal[0] and step==0 else ("港" if i==goal[1] else ("→" if enabled(i) else "≈")))))
			status="向%s的风　·　%s"%[WIND[data.wind],"去浮标取货" if step==0 else "已装货，回港"]
		"guild":
			var banks: Array=[[],[]]
			for i in 4:banks[v[i]].append("船" if i==3 else labels[i])
			status="西岸　%s　　　东岸　%s"%[numbers(banks[0],"·"),numbers(banks[1],"·")]
			labels[3]="空船摆渡"
		"ferry":
			var rows: Array=[]
			for i in 3:
				var slot: Array=data.offers[i]
				rows.append(BOATS[i]+" "+(TIDE_NAMES[v[i]] if v[i]>=0 else TIDE_NAMES[slot[0]]+"或"+TIDE_NAMES[slot[1]]))
			status=numbers(rows,"　｜　")
			if step<3:status+="　　正排"+str(BOATS[step])
		"hostel":
			status="限 %d 里　·　已走 %d 里　·　%s"%[data.limit,route_length(v,v.size()==3),numbers(v.map(func(i):return LANDINGS[i])," → ")]
		"post":
			var card: Array=data.cards[mini(step,4)]
			status="第 %d / 5 封　·　%s"%[mini(step+1,5),"封有改寄朱签" if card[3] else "按原址投递"]
		"archive":
			labels=[]
			for i in 16:labels.append("甲碑" if i==data.beacons[0] else ("乙碑" if i==data.beacons[1] else "·"))
			status="残签　距甲碑 %d 里　·　距乙碑 %d 里"%[distance(goal[0],data.beacons[0],4),distance(goal[0],data.beacons[1],4)]

func act(i: int) -> void:
	match house:
		"weir":
			if i==24:
				win(("鱼塘也满了，渔户送来一尾报春鲤。" if data.map.find("F") in v else "两处田口都到了水。")+"堤上留下 %d 份木料。"%(int(data.wood)-v.size()+1))
			else:v.append(i)
		"farmhouse":
			v[i]+=int(data.turns[step]);step+=1
			if step==4:
				var harvest:=v.duplicate()
				for j in 3:harvest[j]+=data.rain[j]
				if harvest==goal:win("夜雨过后，三畦的水都恰到根边。")
				else:wrong("夜雨后为 %s。撤回一轮，换一畦试试。"%numbers(harvest))
		"sail":
			v[0]=landing(i)
			if step==0 and v[0]==goal[0]:step=1;note="浮货已收，上岸交货。"
			if step==1 and v[0]==goal[1]:win("缆绳套上木桩，这趟风帆送到了货。")
		"guild":
			var bank: int=v[3];var mid: int=data.middle
			v[3]=1-bank
			if i<3:v[i]=1-bank
			if v[mid]==bank and v.slice(0,3).count(bank)>1:
				v[3]=bank
				if i<3:v[i]=bank
				wrong("岸上这两位得有人看着。这趟先别解缆。")
			elif v.count(goal[0])==4:win("船工点过货单，三位都平安到了对岸。")
		"ferry":
			v[step]=i;step+=1
			if step==3:win("三艘船各得一潮，候船人听到了自己的号子。")
			elif not labels.any(func(t):return enabled(labels.find(t))):wrong("下一艘赶不上空泊位，撤回改一趟潮。")
		"hostel":
			v.append(i)
			if v.size()==3:
				if route_length(v,true)<=data.limit:win("脚夫赶上交更，三袋信一齐到了东门。")
				else:wrong("绕了 %d 里，撤回换个取信次序。"%(route_length(v,true)-int(data.limit)))
		"post":
			if i!=data.cards[step][2]:
				data.misfiled+=1;wrong("收信坊与封签不符，再查一次坊册。")
			else:
				step+=1
				if step==5:win("五封信全都投准，脚夫各取其袋。"+("一封也没投错。" if data.misfiled==0 else "途中重分了 %d 次。"%data.misfiled))
		"archive":
			if i==goal[0]:win("两段里程交在同一处，旧仓重新落到舆图上。")
			else:wrong("这格距甲 %d 里、距乙 %d 里。"%[distance(i,data.beacons[0],4),distance(i,data.beacons[1],4)])
