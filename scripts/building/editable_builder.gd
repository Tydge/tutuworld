extends "res://scripts/building/furniture_builder.gd"
func build_opening(parent: Node3D,x: float,data: Dictionary) -> void:
	var frame:=group(parent,"Opening_"+data.id);frame.set_meta("build_element_id",data.id)
	var previous: String=blueprint.materials.trim;blueprint.materials.trim=data.get("color",previous)
	super.build_opening(frame,x,data)
	for child in frame.get_children():
		if str(child.name).begins_with("Curtain"):discard(child)
	for mesh_ in frame.find_children("*","MeshInstance3D",true,false):
		var m: Material=mesh_.material_override
		if m is ShaderMaterial and m.shader==preload("res://assets/shaders/home_surface.gdshader") and m.get_shader_parameter("tint")==Color(blueprint.materials.trim):m.set_shader_parameter("pattern",1 if data.get("style","original")=="wood" else 0)
	blueprint.materials.trim=previous

# Player walls have the same treatment on both faces, independent of draw order.
func wall_piece(n: Node3D,x: float,y: float,width_: float,tall: float) -> void:
	if width_<.001 or tall<.001:return
	block(n,Vector3(x,floor_y+y,0),Vector3(width_,tall,thickness),material(blueprint.materials.plaster),"Plaster",true)
	var top: float=minf(y+tall*.5,.76);var bottom: float=maxf(y-tall*.5,0)
	if top>bottom:
		for side in [-1,1]:
			block(n,Vector3(x,floor_y+(top+bottom)*.5,side*(thickness*.5+.022)),Vector3(width_,top-bottom,.035),material(blueprint.materials.plaster),"Dado")
			block(n,Vector3(x,floor_y+.09,side*(thickness*.5+.045)),Vector3(width_,.18,.055),material(blueprint.materials.trim),"Skirting")
			if top>.74:rounded(n,Vector3(x,floor_y+.78,side*(thickness*.5+.04)),Vector3(width_,.07,.06),.015,material(blueprint.materials.trim),"DadoCap")
func build_wall(parent: Node3D,data: Dictionary) -> void:
	var a:=Vector2(data.a[0],data.a[1]);var b:=Vector2(data.b[0],data.b[1]);var dir: Vector2=(b-a).normalized();var length_: float=a.distance_to(b)
	var n:=group(parent,data.id,Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5));n.rotation.y=-atan2(dir.y,dir.x)
	n.set_meta("module_id",data.id);n.set_meta("module_type","wall");n.set_meta("outward",Vector3(-dir.y,0,dir.x));n.set_meta("length",length_);n.set_meta("view_openings",data.openings);n.set_meta("view_floor",floor_y)
	var openings: Array=data.openings.duplicate(true);openings.sort_custom(func(x,y):return x.offset<y.offset);var cursor: float=-length_*.5
	for opening in openings:
		var x: float=opening.offset-length_*.5;var left: float=x-opening.width*.5
		wall_piece(n,(cursor+left)*.5,height*.5,left-cursor,height)
		if opening.bottom>0:wall_piece(n,x,opening.bottom*.5,opening.width,opening.bottom)
		var above: float=height-opening.bottom-opening.height;wall_piece(n,x,height-above*.5,opening.width,above)
		if not opening.get("geometry_only",false):build_opening(n,x,opening)
		cursor=x+opening.width*.5
	wall_piece(n,(cursor+length_*.5)*.5,height*.5,length_*.5-cursor,height)
	rounded(n,Vector3(0,floor_y+height-.12,0),Vector3(length_,.18,.35),.035,material(blueprint.materials.trim),"Cornice")
	# Endpoint/corner trim is generated once from the complete wall topology.
