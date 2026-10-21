extends Node2D

## TESTE DA ARENA 3D (só no PC, não vai no APK: tools/* fica fora).
##   godot3 --path . res://tools/testes/arena_teste.tscn -- [--seg=44] [--fotos=pasta] [--perfil=arquivo.csv]
## Monta só a arena (ringue, torcida, lutador) e roda uma luta roteirizada
## em laço: guarda, soco fraco, soco forte (cordas), soco na tela, nocaute
## e levantar, comemoração, deboche e o soco final. Grava fotos da janela
## 3D em momentos marcados e, por quadro, o tempo dos scripts da arena, o
## tempo do quadro, desenhos e vértices.
## Para imitar a Mali-450 (corpo deformado pelo processador), ponha na
## pasta do projeto um override.cfg com:
##   [rendering]
##   quality/skinning/force_software_skinning=true

const ROTEIRO = [
	[0.0, "preparar"], [0.3, "guarda"], [2.0, "golpe", 0.45, false, 4200], [4.0, "golpe", 0.95, false, 8800],
	[6.6, "soco_tela"], [9.6, "golpe", 1.0, true, 9600], [14.0, "fim", "vitoria"], [17.0, "preparar"],
	[17.3, "guarda"], [18.0, "golpe", 0.2, false, 1500], [19.5, "fim", "derrota"], [20.2, "soco_final"],
]
const DURACAO = 23.0
const FOTOS = [[1.2, "guarda"], [2.12, "impacto"], [4.5, "cordas"], [7.55, "soco_tela"], [11.0, "nocaute"],
	[15.5, "festa"], [18.4, "desdem"], [21.0, "soco_final"]]

var arena: Arena3D
var tela: TextureRect
var segundos = 44.0
var pasta_fotos = ""
var arquivo = ""
var t = 0.0
var t_total = 0.0
var _passo = 0
var _foto = 0
var _linhas = []
var _ultimo_us = 0
var _arena_us = 0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--seg="):
			segundos = float(a.substr(6))
		elif a.begins_with("--fotos="):
			pasta_fotos = a.substr(8)
		elif a.begins_with("--perfil="):
			arquivo = a.substr(9)
	Engine.target_fps = Perfil.FPS
	arena = Arena3D.new()
	arena.name = "Arena"
	add_child(arena)
	var ini = OS.get_ticks_msec()
	var ok = arena.instalar()
	print("ARENA instalada=%s em %d ms (corpo pela placa=%s)" % [ok, OS.get_ticks_msec() - ini,
		not VisualServer.has_os_feature("skinning_fallback") and not ProjectSettings.get_setting("rendering/quality/skinning/force_software_skinning")])
	arena.preparar()
	arena.ligar(true)
	tela = TextureRect.new()
	tela.expand = true
	tela.rect_position = Vector2(ArenaQuadro.TELA.position.x, 0)
	tela.rect_size = ArenaQuadro.TELA.size * 0.75
	tela.texture = arena.get_texture()
	add_child(tela)
	_ultimo_us = OS.get_ticks_usec()


func _process(delta: float) -> void:
	var agora = OS.get_ticks_usec()
	var quadro = agora - _ultimo_us
	_ultimo_us = agora
	if t_total > 0.0:
		_linhas.append([stepify(t_total, 0.001), quadro, _arena_us,
			int(Performance.get_monitor(Performance.RENDER_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_VERTICES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_MATERIAL_CHANGES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_SHADER_CHANGES_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])
	t += delta
	t_total += delta
	while _passo < ROTEIRO.size() and t >= ROTEIRO[_passo][0]:
		_executar(ROTEIRO[_passo])
		_passo += 1
	var ini = OS.get_ticks_usec()
	arena.avancar(delta)
	_arena_us = OS.get_ticks_usec() - ini
	if pasta_fotos != "" and t_total < DURACAO and _foto < FOTOS.size() and t >= FOTOS[_foto][0]:
		call_deferred("_fotografar", FOTOS[_foto][1])
		_foto += 1
	if t >= DURACAO:
		t = 0.0
		_passo = 0
	if t_total >= segundos:
		_terminar()


func _executar(p: Array) -> void:
	match p[1]:
		"preparar":
			arena.preparar()
		"guarda":
			arena.guardar(true)
		"golpe":
			arena.golpe(p[2], p[3], p[4], false)
			arena.agitar(p[2])
		"soco_tela":
			arena.soco_na_tela()
		"fim":
			arena.fim_de_rodada(p[2])
			arena.agitar(1.0, 3.0)
		"soco_final":
			arena.nocaute_no_jogador()


func _fotografar(nome: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = arena.get_texture().get_data()
	if img == null:
		return
	var d = Directory.new()
	d.make_dir_recursive(pasta_fotos)
	img.save_png(pasta_fotos.plus_file("%02d_%s.png" % [_foto, nome]))


func _terminar() -> void:
	set_process(false)
	if arquivo != "":
		var f = File.new()
		f.open(arquivo, File.WRITE)
		f.store_line("t;quadro_us;arena_us;desenhos;vertices;materiais;shaders;video_mb")
		for l in _linhas:
			var partes = PoolStringArray()
			for v in l:
				partes.append(str(v))
			f.store_line(partes.join(";"))
		f.close()
	var arena_med = 0.0
	var quadro_med = 0.0
	var n = 0
	var desenhos = 0
	var vertices = 0
	for l in _linhas:
		if l[0] < 2.0:
			continue
		n += 1
		quadro_med += l[1]
		arena_med += l[2]
		desenhos = max(desenhos, l[3])
		vertices = max(vertices, l[4])
	if n > 0:
		print("ARENA_TESTE: %d quadros  quadro medio %.2f ms  scripts da arena %.2f ms  desenhos max %d  vertices max %d" % [
			n, quadro_med / n / 1000.0, arena_med / n / 1000.0, desenhos, vertices])
	get_tree().quit()
