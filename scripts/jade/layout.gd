extends RefCounted
## All distances in metres. North is -Z. The palace starts at the terrace at z=-82.
const NAVIGATION:=Rect2i(-183,-186,376,387)
const DOCK:=Vector2(0,209)
const DOCK_HEIGHT:=2.05
const DOCK_DECK:=Rect2(-3.5,200.,7.,13.)
const SEA_LEVEL:=preload("res://scripts/icefield/icefield_layout.gd").SEA_LEVEL
const PONDS:=[Vector2(123,-45),Vector2(-118,-48),Vector2(76,-149),Vector2(-44,-151)]
const LANDMARKS={
	"tide_stone":{"name":"北岸水则碑","at":Vector2(-176,-197),"label":"辨认水则碑的潮痕","day_text":"石上三道凿痕记着旧年春汛。最低一道旁边，刻着西滩船户的姓。","night_text":"碑脚的浅槽映着天光。守堤人把夜潮最高处留给天亮来读碑的人。"},
	"beacon":{"name":"听潮亭","at":Vector2(199,-196),"label":"倚栏听潮","day_text":"先听见礁上的碎浪，再听见北湾的回声。从这里向西，水则碑就在同一条堤上。","night_text":"檐下的灯照着北湾，黑水里传来两声船桨。旧时的船户靠这盏灯认岸。"},
	"east_fork":{"name":"东桥路牌","at":Vector2(112,33),"label":"看东桥路牌","day_text":"向南沿土路到六里宅地，向东到采场。银矿在北坡，砂岩和铁在东岸。","night_text":"路牌上的白字映着灯光。向南到六里宅地，向东到采场，过桥往北入城。"}}
const POND_SEGMENTS:=72
static var pond_outline:=PackedVector2Array()
static var shore_planes: Dictionary={}
static var quay_sections: Dictionary={}
const LIMIT:=Vector2(240,206)
const TERRACES:=[[-1.,62.,92.],[-1.,124.,156.],[1.,78.,103.],[1.,115.,140.]]
const FORECOURTS:=[[-21.,-59.,2.63],[20.,-69.,3.10]]
const PALACE_GATE_Z:=-87.
const BRIDGES:=[-108.,0.,108.]
const LOTS:=["jade_mulberry","jade_canal","jade_swallow","jade_reed","jade_pottery","jade_lotus"]
const LOT_NAMES:=["桑梓里","听潮里","燕归里","芦花里","青瓷里","荷香里"]
const LOT_ORIGINS:=[Vector2(70,84),Vector2(103,84),Vector2(136,84),Vector2(70,117),Vector2(103,117),Vector2(136,117)]
# id, sign, x, z, shell, interior
const HOUSES:=[
	["drum","宣时鼓阁",-21,-59,"clocktower","music"],["baihe","白鹤礼馆",20,-69,"theatre","study"],
	["spice","桂香茶肆",-16,127,"loft","tea"],["oil","杏仁油坊",-17,89,"court","work"],
	["basket","篾匠竹坊",-16,49,"store","work"],["stitch","针线小楼",16,145,"inn","tailor"],
	["lacquer","春漆作",15,107,"store","work"],["almond","杏花食店",19,74,"cottage","tavern"],
	["pipa","南渡琴社",18,184,"cloister","music"],
	["pickle","东津酱坊",43,163,"store","work"],["sail","南津帆作",-49,146,"forge","tailor"],
	["cot","归帆客舍",-40,176,"inn","inn"],["weave","织户东院",41,127,"court","tailor"],
	["pastry","杏仁饼铺",-39,90,"store","tavern"],["caligraphy","墨池斋",51,28,"pavilion","study"],
	["poetry","兰舟画坊",-75,25,"cloister","study"],["herbal","春和草堂",77,-25,"cottage","tea"],
	["weir","水务公所",-18,-23,"court","study"],["duty","漕运钟楼",18,-21,"clocktower","study"],
	["books","抄书人家",-66,-43,"cottage","study"],["silversmith","钿花局",-68,-131,"cloister","work"],
	["dye","蓝染院",-49,112,"forge","tailor"],["hostel","旧渡驿舍",51,149,"inn","inn"],
	["potter","陶家窑房",-63,74,"cottage","work"],["ledger","米行账房",49,86,"store","study"],
	["noodle","桥头食铺",-25,27,"store","tavern"],["stage","枕河戏楼",24,28,"theatre","music"],
	["post","驿路茶棚",-47,24,"cottage","tea"],["carver","刻印作",-49,-38,"forge","work"],
	["reading","观荷书舍",79,-47,"cottage","study"],["fiddler","琴师小院",61,-44,"cloister","music"],
	["incense","制香坊",-23,162,"store","work"],["tailorhome","绣工小筑",37,106,"cottage","tailor"],
	["ferry","候潮驿",-14,183,"inn","inn"],["tavern","泊月酒肆",15,165,"loft","tavern"],
	["farm","南货行",-18,146,"store","shop"],["clothes","云锦庄",15,126,"loft","tailor"],
	["tools","百炼铺",-15,108,"forge","smith"],["furniture","榫卯行",15,90,"loft","shop"],
	["workshop","百工坊",-15,72,"forge","work"],["tea","听雨茶楼",15,52,"loft","tea"],
	["guild","船工会馆",-35,46,"loft","tavern"],["inn","鹭眠客栈",37,50,"inn","inn"],
	["kiln","溪石窑",-102,67,"forge","work"],["academy","临川书院",-108,-44,"cloister","study"],
	["dojo","观澜武馆",28,-46,"cloister","dojo"],["paper","花笺坊",-27,-44,"cottage","study"],
	["garden","藕香水榭",106,-38,"pavilion","tea"],["farmhouse","桑农草堂",-176,95,"cottage","inn"],
	["audience","含章殿",0,-164,"palace","court"],["archive","文渊阁",-36,-132,"court","study"],
	["music","听韶台",36,-132,"court","music"],["banquet","琼筵殿",-62,-170,"pavilion","tea"],
	["chamber","栖梧宫",62,-170,"court","inn"],["scribe","尚书房",-23,-103,"clocktower","study"],
	["silk","尚衣局",24,-106,"inn","tailor"]]
