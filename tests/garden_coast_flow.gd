extends SceneTree
const Shore=preload("res://scripts/city/town_shore.gd")
const Land=preload("res://scripts/building/parcels.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var output: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func draw(count: int=4) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func photo(name_: String) -> void:
	await draw();root.get_texture().get_image().save_png(output+"/"+name_+".png")
func ground(p: Vector2) -> Dictionary:return city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,4,p.y),Vector3(p.x,-3,p.y),8))
func run() -> void:
	output=preload("res://tests/test_support.gd").output_dir()
	var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session);session.create_character("花庭海岸验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.8).timeout;city.set_process(false);city.bunny.set_physics_process(false);session.active=false
	while city.build_mode.ui.studio.busy or not city.build_mode.ui.studio.pending.is_empty():await draw(1)
	var shore: Node3D=city.scenery.get_node("TownNaturalShore")
	check(shore.get_meta("replaced_terrain_cylinders")==3,"Only the old lawn, sand rim and cliff terrain cylinders are replaced")
	var count: int=city.scenery.get_child_count();Shore.ensure(city.scenery)
	check(city.scenery.get_child_count()==count,"Reloading shore upgrade is idempotent")
	for r in [48.,51.,52.]:
		var hit:=ground(Vector2(r,0));check(not hit.is_empty() and absf(hit.position.y+.03)<.006,"Town core remains at its original ground elevation: "+str(r))
	var smooth:=true;var last:=-.03
	for i in range(41):
		var hit:=ground(Vector2(52.+i*.1,0))
		if hit.is_empty() or hit.normal.y<.4 or absf(hit.position.y-last)>.23:smooth=false
		if not hit.is_empty():last=hit.position.y
	check(smooth and last<-.3,"Town edge has a continuous physical slope instead of the old flat hidden collider")
	var site: Node3D=city.scenery.get_node("EastBuildingSite");var commons: Node3D=site.get_node("GardenCommons")
	check(site.find_children("Boundary*","MeshInstance3D",true,false).is_empty(),"All yellow parcel-boundary strips are removed")
	var species: Dictionary={};var heights: Array=[]
	for tree in commons.find_children("PublicTree*","Node3D",true,false):species[tree.get_meta("tree_species")]=true;heights.append(tree.get_node("Crown").position.y)
	check(species.size()==4 and heights.max()-heights.min()>.5,"Public groves have four distinct species and visibly varied heights")
	check(commons.find_children("PerennialBorder*","Node3D",true,false).size()>=6 and commons.has_node("WindingGardenWalk"),"Garden has planted perennial borders and a curved arrival walk")
	check(city.targets.keys().filter(func(id):return str(id).begins_with("bench:EastBuildingSite")).size()==4,"Four garden seats use the normal sit interaction")
	var sign: Node3D=site.get_node("east_nw/Sign");var labels: Array=sign.find_children("*","Label3D",true,false)
	check(labels.size()==4 and labels.all(func(label):return label.billboard==BaseMaterial3D.BILLBOARD_DISABLED and not label.double_sided),"Each sign has fixed front and back text, never camera-facing floating glyphs")
	city.hud.hide();city.bunny.hide();city.update_lighting(.4)
	city.camera.position=Vector3(53,9,33);city.camera.look_at(Vector3(52,.7,13));await photo("town-natural-shore-and-bridge")
	city.camera.position=Vector3(137,46,68);city.camera.look_at(Vector3(110,1,10));await photo("garden-public-redesign")
	city.camera.position=Vector3(100,5,20);city.camera.look_at(Vector3(110,.9,8));await photo("garden-central-plaza")
	for i in range(3):
		var angle: float=[.15,.65,PI+.3][i];city.camera.position=sign.global_position+Vector3(sin(angle)*5.,2.3,cos(angle)*5.);city.camera.look_at(sign.global_position+Vector3.UP*1.4);await photo("fixed-sign-angle-"+str(i))
	city.free();session.free();await process_frame
	print("GARDEN_COAST_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
