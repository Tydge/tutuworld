extends RefCounted
## One surface definition for rendering, collision, resources, saves and authority.
const RADII:=Vector2(178,158)
const Plots=preload("res://scripts/icefield/building_plots.gd")
const ICE_LEVEL:=Plots.LEVEL
const DOCK:=Vector2(-104,121)
const DOCK_HEIGHT:=1.15
const ACCELERATION:=2.3
const BRAKING:=.72
const CAMPFIRES=[Vector2(-38,33),Vector2(-115,-40),Vector2(43,62)]
const FENCES=[Vector2(-132,31),Vector2(-132,36),Vector2(-132,41),Vector2(-48,80),Vector2(-43,80),Vector2(-38,80),Vector2(-114,-76),Vector2(-109.5,-76)]
const BUILDINGS=[
	{"id":"farm","x":-102.,"z":-24.,"kind":"shop","title":"雪芽杂货铺","wall":"a17a57"},
	{"id":"tools","x":-80.,"z":-24.,"kind":"shop","title":"霜石工具铺","wall":"82766b"},
	{"id":"clothes","x":-58.,"z":-24.,"kind":"shop","title":"绒雪裁缝店","wall":"8e615d"},
	{"id":"lodge","x":-119.,"z":22.,"kind":"chalet","title":"松风旅舍","room":"lodge"},
	{"id":"bakery","x":-117.,"z":64.,"kind":"chalet","title":"雪绒面包房","room":"bakery"},
	{"id":"home_a","x":-127.,"z":-57.,"kind":"chalet","title":"北坡书屋","room":"library"},
	{"id":"home_b","x":-94.,"z":-66.,"kind":"chalet","title":"霜铃的小屋","room":"study"},
	{"id":"home_c","x":-56.,"z":-67.,"kind":"chalet","title":"围炉茶室","room":"tea"},
	{"id":"home_d","x":-81.,"z":74.,"kind":"chalet","title":"雪芽的小屋","room":"home"},
	{"id":"home_e","x":-46.,"z":65.,"kind":"chalet","title":"白桦餐厅","room":"dining"},
	{"id":"home_f","x":-49.,"z":43.,"kind":"chalet","title":"织雪小屋","room":"study"},
	{"id":"home_g","x":-104.,"z":46.,"kind":"chalet","title":"松果小馆","room":"dining"},
	{"id":"home_h","x":-128.,"z":-16.,"kind":"chalet","title":"西街小屋","room":"home"},
	{"id":"home_i","x":-124.,"z":-86.,"kind":"chalet","title":"雪线驿舍","room":"lodge"},
	{"id":"home_j","x":-65.,"z":-98.,"kind":"chalet","title":"守钟人的家","room":"home"},
	{"id":"chapel","x":-102.,"z":-103.,"kind":"chapel","title":"极光钟楼","room":"hall"}
]
static func shore_x(z: float) -> float:return -21.+7.*sin(z*.024)+3.*sin(z*.065)
static func ellipse(x: float,z: float) -> float:return Vector2(x/RADII.x,z/RADII.y).length()
static func contains(x: float,z: float) -> bool:return ellipse(x,z)<=1.
static func inlet(x: float,z: float) -> float:return Vector2((x+79.)/23.,(z-130.)/22.).length()
static func raw_snow(x: float,z: float) -> float:
	var inland:=maxf(0.,shore_x(z)-x)
	return ICE_LEVEL+.18+inland*.057+1.0*sin(x*.027+z*.019)*sin(z*.033)*smoothstep(0.,38.,inland)
static func height_at(x: float,z: float) -> float:
	var bank:=1.-smoothstep(-2.,9.,x-shore_x(z))
	var h:=lerpf(ICE_LEVEL,raw_snow(x,z),bank)
	for b in BUILDINGS:
		if absf(x-b.x)>14. or absf(z-b.z)>13.:continue
		var outside:=Vector2(maxf(absf(x-b.x)-6.4,0.),maxf(absf(z-b.z)-5.7,0.)).length()
		h=lerpf(h,raw_snow(b.x,b.z),1.-smoothstep(0.,6.,outside))
	var radial:=ellipse(x,z)
	var a:=atan2(z/RADII.y,x/RADII.x)
	var rim_presence:=1.-smoothstep(.48,.78,sin(a))
	var rim_height: float=15.+2.8*sin(a*13.)+1.4*sin(a*29.)
	h+=smoothstep(.915,.972,radial)*rim_height*rim_presence
	var sea_opening:=smoothstep(.48,.78,sin(a))
	var coast:=smoothstep(lerpf(.97,.925,sea_opening),lerpf(1.08,.95,sea_opening),radial)
	h=lerpf(h,-5.,coast)
	var harbor:=Vector2(maxf(absf(x+104.)-8.,0.),maxf(absf(z-118.)-5.,0.)).length()
	h=lerpf(h,.92,1.-smoothstep(0.,18.,harbor))
	return Plots.grade(Vector2(x,z),lerpf(h,-3.5,1.-smoothstep(.82,1.10,inlet(x,z))))
static func on_dock(p: Vector3) -> bool:return p.x> -108. and p.x< -94. and absf(p.z-DOCK.y)<2.
static func walk_height(x: float,z: float) -> float:return DOCK_HEIGHT if on_dock(Vector3(x,0,z)) else height_at(x,z)
static func can_walk(p: Vector3) -> bool:return on_dock(p) or (ellipse(p.x,p.z)<.967 and inlet(p.x,p.z)>1.10 and height_at(p.x,p.z)>-.20)
static func is_ice(p: Vector3) -> bool:
	return contains(p.x,p.z) and p.x>shore_x(p.z)+8. and absf(p.y-ICE_LEVEL)<.24 and not on_dock(p)
static func normal_at(x: float,z: float) -> Vector3:return Vector3(height_at(x-.3,z)-height_at(x+.3,z),.6,height_at(x,z-.3)-height_at(x,z+.3)).normalized()
static func arrival() -> Array:return [-107.,height_at(-107,116)+.04,116.]
static func valid_position(p: Vector3) -> bool:return p.is_finite() and ellipse(p.x,p.z)<1.04 and p.y> -8 and p.y<60
static func shop_positions() -> Dictionary:
	var out: Dictionary={}
	for b in BUILDINGS:
		if b.kind=="shop":out[b.id]=Vector2(b.x,b.z-2.72)
	return out
static func path_distance(x: float,z: float) -> float:
	var north_south:=Vector2(x+79.,maxf(absf(z-6.)-98.,0.)).length()
	var cross:=Vector2(maxf(absf(x+70.)-48.,0.),z-16.).length()
	var harbor:=Geometry2D.get_closest_point_to_segment(Vector2(x,z),Vector2(-104,118),Vector2(-79,74)).distance_to(Vector2(x,z))
	var shops:=Vector2(maxf(absf(x+80.)-29.,0.),z+12.).length()
	return minf(minf(north_south,cross),minf(harbor,shops))
