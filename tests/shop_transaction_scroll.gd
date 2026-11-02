extends "res://tests/clothing_shop_preview.gd"
func run() -> void:
	root.size=Vector2i(1600,1000)
	session=S.new();session.name="Session";root.add_child(session);Engine.max_fps=30
	session.create_character("逛街兔","bunny","vest_sage");session.state().coins=10000
	var position_: Vector2=DB.shops().farm;session.set_player_position(Vector3(position_.x,.18,position_.y+2))
	var stage:=ShopStage.new();root.add_child(stage)
	hud=HUD.new();hud.city=stage;stage.add_child(hud);hud.shop="farm";hud.open_panel("shop")
	await create_timer(.35).timeout
	var id: String=hud.shop_rows.keys().back()
	var price: int=DB.item(id).price
	var scroll: ScrollContainer=hud.shop_grid.get_parent()
	scroll.ensure_control_visible(button("bulk_buy_item",id));await create_timer(.15).timeout
	var y:=scroll.scroll_vertical;var scroll_id:=scroll.get_instance_id();var card_id: int=hud.shop_rows[id].card.get_instance_id()
	var before: int=session.authority.count(id);var coins: int=session.state().coins
	check(y>20,"Seed shop purchase is scrolled below the first row")
	await click("buy_item",id)
	check(scroll.scroll_vertical==y and scroll.get_instance_id()==scroll_id and hud.shop_rows[id].card.get_instance_id()==card_id,"Single purchase retains the scroll container, position and original card")
	check(session.authority.count(id)==before+1 and session.state().coins==coins-price and hud.shop_rows[id].count.text=="持有 %d"%(before+1),"Single purchase updates real inventory, balance and visible quantity")
	await click("buy_item",id)
	await click("bulk_buy_item",id)
	check(session.authority.count(id)==before+7 and session.state().coins==coins-price*7,"Repeated and bulk purchases use current quantities and prices")
	check(scroll.scroll_vertical==y and hud.shop_rows[id].card.get_instance_id()==card_id,"Repeated and bulk purchases do not jump to the top")
	session.state().coins=price;session.changed.emit();await process_frame
	check(not button("buy_item",id).disabled and button("bulk_buy_item",id).disabled,"Balance updates the affordability of original single and bulk buttons")
	await click("buy_item",id)
	check(button("buy_item",id).disabled and session.state().coins==0 and hud.shop_balance.text=="贝壳币 0" and scroll.scroll_vertical==y,"Purchase immediately updates balance and disables unaffordable buttons without scrolling")
	# Enough different saleable items keep a meaningful list after one stack sells out.
	for item_id in DB.catalog().items:
		if int(DB.item(item_id).get("sell",0))>0: session.authority.add(item_id,4)
	session.changed.emit()
	await click("shop_tab","sell")
	await create_timer(.12).timeout
	id=hud.shop_rows.keys().back()
	scroll=hud.shop_grid.get_parent();scroll.ensure_control_visible(button("sell_all_item",id));await create_timer(.15).timeout
	y=scroll.scroll_vertical;scroll_id=scroll.get_instance_id();card_id=hud.shop_rows[id].card.get_instance_id()
	before=session.authority.count(id);coins=session.state().coins;price=DB.item(id).sell
	check(y>20,"Sale list is genuinely scrolled near its lower end")
	await click("sell_item",id)
	check(session.authority.count(id)==before-1 and session.state().coins==coins+price,"Partial sale charges the current quantity once")
	check(scroll.scroll_vertical==y and hud.shop_rows[id].card.get_instance_id()==card_id,"Partial sale keeps its original card and exact scroll offset")
	check(hud.shop_rows[id].count.text=="持有 %d · 单价 %d 币"%[before-1,price] and hud.shop_rows[id].sell_all.text=="全部出售 · %d 币"%[(before-1)*price],"Remaining quantity and total-sale price update in place")
	var neighbor: String=hud.shop_rows.keys()[-2]
	var neighbor_card_id: int=hud.shop_rows[neighbor].card.get_instance_id()
	await click("sell_all_item",id)
	await create_timer(.15).timeout
	check(session.authority.count(id)==0 and not hud.shop_rows.has(id) and session.state().coins==coins+before*price,"Selling the remainder removes only the exhausted item")
	check(scroll.get_instance_id()==scroll_id and hud.shop_rows[neighbor].card.get_instance_id()==neighbor_card_id,"Selling out retains all surviving cards and the scroll container")
	var maximum: int=maxi(0,int(scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page))
	check(scroll.scroll_vertical==mini(y,maximum),"Shorter sale list clamps the previous scroll position to its new end")
	# A stack larger than one transaction uses live values on each subsequent click.
	session.authority.add("branch",150);session.changed.emit();await create_timer(.1).timeout
	before=session.authority.count("branch");coins=session.state().coins;price=DB.item("branch").sell
	await click("sell_all_item","branch")
	check(session.authority.count("branch")==before-99 and session.state().coins==coins+99*price,"Large-stack sale honors the per-transaction cap")
	await click("sell_all_item","branch")
	check(session.authority.count("branch")==0 and session.state().coins==coins+before*price,"Next sale reads the remaining live quantity")
	while not hud.shop_rows.is_empty():
		id=hud.shop_rows.keys().back();button("sell_all_item",id).pressed.emit();await process_frame
	await create_timer(.15).timeout
	check(is_instance_valid(hud.shop_empty) and hud.shop_grid.get_child_count()==1 and scroll.scroll_vertical==0,"Final sale shows the empty list without stale cards or blank scrolling space")
	hud.close_panel();stage.queue_free();await process_frame;await process_frame
	print("SHOP_TRANSACTION_SCROLL_RESULT ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
