extends RefCounted
## Deterministic tabletop state. Controls, keyboard and the authority use the same action indices.
var house: String
var deal: int
var rng:=RandomNumberGenerator.new()
var brief: String
var status: String
var note: String
var ending: String
var done:=false
var columns:=3
var labels: Array=[]
var goal: Array=[]
var v: Array=[]
var data: Dictionary={}
var step:=0
var picked:=-1
var grid_count:=0
var grid_width:=0
var theme_index:=0

func prepare(id: String, number: int) -> void:
	house=id
	deal=number
	rng.seed=int(id.hash())+number*104729
	setup()
	refresh()

func setup() -> void:pass
func refresh() -> void:pass
func act(_index: int) -> void:pass
func enabled(_index: int) -> bool:return true
func active(_index: int) -> bool:return false

func shuffled(items: Array) -> Array:
	var copy:=items.duplicate()
	for i in range(copy.size()-1,0,-1):
		var j:=rng.randi_range(0,i)
		var old=copy[i]
		copy[i]=copy[j]
		copy[j]=old
	return copy

func choose(items: Array) -> Variant:return items[rng.randi_range(0,items.size()-1)]
func numbers(items: Array, sep: String="、") -> String:
	return sep.join(items.map(func(n):return str(n)))
func grid(width: int, count: int) -> void:
	grid_width=width
	columns=width
	grid_count=count
func neighbors(cell: int,width: int,count: int) -> Array:
	var out: Array=[]
	if cell>=width:out.append(cell-width)
	if cell%width<width-1 and cell+1<count:out.append(cell+1)
	if cell+width<count:out.append(cell+width)
	if cell%width>0:out.append(cell-1)
	return out
func toggle(items: Array,item: int) -> void:
	if item in items:items.erase(item)
	else:items.append(item)
func win(message: String) -> void:
	done=true
	ending=message
func wrong(message: String) -> void:note=message
func swap(items: Array,a: int,b: int) -> void:
	var temp=items[a]
	items[a]=items[b]
	items[b]=temp
