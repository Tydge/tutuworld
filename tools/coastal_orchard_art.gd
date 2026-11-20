extends RefCounted
const Spurs:=preload("res://scripts/city/coastal/fruit_spurs.gd")
var b
var rng:=RandomNumberGenerator.new()
var citrus:=true
var shadow:=false
var shade_lobe:=SphereMesh.new()

func bark(points: Array,radii: Array,sides: int) -> void:
	if shadow and radii[0]<.04:return
	var lengths:=PackedFloat32Array([0.])
	for i in range(1,points.size()):lengths.append(lengths[-1]+points[i].distance_to(points[i-1]))
	if shadow:sides=mini(sides,5)
	for i in range(points.size()-1):
		for j in range(sides):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				var n: int=i+corner.y
				var along: Vector3=(points[mini(n+1,points.size()-1)]-points[maxi(n-1,0)]).normalized()
				var right:=along.cross(Vector3.BACK).normalized()
				if right.length_squared()<.5:right=along.cross(Vector3.RIGHT).normalized()
				var around:=along.cross(right)
				var a: float=(j+corner.x)*TAU/sides
				var normal:=right*cos(a)+around*sin(a)
				var fluting:=1.+.065*sin(a*3.+lengths[n]*.64)
				var dye:=Color("997554").lerp(Color("c99460"),.46+.32*sin(a*3.+.22*lengths[n])).srgb_to_linear()
				dye.a=0.
				b.surface.set_color(dye)
				b.surface.set_uv(Vector2.ZERO)
				b.surface.set_normal(normal)
				b.surface.add_vertex(points[n]+normal*float(radii[n])*fluting)

func leaf(base: Vector3,dir: Vector3,size_: float,cos_sun: float) -> void:
	var axis:=dir.normalized()
	var side:=Vector3(-axis.z,0,axis.x).normalized()
	var tilt:=rng.randf_range(-.37,.37)
	var width:=size_*rng.randf_range(.25,.34)*(1. if citrus else .76)*(1.22 if shadow else 1.)
	side=(side+Vector3.UP*tilt).normalized()
	var tip:=base+axis*size_-Vector3.UP*size_*.14
	var mid:=base+axis*size_*.52+Vector3.UP*size_*.070
	var neck:=base+axis*size_*.24
	var far:=base+axis*size_*.75
	var pos: Array[Vector3]=[base,neck+side*width*.71,mid+side*width,far+side*width*.68,tip,far-side*width*.68,mid-side*width,neck-side*width*.71]
	var normal: Vector3=Vector3.UP.lerp(axis,.27).normalized()
	var t:=clampf(cos_sun+rng.randf_range(-.18,.18),0.,1.)
	var dark:=Color("307d50" if citrus else "487f5d")
	var light:=Color("82b65e" if citrus else "96b772")
	var tone:=dark.lerp(light,t)
	if shadow:return
	var edge: Array=[0,1,2,3,4,5,6,7]
	for j in range(edge.size()):
		for index in [-1,edge[j],edge[(j+1)%edge.size()]]:
			var ridge: bool=index==-1
			var p: Vector3=mid+Vector3.UP*size_*.085 if ridge else pos[index]
			var offset: float=(p-mid).dot(side)/maxf(width,.01)
			var color_: Color=tone.lightened(.045 if ridge else (.018 if offset>0. else 0.)).srgb_to_linear()
			color_.a=.54+.40*clampf((p-base).dot(axis)/size_,0.,1.)
			b.surface.set_color(color_)
			b.surface.set_uv(Vector2(clampf((p-base).dot(axis)/size_,0.,1.),clampf(.5+offset*.43,0.,1.)))
			b.surface.set_normal((normal+side*offset*.65).normalized())
			b.surface.add_vertex(p)

func spray(base: Vector3,axis: Vector3,length_: float,sun: float) -> void:
	var reach:=axis.normalized()*length_
	var side:=Vector3(-axis.z,0,axis.x).normalized()
	var end:=base+reach
	bark([base,base+reach*.50+Vector3.UP*.055,end],[.020,.013,.005],4)
	for k in range(4):
		var t:=.16+.21*k
		for sign_ in [-1.,1.]:
			var p:=base+reach*t+Vector3.UP*sin(t*PI)*.053
			var dir: Vector3=side*sign_*rng.randf_range(.47,.80)+axis*.59+Vector3.UP*rng.randf_range(-.15,.31)
			leaf(p,dir,rng.randf_range(.26,.41)*(1. if citrus else .95),sun+.045*k)
	leaf(end-reach*.09,axis+Vector3.UP*.22,rng.randf_range(.20,.30),sun+.12)
	if shadow:
		# Closed leaf masses are visible to the shadow camera from both above and below.
		# Their dimensions follow the paired leaves on this shoot, leaving gaps between shoots.
		for d in [-1.,1.]:
			var center: Vector3=base+reach*(.49+.11*d)+side*d*.14+Vector3.UP*.085
			var basis:=Basis.looking_at(axis.normalized(),Vector3.UP).scaled_local(Vector3(.207,.12,length_*.48+.115))
			b.stamp(shade_lobe,Transform3D(basis,center),"ffffff")

