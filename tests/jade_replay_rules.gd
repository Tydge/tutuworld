extends SceneTree
const Board=preload("res://scripts/jade/play_board.gd")
const Solutions=preload("res://tests/jade_game_solutions.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var failures:Array=[];var kinds:Array=[];var count:=0
	for id in Board.Games.STATIONS.keys()+Board.Games.PERFORMANCES.keys():
		var kind:String=Board.Games.type_for(id)
		if kind in kinds:failures.append("shared game "+id)
		kinds.append(kind)
		var deals:Dictionary={}
		for k in 12:
			var board:=Board.new(id,k,0)
			var r=board.rule;deals[str([r.goal,r.v,r.data,r.labels])]=true
			var answer:=Solutions.solution(board)
			for action in answer:
				if not board.play(action):failures.append("%s %d rejected %s"%[id,k,answer]);break
			if not r.done:failures.append("%s %d unsolved %s"%[id,k,answer])
			if r.done:
				var expected:String=r.ending;board.undo()
				if board.rule.done or not board.play(answer.back()) or board.rule.ending!=expected:failures.append("undo "+id)
			count+=1
		if deals.size()<2:failures.append("identical deals "+id)
	for k in 8:
		var board:=Board.new("weir",k)
		for n in Solutions.solution(board,true):board.play(n)
		if not board.rule.done or not "鱼塘也满" in board.rule.ending:failures.append("pond "+str(k))
	var paper:=Board.new("paper")
	for n in [9,13,0,12,0,10,4]:paper.play(n)
	if paper.rule.paper_ready():failures.append("overprinted ink is invisible")
	if Board.clean_print([[1,4,0]])!=[] or Board.clean_print([[8,2,2]])!=[[8,2,2]]:failures.append("print normalization")
	var migrated:=Board.normalize({"marks":["oil","oil"],"letter":"post"})
	if migrated.rounds!={"oil":1} or migrated.letter!="post" or migrated.marks!=["oil"]:failures.append("migration")
	print("JADE_REPLAY places=",kinds.size()," deals=",count," failures=",failures)
	quit(int(not failures.is_empty()))
