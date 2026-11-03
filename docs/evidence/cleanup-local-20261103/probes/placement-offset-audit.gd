extends SceneTree
func _initialize() -> void:
 var Catalog=load("res://scripts/building/catalog.gd")
 for kind in ["bed","desk"]:
  for angle in [0,90,180,270]:
   var definition: Dictionary=Catalog.OBJECTS[kind];var offset: Vector2=definition.offset
   var expected: Vector3=Basis(Vector3.UP,deg_to_rad(angle))*Vector3(offset.x,0,offset.y)
   var actual: Vector2=Catalog.footprint({"kind":kind,"position":[79,10],"yaw":angle}).get_center()-Vector2(79,10)
   var delta: float=actual.distance_to(Vector2(expected.x,expected.z))
   print("OFFSET_AUDIT kind=",kind," yaw=",angle," center_error_m=",snappedf(delta,.001)," result=","OPEN" if delta>.01 else "ALIGNED")
 quit()
