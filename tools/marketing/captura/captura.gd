extends Node

## Captura do jogo para o video (so no PC): roda a cena do jogo com uma
## placa de mentira, aperta START (tecla 1), da dois socos fortes e deixa o
## fim correr (nocaute, festa, TOP 20). Grava TODOS os quadros (use com
## --fixed-fps 30) e o registro de sons e estados (captura.json).

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

var main
var pasta = ""
var t = 0.0
var gravando = false
var n = 0
var quadros = []
var _socos = 0
var _armado_em = -1.0
var _idle_desde = -1.0
var _start_dado = false
var _fim_em = -1.0
var _tentou_em = -1.0
var _estado_antes = ""
## o primeiro soco forte (sem derrubar) e o segundo, o nocaute
var forcas = [0.78, 1.0]


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	Engine.set_meta("sons", [])
	Engine.set_meta("perf", {})
	Engine.set_meta("estado", "INICIO")
	main = load("res://scenes/main.tscn").instance()
	add_child(main)


func _process(delta: float) -> void:
	t += delta
	var estado = GameDef.State.keys()[main.state]
	if main.state == GameDef.State.IDLE and main.intro_active:
		estado = "INTRO"
	if t >= 4.0 and (main.link == null or not (main.link is PlacaDeMentira)):
		main.link = PlacaDeMentira.new()
		main.placa_respondeu = true
		main.camera_enabled = false
	if not gravando and estado == "INTRO" and not main.entrada_segurada:
		gravando = true
		print("CAPTURA: comecou no quadro ", Engine.get_idle_frames())
	if gravando:
		quadros.append([n, Engine.get_idle_frames(), estado, stepify(t, 0.001)])
		call_deferred("_gravar", n)
		n += 1
	match main.state:
		GameDef.State.IDLE:
			if estado != "INTRO" and not _start_dado:
				if _idle_desde < 0.0:
					_idle_desde = t
				elif t - _idle_desde > 2.5:
					_start_dado = true
					for apertada in [true, false]:
						var e = InputEventKey.new()
						e.scancode = KEY_1
						e.pressed = apertada
						Input.parse_input_event(e)
					print("CAPTURA: START no quadro ", n)
			elif _start_dado and _socos >= 2 and estado != "INTRO":
				if _fim_em < 0.0:
					_fim_em = t
				elif t - _fim_em > 2.5:
					_terminar()
		GameDef.State.ARMED:
			if _armado_em < 0.0:
				_armado_em = t
			# soca e repete a cada 1 s enquanto o jogo nao mede (o saco ainda
			# descendo, o lutador ainda levantando): so conta quando mede
			if t - _armado_em > 1.8 and not main.golpe_registrado and _socos < 2 and t - _tentou_em > 1.0:
				_tentou_em = t
				var f = forcas[min(_socos, 1)]
				main._receber_hit({"speed": lerp(main.hit_min_speed, main.hit_max_speed, f), "accel": 2.0,
					"duration_ms": 45.0, "axis": main.sensor_eixo})
		_:
			_armado_em = -1.0
	if estado == "MEASURING" and _estado_antes == "ARMED":
		_socos += 1
		_armado_em = -1.0
		print("CAPTURA: soco %d medido no quadro %d" % [_socos, n])
	_estado_antes = estado
	if t > 150.0:
		_terminar()


func _gravar(i: int) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(pasta.plus_file("q%05d.png" % i))


func _terminar() -> void:
	set_process(false)
	var f = File.new()
	f.open(pasta.plus_file("captura.json"), File.WRITE)
	f.store_string(to_json({"quadros": quadros, "sons": Engine.get_meta("sons"), "fps": Engine.iterations_per_second}))
	f.close()
	print("CAPTURA: fim, %d quadros" % n)
	yield(get_tree().create_timer(0.5), "timeout")
	get_tree().quit()
