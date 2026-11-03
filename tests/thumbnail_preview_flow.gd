extends SceneTree
const C=preload("res://scripts/building/catalog.gd")
const Studio=preload("res://scripts/building/thumbnail_studio.gd")
var checks:=0
var failures: Array=[]
var city: Node3D
var editor: Node
var out: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label_)
	if not ok:failures.append(label_)
func frames(count: int=3) -> void:
	for i in range(count):await process_frame;RenderingServer.force_draw()
func ready_for(studio: Node,ids: Array) -> bool:
	for id in ids:
		if not studio.cache.has(id) or not studio.valid_image(studio.cache[id].get_image()):return false
	return true
func wait_for(studio: Node,ids: Array) -> void:
	for i in range(240):
		if ready_for(studio,ids) and not studio.busy:return
		await frames(1)
func photo(name_: String) -> void:
	await frames(6);root.get_texture().get_image().save_png(out+"/"+name_+".png")
func run() -> void:
	out=preload("res://tests/test_support.gd").output_dir();var s=load("res://scripts/services/session.gd").new();s.name="Session";root.add_child(s);s.create_character("缩略图验收兔","bunny","bow_rose")
	city=load("res://scenes/city.tscn").instantiate();root.add_child(city);current_scene=city
	while city.camera==null:await process_frame
	await create_timer(.6).timeout;root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1920,1080);await create_timer(1.2).timeout;await frames(8)
	editor=city.build_mode;editor.open_editor()
	for category in ["结构","照明","床","庭院","桌柜","装饰","座椅","照明"]:editor.ui.show_category(category)
	var ids: Array=["floor","wall","door","window","roof"];ids.append_array(C.OBJECTS.keys());await wait_for(editor.ui.studio,ids)
	for id in ids:check(ready_for(editor.ui.studio,[id]),"Catalog icon contains actual visible pixels after rapid category changes: "+id)
	check(editor.ui.studio.pending.is_empty() and not editor.ui.studio.busy,"The serial thumbnail queue completes without a stuck or duplicate active job")
	for id in ["floor","table_lamp","pendant"]:editor.ui.studio.cache[id].get_image().save_png(out+"/"+id+"-icon.png")
	await photo("lighting-catalog-icons");editor.ui.show_category("结构");editor.choose_tool("floor");await photo("floor-catalog-and-detail-icons")
	check(editor.ui.selected_preview.texture!=null and editor.ui.studio.valid_image(editor.ui.selected_preview.texture.get_image()),"Floor detail icon and its catalog icon both render actual geometry")
	for i in range(3):
		var cold:=Studio.new();editor.ui.add_child(cold);cold.request("floor");cold.request("table_lamp");await wait_for(cold,["floor","table_lamp"])
		check(ready_for(cold,["floor","table_lamp"]),"A cold offscreen viewport renders its first floor and lamp: round "+str(i+1))
		check(ready_for(cold,["table_lamp"]) and cold.cache.table_lamp.get_image().get_used_rect().size.y>=56,"A lamp stays legibly framed immediately after a large floor: round "+str(i+1));cold.free()
	for id in ["floor","table_lamp","floor","table_lamp"]:
		editor.ui.studio.cache.erase(id);editor.ui.studio.request(id);await wait_for(editor.ui.studio,[id])
		var used: Rect2i=editor.ui.studio.cache[id].get_image().get_used_rect()
		check(used.size.y>=(56 if id=="table_lamp" else 36),"Alternating large and small icons keeps consistent framing: "+id)
	for id in ["floor","table_lamp","pendant"]:editor.ui.studio.cache[id].get_image().save_png(out+"/"+id+"-icon.png")
	editor.ui.show_category("照明");await photo("lighting-catalog-icons");editor.ui.show_category("结构");await photo("floor-catalog-and-detail-icons")
	var blank:=Image.create(144,112,false,Image.FORMAT_RGBA8);blank.fill(Color.TRANSPARENT);editor.ui.studio.cache.floor=ImageTexture.create_from_image(blank)
	editor.ui.studio.request("floor");await wait_for(editor.ui.studio,["floor"])
	check(ready_for(editor.ui.studio,["floor"]) and editor.ui.card_images.floor.texture==editor.ui.studio.cache.floor,"An empty cached image is rejected, re-rendered and rebound to the visible card")
	var row:={"type":"object","kind":"table_lamp","painted":false,"appearance":{"shade":{"material":"solid","color":"83b5b1"}}};var key: String=editor.ui.studio.variant_key(row);editor.ui.studio.request_variant(row);await wait_for(editor.ui.studio,[key])
	check(ready_for(editor.ui.studio,[key]),"Custom material thumbnails pass the same nonempty-image validation")
	if ready_for(editor.ui.studio,[key]):check(editor.ui.studio.cache[key].get_image().get_data()!=editor.ui.studio.cache.table_lamp.get_image().get_data(),"A custom lamp thumbnail captures the new material rather than the previous render")
	check(editor.ui.card_images["object:table_lamp"].texture==editor.ui.studio.cache.table_lamp,"A custom thumbnail does not replace the catalog's default lamp image")
	print("THUMBNAIL_PREVIEW_FLOW_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures);quit(0 if failures.is_empty() else 1)
