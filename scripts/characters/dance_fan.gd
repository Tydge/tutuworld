extends RefCounted
const G := preload("res://scripts/geometry.gd")
const SILK := preload("res://assets/round_silk_fan.svg")
static var face: ArrayMesh

static func make(parent: Node3D) -> Node3D:
	var fan := Node3D.new()
	fan.name = "SilkFan"
	parent.add_child(fan)
	var bamboo := G.mat("9d6944")
	G.capsule(fan,Vector3(0,-.075,0),Vector3(0,.24,0),.018,bamboo,"Bamboo")
	G.capsule(fan,Vector3(0,-.07,0),Vector3(.025,-.15,0),.008,G.mat("b36b60"),"Cord")
	G.ball(fan,Vector3(.026,-.16,0),Vector3(.025,.044,.025),G.mat("bd746b"),"SilkKnot")
	if face == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var silk := StandardMaterial3D.new()
		silk.albedo_texture = SILK
		silk.cull_mode = BaseMaterial3D.CULL_DISABLED
		silk.roughness = .87
		st.set_material(silk)
		for i in 48:
			for v: Vector2 in [Vector2.ZERO,Vector2.from_angle(TAU*(i+1)/48.),Vector2.from_angle(TAU*i/48.)]:
				st.set_uv(Vector2(.5+.5*v.x,.5-.5*v.y))
				st.set_normal(Vector3.BACK)
				st.add_vertex(Vector3(.235*v.x,.235*v.y,0.))
		face = st.commit()
	G.mesh(fan,face,Vector3(0,.385,0),null,"Silk")
	return fan
