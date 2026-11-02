extends SceneTree
const Animals=preload("res://scripts/characters/animal_factory.gd")
const S=preload("res://scripts/services/session.gd")
const DB=preload("res://scripts/services/game_data.gd")
const Outfit=preload("res://scripts/city/outfit.gd")
const People=preload("res://scripts/city/npc_profiles.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok: failures.append(label_)
func run() -> void:
	check(Animals.Catalog.supports("panda") and Animals.Catalog.display_name("panda")=="熊猫","Panda is a registered third species")
	var actor:=Animals.create("panda");root.add_child(actor)
	check(actor.rig_profile.species_id=="panda" and actor.get_script()==load("res://scripts/characters/animal_actor.gd"),"Panda uses the existing controller and animation implementation")
	check(actor.find_children("Wardrobe_*","Node3D",true,false).is_empty(),"Base panda contains no baked clothing")
	for path in ["Visual/Head/Eyes","Visual/Head/Mouth","Visual/Head/LeftEar","Visual/Head/RightEar","Visual/LeftArm","Visual/RightArm/Cup","Visual/LeftLeg","Visual/RightLeg","Mood"]:
		check(actor.has_node(path),"Shared semantic rig: "+path)
	check(actor.get_node("Visual/Head/PlushHead").mesh.get_aabb().size.z<1.40,"Head keeps a rounded side profile with a shallow muzzle")
	var total:=0
	for id in DB.catalog().items:
		var item:=DB.item(id)
		if item.kind!="clothing": continue
		total+=1;Outfit.apply(actor,{item.slot:id})
		var path: String="Visual/Head/Wardrobe_head" if item.slot=="head" else "Visual/Wardrobe_"+item.slot
		check(actor.has_node(path),"Existing garment attaches without a species-specific copy: "+id)
	check(total==27,"All twenty-seven current clothes are supported")
	var session:=S.new();root.add_child(session)
	var first: Dictionary=session.create_character("原岛民","bunny","vest_sage")
	session.state().experience=7;session.authority.add("branch",4);session.state().plots.plot_00.crop="carrot"
	var panda: Dictionary=session.create_character("竹团","panda","scarf_blue")
	check(panda.ok and session.state().species=="panda" and session.settings.player_species=="panda","Panda can be created and selected")
	check(session.state().equipment.neck=="scarf_blue" and session.authority.count("scarf_blue")==1,"Panda receives the normal single starter")
	check(session.state().experience==0 and session.authority.count("branch")==0 and session.state().plots.plot_00.crop=="carrot","Panda has independent progress on the existing shared island")
	var fixture: String="/tmp/tutu-panda-%d.json"%OS.get_process_id();session.save_path=fixture;session.test_mode=false
	check(session.save_game(),"Panda roster saves normally")
	var loaded:=S.new();root.add_child(loaded);loaded.save_path=fixture;loaded.load_save()
	check(loaded.state().species=="panda" and loaded.state().character_name=="竹团" and loaded.state().equipment.neck=="scarf_blue","Panda identity and clothing survive reload")
	loaded.test_mode=true;check(loaded.select_character(first.id).ok and loaded.state().experience==7 and loaded.authority.count("branch")==4,"Existing rabbit progress remains intact")
	loaded.select_character(panda.id);loaded.state().character_name=""
	check(loaded.authority.actor_name()=="熊猫","Unnamed panda messages use the right species label")
	var lines: Dictionary={};var previous:=""
	for i in range(100):
		var current:=People.line_for(5,previous)
		if current==previous: failures.append("Repeated NPC line")
		lines[current]=true;previous=current
	check(lines.size()==People.available_lines("Youmu",12).size() and People.PANDA_YOUMU.lines.size()==8,"Youmu has eight lines with time-filtered non-repeating choices")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(fixture+suffix): DirAccess.remove_absolute(fixture+suffix)
	session.test_mode=true;actor.queue_free()
	print("PANDA_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
