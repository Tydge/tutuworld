extends RefCounted
## Orthographic colour elevations of both real banks. The game samples the baked
## images, so turning toward the water does not render the town a second time.
const J=preload("res://scripts/jade/layout.gd")
const PANELS=6
const WIDTH=320
const HEIGHT=160
const WORLD_HEIGHT=36.

static func bake(builder: SceneTree,world: Node3D,material: ShaderMaterial) -> bool:
	var view:=SubViewport.new()
	view.size=Vector2i(WIDTH,HEIGHT)
	view.transparent_bg=true
	view.world_3d=world.get_world_3d()
	view.render_target_update_mode=SubViewport.UPDATE_DISABLED
	builder.root.add_child(view)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=WORLD_HEIGHT;camera.near=.12;camera.far=78.
	view.add_child(camera);camera.current=true
	var sea:=world.get_node("Island/PolarSea") as MeshInstance3D
	sea.hide()
	var atlas:=Image.create_empty(PANELS*WIDTH,HEIGHT*2,false,Image.FORMAT_RGBA8)
	var valid:=true
	for side in range(2):
		for panel in range(PANELS):
			var x: float=(panel-(PANELS-1)*.5)*WORLD_HEIGHT*2.
			var origin:=Vector3(x,16.,J.river_z(x))
			camera.look_at_from_position(origin,origin+(Vector3.FORWARD if side==0 else Vector3.BACK),Vector3.UP)
			view.render_target_update_mode=SubViewport.UPDATE_ONCE
			await builder.process_frame
			await RenderingServer.frame_post_draw
			var shot:=view.get_texture().get_image()
			if shot==null or shot.is_empty():
				valid=false
				break
			shot.convert(Image.FORMAT_RGBA8)
			if side==1:shot.flip_x()
			atlas.blit_rect(shot,Rect2i(0,0,WIDTH,HEIGHT),Vector2i(panel*WIDTH,side*HEIGHT))
	sea.show()
	view.free()
	if not valid:return false
	atlas.generate_mipmaps()
	material.shader=preload("res://assets/shaders/jade_water.gdshader")
	material.set_shader_parameter("river_banks",ImageTexture.create_from_image(atlas))
	material.set_shader_parameter("ripple_normal",preload("res://assets/terrain/water_ripple_normals_v1.png"))
	material.set_shader_parameter("ripple_strength",.235)
	material.set_shader_parameter("flow",Vector2(.022,.006))
	return true
