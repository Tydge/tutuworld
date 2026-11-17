extends SceneTree
const L=preload("res://scripts/valley/valley_layout.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label_)
 if not ok:failures.append(label_)
func run() -> void:
 var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.state().map_id="valley";s.state().player_position=L.arrival("valley")
 var g=load("res://scenes/valley.tscn").instantiate();root.add_child(g)
 while g.camera==null or not g.navigation.ready_for_paths:await process_frame
 s.active=false;g.set_process(false);var original: CharacterBody3D=g.bunny;original.hide();original.set_physics_process(false);original.collision_layer=0
 for species in ["bunny","cat_teacher","panda"]:
  var actor: CharacterBody3D=preload("res://scripts/characters/animal_factory.gd").create(species);g.add_child(actor);actor.world=g;actor.can_move=false;g.bunny=actor
  for side in [-1,1]:
   var x: float=side*78.;var z:=L.ascent_path_z(x);actor.position=Vector3(x,L.height_at(x,z)+.04,z);actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
   await g.recover_spawn()
   for i in range(15):await physics_frame
   check(Vector2(actor.position.x-x,actor.position.z-z).length()<.20,"Valid high save stays on its hillside "+species+str(side))
   check(actor.is_on_floor() and absf(actor.position.y-L.height_at(actor.position.x,actor.position.z))<.3,"Resumed avatar is supported by real sloping floor "+species+str(side))
  var tree: Node3D=g.scenery.get_node("AncientForest").find_children("AncientTrunk*","StaticBody3D",true,false)[0]
  actor.position=tree.global_position+Vector3.UP*.05;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation();await g.recover_spawn()
  check(actor.position.distance_to(tree.global_position)>.65 and L.can_walk(actor.position),"New tree overlapping an old save gets a safe exit "+species)
  g.bunny=original;actor.queue_free();await process_frame
 print("VALLEY_SPAWN_REGRESSION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
