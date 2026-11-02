extends RefCounted
static func petal(st: SurfaceTool,origin: Vector3,axis: Vector3,side: Vector3,length_: float,width_: float,color: Color) -> void:
	for i in range(8):
		for j in [-1,i,i+1]:
			var a: float=j*TAU/8
			var point:=origin if j<0 else origin+axis*cos(a)*length_+side*sin(a)*width_+Vector3.UP*pow(absf(sin(a)),2)*.025
			st.set_color(color);st.set_uv(Vector2(0,1));st.add_vertex(point)
static func bloom(st: SurfaceTool,point: Vector3,color: Color,rng: RandomNumberGenerator,scale_: float=1.) -> void:
	var tall: float=rng.randf_range(.24,.49)*scale_;var tip:=point+Vector3(rng.randf_range(-.05,.05),tall,0)
	for axis in [Vector3.RIGHT,Vector3.BACK]:
		for p in [point-axis*.012,point+axis*.012,tip-axis*.010,point+axis*.012,tip+axis*.010,tip-axis*.010]:
			st.set_color(Color("518347"));st.set_uv(Vector2(0,0));st.add_vertex(p)
	for sign_ in [-1,1]: petal(st,point+Vector3(sign_*.055,tall*.4,0),Vector3(sign_*.12,.07,.02).normalized(),Vector3.BACK,.13*scale_,.045*scale_,Color("68a34f"))
	var twist: float=rng.randf()*TAU
	for i in range(6):
		var angle: float=i*TAU/6+twist
		var axis:=Vector3(cos(angle),.12,sin(angle));var side:=Vector3(-sin(angle),0,cos(angle))
		petal(st,tip+axis*.09*scale_,axis,side,.12*scale_,.073*scale_,color)
	for i in range(10):
		for p in [tip+Vector3(0,.033,0)*scale_,tip+Vector3(cos(i*TAU/10)*.065,.018,sin(i*TAU/10)*.065)*scale_,tip+Vector3(cos((i+1)*TAU/10)*.065,.018,sin((i+1)*TAU/10)*.065)*scale_]:
			st.set_color(Color("d59b3d"));st.set_uv(Vector2(0,1));st.add_vertex(p)
