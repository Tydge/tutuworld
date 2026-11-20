extends RefCounted
## Baked street-front details. Geometry is in metres relative to each attachment.
const VANILLA := "fff1cf"
const COLORS := ["349eb9","de7556","52ac8d"]
const PALE := ["a1e2da","ffc49b","a8e2b2"]

static func awning(b,shop: int) -> void:
	var width := 8.66
	for stripe in range(15):
		var tint: String = COLORS[shop] if stripe%2==0 else VANILLA
		var x := -width*.5 + stripe*width/15.
		var step_ := width/15.
		for k in range(5):
			var a := k/5.
			var c := (k+1)/5.
			var back := Vector3(x,.51-.30*a*a,a*1.44)
			var front := Vector3(x,.51-.30*c*c,c*1.44)
			b.panel(back,back+Vector3.RIGHT*step_,front+Vector3.RIGHT*step_,front,Vector3.UP,tint)
		# A true scalloped hem, with a cream welt tracing its lower edge.
		for k in range(5):
			var u:=k/5.
			var v:=(k+1)/5.
			var a:=Vector3(x+step_*u,.20,1.44)
			var d:=Vector3(x+step_*v,.20,1.44)
			var q:=a-Vector3.UP*(.19+.16*sin(PI*u))
			var s:=d-Vector3.UP*(.19+.16*sin(PI*v))
			b.panel(a,d,s,q,Vector3.BACK,tint)
			b.panel(q,s,s-Vector3.UP*.037,q-Vector3.UP*.037,Vector3.BACK,VANILLA)
	for x in [-width*.5,width*.5]:
		b.drum(Vector3(x,-.31,.02),Vector3(x,.17,1.38),.037,.03,"a57d55",8)

static func shutters(b,shop: int) -> void:
	for window in [-3.69,3.69]:
		for side in [-1.,1.]:
			var x: float=window+side*.90
			b.box(Vector3(x,2.13,.02),Vector3(.42,1.93,.095),COLORS[shop])
			for j in range(8):
				b.box(Vector3(x,1.34+j*.225,.10),Vector3(.33,.093,.075),PALE[shop])
			for edge in [-.82,.82]:
				b.box(Vector3(x,2.13+edge,.155),Vector3(.29,.048,.034),"978763")

static func medallion(b,shop: int) -> void:
	# Glazed enamel sign with a convex brass lip and a carved shop emblem.
	b.drum(Vector3(0,0,0),Vector3(0,0,.12),.73,.72,"ac8557",48)
	b.drum(Vector3(0,0,.11),Vector3(0,0,.19),.70,.67,VANILLA,48)
	b.drum(Vector3(0,0,.18),Vector3(0,0,.22),.61,.61,COLORS[shop],48)
	match shop:
		0:
			b.drum(Vector3(-.20,-.34,.29),Vector3(.16,.17,.29),.025,.19,"ffab4f",12)
			for i in range(3):
				b.ellipsoid(Vector3(.06+i*.11,.26,.30),Vector3(.075,.18,.033),"c0eb84",-.55+i*.46)
		1:
			b.drum(Vector3(-.31,-.32,.26),Vector3(.23,.24,.26),.063,.074,"ffe1a0",10)
			b.box(Vector3(.16,.19,.29),Vector3(.61,.19,.13),"f2d3a2",-.79)
			b.box(Vector3(.34,.01,.30),Vector3(.16,.24,.14),"93bfb4",-.79)
		2:
			b.drum(Vector3(0,-.35,.32),Vector3(0,.34,.32),.19,.19,"f8c6b2",16)
			for y in [-.28,-.15,-.03,.09,.21,.28]:
				b.drum(Vector3(0,y-.019,.32),Vector3(0,y+.019,.32),.225,.225,"fff1cf" if abs(y)>.23 else "e79494",16)
			b.drum(Vector3(-.33,-.31,.55),Vector3(.28,.37,.55),.023,.013,"e6c780",6)

static func pennants(b) -> void:
	var span := 9.2
	for i in range(24):
		var x := -.5*span + i*span/24.
		var end := x+span/24.
		b.drum(Vector3(x,sag(x),0),Vector3(end,sag(end),0),.020,.020,"92805d",6)
	for i in range(11):
		var x:= -3.83+i*.77
		var left:=Vector3(x-.262,sag(x-.262)-.02,0)
		var right:=Vector3(x+.262,sag(x+.262)-.02,0)
		var tip:=Vector3(x+.065,sag(x)-.52-(i%3)*.032,.085)
		var mid:=left.lerp(right,.5)+Vector3(0,0,.072)
		var tint: String=["ffa26f","8ddacd","fcce71","aab9e4","fcada7"][i%5]
		b.facet(left,mid,tip,Vector3.BACK,tint)
		b.facet(mid,right,tip,Vector3.BACK,Color(tint).darkened(.055).to_html(false))
		# Little diamond stitches, raised just ahead of the fold.
		var p:=mid+Vector3(0,-.16,.019)
		b.panel(p+Vector3.UP*.060,p+Vector3.RIGHT*.043,p-Vector3.UP*.060,p-Vector3.RIGHT*.043,Vector3.BACK,VANILLA)

static func sag(x: float) -> float:
	return -.42*(1.-pow(x/4.60,2.))

static func flowers(b) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=29124
	for i in range(75):
		var a:=i*2.39996
		var r:=sqrt((i+.50)/75.)
		var p:=Vector3(cos(a)*r*1.83,0,sin(a)*r*.70)
		var h:=rng.randf_range(.16,.56)*(1.08-.29*r)
		var top:=p+Vector3(sin(i)*.08,h,cos(i)*.05)
		var shade: String=["66a65e","83b95b","669555"][i%3]
		for j in range(3):
			var dir:=Vector3(cos(a+j*2.06),0,sin(a+j*2.06))
			var side:=Vector3(-dir.z,0,dir.x)*.055
			var end:=p+dir*rng.randf_range(.12,.25)+Vector3.UP*h*.75
			b.facet(p,p+side+dir*.10,end,Vector3.UP,shade)
			b.facet(p,end,p-side+dir*.10,Vector3.UP,"81b16a")
		if i%3==1:
			b.drum(p,top,.012,.008,"619455",5)
			for j in range(4):
				b.ellipsoid(top+Vector3(0,.046*j,0),Vector3(.050-j*.007,.050,.050-j*.007),"a995dc" if i%2 else "cab0e5")
		elif i%3==2:
			b.drum(p,top,.010,.007,"6f9b51",5)
			for j in range(6):
				var dir:=Vector3(cos(j*TAU/6.+a),.21,sin(j*TAU/6.+a))
				var side:=Vector3(-dir.z,0,dir.x)*.039
				b.panel(top,top+dir*.055+side,top+dir*.111,top+dir*.055-side,Vector3.UP,"fff2bd" if i%2 else "ffa285")
			b.ellipsoid(top+Vector3.UP*.014,Vector3(.038,.024,.038),"ecc660")
