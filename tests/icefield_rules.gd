extends SceneTree
const L=preload("res://scripts/icefield/icefield_layout.gd")
const V=preload("res://scripts/valley/valley_layout.gd")
const Routes=preload("res://scripts/services/map_routes.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Authority=preload("res://scripts/services/local_authority.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func run() -> void:
	var ice_area:=0;var valley_area:=0;var ice_points:=0;var snow_min:=INF;var snow_max:=-INF;var continuity:=0.
	for z in range(-160,161,2):
		for x in range(-180,181,2):
			var p:=Vector3(x,L.walk_height(x,z)+.035,z)
			if L.can_walk(p) and L.normal_at(x,z).y>cos(PI*.25):
				ice_area+=4
				if L.is_ice(p):ice_points+=1
				elif L.ellipse(x,z)<.9:snow_min=minf(snow_min,p.y);snow_max=maxf(snow_max,p.y)
				continuity=maxf(continuity,absf(L.height_at(x-.001,z)-L.height_at(x+.001,z)))
			if V.can_walk(Vector3(x,0,z)):valley_area+=4
	print("PLAYABLE_AREA icefield_m2=",ice_area," valley_m2=",valley_area," ratio=",float(ice_area)/valley_area)
	check(ice_area>valley_area*2,"Real walkable footprint exceeds twice current valley")
	check(ice_points*4>ice_area*.48,"Broad eastern icefield occupies approximately half the island")
	check(snow_max-snow_min>5. and snow_max-snow_min<13.,"West snow town has gentle real elevation")
	check(continuity<.012,"Continuous snow, ice and harbor terrain")
	check(L.ACCELERATION<20. and L.BRAKING<2. and L.BRAKING<L.ACCELERATION,"Low ice startup and braking acceleration")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/winter_objects.json"))
	for row in catalog.items:
		var packed: PackedScene=load(row.scene);var module: Node3D=packed.instantiate()
		check(module.get_meta("winter_asset_id","")==row.id and module.get_meta("buildable_reference",false),"Reusable placeable module "+row.id)
		for anchor in row.get("anchors",[]):check(module.has_node(NodePath(anchor)),"Local module anchor "+row.id+":"+anchor)
		module.free()
	var a:=Authority.new();a.state.player_position=[13,.2,41.5];var coins: int=a.state.coins
	check(a.execute({"verb":"travel","destination":"icefield"}).ok and a.state.map_id=="icefield" and a.state.coins==coins-10,"City to icefield debits exactly ten")
	check(a.state.player_position==L.arrival(),"Arrival is the safe snow harbor")
	check(not a.execute({"verb":"travel","destination":"valley"}).ok,"No unlisted cross-island route")
	var ids: Dictionary={};var types: Dictionary={}
	for r in DB.all_resources():check(not ids.has(r.id),"Unique persistent resource ID "+r.id);ids[r.id]=true
	for r in DB.resources("icefield"):
		check(L.can_walk(Vector3(r.x,r.y,r.z)) and L.normal_at(r.x,r.z).y>.86,"Resource is reachable "+r.id)
		types[r.item]=true
		a.state.player_position=[r.x,r.y,r.z];a.state.stamina=100
		for skill in a.state.skills:a.state.skills[skill]=10;a.state.skill_experience[skill]=preload("res://scripts/services/character_stats.gd").skill_start(10)
		var tool: String=DB.item(r.item).get("tool","")
		if tool!="":a.add(tool,1)
		var before: int=a.count(r.item);var result: Dictionary=a.execute({"verb":"gather","target":r.id})
		check(result.ok,"Starts icefield gathering "+r.id)
		if result.ok:a.tick(a.job.duration+.01);check(a.count(r.item)>before and not a.state.resources[r.id].available,"Collects and schedules regeneration "+r.id)
	check(types.size()==6 and not types.has("orange"),"All six wood, ore and stone resources; no oranges")
	for b in L.BUILDINGS:
		if b.kind!="shop":continue
		a.state.player_position=[b.x,L.height_at(b.x,b.z)+.18,b.z-2.72]
		var item: String={"farm":"seed_carrot","tools":"pickaxe","clothes":"bow_rose"}[b.id]
		a.state.coins=10000;a.state.inventory.erase(item)
		check(a.execute({"verb":"buy","shop":b.id,"item":item}).ok,"Snow town shop can trade "+b.id)
		a.state.player_position=[b.x,0,b.z+30.]
		check(not a.execute({"verb":"buy","shop":b.id,"item":item}).ok,"Remote shop trade is rejected "+b.id)
	a.state.player_position=[L.DOCK.x,L.DOCK_HEIGHT,L.DOCK.y];coins=a.state.coins
	check(a.execute({"verb":"travel","destination":"city"}).ok and a.state.coins==coins,"Icefield return is free")
	var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("雪地存档","panda","scarf_red")
	var raw: Dictionary=s.snapshot();raw.map_id="icefield";raw.player_position=[85.,.84,-37.];raw.coins=783;raw.inventory.iron=11
	var restored=s.restore_state(raw)
	check(restored.state.map_id=="icefield" and restored.state.player_position==raw.player_position and restored.state.coins==783 and restored.count("iron")==11,"Icefield save preserves position, identity and assets")
	raw.map_id="city";raw.player_position=[13,.2,39.5];raw.resources.erase("icefield_branch_00")
	check(s.restore_state(raw).state.resources.has("icefield_branch_00"),"Old saves gain new sources without resetting old world data")
	print("ICEFIELD_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
