extends "res://scripts/jade/rounds/round.gd"

const ENVOYS=["鹤使","执幡","捧盒","司灯"]
const RUBBINGS=["山静听松风","江清月近人","竹露滴清响","明月照积雪","风定落花香","细雨湿流光"]
const VERSES=[
	["舟系","一叶小船挽住缆绳，","柳桥桩",["垂条刚刚发芽","两岸有一道石拱","岸上立着旧木头"]],
	["月照","山色入夜，清辉落在","桥窗溪",["两岸相连的石拱上","一方透光的纸格上","穿石而过的细流上"]],
	["鹭踏","白鸟收了翅，爪尖轻点","沙泥石",["满滩的细粒","柔软的湿土","露出水面的硬块"]],
	["风摇","看不见的手拂过西窗，","灯竹铃",["烛火在纸罩里偏了偏","青节细叶一阵低头","檐下传来一声清响"]],
	["露压","清早凝了水珠，","花荷苇",["一簇红瓣垂下枝头","圆圆的池叶弯向水面","细长的岸草向河心低垂"]],
	["霜染","白气结晶，秋色点上了","枫菊苔",["掌状的红叶","重阳盛开的花瓣","石阶上的一层青衣"]]]
const LINES=[["白鹭眠秋渚","眼秋清"],["水浅见鱼游","钱余油"],["小舟穿苇去","芽韦支"],["青山横北郭","请桓廓"],["风起动荷香","枫何乡"],["野渡浮新月","度孚玥"],["远寺闻晨钟","侍问种"],["春溪映柳阴","椿影荫"]]
const REQUESTS=[
	["春汛","渡口换缆","田渠清淤","书院护卷","渡口换上了新缆","田口响起了水声","书生把干卷送回架上"],
	["灯会","架迎灯桥","清荷花池","抄灯谜册","桥头的灯船亮了","荷池倒映出灯影","书院挂起了新谜笺"],
	["初雪","渡船备炭","给菜畦覆草","替学舍修窗","船舱暖了起来","霜下留住了青苗","学舍窗边透着暖光"],
	["秋集","修卸粮栈","借牛翻田","印农书","新谷堆在栈桥边","牛铃响过收割的田","摊上添了一册农书"]]

func setup() -> void:
	theme_index=3
	match house:
		"drum":
			data.coupling=1+deal%2;goal=shuffled(range(1,6)).slice(0,2);v=[0,0]
			labels=["外环逆拨","外环顺拨","内环逆拨","内环顺拨"];columns=2
			brief="拨准两圈才可报更。外环每走一刻，内环会同向走 %d 刻；内环能单独校准。"%data.coupling
		"baihe":
			goal=shuffled(ENVOYS);v=shuffled(goal)
			if v==goal:swap(v,0,3)
			columns=4
			brief="交换两枚名签排仪仗。%s在%s前一位，%s压阵，%s先于%s。"%[goal[0],goal[1],goal[3],goal[1],goal[2]]
		"caligraphy":
			grid(3,6);data.text=RUBBINGS[deal%RUBBINGS.size()];goal=[0,1,2,3,4,5];v=goal.duplicate()
			var prev:=-1
			for k in 7+deal%5:
				var hole:=v.find(5);var opts:=neighbors(hole,3,6);opts.erase(prev)
				var tile:int=choose(opts);swap(v,hole,tile);prev=hole
			if v==goal:swap(v,4,5)
			brief="旧帖裂成五片。点空位旁的一片移过去，让残字从左上到右下恢复帖文。"
		"poetry":
			var poem:Array=VERSES[deal%VERSES.size()]
			var dest:=rng.randi_range(0,2)
			data.line=poem[1]+poem[3][dest]+"。"
			data.verse=poem[0]+poem[2][dest]
			var distractor:String=VERSES[(deal+1+rng.randi_range(0,4))%VERSES.size()][0][0]
			labels=shuffled(Array((str(poem[0])+str(poem[2])+distractor).split("")));columns=6
			brief="画主人留下了一句画意。依次拾字，把画里的主角、动作和落处题进三个空格。"
		"books":
			data.lines=shuffled(LINES).slice(0,3);data.copies=[]
			for entry in data.lines:
				var at:=rng.randi_range(0,4);var original:String=entry[0]
				var wrong_char:String=choose(Array(str(entry[1]).split("")))
				var copy:=original.substr(0,at)+wrong_char+original.substr(at+1)
				if copy==original:copy=original.substr(0,at)+"误"+original.substr(at+1)
				data.copies.append(copy);goal.append(at)
			columns=5;brief="对着墨本校三行诗。直接点抄本里写走样的那个字，勘误笺会自动夹到下一页。"
		"academy":
			data.takes=[[1,2,3],[1,2],[1,3,4],[2,3,5]][deal%4]
			var supply:=rng.randi_range(12,20)
			while not winning(supply):supply+=1
			v=[supply];labels=[]
			for take in data.takes:labels.append("取 %d 子"%take)
			brief="和先生对弈，轮流从同一堆取石。每轮可取 %s 子，轮到谁无子可取，谁就输。"%numbers(data.takes)
		"audience":
			var case_:Array=REQUESTS[deal%REQUESTS.size()];data.case=case_
			data.cost=shuffled([2,3,4]);data.funds=7
			labels=case_.slice(1,4);labels.append("落朱批");columns=4
			brief="%s到了，三坊呈上请帖。七签够办两件。点请帖拨款或收回，选定两坊后落朱批。"%case_[0]
		"chamber":
			theme_index=2;grid(4,16)
			var path:Array=[rng.randi_range(0,15)]
			for n in 4+deal%3:
				var opts:=neighbors(path.back(),4,16).filter(func(i):return i not in path)
				if opts.is_empty():break
				path.append(choose(opts))
			goal=path;v=[goal[0]]
			brief="星官留下的是方位诗。从金色起星按罗盘逐段寻星，走过的星会连成图。上为北，右为东。"
