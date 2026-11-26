extends "res://scripts/jade/rounds/round.gd"

const THREADS=["朱线","靛线","金线","青线","白线"]
const MOTIFS=["梅瓣","竹叶","水纹"]
const INKS=["胭脂","石青","藤黄"]
const PIGMENTS=["朱砂","黄土","松烟"]
const NONOGRAMS=[99,101,103,105,107,109,113,115,117,120,121,135,139,141,143,147,149,150,151,154,155,157,165,166,167,170,171,173,174,178,181,182,184,186,195,197,199,201,202,203]

func setup() -> void:
	theme_index=1
	match house:
		"basket":
			grid(3,9)
			data.mask=NONOGRAMS[deal%NONOGRAMS.size()]
			brief="根据行、列旁的篾数编席。数字是连续挑起的根数；「1·1」之间要空一根。点格可挑起或压回。"
		"weave":
			labels=["提左综","提右综","提双综","空梭"];columns=4
			goal=shuffled(range(4)).slice(0,3 if deal%3!=2 else 4)
			data.offset=rng.randi_range(0,goal.size()-1)
			brief="旧锦留下一段循环。看布带的经纹，从断口续织三梭。双综提两侧，空梭留白。"
		"stitch":
			grid(3,9)
			var paths: Array=[[0,1,4,3,0,4,5,8],[2,1,4,5,2,4,7,6],[6,3,4,7,6,4,1,0],[8,5,4,7,8,4,3,0]]
			var path: Array=paths[deal%paths.size()].duplicate()
			if deal%8>=4:path.reverse()
			data.edges=[]
			for j in range(path.size()-1):data.edges.append(edge(path[j],path[j+1]))
			picked=path[0]
			brief="从朱针所在的孔出发，点下一孔，沿每条灰色缝线恰好走一次。岔口要给自己留出回路。"
		"carver":
			grid(3,9)
			data.mask=NONOGRAMS[(deal*7+5)%NONOGRAMS.size()]
			data.axis=deal%2
			brief="印章落纸会翻面。照左方印蜕刻出反面朱格；沿箭头方向翻印即可还原。点错可再点提刀。"
		"tailorhome":
			var order:=shuffled(range(5));data.above=[[],[],[],[],[]]
			for n in range(1,5):
				data.above[order[n]].append(order[n-1])
				if n>=3 and deal%2==0:data.above[order[n]].append(order[n-3])
			labels=THREADS.duplicate();columns=5
			brief="绣绷缠了五股线。看交叉口，先抽压在上面的线；压住它的线都取走后，下一股才能抽出。"
		"paper":
			grid(3,9)
			data.layers=[];data.ink=deal%3;data.motif=(deal/3)%3
			data.request=(deal+1)%3
			brief="点纸面落一枚花印。换色、换版叠出自己的花笺；至少两色、两种花版，并用到客人点的色。"
		"lacquer":
			goal=[rng.randi_range(1,3),rng.randi_range(1,3),rng.randi_range(1,2)]
			v=[0,0,0];labels=["添朱砂","添黄土","添松烟","刮去朱","刮去黄","刮去黑"]
			brief="旧漆片给出配色比例。少量试调，对照两块漆样；同一比例调半碗或一碗都算成功。"
		"potter":
			v=[3,4,3];goal=v.duplicate()
			for k in 4+deal%3:
				var src:int=choose([0,1,2]);var dest:int=choose(neighbors(src,3,3))
				if goal[src]>1 and goal[dest]<6:goal[src]-=1;goal[dest]+=1
			if goal==v:goal=[2,5,3]
			labels=["口泥推向腹","腹泥提向口","腹泥推向足","足泥提向腹"];columns=2
			brief="泥量是固定的。每次把一份泥推到相邻的一段，让陶坯的轮廓合上金线。"
		"silversmith":
			grid(4,16)
			# Reachable stopping points are computed using the same physical stops as the player.
			data.pins=shuffled([5,6,9,10]).slice(0,2);v=[choose([0,3,12,15])]
			var seen: Array=[v[0]]
			var depths: Array=[0]
			for at in seen:
				for n in slide_ends(at):
					if n not in seen:depths.append(int(depths[seen.find(at)])+1);seen.append(n)
			goal=[seen[depths.find(depths.max())]]
			brief="把银珠錾进花心。点同一直线上的落点，银珠会一路滑到边框或挡钉前才停。"
		"kiln":
			data.heat=rng.randi_range(3,6);data.draft=shuffled([0,1,2,1])
			var temp:int=data.heat
			for k in 4:
				temp+=int(choose([0,2,4]))-int(data.draft[k]);goal.append(temp)
			v=[data.heat];labels=["收火 · 0","添柴 · 2","鼓风 · 4"]
			brief="窑温会留下来。看每段的风损与目标温度，选收火、添柴或鼓风，让四段釉火依次成熟。"

func edge(a: int,b: int) -> int:return mini(a,b)*9+maxi(a,b)
func runs(indices: Array) -> String:
	var blocks: Array=[];var length:=0
	for i in indices:
		if int(data.mask)&(1<<int(i)):length+=1
		elif length:blocks.append(length);length=0
	if length:blocks.append(length)
	return numbers(blocks,"·") if blocks.size() else "0"
func transformed(i: int) -> int:return i-i%3+2-i%3 if data.axis==0 else (2-i/3)*3+i%3
func slide_ends(from: int) -> Array:
	var ends: Array=[]
	for d: int in [-4,1,4,-1]:
		var pos:=from
		while pos+d in neighbors(pos,4,16) and pos+d not in data.pins:pos+=d
		if pos!=from:ends.append(pos)
	return ends
