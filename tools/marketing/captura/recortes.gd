extends Node2D

## Recortes do lutador para a divulgacao (so no PC): roda a luta roteirizada
## da arena e grava, de N em N quadros, so o lutador com fundo transparente.
##   godot3 --video-driver GLES3 --fixed-fps 30 --path . res://tools/marketing/captura/recortes.tscn -- --pasta=/x --fov=30 --cada=3

const ROTEIRO = [
	[0.0, "preparar"], [0.3, "guarda"], [2.0, "golpe", 0.45, false, 4200], [4.0, "golpe", 0.95, false, 8800],
	[6.6, "soco_tela"], [9.6, "golpe", 1.0, true, 9600], [14.0, "fim", "vitoria"], [17.0, "preparar"],
	[17.3, "guarda"], [18.0, "golpe", 0.2, false, 1500], [19.5, "fim", "derrota"], [20.2, "soco_final"],
]
const DURACAO = 23.0

var arena: Arena3D
var pasta = ""
var fov = 30.0
var cada = 3
var cheio = false
var janelas = []
var ate = 999.0
var t = 0.0
var _passo = 0
var _quadro = 0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--pasta="):
			pasta = a.substr(8)
		elif a.begins_with("--fov="):
			fov = float(a.substr(6))
		elif a.begins_with("--cada="):
			cada = int(a.substr(7))
		elif a == "--cheio":
			cheio = true
		elif a.begins_with("--ate="):
			ate = float(a.substr(6))
		elif a.begins_with("--janelas="):
			for j in a.substr(10).split(","):
				var ab = j.split("-")
				janelas.append([float(ab[0]), float(ab[1])])
	arena = Arena3D.new()
	add_child(arena)
	arena.instalar()
	arena.aplicar_degrau(0)
	arena.preparar()
	arena.ligar(true)
	if not cheio:
		arena.transparent_bg = true
		for no in Compat.filhos_do_tipo(arena, "VisualInstance"):
			if not arena.lutador.is_a_parent_of(no) and not (no is Light):
				no.visible = false
	var d = Directory.new()
	d.make_dir_recursive(pasta)


func _process(delta: float) -> void:
	t += delta
	while _passo < ROTEIRO.size() and t >= ROTEIRO[_passo][0]:
		_executar(ROTEIRO[_passo])
		_passo += 1
	arena.avancar(delta)
	arena.camera.fov = fov
	# fora das janelas a arena nao desenha (o corpo anda igual): bem mais rapido
	arena.render_target_update_mode = Viewport.UPDATE_ALWAYS if _na_janela() else Viewport.UPDATE_DISABLED
	if not cheio:
		for no in Compat.filhos_do_tipo(arena, "VisualInstance"):
			if not arena.lutador.is_a_parent_of(no) and not (no is Light) and no.visible:
				no.visible = false
	_quadro += 1
	if _quadro % cada == 0 and _na_janela():
		call_deferred("_gravar", _quadro)
	if t >= DURACAO or t > ate:
		get_tree().quit()


func _na_janela() -> bool:
	if janelas.empty():
		return true
	for j in janelas:
		if t >= j[0] and t <= j[1]:
			return true
	return false


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


func _gravar(n: int) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = arena.get_texture().get_data()
	if img == null:
		return
	img.save_png(pasta.plus_file("q%04d_%05.2f.png" % [n, t]))
