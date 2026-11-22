extends SceneTree
const Land=preload("res://scripts/building/parcels.gd")
const Layout=preload("res://scripts/building/layout.gd")
const Templates=preload("res://scripts/building/templates.gd")
const Ice=preload("res://scripts/icefield/icefield_layout.gd")
const Trail=preload("res://scripts/icefield/snow_trail.gd")
const Access=preload("res://scripts/city/furniture_access.gd")
const Support=preload("res://tests/test_support.gd")
var session: Node
var game: Node3D
var failures: Array[String]=[]
var checks:=0

func _initialize() -> void:call_deferred("run")
func check(value: bool,label_: String) -> void:
	checks+=1
	print("PASS " if value else "FAIL ",label_)
	if not value:failures.append(label_)

func place(point: Vector3) -> void:
	game.bunny.position=point
	game.bunny.velocity=Vector3.ZERO
	game.bunny.reset_physics_interpolation()
	game.camera_focus=point+Vector3.UP*1.35
	game.update_camera(1.)
	for frame in range(5):await physics_frame
	game.update_target()

func screenshot(name_: String) -> void:
	await create_timer(.64).timeout
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(Support.output_dir()+"/"+name_+".png")

func station(kind: String,room: String) -> String:
	for id in game.targets:
		if id.begins_with(room) and game.targets[id].kind==kind:return id
	return ""

