extends RefCounted
static func add_to(parent: Control) -> void:
	var credits:=RichTextLabel.new();credits.name="AudioCredits";credits.fit_content=true;credits.bbcode_enabled=true;credits.scroll_active=false;credits.custom_minimum_size.y=140;credits.add_theme_font_size_override("normal_font_size",13)
	credits.text="[b]环境音效来源[/b]\n海浪：jasinski，Beach Ocean Waves（qubodup 整理），[url=https://opengameart.org/content/beach-ocean-waves]OpenGameArt[/url]，CC0。\n海鸟：Rango Mango 整理，Solo Seagull Sound Effects，[url=https://opengameart.org/content/solo-seagull-sound-effects]OpenGameArt[/url]，CC0。\n溪流：kurt，Stream Sounds，[url=https://opengameart.org/content/stream-sounds]OpenGameArt[/url]，[url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url]。\n录音经剪辑、调整音量、转为单声道并制作循环。"
	credits.meta_clicked.connect(func(url):OS.shell_open(str(url)));credits.hide()
	var button:=Button.new();button.name="ShowAudioCredits";button.text="音效来源与许可";button.pressed.connect(func():credits.visible=not credits.visible);parent.add_child(button);parent.add_child(credits)
