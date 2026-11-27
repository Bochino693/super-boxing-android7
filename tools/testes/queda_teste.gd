extends Node2D

## TESTE DA QUEDA DO NOCAUTE (só no PC, não vai no APK: tools/* fica fora).
##   godot3 --path . res://tools/testes/queda_teste.tscn -- --fotos=pasta [--forca=1.0] [--levanta] [--inteira]
## Monta só a arena, dá o soco que derruba e fotografa a janela 3D de 0,1
## em 0,1 s da queda (passo fixo de 1/30 s: a mesma queda toda vez). Sem
## `--levanta` é o nocaute do fim (ele fica na lona); com, o knockdown do
## meio da rodada (ele levanta). Imprime, por foto, o tombo das pernas e
## do tronco e a altura da bacia — o que conferir de olho na sequência.

const PASSO = 1.0 / 30.0
const SOCO_EM = 1.2

var arena: Arena3D
var pasta_fotos = ""
var forca = 1.0
var fica = true
var inteira = false
var t = 0.0
var _batido = false
var _proxima_foto = SOCO_EM - 0.1
var _fim = SOCO_EM + 2.6


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--fotos="):
			pasta_fotos = a.substr(8)
		elif a.begins_with("--forca="):
			forca = float(a.substr(8))
		elif a == "--inteira":
			inteira = true
		elif a == "--levanta":
			fica = false
			_fim = SOCO_EM + 6.0
	arena = Arena3D.new()
	arena.name = "Arena"
	add_child(arena)
	var ok = arena.instalar()
	print("QUEDA_TESTE: arena instalada=%s" % ok)
	arena.preparar()
	arena.ligar(true)
	arena.guardar(true)


func _process(_delta: float) -> void:
	t += PASSO
	if not _batido and t >= SOCO_EM:
		_batido = true
		var r = arena.golpe(forca, true, 9600, fica)
		print("QUEDA_TESTE: soco  nocaute=%s" % str(r.get("nocaute", false)))
	arena.avancar(PASSO)
	if t >= _proxima_foto and t <= _fim:
		var passo_foto = 0.1 if t < SOCO_EM + 1.6 else 0.5
		_proxima_foto += passo_foto
		var l = arena.lutador
		print("QUEDA_TESTE: t=%.2f  pernas=%.2f  tronco=%.2f  bacia=%.2f  quadril=%s costas=%s" % [
			t - SOCO_EM, l._qf_a, l._qf_a + l._qf_b, l._bacia.y if not l._qf else l._deitado_bacia.y,
			str(l._qf_quadril), str(l._qf_costas)])
		if pasta_fotos != "":
			call_deferred("_fotografar", "%05.2f" % (t - SOCO_EM))
	if t > _fim + 0.2:
		get_tree().quit()


func _fotografar(nome: String) -> void:
	yield(VisualServer, "frame_post_draw")
	var img = arena.get_texture().get_data()
	if img == null:
		return
	if not inteira:
		img.resize(img.get_width() / 3, img.get_height() / 3)
	var d = Directory.new()
	d.make_dir_recursive(pasta_fotos)
	img.save_png(pasta_fotos.plus_file("queda_%s.png" % nome))
