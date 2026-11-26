extends RefCounted
## The print travels with the placed furnishing, so every visitor sees the owner's actual stamps.
const G=preload("res://scripts/geometry.gd")
const COLORS=["b94c50","507e9a","dcab45"]
const SAMPLE=[[0,1,1],[4,0,0],[8,2,2]]
static func make(n: Node3D) -> void:
	G.box(n,Vector3(0,.57,.046),Vector3(1.12,1.12,.07),G.mat("936449"),"PearwoodFrame")
	G.box(n,Vector3(0,.57,.09),Vector3(1.035,1.035,.035),G.mat("eadbb7"),"SilkPaper")
	var marks:=Node3D.new();marks.name="PrintBlocks";n.add_child(marks)
	apply(n,SAMPLE)
static func apply(n: Node3D,layers: Array) -> void:
	var marks:=n.get_node_or_null("PrintBlocks")
	if marks==null or marks.get_meta("layers",[])==layers:return
	marks.set_meta("layers",layers.duplicate(true))
	for child in marks.get_children():child.free()
	for i in layers.size():
		var mark:Array=layers[i];var color:=G.mat(COLORS[int(mark[2])])
		var center:=Vector3((int(mark[0])%3-1)*.33,.57+(1-int(mark[0])/3)*.33,.115+i*.0015)
		match int(mark[1]):
			0:
				for j in 5:
					var angle:=j*TAU/5.
					G.ball(marks,center+Vector3(cos(angle)*.067,sin(angle)*.067,0),Vector3(.057,.057,.004),color)
				G.ball(marks,center+Vector3(0,0,.005),Vector3(.032,.032,.004),G.mat("c69c55"))
			1:
				for j in 3:
					var leaf:=G.ball(marks,center+Vector3((j-1)*.06,0,0),Vector3(.022,.103,.004),color)
					leaf.rotation.z=-.40
			2:
				for j in 3:
					for k in 6:
						var x:float=(k-2.5)*.034
						var wave:=G.ball(marks,center+Vector3(x,(j-1)*.044+.028*cos(k*.96),0),Vector3(.027,.013,.004),color)
						wave.rotation.z=-.4*sin(k*.96)