func cluster(base: Vector3,axis: Vector3,size_: float,sun: float) -> void:
	var az:=atan2(axis.z,axis.x)
	for j in range(8):
		var a:=az+j*TAU/8.+rng.randf_range(-.20,.20)
		var reach:=(Vector3(cos(a),rng.randf_range(.03,.85),sin(a))+.42*axis).normalized()
		spray(base,reach,size_*rng.randf_range(.67,1.03),sun+rng.randf_range(-.13,.13))

func build(baker,fruiting: bool,shadow_only:=false) -> void:
	shade_lobe.radius=1.
	shade_lobe.height=2.
	shade_lobe.radial_segments=6
	shade_lobe.rings=2
	shadow=shadow_only
	b=baker
	citrus=fruiting
	rng.seed=54181 if citrus else 73191
	var trunk: Array[Vector3]=[Vector3(0,-.08,0),Vector3(.05,.52,.03),Vector3(-.09,1.28,.07),Vector3(.05,1.87,.03),Vector3(-.11,2.60,-.06),Vector3(.06,3.16,-.03),Vector3(.10,3.80,.09)]
	bark(trunk,[.30,.266,.225,.18,.13,.086,.039],12)
	for i in range(5):
		var out:=Spurs.direction(i)
		var root:=out*rng.randf_range(.39,.57)
		bark([Vector3(0,.38,0),root*.57+Vector3.UP*.09,root-Vector3.UP*.047],[.108,.088,.031],6)
		var elbow:=Spurs.elbow(i)
		var fork:=Spurs.fork(i)
		var tip:=Spurs.tip(i)
		var crotch: Vector3=trunk[2+(i%2)]
		bark([crotch,crotch.lerp(elbow,.48)-Vector3.UP*.09,elbow,fork],[.155,.121,.10,.076],9)
		var bend:=fork.lerp(tip,.55)+Vector3.UP*.10
		bark([fork,bend,tip],[.072,.047,.022],7)
		# Leaves share the final fruit-bearing twig, above the fruit's calyx.
		for j in range(3):
			var angle: float=(j-1)*.81
			leaf(tip.lerp(bend,.08+j*.13),out.rotated(Vector3.UP,angle)+Vector3.UP*.43,.26+j*.034,.72)
		# The fruit is cradled between two lower fans; leave an outward-facing
		# opening where the calyx and its continuous bearing twig can be seen.
		var tangent:=out.rotated(Vector3.UP,PI*.5)
		for side in [-1.,1.]:
			var start:=bend.lerp(tip,.50)+Vector3.UP*.035
			var shoulder: Vector3=start+tangent*side*.19+Vector3.UP*.01
			bark([start,shoulder],[.028,.012],5)
			for j in range(4):
				var direction_: Vector3=(tangent*side*.54+out*(.12+j*.21)+Vector3.UP*(.43-j*.21)).normalized()
				spray(shoulder,direction_,.39+.054*j,.38+.12*j)
		for j in range(3):
			var sideways:=out.rotated(Vector3.UP,PI*.5)
			var p:=fork+out*(.11+j*.13)+sideways*(j-1)*.64+Vector3.UP*(.09+.22*(j%2)+.22*sin(i))
			bark([fork,fork.lerp(p,.55)+Vector3.UP*.07,p],[.068,.045,.020],6)
			cluster(p,out*.63+Vector3.UP*.49,rng.randf_range(.54,.79),.28+.105*j+.043*i)
		var upper:=elbow+out*.29+Vector3.UP*(1.02+.095*i)
		bark([elbow,elbow.lerp(upper,.62)-out*.07,upper],[.083,.052,.023],7)
		cluster(upper,out+Vector3.UP*.34,.77,.54+i*.032)
	for j in range(6):
		var a:=j*2.39996
		var base:=trunk[-2] if j%2 else trunk[-1]
		var peak:=Vector3(cos(a)*(.40+.11*(j%2)),3.78+.15*(j%3),sin(a)*.50)
		bark([base,base.lerp(peak,.56)+Vector3.UP*.06,peak],[.052,.037,.018],6)
		cluster(peak,Vector3(cos(a),.7,sin(a)),.64,.81)
