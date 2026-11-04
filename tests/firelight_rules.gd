extends SceneTree
const L=preload("res://scripts/building/layout.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var model:=Node3D.new();root.add_child(model);preload("res://scripts/building/module_factory.gd").builder(model).build_item(model,"hearth")
	var fire: SpotLight3D=model.get_node("FixtureFireLight");var motion: Node=fire.get_node("FireFlicker");motion.set_process(false)
	check(fire.light_energy>0 and not fire.shadow_enabled and fire.spot_range<=5. and fire.distance_fade_enabled,"Buildable hearth has a bounded real light without shadow-map passes")
	var minimum:=INF;var maximum:=0.;var before: int=motion.updates;var started:=Time.get_ticks_usec()
	for i in range(600):motion._process(1./60.);minimum=minf(minimum,fire.light_energy);maximum=maxf(maximum,fire.light_energy)
	var elapsed:=Time.get_ticks_usec()-started
	check(maximum-minimum>motion.base_energy*.32 and minimum>=motion.base_energy*.735 and maximum<=motion.base_energy*1.265,"Warm firelight has a perceptible smooth envelope without flashes or blackouts")
	check(motion.updates-before<=201 and motion.updates-before>=195,"Energy updates at twenty Hz instead of every rendered frame")
	motion.reduced=true;fire.light_energy=motion.base_energy;motion._process(.2);check(fire.light_energy==motion.base_energy,"Reduced motion keeps a steady flame light")
	print("FIRELIGHT_CPU elapsed_usec=",elapsed," simulated_frames=600 updates=",motion.updates-before)
	var layout:=L.add(L.empty(),{"type":"floor","a":[61.,-7.],"b":[97.,27.]})
	for i in range(16):layout=L.add(layout,{"type":"object","kind":"hearth","position":[64.+(i%8)*4.,float(floori(i/8.))*4.],"yaw":0.})
	check(L.validate(layout).ok and L.usage(layout).lights==16,"Fireplaces share the actual-light capacity budget")
	var extra:=L.add(layout,{"type":"object","kind":"hearth","position":[64.,8.],"yaw":0.})
	check(not L.validate(extra).ok,"A seventeenth new fireplace cannot evade the light limit")
	extra.erase("lighting_version");var legacy:=L.validate(extra)
	check(legacy.ok and legacy.layout.get("legacy_light_limit",0)==17,"An old layout retains its formerly uncounted fireplace light without losing furniture")
	if legacy.ok:check(not L.validate(L.add(legacy.layout,{"type":"object","kind":"hearth","position":[68.,8.],"yaw":0.})).ok,"The old-save exemption cannot expand to a newly placed fireplace")
	model.free();print("FIRELIGHT_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
