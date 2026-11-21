extends Node3D
const DB = preload("res://scripts/services/game_data.gd")
const Parts = preload("res://scripts/appearance/model_parts.gd")
const CROPS = {
	"carrot": preload("res://assets/harvest/carrot.glb"),
	"lettuce": preload("res://assets/harvest/lettuce.glb"),
	"tomato": preload("res://assets/harvest/tomato.glb"),
	"pumpkin": preload("res://assets/harvest/pumpkin.glb"),
	"wheat": preload("res://assets/harvest/wheat.glb")
}
const WEEDS = preload("res://assets/harvest/weeds.glb")
const PIGMENT = preload("res://assets/harvest/pigment.tres")
static var clusters: Dictionary = {}
var plants: MultiMeshInstance3D
var weeds: MeshInstance3D
var marker: Label3D

static func cluster(mesh: Mesh) -> MultiMesh:
	if clusters.has(mesh):
		return clusters[mesh]
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = 4
	for i in 4:
		var x := (-1.0 if i % 2 == 0 else 1.0) * .40
		var z := (-1.0 if i < 2 else 1.0) * .40
		const SIZES := [0.95, 1.03, 0.89, 1.0]
		var basis := Basis(Vector3.UP, i * 2.39996 + .37).scaled(Vector3.ONE * SIZES[i])
		batch.set_instance_transform(i, Transform3D(basis, Vector3(x, -.084, z)))
	clusters[mesh] = batch
	return batch

func refresh(plot: Dictionary, needs: Dictionary) -> void:
	var crop := str(plot.crop)
	visible = CROPS.has(crop)
	if not visible:
		return
	if plants == null:
		plants = MultiMeshInstance3D.new()
		plants.name = "Planting"
		plants.lod_bias = .36
		plants.material_override = PIGMENT
		add_child(plants)
		# Turn the complete square planting in quarter turns without changing its footprint.
		plants.rotation.y = (hash(Vector2(position.x,position.z)) % 4) * PI * .5
		marker = Label3D.new()
		marker.font = preload("res://assets/fonts/NotoSansSC.ttf")
		marker.pixel_size = .009
		marker.font_size = 22
		marker.modulate = Color("f4f0d6")
		marker.position = Vector3(0,1.35,0)
		add_child(marker)
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.outline_size = 6
		marker.outline_modulate = Color("4d795e")
	var duration := float(DB.crop(crop).days) * 3600.0
	var phase := clampi(floori(float(plot.growth) * 4.0 / duration), 0, 4)
	var mesh: Mesh = Parts.from_scene(CROPS[crop])["Phase%d" % phase]
	var batch := cluster(mesh)
	if plants.multimesh != batch:
		plants.multimesh = batch
	if needs.weed:
		if weeds == null:
			weeds = MeshInstance3D.new()
			weeds.material_override = PIGMENT
			weeds.lod_bias = .45
			weeds.position.y = -.084
			weeds.rotation.y = plants.rotation.y
			add_child(weeds)
		var patch: Mesh = Parts.from_scene(WEEDS)["Seeded" if phase >= 2 else "Rosettes"]
		if weeds.mesh != patch:
			weeds.mesh = patch
	if weeds != null:
		weeds.visible = needs.weed
	marker.text = "可收获" if needs.ready else ("需要浇水" if needs.water else ("需要除草" if needs.weed else ""))
