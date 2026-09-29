extends Node

## A CAIXA-PRETA DA TV BOX.
##
## O `Diario` diz em que etapa a ABERTURA parou. Isto aqui cobre o resto:
## a sessão inteira, até a TV Box ser desligada ou alguma coisa cair. A
## cada poucos segundos grava, por cima, um arquivo pequeno com a foto do
## momento:
##
##   • quanto tempo o jogo está aberto e em que tela está;
##   • a câmera (ao vivo? em que tamanho?);
##   • a MEMÓRIA DO ANDROID: quanto está livre, o menor valor da sessão, o
##     limite em que o Android passa a fechar o que está em segundo plano
##     (o launcher é o primeiro da fila: "LongLauncher parou"), e quantas
##     vezes o Android avisou que estava apertado;
##   • a memória do próprio jogo.
##
## Na abertura seguinte, a foto da sessão anterior aparece na tela (e os
## últimos erros que o Android registrou do jogo, pelo PunchQuadros) —
## basta fotografar. Nada de cabo, nada de ADB.
##
## Sem `class_name` de propósito (usado por `preload`, como o ModoSeguro).

const ARQUIVO = "user://caixa_preta.txt"
const A_CADA_S = 6.0

const _E = {
	"no": null,
	"anterior": [],
	"erros": "",
	"jogo": null,
	"livre_min": -1,
}

var _desde_ms = 0
var _falta = 1.0
var _ponte = null
var _pedir_erros_ate_ms = 0

## Liga a caixa-preta (uma vez por abertura). Lê a da sessão anterior
## ANTES de começar a gravar a nova.
static func ligar(arvore: SceneTree) -> void:
	if _E.no != null:
		return
	_E.anterior = _ler_anterior()
	var no = load("res://scripts/caixa_preta.gd").new()
	no.name = "CaixaPreta"
	_E.no = no
	arvore.root.call_deferred("add_child", no)

## O jogo se apresenta para a caixa-preta saber a tela e a câmera.
static func jogo(no: Node) -> void:
	_E.jogo = no

## As linhas da sessão anterior (vazio na primeira abertura).
static func anterior() -> Array:
	return _E.anterior

## Os últimos erros que o Android registrou do jogo na sessão anterior
## ("" enquanto lê; "NENHUM" quando não houve).
static func erros() -> String:
	return _E.erros

static func _ler_anterior() -> Array:
	var linhas = []
	if not Compat.existe(ARQUIVO):
		return linhas
	var f = Compat.abrir(ARQUIVO, File.READ)
	if f == null:
		return linhas
	while not f.eof_reached():
		var l = f.get_line().strip_edges()
		if not l.empty():
			linhas.append(l)
	f.close()
	return linhas

func _ready() -> void:
	_desde_ms = Time.get_ticks_msec()
	_pedir_erros_ate_ms = _desde_ms + 60000
	if OS.get_name() == "Android" and Engine.has_singleton("PunchQuadros"):
		_ponte = Engine.get_singleton("PunchQuadros")
	pause_mode = Node.PAUSE_MODE_PROCESS

func _process(delta: float) -> void:
	_falta -= delta
	if _falta > 0.0:
		return
	_falta = A_CADA_S
	if _ponte != null and _E.erros.empty() and Time.get_ticks_msec() < _pedir_erros_ate_ms:
		_E.erros = str(_ponte.call("errosDaAberturaAnterior"))
	_gravar()

func _gravar() -> void:
	var linhas = []
	var s = int((Time.get_ticks_msec() - _desde_ms) / 1000)
	linhas.append("BUILD %d • SESSÃO DE %dm%02ds • TELA %s" % [Versao.NUMERO, s / 60, s % 60, _tela()])
	linhas.append("CÂMERA: %s" % _camera())
	linhas.append("MEMÓRIA: %s" % _memoria())
	var texturas = 0
	for t in VisualServer.texture_debug_usage():
		texturas += int(t["bytes"])
	linhas.append("GODOT: imagens %.0f MB • fixa %.0f MB • dinâmica %.0f MB" % [
		texturas / 1048576.0, OS.get_static_memory_usage() / 1048576.0,
		OS.get_dynamic_memory_usage() / 1048576.0])
	var f = Compat.abrir(ARQUIVO, File.WRITE)
	if f == null:
		return
	for l in linhas:
		f.store_line(l)
	f.close()

func _tela() -> String:
	var j = _E.jogo
	if j == null or not is_instance_valid(j):
		return "ABERTURA"
	if bool(j.get("central_aberta")):
		return "CENTRAL"
	var nomes = ["ESPERA", "CONTAGEM", "SOCO", "MEDINDO", "RESULTADO", "CONFIGURAÇÃO"]
	var e = int(j.get("state"))
	return nomes[e] if e >= 0 and e < nomes.size() else str(e)

func _camera() -> String:
	var j = _E.jogo
	if j == null or not is_instance_valid(j):
		return "ainda não acordou"
	var cam = j.get("camera_service")
	if cam == null:
		return "sem serviço"
	if cam.ao_vivo():
		var t = cam.preview_texture()
		var tam = "%dx%d" % [t.get_width(), t.get_height()] if t != null else "?"
		return "AO VIVO %s" % tam
	return str(cam.status).substr(0, 60)

func _memoria() -> String:
	if _ponte == null:
		return "sem leitura (só na TV Box)"
	var m = _ponte.call("memoria")
	if not m is Dictionary or not m.has("livre"):
		return "sem leitura"
	var livre = int(m["livre"])
	if _E.livre_min < 0 or livre < _E.livre_min:
		_E.livre_min = livre
	var texto = "livre %d MB (mínimo %d) • limite %d • jogo %d MB" % [
		livre, _E.livre_min, int(m.get("limite", 0)), int(m.get("jogo", 0))]
	var apertos = int(m.get("apertos", 0))
	if apertos > 0:
		texto += " • %d AVISOS DE MEMÓRIA (pior %d)" % [apertos, int(m.get("pior", 0))]
	if bool(m.get("pouca", false)):
		texto += " • POUCA AGORA"
	return texto
