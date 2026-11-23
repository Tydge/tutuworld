extends RefCounted
## One continuous heightfield drives visible terrain, colliders, dressing and travel.
const REVISION:=2
const LEGACY_SIZE:=Vector2(108,106)
const SIZE:=LEGACY_SIZE*2.
const HOUSE:=Vector3(24,8,-72)
const BRIDGE_Z:=10.
const DOCK:=Vector2(-14.2,94.4)
const DOCK_HEIGHT:=.18
const DOCK_DECK:=Rect2(-22.4,DOCK.y-1.85,11.2,3.7)
const BRIDGE_DECK:=Rect2(-12.185,BRIDGE_Z-1.95,24.37,3.9)
const DECK_GROUND_CLEARANCE:=.12
static func river_x(z: float) -> float:return sin(z*.035)*4.
static func river_half_width(z: float) -> float:return 6.1+smoothstep(56.,116.,z)*12.
static func water_level(z: float) -> float:return lerpf(5.8,-1.55,smoothstep(-94.,117.,z))
static func bank_height(z: float) -> float:return water_level(z)+.65
static func terrain_contains(x: float,z: float) -> bool:
	return Vector2(x,z/.88).length()<106 or Vector2((x+26)/28.,(z-84)/38.).length()<1 or Vector2(x/58.,(z-98)/44.).length()<1
static func height_at(x: float,z: float) -> float:
	var bank_distance:=absf(x-river_x(z))-river_half_width(z)
	var inland:=smoothstep(.8,73.,bank_distance)
	var rolling:=29.+4.5*sin(x*.040+z*.035)+3.0*cos(z*.045-x*.025)+1.8*sin(z*.083+x*.028)
	var rim:=9.*smoothstep(.86,.99,Vector2(x,z/.88).length()/106.)
	var height_: float=bank_height(z)+inland*(rolling+rim)
	# A rounded riverbed under clear water, never an abrupt rectangular shelf.
	height_-=1.55*(1.-smoothstep(-2.2,.6,bank_distance))
	# Small organic clearings for the existing cottage and harbor.
	var cottage:=Vector2(maxf(absf(x-HOUSE.x)-7.2,0.),maxf(absf(z-HOUSE.z)-6.2,0.)).length()
	height_=lerpf(HOUSE.y,height_,smoothstep(0.,9.,cottage))
	var harbor:=Vector2(maxf(absf(x+21)-6.,0.),maxf(absf(z-90)-6.5,0.)).length()
	var harbor_weight: float=(1.-smoothstep(.0,9.,harbor))*smoothstep(-.1,2.,bank_distance)
	height_=lerpf(height_,.0,harbor_weight)
	height_+=.18*(1.-smoothstep(4.,6.,absf(x+16.8)))*smoothstep(89.,92.5,z)*(1.-smoothstep(96.5,100.,z))*smoothstep(0.,1.8,bank_distance)
	if absf(z-BRIDGE_Z)<4.:
		var approach: float=(1.-smoothstep(2.5,4.,absf(z-BRIDGE_Z)))*smoothstep(8.5,11.5,absf(x))*(1.-smoothstep(16.,23.,absf(x)))
		height_=lerpf(height_,bank_height(BRIDGE_Z)+.10,approach)
	# The bay bed continues under the estuary, then drops gradually into deeper sea.
	var coast:=minf(Vector2(x,z/.88).length()-106.,(Vector2((x+26)/28.,(z-84)/38.).length()-1.)*28.)
	height_=lerpf(height_,-8.,smoothstep(0.,15.,coast))
	if absf(z-DOCK.y)<4.4:height_=ground_below_deck(height_,x,z,DOCK_DECK,DOCK_HEIGHT)
	if absf(z-BRIDGE_Z)<4.5:height_=ground_below_deck(height_,x,z,BRIDGE_DECK,bridge_height(x))
	return height_
static func ground_below_deck(ground: float,x: float,z: float,deck: Rect2,top: float) -> float:
	# Include every 1 m terrain triangle touched by the boards. Capping only the
	# exact footprint leaves mixed edge triangles poking through the deck.
	var center:=deck.get_center();var half:=deck.size*.5+Vector2.ONE*1.1
	var outside:=Vector2(maxf(absf(x-center.x)-half.x,0.),maxf(absf(z-center.y)-half.y,0.))
	if outside.x>=1.4 or outside.y>=1.4:return ground
	var weight:=1.-smoothstep(0.,1.4,outside.length())
	return lerpf(ground,minf(ground,top-DECK_GROUND_CLEARANCE),weight)
static func backdrop_height(radius: float,angle: float) -> float:
	var base:=height_at(cos(angle)*103.,sin(angle)*103.*.88)
	var radii: Array=[103.,109.,122.,140.,160.,185.];var rises: Array=[-.25,2.8,10.,16.,11.,-2.]
	var rise: float=rises[-1]
	for i in range(radii.size()-1):
		if radius<=radii[i+1]:rise=lerpf(rises[i],rises[i+1],clampf((radius-radii[i])/(radii[i+1]-radii[i]),0,1));break
	return base+rise*(1.+.20*sin(angle*5+.3)+.13*sin(angle*9))
