extends RefCounted
const UI=preload("res://scripts/ui/ui_kit.gd")
static func build(hud: CanvasLayer) -> void:
	hud.content.add_child(UI.label("船票每程 10 贝壳币 · 从目的地返回海岛城免费",18,UI.MUTED))
	for d in [{"id":"jade","title":"玉京城","description":"从南津上岸，穿灯市、渡玉带河，循白石御道入宫。","color":Color("f0e3ce")},{"id":"valley","title":"眠风山谷","description":"穿过林间小径和溪桥，去山腰看风景。\n可以采木、挖矿、采石和摘橘子。","color":Color("e1ead8")},{"id":"icefield","title":"冰原岛","description":"雪山下的暖灯小镇，和一望无际的蓝冰原。\n雪地留下脚印；冰面会滑。带好采集工具。","color":Color("e0ecf1")}]:
		var card:=UI.panel(d.color,20,22);hud.content.add_child(card);var column:=UI.column(12);card.add_child(column)
		column.add_child(UI.label(d.title,26));column.add_child(UI.label(d.description,19))
		var button:=UI.button("前往"+d.title+"  ·  10 贝壳币",func():
			hud.close_panel();preload("res://scripts/valley/boat_travel.gd").go(hud.city,d.id),true)
		button.name="Travel_"+d.id;button.disabled=int(hud.session.state().coins)<10;column.add_child(button)
