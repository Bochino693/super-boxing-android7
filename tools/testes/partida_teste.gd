extends Node

## TESTE DE UMA PARTIDA INTEIRA (só no PC, não vai no APK).
##   godot3 --path . res://tools/testes/partida_teste.tscn -- [--partidas=2] [--fotos=pasta] [--perfil=arquivo.csv] [--degrau=0]
## Abre a cena do jogo como no editor, finge uma placa Arduino que respondeu
## (sem motor) e câmera desligada, aperta START (a tecla 1) e dá os dois socos quando o
## jogo pede (fracos, médios e fortes, alternando). Grava fotos da tela e,
## por quadro, o tempo do quadro, o estado do jogo e se a arena estava no ar.
## `--natural` deixa o fim da rodada correr sozinho (nocaute, festa, TOP 20
## e a cortina de volta à abertura), fotografando o caminho.
## `--degrau=N` prende o gráfico da arena no degrau N (`Arena3D.DEGRAUS`):
## num PC sem placa de vídeo o jogo desceria sozinho para o último.
## `--camera` finge uma webcam ao vivo (um quadro novo a cada 125 ms): a
## rodada passa pela pose e pela foto, e as fotos da tela pegam a cortina
## do ringue quadro a quadro. `--camera-cai=S` corta a webcam S segundos
## depois do START (a pose tem de desistir e ir para o ringue).

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

const TelaGirada = preload("res://scripts/tela_girada.gd")
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
var _fim_em = 0.0
var _linhas = []
var _ultimo_us = 0
var _fotos_feitas = {}
var _quadros_por_estado = {}
var _esconder = ""
var _degrau = -1
var _natural = false
var _camera = false
var _camera_cai = -1.0
var _start_em = -1.0
var _quadro_cam = 0
var _proximo_quadro_cam = 0.0
var _cortina_vista = false


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
		elif a.begins_with("--degrau="):
			_degrau = int(a.substr(9))
		elif a == "--natural":
			_natural = true
		elif a == "--camera":
			_camera = true
		elif a.begins_with("--camera-cai="):
			_camera = true
			_camera_cai = float(a.substr(13))
	# Cronômetros por chamada (só quando o código foi instrumentado à mão,
	# para medir; ver o resumo "PERF" no fim).
	Engine.set_meta("perf", {})
	Engine.set_meta("estado", "INICIO")
	main = load("res://scenes/main.tscn").instance()
	# a tela escolhida como no carregador: `PUNCH_GIRADO=1` desenha girado
	# como na TV Box (direto se a janela for 1920x1080) e
	# `PUNCH_SUBVIEWPORT=1` força a tela intermediária
	if TelaGirada.intermediaria():
		Compat.enquadrar(get_tree(), TelaGirada.JANELA if TelaGirada.girada() else TelaGirada.TELA)
		TelaGirada.montar_intermediaria(self).add_child(main)
	else:
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
	main.camera_enabled = _camera
	if _camera:
		main.camera_service.set_process(false)
		main.camera_service.enabled = true


## A WEBCAM DE MENTIRA: um quadro novo (que muda) a cada 125 ms, entregue
## pelo mesmo caminho da ponte Android (`_registrar_quadro`).
func _passo_da_camera() -> void:
	var cs = main.camera_service
	if _camera_cai >= 0.0 and _start_em >= 0.0 and t - _start_em >= _camera_cai:
		return
	if t < _proximo_quadro_cam:
		return
	_proximo_quadro_cam = t + 0.125
	_quadro_cam += 1
	var img = Image.new()
	img.create(320, 240, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.3, 0.45))
	var lado = 60 + (_quadro_cam * 7) % 80
	img.fill_rect(Rect2(130 - lado / 2, 120 - lado / 2, lado, lado), Color(0.95, 0.8, 0.6))
	if cs._uvc_texture == null:
		cs._uvc_texture = ImageTexture.new()
		cs._uvc_texture.create_from_image(img, Texture.FLAG_FILTER)
	else:
		cs._uvc_texture.set_data(img)
	cs.estado = cs.Estado.ACESA
	cs._registrar_quadro(img, Time.get_ticks_msec())


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
		int(Performance.get_monitor(Performance.RENDER_2D_ITEMS_IN_FRAME)),
		stepify(main.transicao, 0.001), main.sons.playing("round_bell"), main.pose_finished])
	_ultimo_us = agora
	t += delta
	if _degrau >= 0 and main.degrau_grafico != _degrau:
		main.degrau_grafico = _degrau
		main.arena.aplicar_degrau(_degrau)
	if t < 4.0:
		return
	if main.link == null or not (main.link is PlacaDeMentira):
		_fingir_placa()
	if _camera:
		_passo_da_camera()
	if _esconder != "":
		main.get_node(_esconder).visible = false
	match main.state:
		GameDef.State.IDLE:
			if _natural and _resultado_em >= 0.0:
				feitas += 1
				_socos = 0
				_resultado_em = -1.0
				print("PARTIDA_TESTE: rodada %d voltou sozinha à abertura em %.1f s" % [feitas, t - _fim_em])
				_foto("p%d_abertura" % (feitas - 1), 1.5)
			if feitas >= partidas:
				_terminar()
				return
			if _resultado_em < 0.0 or t - _resultado_em > 1.0:
				_tecla_start()
				_start_em = t
				_cortina_vista = false
				# sem câmera, a cortina leva direto ao ringue (sem a pose)
				_foto("p%d_start" % feitas, 0.5)
		GameDef.State.COUNTDOWN:
			if main.transicao < 0.0 and not main.pose_finished:
				_foto("p%d_pose" % feitas, 0.0)
			if main.pose_finished and main.transicao >= 0.0 and not _cortina_vista:
				_cortina_vista = true
				for k in 6:
					_foto("p%d_cortina%d" % [feitas, k], 0.1 * k)
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
				_fim_em = t
				_foto("p%d_resultado" % feitas, 1.5)
				if _natural:
					for k in [4, 8, 12, 16, 20]:
						_foto("p%d_fim_%02d" % [feitas, k], float(k))
			elif _natural:
				pass
			elif t - _resultado_em > 7.0 and main.verdict_time >= 0.0:
				feitas += 1
				_socos = 0
				_resultado_em = -1.0
				main._entrar_em_abertura()
		_:
			_armado_em = -1.0


## O START do teste é a tecla 1, como no gabinete com teclado.
func _tecla_start() -> void:
	for apertada in [true, false]:
		var e = InputEventKey.new()
		e.scancode = KEY_1
		e.pressed = apertada
		Input.parse_input_event(e)


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
		f.store_line("t;quadro_us;estado;arena;process_ms;draw2d_ms;render_ms;desenhos3d;desenhos2d;itens2d;cortina;sino;foto")
		for l in _linhas:
			f.store_line("%s;%d;%s;%s;%.3f;%.3f;%.3f;%d;%d;%d;%s;%s;%s" % l)
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