func winning(pile: int) -> bool:
	var wins: Array=[false]
	for count in range(1,pile+1):
		var can:=false
		for n in data.takes:
			if n<=count and not wins[count-n]:can=true;break
		wins.append(can)
	return wins[pile]
func spent() -> int:
	var amount:=0
	for i in v:amount+=int(data.cost[i])
	return amount
func direction(a: int,b: int) -> String:
	return {-4:"北",4:"南",-1:"西",1:"东"}[b-a]
func enabled(i: int) -> bool:
	match house:
		"caligraphy":return i in neighbors(v.find(5),3,6)
		"academy":return data.takes[i]<=v[0] and not data.get("lost",false)
		"audience":return v.size()==2 if i==3 else (i in v or (v.size()<2 and spent()+int(data.cost[i])<=7))
		"chamber":return i in neighbors(v.back(),4,16) and i not in v
	return true
func active(i: int) -> bool:
	if house=="baihe":return i==picked
	if house in ["audience","chamber"]:return i in v
	return false
func refresh() -> void:
	match house:
		"drum":status="目标刻记　外 %d · 内 %d　｜　现刻　外 %d · 内 %d"%[goal[0],goal[1],v[0],v[1]]
		"baihe":
			labels=v.duplicate();status="从队首到队尾　·　"+("再点一签与"+str(v[picked])+"换位" if picked>=0 else "先选一签")
		"caligraphy":
			labels=[]
			for item in v:labels.append("空" if item==5 else data.text[item])
			status="底帖　「"+str(data.text)+"」"
		"poetry":status=str(data.line)+"　｜　"+"".join(v)+"＿".repeat(3-v.size())
		"books":
			labels=Array(str(data.copies[mini(step,2)]).split(""))
			status="墨本　「%s」　　　第 %d / 3 页"%[data.lines[mini(step,2)][0],mini(step+1,3)]
		"academy":status="棋盘上还剩 %d 子　·　%s"%[v[0],str(data.get("reply","你执先手"))]
		"audience":
			status="库中余 %d / 7 签　·　已准 %d / 2 件"%[7-spent(),v.size()]
			for i in 3:labels[i]="%s · %d签"%[data.case[i+1],data.cost[i]]
		"chamber":
			labels=[]
			for i in 16:labels.append("起" if i==goal[0] else ("★" if i in v else "✧"))
			var bearings:Array=[]
			for k in range(1,goal.size()):bearings.append(direction(goal[k-1],goal[k]))
			status="星官方位　"+numbers(bearings," → ")+"　｜　已寻 %d 段"%(v.size()-1)
func act(i: int) -> void:
	match house:
		"drum":
			var amount:=1 if i%2==1 else -1
			if i<2:v[0]=posmod(v[0]+amount,6);v[1]=posmod(v[1]+amount*int(data.coupling),6)
			else:v[1]=posmod(v[1]+amount,6)
			if v==goal:win("两道刻记相对，三通更鼓传遍了南市。")
		"baihe":
			if picked<0:picked=i
			else:
				swap(v,picked,i);picked=-1
				if v==goal:win("幡影齐齐一动，仪仗依次穿过廊门。")
		"caligraphy":
			swap(v,v.find(5),i)
			if v==goal:win("五片残帖合拢，墨迹又连成了一句诗。")
		"poetry":
			if labels[i]!=data.verse[v.size()]:wrong("这一字还接不上画意，再拣一张。");return
			v.append(labels[i])
			if v.size()==3:win("「"+str(data.verse)+"」落在画角，画主人轻轻念了一遍。")
		"books":
			if i!=goal[step]:wrong("底本也是这个字。再看看另几处墨迹。");return
			step+=1
			if step==3:win("三页勘完，订书线旁各夹进一张朱笺。")
		"academy":
			v[0]-=int(data.takes[i])
			var legal:Array=data.takes.filter(func(n):return n<=v[0])
			if legal.is_empty():win("先生无子可取，拱手让了这一局。");return
			var reply:int=legal[0]
			for take in legal:
				if not winning(v[0]-take):reply=take;break
			v[0]-=reply;data.reply="先生取了 %d 子"%reply
			if v[0]<data.takes.min():data.lost=true;wrong("先生赢了。撤回这一手，可以换个走法。")
		"audience":
			if i==3:
				var news:Array=[]
				for n in v:news.append(data.case[n+4])
				win(numbers(news,"，")+"。")
			else:toggle(v,i)
		"chamber":
			if i!=goal[v.size()]:wrong("这颗星在%s边，看看下一句方位。"%direction(v.back(),i));return
			v.append(i)
			if v.size()==goal.size():win("末星入图，一幅新星宿照亮梧桐窗。")
