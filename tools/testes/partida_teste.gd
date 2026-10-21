extends Node

## TESTE DE UMA PARTIDA INTEIRA (só no PC, não vai no APK).
##   godot3 --path . res://tools/testes/partida_teste.tscn -- [--partidas=2] [--fotos=pasta] [--perfil=arquivo.csv]
## Abre a cena do jogo como no editor, finge uma placa Arduino que respondeu
## (sem motor) e câmera desligada, aperta START e dá os dois socos quando o
## jogo pede (fracos, médios e fortes, alternando). Grava fotos da tela e,
## por quadro, o tempo do quadro, o estado do jogo e se a arena estava no ar.

class PlacaDeMentira:
	extends SerialLink
	func available() -> bool:
		return true
	func is_open() -> bool:
		return true
	func send_line(_l: String) -> bool:
		return true
	func poll() -> void:
		pass

## Sondas: a primeira e a última a rodar no _process de cada quadro.
class Sonda:
	extends Node
	var dono
	var lado = 0
	func _process(_d):
		dono._sonda(lado)

const FORCAS = [[0.55, 0.92], [0.95, 0.99], [0.25, 0.4]]

var main
var partidas = 2
var pasta_fotos = ""
var arquivo = ""
var t = 0.0
var feitas = 0
var _socos = 0
var _armado_em = -1.0
var _resultado_em = -1.0
var _linhas = []
var _ultimo_us = 0
var _fotos_feitas = {}
var _quadros_por_estado = {}
var _esconder = ""


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--partidas="):
			partidas = int(a.substr(11))
		elif a.begins_with("--fotos="):
			pasta_fotos = a.substr(8)
		elif a.begins_with("--perfil="):
			arquivo = a.substr(9)
		elif a.begins_with("--esconder="):
			_esconder = a.substr(11)
	# Cronômetros por chamada (só quando o código foi instrumentado à mão,
	# para medir; ver o resumo "PERF" no fim).
	Engine.set_meta("perf", {})
	Engine.set_meta("estado", "INICIO")
	main = load("res://scenes/main.tscn").instance()
	add_child(main)
	_ultimo_us = OS.get_ticks_usec()
	for lado in [0, 1]:
		var sd = Sonda.new()
		sd.dono = self
		sd.lado = lado
		sd.process_priority = -100000 if lado == 0 else 100000
		get_tree().root.call_deferred("add_child", sd)
	VisualServer.connect("frame_pre_draw", self, "_pre_desenho")
	VisualServer.connect("frame_post_draw", self, "_pos_desenho")


var _proc_ini = 0
var _proc_us = 0
var _proc_fim = 0
var _flush_us = 0
var _pre = 0
var _render_us = 0

func _sonda(lado: int) -> void:
	if lado == 0:
		_proc_ini = OS.get_ticks_usec()
	else:
		_proc_fim = OS.get_ticks_usec()
		_proc_us = _proc_fim - _proc_ini

func _pre_desenho() -> void:
	_pre = OS.get_ticks_usec()
	_flush_us = _pre - _proc_fim if _proc_fim > 0 else 0

func _pos_desenho() -> void:
	_render_us = OS.get_ticks_usec() - _pre


func _fingir_placa() -> void:
	main.link = PlacaDeMentira.new()
	main.placa_respondeu = true
	main.camera_enabled = false


func _process(delta: float) -> void:
	var agora = OS.get_ticks_usec()
	var estado = GameDef.State.keys()[main.state] if main.state < GameDef.State.size() else str(main.state)
	if main.state == GameDef.State.IDLE and main.intro_active:
		estado = "INTRO"
	Engine.set_meta("estado", estado)
	_quadros_por_estado[estado] = _quadros_por_estado.get(estado, 0) + 1
	_linhas.append([stepify(t, 0.001), agora - _ultimo_us, estado, main.arena.ativa(),
		_proc_us / 1000.0, _flush_us / 1000.0, _render_us / 1000.0,
		int(Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_2D_ITEMS_IN_FRAME))])
	_ultimo_us = agora
	t += delta
	if t < 4.0:
		return
	if main.link == null or not (main.link is PlacaDeMentira):
		_fingir_placa()
	if _esconder != "":
		main.get_node(_esconder).visible = false
	match main.state:
		GameDef.State.IDLE:
			if feitas >= partidas:
				_terminar()
				return
			if _resultado_em < 0.0 or t - _resultado_em > 1.0:
				main._pressionou_start()
		GameDef.State.ARMED:
			if _armado_em < 0.0:
				_armado_em = t
			if t - _armado_em > 1.6 and not main.golpe_registrado:
				var f = FORCAS[feitas % FORCAS.size()][min(_socos, 1)]
				main._receber_hit({"speed": lerp(main.hit_min_speed, main.hit_max_speed, f), "accel": 2.0,
					"duration_ms": 45.0, "axis": main.sensor_eixo})
				_socos += 1
				_armado_em = -1.0
				_foto("p%d_soco%d" % [feitas, _socos], 0.15)
		GameDef.State.RESULT:
			if _resultado_em < 0.0:
				_resultado_em = t
				_foto("p%d_resultado" % feitas, 1.5)
			elif t - _resultado_em > 7.0 and main.verdict_time >= 0.0:
				feitas += 1
				_socos = 0
				_resultado_em = -1.0
				main._entrar_em_abertura()
		_:
			_armado_em = -1.0


func _foto(nome: String, depois: float) -> void:
	if pasta_fotos == "" or _fotos_feitas.has(nome):
		return
	_fotos_feitas[nome] = true
	yield(get_tree().create_timer(depois), "timeout")
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	var d = Directory.new()
	d.make_dir_recursive(pasta_fotos)
	img.save_png(pasta_fotos.plus_file(nome + ".png"))


func _terminar() -> void:
	set_process(false)
	if arquivo != "":
		var f = File.new()
		f.open(arquivo, File.WRITE)
		f.store_line("t;quadro_us;estado;arena;process_ms;draw2d_ms;render_ms;desenhos3d;desenhos2d;itens2d")
		for l in _linhas:
			f.store_line("%s;%d;%s;%s;%.3f;%.3f;%.3f;%d;%d;%d" % l)
		f.close()
	print("PARTIDA_TESTE: %d partidas, %d quadros" % [feitas, _linhas.size()])
	var perf: Dictionary = Engine.get_meta("perf")
	var chaves = perf.keys()
	chaves.sort_custom(self, "_mais_caro")
	for k in chaves:
		var estado = str(k).split("|")[0]
		var q = max(1, int(_quadros_por_estado.get(estado, 1)))
		if float(perf[k]) / q >= 20.0:
			print("PERF %-10s %8.0f us/quadro  %s" % [estado, float(perf[k]) / q, str(k).split("|")[1]])
	get_tree().quit()


func _mais_caro(a, b) -> bool:
	var perf: Dictionary = Engine.get_meta("perf")
	return float(perf[a]) / max(1, int(_quadros_por_estado.get(str(a).split("|")[0], 1))) > \
		float(perf[b]) / max(1, int(_quadros_por_estado.get(str(b).split("|")[0], 1)))
