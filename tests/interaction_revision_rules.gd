extends SceneTree
const Server=preload("res://server/world_server.gd")
const Animals=preload("res://scripts/characters/animal_factory.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
 checks+=1
 if not ok:failures.append(label_);print("FAIL ",label_)
func run() -> void:
 Engine.max_fps=90;Engine.time_scale=3
 OS.set_environment("TUTU_GAME_PORT","18901")
 OS.set_environment("TUTU_STATE_DIR",ProjectSettings.globalize_path("res://.qa-artifacts/0.3.2/rules-"+str(Time.get_ticks_usec())))
 var server=Server.new();root.add_child(server)
 while not server.ready_for_players or not server.maps.valley.navigation.sampling_ready:await physics_frame
 var city=server.maps.city;var count_:=0;var positions: Array=[]
 for id in city.targets:
  if not str(id).begins_with("bench:"):continue
  count_+=1;var target: Dictionary=city.targets[id]
  check(target.position.is_equal_approx(target.node.global_position),"Bench target uses its own physical position")
  check(not positions.has(target.position),"Repeated names do not overwrite another seat");positions.append(target.position)
 check(count_==5,"All four park benches and the beach bench have unique targets")
 for npc in city.npcs:npc.process_mode=Node.PROCESS_MODE_DISABLED;npc.collision_layer=0
 for species in Animals.Catalog.ids():
  var actor=Animals.create(species);city.add_child(actor);actor.set_physics_process(false)
  for shop_id in ["farm","tools","clothes"]:
   var shop=city.scenery.get_node("Shop_"+shop_id)
   for offset in [-1.3,0.,1.3]:
    var from: Vector3=shop.to_global(Vector3(offset,.03,6.2));var target: Vector3=shop.to_global(Vector3(offset,.18,3.1))
    actor.position=from;actor.velocity=Vector3.ZERO;actor.reset_physics_interpolation()
    var arrived:=false
    for i in range(105):
     await physics_frame
     var direction: Vector3=target-actor.position;direction.y=0
     if direction.length()<.18:arrived=true;break
     var delta: float=Engine.time_scale/Engine.physics_ticks_per_second
     actor.velocity.x=direction.normalized().x*2.8;actor.velocity.z=direction.normalized().z*2.8
     actor.velocity.y=-.2 if actor.is_on_floor() else actor.velocity.y-18*delta
     actor.move_on_ground(delta)
    check(arrived,"Walk over shop step without jumping: "+species+"/"+shop_id+"/"+str(offset))
  actor.queue_free();await process_frame
 var valley=server.maps.valley;var panda=valley.targets.Panda.node;var routine=panda.get_node("PandaRoutine")
 for from in [Vector3(12,4.05,-29.3),Vector3(22,2.05,-17),Vector3(-18,2.05,-17)]:
  server.state().time=7*3600./24
  for i in range(4):await physics_frame
  check(not panda.sleeping,"Panda wakes with normal collision")
  panda.position=from;panda.velocity=Vector3.ZERO;panda.reset_physics_interpolation();routine.path.clear();routine.returning=false;routine.wait=0;routine.recovery_time=0
  server.state().time=21*3600./24
  var elapsed:=0.0
  while not panda.sleeping and elapsed<110:
   await physics_frame;elapsed+=Engine.time_scale/Engine.physics_ticks_per_second
  check(panda.sleeping,"Panda walks from outdoors to bed: "+str(from)+" elapsed="+str(elapsed))
  check(panda.sleeping and panda.collision_layer==0 and panda.position.distance_to(valley.home.global_position)<7,"Panda sleeps inside the cottage")
 Engine.time_scale=1
 server.listener.stop();server.queue_free();await process_frame
 print("INTERACTION_REVISION_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
