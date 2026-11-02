extends RefCounted
static func at_time(day_fraction: float) -> Dictionary:
	var height:=sin((day_fraction-.25)*TAU)
	var day:=smoothstep(-.12,.30,height)
	var dusk: float=(1.0-smoothstep(.05,.42,absf(height)))*.85
	return {"day":day,"night":1.0-smoothstep(-.32,.03,height),"height":height,
		"zenith":Color("0a1336").lerp(Color("4b8de5"),day).lerp(Color("675d9c"),dusk*.35),
		"horizon":Color("202e58").lerp(Color("78b7ea"),day).lerp(Color("e9a57e"),dusk),
		"cloud":Color("28395e").lerp(Color("f7fbff"),day).lerp(Color("efbca0"),dusk*.65),
		"sea":Color("10294b").lerp(Color("258fbc"),day).lerp(Color("776b9f"),dusk*.45)}
