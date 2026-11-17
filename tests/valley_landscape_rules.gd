extends SceneTree
const L=preload("res://scripts/valley/valley_layout.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label_: String) -> void:
 checks+=1
 print("PASS " if ok else "FAIL ",label_)
 if not ok:failures.append(label_)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 check(is_equal_approx(L.SIZE.x*L.SIZE.y/(L.LEGACY_SIZE.x*L.LEGACY_SIZE.y),4.),"Exactly four times original map area")
 var jump:=0.;var minimum:=INF;var maximum:=-INF;var finite:=true
 for z in range(-90,106):
  for x in range(-104,105):
   if not L.terrain_contains(x,z):continue
   var h: float=L.height_at(x,z);finite=finite and is_finite(h);minimum=minf(minimum,h);maximum=maxf(maximum,h)
   # Every former/chunk/integer boundary, with probes only 2 mm apart.
   jump=maxf(jump,absf(L.height_at(x-.001,z)-L.height_at(x+.001,z)))
   jump=maxf(jump,absf(L.height_at(x,z-.001)-L.height_at(x,z+.001)))
 for side in [-1,1]:
  for z in range(60,141):
   var zz:=z*.1
   for x in [8.5,11.4,11.5,12.,16.,23.]:jump=maxf(jump,absf(L.height_at(side*x-.001,zz)-L.height_at(side*x+.001,zz)))
 check(finite and jump<.012,"Continuous terrain, including bridge approaches, max 2mm probe change="+str(jump))
 check(maximum-minimum>32.,"Valley has substantial real relief: "+str(maximum-minimum))
 var summit:=L.height_at(-78,L.ascent_path_z(-78));var bottom:=L.height_at(-11,-23)
 check(summit-bottom>20.,"Walkable western overlook stands over twenty metres above riverbank")
 var steepest:=0.
 for side in [-1,1]:
  var previous:=Vector3(side*34,L.height_at(side*34,L.ascent_path_z(34)),L.ascent_path_z(34))
  for step in range(1,89):
   var x: float=34.+step*.5;var p:=Vector3(side*x,L.height_at(side*x,L.ascent_path_z(x)),L.ascent_path_z(x))
   steepest=maxf(steepest,absf(p.y-previous.y)/Vector2(p.x-previous.x,p.z-previous.z).length());previous=p
 check(steepest<.8,"Actual ascending trails remain below walking slope limit, max grade="+str(steepest))
 var bank_ok:=true
 for z in range(-90,89):
  for side in [-1,1]:
   var x: float=L.river_x(z)+side*(L.river_half_width(z)+1.)
   bank_ok=bank_ok and L.height_at(x,z)>L.water_level(z)
 check(bank_ok,"Continuous water is contained below both banks before the estuary")
 var session=load("res://scripts/services/session.gd").new();session.name="Session";root.add_child(session)
 session.create_character("存档迁移测试","cat_teacher","scarf_green")
 for old in [Vector3(-8,.1,32),Vector3(22,4.2,-31),Vector3(12,4.2,-36),Vector3(-5.8,.18,47.2)]:
  var raw: Dictionary=session.snapshot();raw.map_id="valley";raw.player_position=[old.x,old.y,old.z];raw.erase("valley_landscape_revision");raw.inventory.copper_axe=1
  var restored=session.restore_state(raw);var expected:=L.legacy_position(old)
  check(Vector3(restored.state.player_position[0],restored.state.player_position[1],restored.state.player_position[2]).is_equal_approx(expected),"Legacy position moves onto new landscape "+str(old))
  var twice=session.restore_state(restored.state)
  check(twice.state.player_position==restored.state.player_position and twice.state.species=="cat_teacher" and twice.count("copper_axe")==1,"Migration is idempotent; species and inventory retained")
 print("VALLEY_LANDSCAPE_RULES_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
 quit(0 if failures.is_empty() else 1)