static func normal_at(x: float,z: float) -> Vector3:
	var step:=.25
	return Vector3(height_at(x-step,z)-height_at(x+step,z),step*2.,height_at(x,z-step)-height_at(x,z+step)).normalized()
static func bridge_at(p: Vector3) -> bool:return absf(p.z-BRIDGE_Z)<2.1 and absf(p.x)<12.4
static func bridge_height(x: float) -> float:return bank_height(BRIDGE_Z)+.10+.65*sin(clampf((x+12)/24.,0,1)*PI)
static func on_dock(p: Vector3) -> bool:return p.x> -22.5 and p.x< -11.1 and absf(p.z-DOCK.y)<1.95
static func walk_height(x: float,z: float) -> float:
	if bridge_at(Vector3(x,0,z)):return bridge_height(x)
	if on_dock(Vector3(x,0,z)):return DOCK_HEIGHT
	return height_at(x,z)
static func can_walk(p: Vector3) -> bool:
	if absf(p.x-HOUSE.x)<6.35 and absf(p.z-HOUSE.z)<5.35:return true
	if on_dock(p):return true
	var harbor:=Vector2((p.x+26)/22.,(p.z-84)/22.).length()<1.
	if Vector2(p.x,p.z/.88).length()>100 and not harbor:return false
	if absf(p.x-river_x(p.z))<river_half_width(p.z)+.20 and not bridge_at(p):return false
	return true
static func can_navigate(p: Vector3) -> bool:
	return can_walk(p) and normal_at(p.x,p.z).y>.76
static func valid_saved_position(map_id: String,p: Vector3) -> bool:
	if not p.is_finite():return false
	if map_id=="jade":return p.y<80. and preload("res://scripts/jade/layout.gd").dry_footing(p)
	if map_id=="icefield":return preload("res://scripts/icefield/icefield_layout.gd").valid_position(p)
	if map_id=="valley":return absf(p.x)<110 and p.z> -98 and p.z<124 and p.y> -8 and p.y<80
	return preload("res://scripts/city/town_shore.gd").can_walk(p) or preload("res://scripts/building/site.gd").contains(p)
static func legacy_position(p: Vector3) -> Vector3:
	if absf(p.x-12)<6.35 and absf(p.z+36)<5.35:return HOUSE+Vector3(p.x-12,p.y-4,p.z+36)
	if p.x> -14.2 and p.x< -2.8 and p.z>45.2 and p.z<49.25:return Vector3(-16.8+(p.x+8.4),p.y,DOCK.y+(p.z-47.2))
	var q:=Vector3(p.x*2,0,p.z*2);q.y=walk_height(q.x,q.z)+.035
	return q
static func dock(map_id: String) -> Vector2:return DOCK if map_id=="valley" else Vector2(13,41.5)
static func arrival(map_id: String) -> Array:return [-22,walk_height(-22,86)+.035,86] if map_id=="valley" else [13,.2,39.5]
static func west_path(z: float) -> float:
	var west: float=-16-clampf(64-z,0,44)*.4+sin(z*.07)*1.5
	if z>62:west=lerpf(-16,-22,smoothstep(62.,88.,z))
	return west
static func ascent_path_z(x: float) -> float:
	return 37.-(absf(x)-34.)*.88+3.*sin((absf(x)-34.)*.11)
static func path_distance(x: float,z: float) -> float:
	var result:=absf(x-west_path(z))
	result=minf(result,Vector2(x-(44.+sin(z*.035)*2.5),maxf(z-35.,0.)).length())
	result=minf(result,Vector2(maxf(absf(x)-57.,0.),z-BRIDGE_Z).length())
	result=minf(result,Vector2(x-HOUSE.x,maxf(z+42.,0.)).length())
	result=minf(result,Vector2(maxf(absf(x-5.5)-41.5,0.),z+58.).length())
	var end_distance:=maxf(maxf(25.-absf(x),absf(x)-83.),0.)
	result=minf(result,Vector2(end_distance,(z-ascent_path_z(x))*.75).length())
	return result
static func on_path(x: float,z: float) -> bool:return path_distance(x,z)<2.9
static func in_overlook_vista(point: Vector3) -> bool:
	for side in [-1,1]:
		var start:=Vector2(side*78,ascent_path_z(78));var end:=Vector2(side*10,BRIDGE_Z)
		var p:=Vector2(point.x,point.z);var ray:=end-start;var u: float=(p-start).dot(ray)/ray.length_squared()
		if u<0. or u>1.:continue
		if p.distance_to(start+ray*u)<lerpf(10.,6.,u):return true
	return false
