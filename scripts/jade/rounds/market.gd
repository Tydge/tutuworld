extends "res://scripts/jade/rounds/round.gd"

const HERBS=[["艾叶","绒叶","浅裂","清苦"],["薄荷","光叶","锯齿","清凉"],["紫苏","绒叶","锯齿","辛香"],["香茅","光叶","长条","柠香"],["菖蒲","光叶","长条","辛香"],["藿香","绒叶","锯齿","清凉"]]
const SEASONS=["春芽","小满","秋收","冬藏"]
const BRANCHES=["左主枝","左内梢","左外梢","右主枝","右内梢","右外梢"]
func setup() -> void:
	theme_index=5
	match house:
		"oil":
			goal=shuffled([1,2,3,5,7,9,11]).slice(0,5);goal.sort()
			var mix:=shuffled(goal).slice(0,2+deal%2)
			data.mass=mix.reduce(func(a,b):return a+b,0)
			labels=goal.map(func(n):return "%d 钱"%n);columns=5
			brief="客人带来一只空油壶。点砝码上秤，再点取下，把秤杆压平。能少用一枚就少用一枚。"
		"herbal":
			data.samples=shuffled(range(6)).slice(0,4);goal=shuffled(data.samples).slice(0,2)
			labels=["摸叶面","看叶缘","闻香气"]
			data.inspections=0;data.mistakes=0
			for sample in data.samples:
				var herb:Array=HERBS[sample]
				labels.append("%s　·　%s / %s / %s"%[herb[0],herb[1],herb[2],herb[3]])
			columns=1
			brief="摸叶、看缘、闻香，拿药样跟四张屉签对照。确信时点药屉归样。两包辨完，掌柜会数你验了几次。"
		"pastry":
			grid(4,12)
			var offset:=deal%2
			var places:Array=[[0,1],[2,3],[4,5],[6,7],[8,9],[10,11]] if not offset else [[0,4],[1,5],[2,3],[6,7],[8,9],[10,11]]
			data.block=choose(places);data.pairs=[]
			brief="每副杏花模占相邻两格。依次点两格摆下一副，把烤盘的空位铺满；炭口要留空。"
		"noodle":
			goal=shuffled([2,3,4,5]).slice(0,3)
			data.length=goal.reduce(func(a,b):return a+b,0)
			labels=[]
			for i in range(1,data.length):labels.append(str(i))
			columns=6
			brief="这根面绳已经量好。从左到右按三桌的份数下刀。点刻度落刀，再点可收刀。"
		"banquet":
			v=shuffled([1,2,3,4]);goal=v.duplicate()
			for k in 3+deal%3:
				var i:int=choose([0,1,2,3])
				if goal[i]==0:i=goal.find(goal.max())
				sow(goal,i)
			if goal==v:sow(goal,goal.find(goal.max()))
			labels=["东席","南席","西席","北席"];columns=4
			brief="点一席捧起整盘糕，从下一席起顺时针每席放一枚。让四席的枚数合上宴单。"
		"ledger":
			data.bags=rng.randi_range(3,7);data.price=rng.randi_range(8,17);data.paid=rng.randi_range(4,18)
			goal=[int(data.bags)*int(data.price)-int(data.paid)]
			labels=["1","2","3","4","5","6","7","8","9","退一位","0","盖账印"];columns=3
			brief="算出米行还欠的钱，直接按数字填进账页，核对后盖印。数字键也能入账。"
		"pickle":
			var capacity: Array=choose([[5,3,4],[7,4,2],[7,3,5],[8,5,6],[9,4,6],[8,3,4]])
			goal=capacity;v=[0,0]
			labels=["盛满大瓮","大倒小","倒空大瓮","盛满小瓮","小倒大","倒空小瓮"]
			brief="两瓮都没有刻线。可盛满、倒空或互倒至一边满空，让大瓮里恰留 %d 勺。"%goal[2]
		"garden":
			theme_index=0
			data.blooms=shuffled([1,2,3,4,5,6])
			data.shadows=shuffled([1,2,4,5]).slice(0,2+deal%2)
			data.keep=21
			for shadow in data.shadows:data.keep-=int(data.blooms[shadow])
			if data.shadows.size()==3:
				var root:=0 if 1 in data.shadows and 2 in data.shadows else 3
				data.keep-=int(data.blooms[root])
			labels=BRANCHES.duplicate()
			brief="朱圈是想借景的窗眼。两剪之内，剪去圈前的遮枝，尽量保住花苞。剪主枝会带走左右两梢。"
		"incense":
			theme_index=1
			var rings:=3 if deal%3!=2 else 4
			v=[[],[],[]]
			var order:=range(rings);order.reverse()
			for ring in order:v[rng.randi_range(0,2)].append(ring+1)
			data.dest=deal%3;data.rings=rings
			if v[data.dest].size()>=rings-1:
				v=[[],[],[]]
				for ring in order:v[(int(data.dest)+1)%3].append(ring+1)
			labels=["左托","中托","右托"]
			brief="把香环移到指定香托。点起一托最上层，再点落处；轻的小环只能放在大环上。"

func sow(trays: Array,i: int) -> void:
	var count:int=trays[i];trays[i]=0
	for k in count:trays[(i+1+k)%4]+=1
