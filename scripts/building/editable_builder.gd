extends "res://scripts/building/furniture_builder.gd"
const Forms=preload("res://scripts/building/structure_shapes.gd")
const Styles=preload("res://scripts/building/structure_catalog.gd")
const JadeArt = preload("res://scripts/building/jade_structure_art.gd")
var wall_finishes: Dictionary={}
var roof_form:="classic"
func build_roof(n: Node3D) -> void:
	if roof_form=="classic":super.build_roof(n)
	else:
		Forms.roof(self,n,roof_form)
		preload("res://scripts/building/roof_snow.gd").apply(n,bool(blueprint.get("snow",false)))
func build_door(n: Node3D) -> void:
	var form: String=blueprint.walls[0].openings[0].get("form","classic")
	if form=="classic":super.build_door(n)
	else:Forms.door(self,n,form)
func build_opening(parent: Node3D,x: float,data: Dictionary) -> void:
	var frame:=group(parent,"Opening_"+data.id);frame.set_meta("build_element_id",data.id)
	var previous: String=blueprint.materials.trim;blueprint.materials.trim=data.get("color",previous)
	if data.get("form","classic")=="classic":super.build_opening(frame,x,data)
	else:Forms.opening(self,frame,x,data)
	for child in frame.get_children():
		if str(child.name).begins_with("Curtain"):discard(child)
	for mesh_ in frame.find_children("*","MeshInstance3D",true,false):
		var m: Material=mesh_.material_override
		if m is ShaderMaterial and m.shader==preload("res://assets/shaders/home_surface.gdshader") and m.get_shader_parameter("pattern")!=10 and m.get_shader_parameter("tint")==Color(blueprint.materials.trim):m.set_shader_parameter("pattern",1 if data.get("style","original")=="wood" else 0)
	blueprint.materials.trim=previous

# Finishes use canonical world sides, independent of the order the wall was drawn.
func wall_piece(n: Node3D,x: float,y: float,width_: float,tall: float) -> void:
	if width_<.001 or tall<.001:return
	var front: Dictionary=wall_finishes.get(1,{"color":blueprint.materials.plaster,"style":"original"})
	var back: Dictionary=wall_finishes.get(-1,front)
	block(n,Vector3(x,floor_y+y,0),Vector3(width_,tall,thickness),material(front.color,Styles.pattern(front.style)),"Plaster",true)
	if front!=back:
		var plane:=QuadMesh.new();plane.size=Vector2(width_,tall)
		var face:=G.mesh(n,plane,Vector3(x,floor_y+y,-thickness*.5-.002),material(back.color,Styles.pattern(back.style)),"BackFinish");face.rotation.y=PI
	var top: float=minf(y+tall*.5,.76);var bottom: float=maxf(y-tall*.5,0)
	if top>bottom:
		for side in [-1,1]:
			var finish: Dictionary=wall_finishes.get(side,front)
			var plinth: Material=material(finish.color,Styles.pattern(finish.style))
			if finish.style in ["jade_frame","jade_lacquer"]:plinth=material("b5a48c",3)
			block(n,Vector3(x,floor_y+(top+bottom)*.5,side*(thickness*.5+.022)),Vector3(width_,top-bottom,.035),plinth,"Dado")
			block(n,Vector3(x,floor_y+.09,side*(thickness*.5+.045)),Vector3(width_,.18,.055),material(blueprint.materials.trim),"Skirting")
			if top>.74:rounded(n,Vector3(x,floor_y+.78,side*(thickness*.5+.04)),Vector3(width_,.07,.06),.015,material(blueprint.materials.trim),"DadoCap")
func pier_offsets(data: Dictionary, length_: float, solid: bool) -> Array[float]:
	var span: Array=data.get("frame_span",[length_,0.])
	var bays:=maxi(1,roundi(span[0]/3.8))
	var offsets: Array[float]=[]
	for i in range(bays+int(solid)):
		var pos: float=lerpf(.24,span[0]-.24,float(i)/bays) if solid else i*span[0]/bays+minf(.20,span[0]*.5)
		var offset: float=pos-span[1]
		if offset>=0. and offset<length_:offsets.append(offset)
	return offsets

