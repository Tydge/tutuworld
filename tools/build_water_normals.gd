extends SceneTree
## Deterministic periodic normal data. No downloaded art or runtime texture generation.
func _initialize() -> void:
	var size_:=512;var image:=Image.create(size_,size_,false,Image.FORMAT_RGB8)
	var waves: Array=[];var rng:=RandomNumberGenerator.new();rng.seed=743260
	for i in range(18):
		var x:=rng.randi_range(1,12)*(1 if i%2 else -1);var z:=rng.randi_range(1,12);var frequency:=sqrt(float(x*x+z*z))
		waves.append(Vector4(x,z,rng.randf()*TAU,.35/frequency))
	for y in range(size_):
		for x in range(size_):
			var p:=Vector2(x,y)/size_*TAU;var gradient:=Vector2.ZERO
			for wave: Vector4 in waves:
				var derivative:=cos(p.x*wave.x+p.y*wave.y+wave.z)*wave.w
				gradient+=Vector2(wave.x,wave.y)*derivative
			var n:=Vector3(-gradient.x,1.,-gradient.y).normalized()
			image.set_pixel(x,y,Color(n.x*.5+.5,n.z*.5+.5,n.y*.5+.5))
	var result:=image.save_png("res://assets/terrain/water_ripple_normals_v1.png");print("WATER_NORMALS_BUILT ",result);quit(result)