func enabled(i: int) -> bool:
	match house:
		"paper":return (data.layers.size()<8 and not data.layers.has([i,data.motif,data.ink])) if i<9 else (paper_ready() if i==15 else true)
		"tailorhome":return i not in v
		"silversmith":return i in slide_ends(v[0])
		"potter":
			var pair: Array=[[0,1],[1,0],[1,2],[2,1]][i]
			return v[pair[0]]>1 and v[pair[1]]<6
		"lacquer":return v[i%3]<8 if i<3 else v[i%3]>0
	return true
func paper_ready() -> bool:
	var visible:Dictionary={}
	for layer in data.layers:visible[Vector2i(layer[0],layer[1])]=layer[2]
	var motifs:Dictionary={}
	for stamp:Vector2i in visible:motifs[stamp.y]=true
	var inks:=visible.values()
	return motifs.size()>=2 and data.request in inks and inks.any(func(ink):return ink!=data.request)
func active(i: int) -> bool:
	if house in ["basket","carver","tailorhome"]:return i in v
	if house=="paper":return i==9+int(data.motif) or i==12+int(data.ink)
	if house=="stitch":return i==picked
	if house=="silversmith":return i==v[0]
	return false
func refresh() -> void:
	match house:
		"basket","carver":
			labels=[]
			for i in 9:labels.append(("挑" if i in v else "压") if house=="basket" else ("朱" if i in v else "白"))
			status="篾席　·　行列数见两侧" if house=="basket" else ("印面　·　左右翻印" if data.axis==0 else "印面　·　上下翻印")
		"weave":
			status="断口前的锦纹　"+weave_sample()+"　　　已续 %d / 3 梭"%step
		"stitch":
			labels=[]
			for i in 9:labels.append("针" if i==picked else str(i+1))
			status="已缝 %d / %d 段"%[v.size(),data.edges.size()]
		"tailorhome":
			var overlaps: Array=[]
			for i in 5:
				for top in data.above[i]:
					if i not in v and top not in v:overlaps.append(THREADS[top][0]+"压"+THREADS[i][0])
			status="交叉口　"+"　·　".join(overlaps) if overlaps.size() else "最后一线已松开"
		"paper":
			labels=[]
			for i in 9:labels.append("落印")
			labels.append_array(MOTIFS);labels.append_array(INKS);labels.append("揭纸收笺")
			status="客点%s　·　手中 %s / %s　·　已印 %d / 8"%[INKS[data.request],MOTIFS[data.motif],INKS[data.ink],data.layers.size()]
		"lacquer":
			status="朱砂∶黄土∶松烟　　旧方 %s　｜　碟中 %s"%[numbers(goal,"∶"),numbers(v,"∶")]
		"potter":status="口、腹、足　　样坯 %s　｜　手中 %s"%[numbers(goal," / "),numbers(v," / ")]
		"silversmith":
			labels=[]
			for i in 16:labels.append("银珠" if i==v[0] else ("花心" if i==goal[0] else ("钉" if i in data.pins else ("落点" if enabled(i) else "·"))))
			status="花心嵌银　·　借挡钉换向"
		"kiln":
			var k:=mini(step,3)
			status="第 %d 段　·　现温 %d　·　本段风损 %d　·　目标 %d"%[k+1,v[0],data.draft[k],goal[k]]
func weave_sample() -> String:
	var strips: Array=[]
	for i in goal.size()+2+step:strips.append(["▮·","·▮","▮▮","··"][goal[(i+int(data.offset))%goal.size()]])
	return numbers(strips,"　")
func act(i: int) -> void:
	match house:
		"basket","carver":
			toggle(v,i)
			for j in 9:
				var src:=transformed(j) if house=="carver" else j
				if (j in v)!=bool(int(data.mask)&(1<<src)):return
			win("起出印石，拓纸上的纹样端正如初。" if house=="carver" else "席心收紧，每一行篾纹都合上了。")
		"weave":
			if i!=goal[(goal.size()+2+step+int(data.offset))%goal.size()]:wrong("这一梭错了纹，梭子已经退回断口。");return
			step+=1
			if step==3:win("梭子走过断口，谁也找不到新旧两段的接缝。")
		"stitch":
			var seam:=edge(picked,i)
			if seam not in data.edges or seam in v:wrong("这一段没有待补的线；可沿灰线走，或撤针。");return
			v.append(seam);picked=i
			if v.size()==data.edges.size():win("最后一段收针，燕尾补得平平整整。")
		"tailorhome":
			for top in data.above[i]:
				if top not in v:wrong("%s还压着它，先取上面那股。"%THREADS[top]);return
			v.append(i)
			if v.size()==5:win("五股丝线各归线轴，绣绷重新舒展开来。")
		"paper":
			if i in [9,10,11]:data.motif=i-9
			elif i in [12,13,14]:data.ink=i-12
			elif i==15:win("揭纸透光，%s留在了你的花笺册。"%INKS[data.request])
			else:data.layers.append([i,data.motif,data.ink])
		"lacquer":
			v[i%3]+=1 if i<3 else -1
			if v[0]>0 and v[0]*goal[1]==v[1]*goal[0] and v[0]*goal[2]==v[2]*goal[0]:win("新漆吃进木纹，恰与旧匣同色。")
		"potter":
			var pair: Array=[[0,1],[1,0],[1,2],[2,1]][i]
			v[pair[0]]-=1;v[pair[1]]+=1
			if v==goal:win("一线金边正好贴住碗身，新坯可以离盘。")
		"silversmith":
			v[0]=i
			if i==goal[0]:win("银珠滑进钗心，槌下一声清响。")
		"kiln":
			var after:int=v[0]+2*i-int(data.draft[step])
			if after!=goal[step]:wrong("照这个火法会到 %d 度，先留住这一炉。"%after);return
			v[0]=after;step+=1
			if step==4:win("窑门一开，青釉里的细纹全浮了出来。")