func enabled(i: int) -> bool:
	match house:
		"herbal":return i not in v if i<3 else not v.is_empty()
		"pastry":return i not in data.block and i not in v
		"garden":return step<2 and i not in v
		"banquet":return v[i]>0
		"incense":return not v[i].is_empty() if picked<0 else (i==picked or v[i].is_empty() or v[i].back()>v[picked].back())
	return true
func active(i: int) -> bool:
	if house in ["oil","garden","herbal"]:return i in v
	if house=="noodle":return i+1 in v
	if house in ["pastry","incense"]:return i==picked
	return false
func refresh() -> void:
	match house:
		"oil":status="油单 %d 钱　｜　盘上 %d 钱　·　%d 枚砝码"%[data.mass,weight(),v.size()]
		"herbal":
			var traits: Array=[]
			for k in v:traits.append(HERBS[goal[mini(step,1)]][k+1])
			status="第 %d 包　·　%s"%[mini(2,step+1),"先取样辨识" if traits.is_empty() else numbers(traits)]
		"pastry":
			labels=[]
			for i in 12:labels.append("炭口" if i in data.block else ("杏花" if i in v else ("起模" if i==picked else "·")))
			status="已排 %d / 5 副　·　%s"%[data.pairs.size(),"再点相邻一格" if picked>=0 else "选空格摆模"]
		"noodle":
			var cuts:=v.duplicate();cuts.sort();cuts.append(data.length)
			var pieces: Array=[];var last:=0
			for cut in cuts:pieces.append(cut-last);last=cut
			status="桌单 %s　｜　已切 %s 份"%[numbers(goal," / "),numbers(pieces," / ")]
		"banquet":status="东 → 南 → 西 → 北　　宴单 %s　｜　席上 %s"%[numbers(goal," / "),numbers(v," / ")]
		"ledger":status="%d 担 × %d 钱　·　已付 %d 钱　｜　欠款 %s 钱"%[data.bags,data.price,data.paid,numbers(v,"") if v.size() else "＿"]
		"pickle":status="大瓮 %d / %d　·　小瓮 %d / %d　｜　大瓮要留 %d 勺"%[v[0],goal[0],v[1],goal[1],goal[2]]
		"garden":
			var left:=21
			for b in v:left-=int(data.blooms[b])
			status="余 %d 剪　·　透窗 %d / %d　·　花苞 %d，至少留 %d"%[2-step,data.shadows.filter(func(n):return n in v).size(),data.shadows.size(),left,data.keep]
			labels=[]
			for i in 6:labels.append("%s · %d 苞"%[BRANCHES[i],data.blooms[i]])
		"incense":status="移往%s　·　%s"%[labels[data.dest],"选一个香托提环" if picked<0 else "已提环，点落处"]
func weight() -> int:
	var mass:=0
	for i in v:mass+=int(goal[i])
	return mass
func act(i: int) -> void:
	match house:
		"oil":
			toggle(v,i)
			if weight()==data.mass:win("秤星归平。用 %d 枚砝码，戥出了客人要的油。"%v.size())
		"herbal":
			if i<3:
				v.append(i);data.inspections+=1
			elif data.samples[i-3]==goal[step]:
				step+=1;v=[]
				if step==2:win("两包归屉。共验 %d 次，%s。"%[data.inspections,"一味没错" if data.mistakes==0 else "纠正错屉 %d 次"%data.mistakes])
				else:note="第一包辨对了，换下一包。"
			else:
				data.mistakes+=1;wrong("这只药屉不合，药样仍在案上。")
		"pastry":
			if picked<0:picked=i
			elif i==picked:picked=-1
			elif i in neighbors(picked,4,12):
				data.pairs.append([picked,i]);v.append_array([picked,i]);picked=-1
				if v.size()==10:win("五副饼模排满，边角也烤得到火。")
			else:picked=i;note="从这里起模，再点上下左右的一格。"
		"noodle":
			toggle(v,i+1)
			if v.size()==2 and goal[0] in v and goal[0]+goal[1] in v:win("三段面落在各自的砧板上，桌桌合份。")
		"banquet":
			sow(v,i)
			if v==goal:win("转盘停下，四桌都分到了合数的点心。")
		"ledger":
			if i==9:v.pop_back()
			elif i==11:
				if not v.is_empty() and int(numbers(v,""))==goal[0]:win("账尾朱印落定，米钱两清。")
				else:wrong("账还未平，核一核预付款。")
			elif v.size()<3:v.append(0 if i==10 else i+1)
		"pickle":
			var jug:=i/3;var other:=1-jug
			match i%3:
				0:v[jug]=goal[jug]
				1:
					var n:=mini(v[jug],goal[other]-v[other]);v[jug]-=n;v[other]+=n
				2:v[jug]=0
			if v[0]==goal[2]:win("大瓮里留的这一勺不少，正好封坛。")
		"garden":
			step+=1;v.append(i)
			if i%3==0:
				for k in [i+1,i+2]:
					if k not in v:v.append(k)
			var buds:=21
			for b in v:buds-=int(data.blooms[b])
			if buds<data.keep:wrong("花苞剪少了，可以撤剪。")
			elif data.shadows.all(func(b):return b in v):win("窗里露出远山，枝头还留了 %d 朵花。"%buds)
			elif step==2:wrong("还有窗眼被挡。撤一剪，看看主枝能否同时让开两梢。")
		"incense":
			if picked<0:picked=i
			elif i==picked:picked=-1
			else:
				v[i].append(v[picked].pop_back());picked=-1
				if v[data.dest].size()==data.rings:win("层香归托，一缕细烟缓缓立起来。")