static func river_z(x: float) -> float:return 9.*sin(x*.015)
static func lane(z: float) -> float:return 9.*sin((z-38.)*.041)*sin(clampf((z-30.)/167.,0.,1.)*PI) if z>30. else 0.
static func door_angle(h: Array) -> float:
	if h[0] in ["drum","baihe"]:return PI/2 if h[2]<0 else -PI/2
	if h[0]=="weir":return PI
	if h[3]>37 and absf(h[2])<44:return (-1. if h[2]>0 else 1.)*(PI*.50+.11*sin(h[3]))
	return {"garden":-.3,"paper":.17,"kiln":.5,"farmhouse":-.25,"scribe":.32,"silk":-.22,"archive":.13,"music":-.13}.get(h[0],0.)
static func center(h: Array) -> Vector2:return Vector2(h[2]+lane(h[3]),h[3])
static func dims(kind: String) -> Vector3:
	return {"clocktower":Vector3(5.45,5.15,5.8),"theatre":Vector3(6.6,4.6,5.3),"palace":Vector3(12.5,8.,8.),"court":Vector3(8.5,6.3,6.5),"inn":Vector3(7.6,4.,6.),"forge":Vector3(7.2,4.6,4.),"cloister":Vector3(8.7,5.2,5.),"store":Vector3(4.6,4.8,6.3),"pavilion":Vector3(6.5,5.6,4.5),"cottage":Vector3(4.7,3.8,5.3)}.get(kind,Vector3(6.1,4.7,5.1))
# Only look up foundations touching this cell. Preserve the ground slope beyond the apron.
static var foundations: Dictionary={}
static var stair_aprons: Dictionary={}
static func prepare_foundations() -> void:
	if not foundations.is_empty():return
	for house in HOUSES:
		var c:=center(house);var angle:=door_angle(house);var d:=dims(house[4])
		var half:=Vector2(d.x+1.8,d.z+1.8)
		if house[4] in ["loft","inn","clocktower","cloister","forge","cottage"]:half.x+=2.2
		var pad:=[c,angle,half,raw_height(c.x,c.y)]
		if house[4] in ["loft","inn","clocktower","theatre"]:
			var stair_center:=c+Vector2(d.x+1.86,-d.z-1.5).rotated(-angle)
			var apron:=[stair_center,angle,pad[3]]
			for sx in range(floori((stair_center.x-9.)/24.),floori((stair_center.x+9.)/24.)+1):
				for sz in range(floori((stair_center.y-9.)/24.),floori((stair_center.y+9.)/24.)+1):
					var key:=Vector2i(sx,sz)
					if not stair_aprons.has(key):stair_aprons[key]=[]
					stair_aprons[key].append(apron)
		var reach:=half.length()+5.
		for gx in range(floori((c.x-reach)/24.),floori((c.x+reach)/24.)+1):
			for gz in range(floori((c.y-reach)/24.),floori((c.y+reach)/24.)+1):
				var key:=Vector2i(gx,gz)
				if not foundations.has(key):foundations[key]=[]
				foundations[key].append(pad)