func build_wall(parent: Node3D,data: Dictionary) -> void:
	var a:=Vector2(data.a[0],data.a[1]);var b:=Vector2(data.b[0],data.b[1]);var dir: Vector2=(b-a).normalized();var length_: float=a.distance_to(b)
	var canonical: Vector2=Vector2.DOWN if absf(dir.x)>.5 else Vector2.RIGHT
	var positive: bool=Vector2(-dir.y,dir.x).dot(canonical)>0
	wall_finishes={1:Styles.surface(data,"positive" if positive else "negative"),-1:Styles.surface(data,"negative" if positive else "positive")}
	var form: String = data.get("form","")
	var n:=group(parent,data.id,Vector3((a.x+b.x)*.5,0,(a.y+b.y)*.5));n.rotation.y=-atan2(dir.y,dir.x)
	n.set_meta("module_id",data.id);n.set_meta("module_type","wall");n.set_meta("outward",Vector3(-dir.y,0,dir.x));n.set_meta("length",length_);n.set_meta("view_openings",data.openings);n.set_meta("view_floor",floor_y)
	if form in Styles.PAVILION_WALLS:
		var dye: String=data.get("color","a16850")
		for face in wall_finishes.values():
			if face.get("painted",false):dye=face.color
		JadeArt.pavilion_bays(self,n,length_,data.get("pavilion",[]),form=="jade_pavilion_entry",dye)
		return
	if form in ["jade_eaves","jade_eaves_bay","jade_stage_back"]:
		JadeArt.wall_eave(self,n,length_,form=="jade_stage_back")
	if form in Styles.GALLERY_WALLS:
		var dye: String = data.get("color","a16850")
		for face in wall_finishes.values():
			if face.get("painted",false):dye=face.color
		block(n,Vector3(0,floor_y+height-.25,0),Vector3(length_,.50,.42),JadeArt.wood_beam(self),"CloudBeam")
		for offset in pier_offsets(data,length_,false):
			var x:=offset-length_*.5
			var pier := group(n,"Pier",Vector3(x,floor_y,0))
			JadeArt.stamp(self,pier,"column",JadeArt.column,dye)
			P.box(n,"PierCollision",Vector3(x,floor_y+height*.5,0),Vector3(.36,height,.36))
		if form=="jade_balustrade":
			for y in [.42,.95]:block(n,Vector3(0,floor_y+y,0),Vector3(length_,.11,.16),material(dye),"Rail")
			var count:=maxi(1,ceili(length_/.72))
			for i in count:
				var x: float=(i+.5)*length_/count-length_*.5
				block(n,Vector3(x,floor_y+.46,0),Vector3(.085,.92,.11),material(dye),"Baluster")
			P.box(n,"RailCollision",Vector3(0,floor_y+.50,0),Vector3(length_,1.,.16))
		return
	if form in Styles.POST_WALLS:
		var count := maxi(1, ceili(length_/.5))
		for i in count:
			var pier := group(n, "Post",Vector3(-length_*.5+(i+.5)*length_/count, floor_y, 0))
			if form=="jade_low_post":pier.scale.y=(height-1.)/height
			JadeArt.stamp(self,pier,"column",JadeArt.column,data.get("color","874e3c"))
		var post_height:=height-1. if form=="jade_low_post" else height
		P.box(n,"PostCollision",Vector3(0,floor_y+post_height*.5,0),Vector3(length_,post_height,.32))
		return
	var trim: String=blueprint.materials.trim
	if form in Styles.TIMBER_WALLS or data.get("style","")=="jade_frame":blueprint.materials.trim="79533e"
	var openings: Array=data.openings.duplicate(true);openings.sort_custom(func(x,y):return x.offset<y.offset);var cursor: float=-length_*.5
	for opening in openings:
		var x: float=opening.offset-length_*.5;var left: float=x-opening.width*.5
		wall_piece(n,(cursor+left)*.5,height*.5,left-cursor,height)
		if opening.bottom>0:wall_piece(n,x,opening.bottom*.5,opening.width,opening.bottom)
		var above: float=height-opening.bottom-opening.height;wall_piece(n,x,height-above*.5,opening.width,above)
		# Fill the shoulders of curved openings with the same two wall finishes.
		var opening_form: String=opening.get("form","classic")
		if opening_form in ["arch","round"]:
			var full_width: float=opening.get("full_width",opening.width);var center: float=x+opening.get("center_shift",0.);var radius: float=full_width*.5
			var slices:=maxi(2,ceili(opening.width/.08));var width_: float=opening.width/slices
			for i in range(slices):
				var px:=left+(i+.5)*width_;var dx:=clampf((px-center)/radius,-1.,1.);var arc:=sqrt(maxf(0.,1.-dx*dx))
				var cap: float=opening.height-(radius*(1.-arc) if opening_form=="arch" else opening.height*.5*(1.-arc))
				var fill: float=opening.height-cap
				if fill>.001:wall_piece(n,px,opening.bottom+cap+fill*.5,width_+.002,fill)
				if opening_form=="round" and fill>.001:wall_piece(n,px,opening.bottom+fill*.5,width_+.002,fill)
		if not opening.get("geometry_only",false):build_opening(n,x,opening)
		cursor=x+opening.width*.5
	wall_piece(n,(cursor+length_*.5)*.5,height*.5,length_*.5-cursor,height)
	rounded(n,Vector3(0,floor_y+height-.12,0),Vector3(length_,.18,.35),.035,material(blueprint.materials.trim),"Cornice")
	for side in [-1,1]:
		if form not in Styles.TIMBER_WALLS and wall_finishes[side].style != "jade_frame": continue
		var rail := group(n,"PaintedBeam",Vector3(0,floor_y+height-.28,side*.19))
		block(rail,Vector3.ZERO,Vector3(length_,.47,.17),JadeArt.wood_beam(self),"CloudBeam")
		for offset in pier_offsets(data,length_,true):
			if openings.any(func(hole): return absf(offset-hole.offset)<hole.width*.5+.18): continue
			var pier := group(n,"BracketColumn",Vector3(offset-length_*.5,floor_y,side*.22))
			if side<0: pier.rotation.y=PI
			JadeArt.stamp(self,pier,"column",JadeArt.column,"a16850")
	blueprint.materials.trim=trim
	# Endpoint/corner trim is generated once from the complete wall topology.