func run() -> void:
	session=load("res://scripts/services/session.gd").new()
	session.name="Session";root.add_child(session)
	session.settings.background_throttle=false
	session.create_character("冬日回归测试","cat_teacher","bow_rose")
	session.state().map_id="icefield";session.state().player_position=Ice.arrival();session.state().time=1700.
	game=load("res://scenes/icefield.tscn").instantiate();root.add_child(game);current_scene=game
	var until:=Time.get_ticks_msec()+60000
	while (game.preparing or not is_instance_valid(game.build_mode)) and Time.get_ticks_msec()<until:await process_frame
	check(is_instance_valid(game.build_mode) and is_instance_valid(game.hud.build_button),"Icefield exposes the live build editor")
	if not is_instance_valid(game.build_mode):quit(1);return
	for id in Land.ids_for("icefield"):
		var rect:=Land.bounds(id)
		var sign:=Land.sign_position(id)
		check(rect.size==Land.SIZE and absf(Ice.height_at(sign.x,sign.z)-sign.y)<.01 and game.targets.has("land:"+id),"Complete level plot and sign "+id)
	check(game.scenery.get_node("IcefieldBuildingSite").find_children("CornerStake*","",true,false).is_empty(),"Winter lots retain their purchase signs without boundary posts")
	for sample in Templates.SAMPLE_NAMES:
		var source:=Templates.player_sample(sample)
		if source.is_empty():
			check(false,"Valid source for "+sample);continue
		for id in ["east_ne","snow_birch","ice_south_1","ice_north_2"]:
			var map_id:=Land.map_for(id);var center:=Land.bounds(id).get_center()
			var proposed:=Layout.validate(Layout.merge_template(Layout.empty(map_id),source,center,0),map_id)
			check(proposed.ok and Land.outside(proposed.get("layout",{}),id).is_empty(),"Template "+sample+" fits "+id+" "+str(proposed.get("message","")))
	var id:="ice_south_1";var sign:=Land.sign_position(id)
	await place(sign+Vector3(0,.06,1.7))
	check(game.current_target=="land:"+id,"Approaching the standing sign offers E purchase")
	game.interact()
	var purchase:=game.hud.find_child("Purchase_"+id,true,false) as Button
	check(is_instance_valid(purchase),"In-world sign opens the winter purchase action")
	if purchase:purchase.pressed.emit()
	await process_frame
	check(Land.owns(session.state(),id),"Real purchase stores winter lot ownership")
	await process_frame
	check(not game.hud.build_button.disabled,"On-screen building control activates beside an owned winter lot")
	var editor: Node=game.build_mode
	var opened: Dictionary=await editor.open_nearby_parcel()
	check(opened.ok,"Owner opens winter construction from the sign")
	if opened.ok:
		editor.place_template("snow_tea_house")
		check(editor.place_at(Land.bounds(id).get_center()),"A winter plan can actually be placed")
		await screenshot("01-snow-plot")
		editor.close_editor()
		var saved: Dictionary=Land.layout_for(session.state(),"icefield")
		check(not saved.elements.is_empty() and session.state().build_layout.elements.is_empty(),"Icefield layout saves independently of city")
		check(is_instance_valid(editor.room) and is_equal_approx(editor.room.global_position.y,Ice.ICE_LEVEL),"Built room and rendering use the ice pad height")
		var foundation: Vector2i=Layout.compiled(saved).floors.keys()[0]
		var foot:=Vector3((foundation.x+.5)*.5,Ice.ICE_LEVEL+.20,(foundation.y+.5)*.5)
		await place(foot)
		check(Ice.is_ice(game.bunny.position) and not game.is_ice_surface(game.bunny.position) and not game.bunny.ice_inertia,"Standing on a built ground floor overrides the blue ice beneath")
		var bare:=Vector3(32.,Ice.ICE_LEVEL+.035,100.)
		await place(bare)
		check(game.is_ice_surface(game.bunny.position) and game.bunny.ice_inertia,"Leaving the foundation restores ice inertia")
	for bed_id in Trail.LODGE_BEDS:
		var bed_row: Dictionary=game.targets.get(bed_id,{})
		check(not bed_row.is_empty(),"Registered inn bed "+bed_id)
		if bed_row.is_empty():continue
		var bed: Node3D=bed_row.node
		await place(bed.to_global(Vector3(-1.9 if bed.position.x>0 else 1.9,.03,0)))
		check(Access.reachable(game,bed,game.bunny),"Approachable from the lodge aisle")
		game.current_target=bed_id;game.interact()
		check(game.sleep_active and session.state().rest_bed==bed_id,"E starts sleep in "+bed_id)
		if game.sleep_active:
			var saved_sleep: RefCounted=session.restore_state(session.snapshot())
			check(saved_sleep.state.rest_bed==bed_id,"The inn bed survives a save and load")
			session.state().stamina=60.;session.state().stamina_recovery_elapsed=0.;session.authority.tick_stamina(15.1)
			check(session.state().stamina==61.,"Sleeping doubles stamina recovery")
			if bed_id==Trail.LODGE_BEDS[0]:
				game.pitch=1.04;game.distance_=13.
				await screenshot("02-lodge-bed")
			game.wake_from_bed()
			check(not game.sleep_active and not game.bunny.sleeping,"The inn allows safe waking")
	var tailor: Dictionary=game.targets.get("shop_clothing_rack",{})
	check(not tailor.is_empty(),"Original clothes shop display is an interactive rack")
	if not tailor.is_empty():
		for garment in ["bow_sage","bow_honey","cowboy_hat_saddle","duffle_berry","apron_honey","bell_blue","top_hat_midnight","kerchief_pine","capelet_frost","day_dress_cornflower","oxford_shirt_tide","silk_bowtie_claret","gold_chain_cable"]:
			session.authority.add(garment,1)
		session.state().clothing_designs["bow_sage"]={"color":"12a4fe","accent":"f08d34","pattern":"dots"}
		session.state().clothing_designs["bow_honey"]={"color":"a33049","accent":"f4d752","pattern":"tartan"}
		await place(tailor.position+Vector3(.6,.025,0))
		game.current_target="shop_clothing_rack";game.interact()
		check(game.hud.mode=="tailor" and is_instance_valid(game.hud.tailoring),"E at the display opens the fitting mirror")
		if game.hud.mode=="tailor":
			var screen: RefCounted=game.hud.tailoring
			var index: int=screen.options.find("tartan")
			screen.material.select(index)
			for button in [screen.base_dye,screen.pattern_dye]:
				var picker: ColorPicker=button.get_picker()
				check(picker.color_mode==ColorPicker.MODE_RGB and picker.sliders_visible and picker.hex_visible,"Fabric channel exposes free RGB and hexadecimal entry")
			screen.base_dye.color=Color("12a4fe");screen.pattern_dye.color=Color("f08d34")
			screen.repaint()
			await ready_portraits(screen)
			var original:=portrait(screen,"bow_rose").texture
			screen.apply.pressed.emit()
			await ready_portraits(screen)
			await screenshot("03-tailoring")
			var tartan:=portrait(screen,"bow_rose").texture
			var dots:=portrait(screen,"bow_sage").texture
			var warm:=portrait(screen,"bow_honey").texture
			check(tartan!=null and dots!=null and warm!=null,"All three owned versions have real model portraits")
			if tartan and dots and warm and original:
				check(tartan.get_image().get_data()!=dots.get_image().get_data(),"Identical dyes with dots and tartan yield different woven thumbnails")
				check(tartan.get_image().get_data()!=warm.get_image().get_data(),"Same weave with different dyes yields different thumbnails")
				check(original.get_image().get_data()!=tartan.get_image().get_data(),"Saving a dye job refreshes its portrait")
			check(session.state().clothing_designs.get("bow_rose",{})=={"pattern":"tartan","color":"12a4fe","accent":"f08d34"},"The fitting mirror saves both dyes and the texture")
			var restored: RefCounted=session.restore_state(session.snapshot())
			check(restored.state.clothing_designs==session.state().clothing_designs,"Garment customization survives restoration")
			screen.reset.pressed.emit()
			await ready_portraits(screen)
			check(not session.state().clothing_designs.has("bow_rose") and portrait(screen,"bow_rose").texture==original,"Restore returns the original garment portrait and preserves other designs")
			game.hud.close_panel()
	for mark in Trail.STAMPS:
		var target: String="snow_stamp:"+mark
		var position_: Vector3=game.targets[target].position
		await place(position_+Vector3(0,.06,.46))
		game.interact()
		check(mark in session.state().snow_trail.stamps,"Press E to stamp "+mark)
	var atlas:=station("atlas","winter:home_a:")
	check(atlas!="","The library has a physical atlas")
	if atlas!="":
		await place(game.targets[atlas].position+Vector3(0,.06,.45))
		game.current_target=atlas;game.interact()
		await screenshot("04-library-atlas")
		var claim:=game.hud.find_child("ClaimSnowTrail",true,false) as Button
		if claim:claim.pressed.emit()
		check(session.state().snow_trail.claimed and session.authority.count(Trail.LOAF)==2,"The three field stamps pay a single library reward")
		game.hud.close_panel()
	var oven:=station("bakery","winter:bakery:")
	check(oven!="","The bakery has a functioning oven")
	if oven!="":
		await place(game.targets[oven].position+Vector3(0,.04,.4))
		game.current_target=oven
		session.authority.add("wheat",1);session.authority.add("branch",1)
		game.interact()
		check(session.job().get("verb","")=="bake","Baking starts at the walk-up oven")
		check(session.authority.count("wheat")==1,"Ingredients are held until bread comes out")
		if not session.job().is_empty():session.job().duration=.1;await create_timer(.2).timeout
		check(session.authority.count(Trail.LOAF)==3 and session.authority.count("wheat")==0,"A loaf enters the bag after a completed bake")
	print("WINTER_PLAYGROUND_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

func portrait(screen: RefCounted,id: String) -> TextureRect:
	return screen.garment_buttons[screen.items.find(id)].get_node("GarmentPicture")

func ready_portraits(screen: RefCounted) -> void:
	for frame in range(160):
		await process_frame
		if screen.portraits.active.is_empty() and screen.portraits.pending.is_empty():break
	for tile in screen.garment_buttons:
		var picture: TextureRect=tile.get_node("GarmentPicture")
		check(tile.get_global_rect().encloses(picture.get_global_rect()) and tile.get_global_rect().get_center().distance_to(picture.get_global_rect().get_center())<.1 and picture.texture!=null,"Rendered garment is centered inside its clickable tile "+tile.tooltip_text)