static func height_at(x: float,z: float) -> float:
	prepare_foundations()
	var height:=raw_height(x,z);var point_:=Vector2(x,z)
	var closest:=5.
	for pad in foundations.get(Vector2i(floori(x/24.),floori(z/24.)),[]):
		var local_: Vector2=(point_-pad[0]).rotated(pad[1])
		var distance: float=(local_.abs()-pad[2]).max(Vector2.ZERO).length()
		if distance<closest:
			height=lerpf(pad[3],raw_height(x,z),smoothstep(.2,4.8,distance));closest=distance
	# The triangulated ground needs two neighbouring samples outside the stair foot.
	# Keep this landing continuous when nearby buildings sit on different terraces.
	for apron in stair_aprons.get(Vector2i(floori(x/24.),floori(z/24.)),[]):
		var local_: Vector2=(point_-apron[0]).rotated(apron[1])
		var edge: float=(local_.abs()-Vector2(3.7,4.65)).max(Vector2.ZERO).length()
		height=lerpf(float(apron[2]),height,smoothstep(0.,2.7,edge))
	if z>36. and z<192.:
		var blend:=smoothstep(36.,44.,z)*(1.-smoothstep(185.,192.,z))*(1.-smoothstep(6.9,9.4,absf(x-lane(z))))
		height=lerpf(height,raw_height(x,z),blend)
	return forecourt_height(x,z,height)
# Cut the street-side earth below the masonry. A level landing and one crossfall-free
# ramp serve both the rendered stairs and the route used by NPCs and the server.
static func approach_height(z: float) -> float:
	return 6.+4.*smoothstep(-58.,-80.,z)
static func forecourt_height(x: float,z: float,terrain: float) -> float:
	if z < -90. or z > -38. or absf(x)>41.:return terrain
	for row in FORECOURTS:
		var side:=signf(row[0])
		var u: float=(x-row[0])*side+9.7
		var dz:=absf(z-row[1])
		if u < -9. or u>25. or dz>20.5:continue
		var low:=approach_height(row[1])
		var high: float=low+row[2]
		var ramp:=clampf((u+5.8)/5.8,0.,1.)
		var along:=1.-smoothstep(2.65,4.8,dz)
		var street:=lerpf(approach_height(z),low,along)
		# At the face, rise behind the stone wall. The middle opening carries the ramp.
		# Leave a level strip outside the return walls. The terrace's own stone deck spans the cut.
		var inside:=1.-smoothstep(8.2,10.8,dz)
		var fill:=lerpf(street,high,smoothstep(.20,2.7,u)*inside)
		var target:=lerpf(fill,lerpf(low,high,ramp),along)
		var feather:=smoothstep(-9.,-6.2,u)*(1.-smoothstep(20.3,25.,u))*(1.-smoothstep(15.6,20.5,dz))
		terrain=lerpf(terrain,target,feather)
	return terrain
static func near_entrance(x: float,z: float) -> bool:
	prepare_foundations()
	for apron in stair_aprons.get(Vector2i(floori(x/24.),floori(z/24.)),[]):
		var relative: Vector2=(Vector2(x,z)-apron[0]).rotated(apron[1])
		if absf(relative.x)<2.9 and absf(relative.y)<5.5:return true
	return false
static func raw_height(x: float,z: float) -> float:
	var h:=2.+4.*smoothstep(60.,38.,z)+4.*smoothstep(-58.,-80.,z)+7.*smoothstep(-103.,-123.,z)+6.*smoothstep(-135.,-156.,z)
	h+=4.*smoothstep(140.,184.,absf(x))*smoothstep(66.,28.,z)
	# The central commercial road climbs four broad landings from the dock to the bridge.
	# The entire street has a continuous roadbed. Shopfronts sit along shallow stone curbs.
	var grade:=2.+.98*smoothstep(184.,164.,z)+.90*smoothstep(139.,120.,z)+.83*smoothstep(98.,82.,z)+1.15*smoothstep(62.,42.,z)
	var bazaar: float=smoothstep(27.,43.,z)*(1.-smoothstep(190.,202.,z))*(1.-smoothstep(36.,60.,absf(x-lane(z))))
	h=lerpf(h,grade,bazaar)
	# A low verge marks each staggered elevated sidewalk.
	var side:=x-lane(z)
	for lot in TERRACES:
		if side*lot[0]<0 or z<lot[1]-8. or z>lot[2]+8.:continue
		var along:=smoothstep(lot[1]-4.,lot[1]+6.,z)*(1.-smoothstep(lot[2]-6.,lot[2]+4.,z))
		var lip:=smoothstep(8.25,9.85,absf(side))
		h+=lip*(1.-smoothstep(36.,59.,absf(side)))*along*(.32 if lot[0]<0 else .26)
	for terrace in FORECOURTS:
		var dx:=absf(x-terrace[0])-9.7;var dz:=absf(z-terrace[1])-9.8
		var outside:=Vector2(maxf(0.,dx),maxf(0.,dz)).length()
		h+=float(terrace[2])*(1.-smoothstep(0.,6.,outside))
	var bank:=absf(z-river_z(x))
	h=lerpf(-2.4,h,smoothstep(7.,13.,bank))
	var edge:=minf(LIMIT.x-absf(x),LIMIT.y-absf(z))
	return lerpf(-3.8,h,smoothstep(-6.,1.,edge))
