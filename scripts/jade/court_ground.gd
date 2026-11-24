extends RefCounted
## Offline district painting. RGB encodes stone aprons, alleys and eave shade. Alpha marks masonry walks.
const J=preload("res://scripts/jade/layout.gd")
const SIZE=1024
const HALF=256.
const FIELD_PATHS=[
	[Vector2(108,26),Vector2(109,35),Vector2(103,51),Vector2(98,73),Vector2(98,111),Vector2(98,143)],
	[Vector2(67,111),Vector2(98,111),Vector2(131,111),Vector2(164,111)],
	[Vector2(109,35),Vector2(134,43),Vector2(155,42),Vector2(172,40),Vector2(189,55),Vector2(202,73)],
	[Vector2(-67,-182),Vector2(-104,-189),Vector2(-144,-192),Vector2(-175,-194)],
	[Vector2(-175,-194),Vector2(-103,-199),Vector2(0,-194),Vector2(88,-198),Vector2(143,-193),Vector2(198,-192)],
	[Vector2(64,-183),Vector2(88,-198)]]
static var alleys: Array=FIELD_PATHS+[
	[Vector2(-7,25),Vector2(-22,19),Vector2(-43,17),Vector2(-74,19),Vector2(-108,18)],
	[Vector2(6,27),Vector2(25,19),Vector2(48,19),Vector2(55,31),Vector2(80,39),Vector2(110,23)],
	[Vector2(-8,-33),Vector2(-29,-32),Vector2(-49,-27),Vector2(-68,-27),Vector2(-87,-24),Vector2(-108,-24)],
	[Vector2(5,-34),Vector2(28,-34),Vector2(50,-30),Vector2(66,-32),Vector2(84,-39),Vector2(103,-30)],
	[Vector2(-74,18),Vector2(-63,38),Vector2(-72,65),Vector2(-72,81),Vector2(-54,102),Vector2(-50,122)],
	[Vector2(-9,177),Vector2(-29,173),Vector2(-47,155),Vector2(-52,136),Vector2(-49,115)],
	[Vector2(8,167),Vector2(26,160),Vector2(43,156),Vector2(44,129),Vector2(52,115),Vector2(55,94),Vector2(51,78)],
	[Vector2(-8,-99),Vector2(-25,-90),Vector2(-45,-96),Vector2(-55,-118),Vector2(-50,-139),Vector2(-67,-156)],
	[Vector2(8,-99),Vector2(24,-91),Vector2(44,-96),Vector2(51,-115),Vector2(52,-138),Vector2(64,-154)]]
static func coord(v: float) -> int:return clampi(floori((v+HALF)*2.),0,SIZE-1)
# The fourth channel lays continuous masonry under low open walkways.
static func paving(img: Image,center: Vector2,yaw: float,size_: Vector2) -> void:
	var reach:=size_.length()*.5+.5
	for y in range(coord(center.y-reach),coord(center.y+reach)+1):
		for x in range(coord(center.x-reach),coord(center.x+reach)+1):
			var local_:=(Vector2(x+.5,y+.5)*.5-Vector2(HALF,HALF)-center).rotated(yaw)
			var edge:=local_.abs()-size_*.5
			var coverage:=1.-smoothstep(-.2,.2,maxf(edge.x,edge.y))
			var colour:=img.get_pixel(x,y)
			if coverage>colour.a:
				colour.a=coverage
				img.set_pixel(x,y,colour)

static func make(world: Node3D) -> Image:
	var img:=Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for h in J.HOUSES:
		var c:=J.center(h);var ang:=J.door_angle(h);var d:=J.dims(h[4])
		var royal: bool=h[3]<-82
		var riverside: bool=absf(h[3]-J.river_z(c.x))<36. and absf(c.x)<118.
		var fore:=10.5 if royal else (5.8 if riverside else 4.65)
		var flank:=7.1 if royal else (4.2 if riverside else 2.6)
		var back:=4.0 if royal else 2.7
		var reach:=d.length()+maxf(fore,flank)+3.5
		for y in range(coord(c.y-reach),coord(c.y+reach)+1):
			for x in range(coord(c.x-reach),coord(c.x+reach)+1):
				var p:=(Vector2(x+.5,y+.5)*.5-Vector2(HALF,HALF)-c).rotated(ang)
				var over:=Vector2(maxf(absf(p.x)-d.x,0.),maxf(absf(p.y)-d.z,0.)).length()
				var yard:=Vector2(absf(p.x)-d.x-flank,maxf(-p.y-d.z-back,p.y-d.z-fore))
				var apron:=1.-smoothstep(.15,1.2,yard.max(Vector2.ZERO).length())
				var shade: float=(1.-smoothstep(.0,1.85,over))*.68
				var col:=img.get_pixel(x,y)
				img.set_pixel(x,y,Color(maxf(apron,col.r),col.g,maxf(shade,col.b),0.))
	for alley in alleys:
		var path:=Curve2D.new()
		for i in range(alley.size()):
			var tangent:=Vector2.ZERO
			if i>0 and i+1<alley.size():tangent=(alley[i+1]-alley[i-1]).normalized()*3.1
			path.add_point(alley[i],-tangent,tangent)
		path.bake_interval=.8
		for pos in path.get_baked_points():
			for iy in range(coord(pos.y-2.7),coord(pos.y+2.7)+1):
				for ix in range(coord(pos.x-2.7),coord(pos.x+2.7)+1):
					var p:=Vector2(ix+.5,iy+.5)*.5-Vector2(HALF,HALF)
					var wear:=1.-smoothstep(1.47,2.65,p.distance_to(pos))
					var col:=img.get_pixel(ix,iy)
					if wear>col.g:img.set_pixel(ix,iy,Color(col.r,wear,col.b,0.))
	for part in world.get_children():
		if not part.has_meta("veranda_paving"):continue
		var rect: Rect2=part.get_meta("veranda_paving")
		var at:=rect.get_center()
		var point: Vector3=part.to_global(Vector3(at.x,0,at.y))
		paving(img,Vector2(point.x,point.z),part.rotation.y,rect.size*Vector2(part.scale.x,part.scale.z))
		part.remove_meta("veranda_paving")
	for row in J.TERRACES:
		for end in [-1,1]:
			for j in range(7):
				var z: float=(row[1] if end<0 else row[2])-end*(j+.5)*.95
				paving(img,Vector2(J.lane(z)+row[0]*11.7,z),0.,Vector2(3.8,.95))
	img.generate_mipmaps()
	return img
