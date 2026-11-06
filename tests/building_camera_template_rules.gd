extends SceneTree
const L=preload("res://scripts/building/layout.gd")
const T=preload("res://scripts/building/templates.gd")
const Zoom=preload("res://scripts/services/camera_zoom.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);print("FAIL ",label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var pan:=InputEventPanGesture.new();pan.delta=Vector2(0,.2)
	check(is_equal_approx(Zoom.distance_for(pan,12.,.75,4.5,22.),12.15),"Continuous trackpad scroll preserves small deltas")
	pan.delta.y=-1000.;check(Zoom.distance_for(pan,12.,.75,4.5,22.)==4.5,"Trackpad zoom clamps near limit")
	pan.delta.y=1000.;check(Zoom.distance_for(pan,38.,2.,10.,58.)==58.,"Build trackpad zoom clamps far limit")
	pan.delta=Vector2(4,0);check(not Zoom.accepts(pan),"Horizontal swipe does not zoom")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.factor=.2
	check(is_equal_approx(Zoom.distance_for(wheel,12.,.75,4.5,22.),11.85),"High precision wheel uses its factor")
	wheel.factor=0.;check(Zoom.distance_for(wheel,12.,.75,4.5,22.)==11.25,"Wheel without a factor retains normal tick")
	wheel.pressed=false;check(not Zoom.accepts(wheel),"Wheel release cannot zoom twice")
	var pinch:=InputEventMagnifyGesture.new();pinch.factor=1.2
	check(is_equal_approx(Zoom.distance_for(pinch,12.,.75,4.5,22.),10.),"Pinch magnification adjusts camera distance")
	pinch.factor=0.;check(not Zoom.accepts(pinch),"Invalid magnification is ignored")
	for kind in ["single_one","two_storey"]:
		var source:=T.player_sample(kind);var original:=JSON.stringify(source);var origin:=L.template_origin(source)
		for turn in [0.,90.,180.,270.,360.]:
			var merged:=L.merge_template(L.empty(),source,Vector2(100,10),turn);var result:=L.validate(merged)
			check(result.ok,"Whole template validates at %s/%s: %s"%[kind,turn,result.get("message","")])
			if result.ok:check(L.normalize(JSON.parse_string(JSON.stringify(result.layout)))==result.layout,"Rotated roof directions and attachments survive JSON reload")
			for i in range(source.elements.size()):
				var old: Dictionary=source.elements[i];var row: Dictionary=merged.elements[i]
				check(old.get("appearance",{})==row.get("appearance",{}),"Part materials preserved")
				if old.has("position"):
					var local:=Vector3(old.position[0]-origin.x,0,old.position[1]-origin.y).rotated(Vector3.UP,deg_to_rad(turn))
					check(Vector2(row.position[0],row.position[1]).distance_to(Vector2(100+local.x,10+local.z))<.001,"Furniture and stairs rotate about the template pivot")
				if old.type in ["door","window"]:
					var before:=-(PI*.5 if old.axis==1 else 0.)+(PI if old.get("reverse",false) else 0.)
					var after:=-(PI*.5 if row.axis==1 else 0.)+(PI if row.get("reverse",false) else 0.)
					check(Vector3.RIGHT.rotated(Vector3.UP,before+deg_to_rad(turn)).is_equal_approx(Vector3.RIGHT.rotated(Vector3.UP,after)),"Opening hinge and facing rotate with wall")
					check(L.find(merged,row.wall).type=="wall","Opening remains attached to a remapped wall")
				if old.get("support","").begins_with("build_"):
					check(L.find(merged,row.support).get("kind","")==L.find(source,old.support).get("kind",""),"Supported decorations retain their furniture")
				if old.type=="wall" and old.has("faces"):
					var old_normal:=Vector3.BACK if is_equal_approx(old.a[1],old.b[1]) else Vector3.RIGHT
					var canonical:=Vector3.BACK if is_equal_approx(row.a[1],row.b[1]) else Vector3.RIGHT
					var side: String="positive" if old_normal.rotated(Vector3.UP,deg_to_rad(turn)).dot(canonical)>.5 else "negative"
					check(row.faces.get(side,{})==old.faces.get("positive",{}),"Physical wall side keeps its finish")
		check(JSON.stringify(source)==original,"Template catalog data is never mutated")
	# An odd-width template must still land on the half-metre structure grid.
	var odd:=L.add(L.empty(),{"type":"floor","a":[70.,0.],"b":[73.5,4.]})
	check(L.validate(L.merge_template(L.empty(),odd,Vector2(100,10),90.)).ok,"Odd tile counts rotate on grid")
	var invalid:=T.player_sample("single_one")
	for row in invalid.elements:
		if row.type=="roof":row.yaw=45.;break
	check(not L.validate(invalid).ok,"Roof direction rejects non-quarter turns")
	print("BUILDING_CAMERA_TEMPLATE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