static func bridge(x: float,z: float) -> bool:
	for bx in BRIDGES:
		if absf(x-bx)<=4.45 and absf(z-river_z(bx))<=18.:return true
	return false
static func deck(z: float,bx: float) -> float:
	return 6.10+1.65*(1.-pow(clampf(absf(z-river_z(bx))/18.,0.,1.),2))
static func foot(x: float,z: float) -> float:
	if DOCK_DECK.has_point(Vector2(x,z)):return DOCK_HEIGHT
	if bridge(x,z):
		for bx in BRIDGES:
			if absf(x-bx)<=4.45:return deck(z,bx)
	return height_at(x,z)
# Shore cells use the same two triangles (including the diagonal) as landscape().
static func shore_face(p: Vector3) -> Plane:
	var cell:=Vector2i(floori(p.x/2.),floori(p.z/2.))
	var base:=Vector2(cell)*2.
	var upper:=p.x-base.x+p.z-base.y>2.
	var key:=Vector3i(cell.x,cell.y,int(upper))
	if not shore_planes.has(key):
		var stride:=2.
		if upper:
			base+=Vector2(2.,2.)
			stride=-2.
		var y:=height_at(base.x,base.y)
		var dx:=(height_at(base.x+stride,base.y)-y)/stride
		var dz:=(height_at(base.x,base.y+stride)-y)/stride
		shore_planes[key]=Plane(Vector3(-dx,1.,-dz).normalized(),Vector3(base.x,y,base.y))
	return shore_planes[key]

static func by_water(p: Vector3) -> bool:
	return absf(p.z-river_z(p.x))<16. or absf(p.x)>LIMIT.x-3. or absf(p.z)>LIMIT.y-3.

static func terrain_floor(p: Vector3) -> float:
	var face:=shore_face(p)
	return (face.d-face.normal.x*p.x-face.normal.z*p.z)/face.normal.y

# Remove the downhill part of a collision displacement. Preserve travel along
# the contour, including when the capsule touches a different face from its feet.
static func clip_bank_step(before: Vector3,proposed: Vector3) -> Vector3:
	var p:=proposed
	var flat_step:=Vector2(p.x-before.x,p.z-before.z).length()
	for i in range(3):
		var face:=shore_face(p)
		var downhill:=Vector2(face.normal.x,face.normal.z)
		var lift:=SEA_LEVEL+.025-terrain_floor(p)
		if lift<=.0001:break
		if downhill.length_squared()<.0001:return before
		var back:=downhill*(lift*face.normal.y/downhill.length_squared())
		p.x-=back.x;p.z-=back.y
	if Vector2(p.x-proposed.x,p.z-proposed.z).length()>flat_step+.08 or not can_walk(p):
		return before
	p.y=maxf(p.y,terrain_floor(p)+.025)
	return p

static func pond_rim(a: float) -> Vector2:
	var r:=2.80+.38*sin(3.*a)+.21*sin(5.*a+.6)
	return Vector2(cos(a)*r*1.37,sin(a)*r)

static func in_pond(p: Vector3) -> bool:
	for center_: Vector2 in PONDS:
		var offset:=Vector2(p.x,p.z)-center_
		if absf(offset.x)>4.7 or absf(offset.y)>3.5:continue
		if pond_outline.is_empty():
			for i in range(POND_SEGMENTS):pond_outline.append(pond_rim(i*TAU/POND_SEGMENTS))
		if Geometry2D.is_point_in_polygon(offset,pond_outline):
			return terrain_floor(p)<height_at(center_.x,center_.y)+.106
	return false

# Each transform is centred on the walkable top of the actual quay block.
static func quays() -> Dictionary:
	if not quay_sections.is_empty():return quay_sections
	for i in range(-29,30):
		var x:=i*4.14
		if BRIDGES.any(func(bx):return absf(x-bx)<5.8):continue
		var basis:=Basis(Vector3.UP,-atan(.135*cos(x*.015)))
		var section: Array[Transform3D]=[]
		for side: float in [-1.,1.]:
			var z:=river_z(x)+side*11.6
			section.append(Transform3D(basis,Vector3(x,height_at(x,z)+.26,z)))
			if absf(x)<96. and absf(x)>12.:
				z=river_z(x)+side*9.65
				section.append(Transform3D(basis,Vector3(x,height_at(x,z)+.41,z)))
		quay_sections[i]=section
	return quay_sections

static func crossing_height(p: Vector3) -> float:
	if DOCK_DECK.has_point(Vector2(p.x,p.z)):return 2.05
	if absf(p.z-river_z(p.x))>19.:return -INF
	if bridge(p.x,p.z):return foot(p.x,p.z)
	if absf(p.x)<124.:
		var cell:=roundi(p.x/4.14)
		for i in range(cell-1,cell+2):
			for pose: Transform3D in quays().get(i,[]):
				var local:=pose.inverse()*p
				if absf(local.x)<=2.1 and absf(local.z)<=.4 and pose.origin.y>SEA_LEVEL:
					return pose.origin.y
	return -INF

static func can_walk(p: Vector3) -> bool:
	if not p.is_finite() or absf(p.x)>LIMIT.x+6. or absf(p.z)>LIMIT.y+7.:return false
	if in_pond(p):return false
	return not by_water(p) or terrain_floor(p)>SEA_LEVEL or is_finite(crossing_height(p))

static func dry_footing(p: Vector3) -> bool:
	if p.y<=SEA_LEVEL or not can_walk(p):return false
	if not by_water(p) or terrain_floor(p)>SEA_LEVEL:return true
	return p.y>=crossing_height(p)-.30

static func arrival() -> Array:return [0.,2.12,203.]
static func point(x: float,z: float) -> Vector3:return Vector3(x,foot(x,z),z)
static var merchants: Dictionary={}
static func shops() -> Dictionary:
	if not merchants.is_empty():return merchants
	var out:=merchants
	for h in HOUSES:
		if h[0] in ["farm","tools","furniture","clothes","spice","almond"]:
			var offset:=Vector2(.84,dims(h[4]).z-2.05) if h[0] in ["spice","almond"] else Vector2(0,-2.)
			out[h[0]]=center(h)+offset.rotated(-door_angle(h))
	return out
static var field_rows: Array=[]
static func farm() -> Array:
	if not field_rows.is_empty():return field_rows
	var rows:=field_rows
	for i in range(32):
		rows.append({"id":"jade_plot_%02d"%i,"x":-174.+(i%8)*2.25,"z":118.+floori(i/8.)*2.5,"map":"jade"})
	return rows
static var material_sources: Array=[]
static func sources() -> Array:
	if not material_sources.is_empty():return material_sources
	# IDs retain their original material so depleted nodes and active jobs still identify the same resource.
	var deposits:={
		"cedar":[Vector2(-202,134),Vector2(-196,141),Vector2(-184,146),Vector2(-190,152),Vector2(-178,159),Vector2(-166,156)],
		"birch":[Vector2(-194,49),Vector2(-188,57),Vector2(-181,62),Vector2(-185,72),Vector2(-153,-53),Vector2(-145,-59)],
		"nephrite":[Vector2(-152,-69),Vector2(-158,-74),Vector2(-165,-70),Vector2(175,-76),Vector2(179,-82),Vector2(185,-85)],
		"silver_ore":[Vector2(178,-61),Vector2(182,-56),Vector2(189,-52),Vector2(196,-50),Vector2(201,-43),Vector2(207,-39)],
		"sandstone":[Vector2(172,40),Vector2(181,44),Vector2(185,51),Vector2(191,56),Vector2(166,153),Vector2(175,155)],
		"iron":[Vector2(196,62),Vector2(201,69),Vector2(207,75),Vector2(182,161),Vector2(188,167),Vector2(195,171)]}
	var materials:=["cedar","nephrite","silver_ore","birch","sandstone","iron"]
	for cluster in range(6):
		for i in range(6):
			var item: String=materials[(cluster+i)%6]
			var p: Vector2=deposits[item][cluster]
			material_sources.append({"id":"jade_source_%d_%d"%[cluster,i],"item":item,"x":p.x,"z":p.y,"y":height_at(p.x,p.y),"map":"jade"})
	return material_sources
