extends Reference

## O MODO SEGURO, DECIDIDO SOZINHO.
##
## O visual caprichado (lutador de uma passada com as luzes de palco,
## torcida animada no vértice, arena mais nítida) só foi visto rodando no
## PC. A placa de vídeo da S905L (Mali-450) tem manias que o PC não tem, e
## um shader que ela não engole derruba o jogo. Então:
##
##   1. a abertura marca "tentando o visual novo" ANTES de desenhar nada;
##   2. passado um minuto e meio de jogo sem cair, marca que deu certo
##      (`firmou`) e daí em diante o visual novo vale sempre;
##   3. se a abertura anterior marcou "tentando" e nunca chegou ao
##      "firmou", foi ela que caiu: esta abre no MODO SEGURO — o desenho
##      exato da build 97, que rodava na placa — e não tenta mais.
##
## A marca vale por build: uma build nova tenta o visual novo de novo.
## Câmera, permissões e tela cheia são as mesmas nos dois modos.
##
## Sem `class_name` de propósito: é usado por `preload` (lutador, arena,
## carregador, versão) e não entra na lista de classes globais.

const ARQUIVO = "user://modo_seguro.cfg"
const SECAO = "modo"
## Quanto tempo de jogo, depois da abertura, prova que o visual novo roda.
const FIRMA_EM_S = 90.0

const _E = {
	"decidido": false,
	"seguro": false,
	"firmado": false,
}

static func seguro() -> bool:
	# Visual novo desligado no perfil: sempre o desenho da build 97, sem
	# tentativa nenhuma.
	if not Perfil.VISUAL_NOVO:
		return true
	if not _E.decidido:
		_decidir()
	return _E.seguro

static func _decidir() -> void:
	_E.decidido = true
	var build = _build()
	var cfg = ConfigFile.new()
	cfg.load(ARQUIVO)
	var mesma_build = int(cfg.get_value(SECAO, "build", -1)) == build
	var seguro = mesma_build and bool(cfg.get_value(SECAO, "seguro", false))
	var firmou = mesma_build and bool(cfg.get_value(SECAO, "firmou", false))
	if mesma_build and bool(cfg.get_value(SECAO, "tentando", false)) and not firmou:
		# A abertura anterior tentou o visual novo e não chegou ao fim.
		seguro = true
		print("SUPERBOXING modo seguro: a abertura anterior caiu com o visual novo")
	_E.seguro = seguro
	_E.firmado = firmou
	cfg.set_value(SECAO, "build", build)
	cfg.set_value(SECAO, "seguro", seguro)
	cfg.set_value(SECAO, "firmou", firmou)
	cfg.set_value(SECAO, "tentando", not seguro and not firmou)
	cfg.save(ARQUIVO)
	print("SUPERBOXING visual: %s" % ("SEGURO (build 97)" if seguro else "NOVO"))

## Caiu com o visual novo e voltou sozinho para o seguro?
static func voltou_sozinho() -> bool:
	return Perfil.VISUAL_NOVO and seguro()

## O visual novo rodou o bastante: não é mais suspeito.
static func firmou() -> void:
	if not Perfil.VISUAL_NOVO:
		return
	if not _E.decidido:
		_decidir()
	if _E.seguro or _E.firmado:
		return
	_E.firmado = true
	var cfg = ConfigFile.new()
	cfg.load(ARQUIVO)
	cfg.set_value(SECAO, "firmou", true)
	cfg.set_value(SECAO, "tentando", false)
	cfg.save(ARQUIVO)
	print("SUPERBOXING visual novo firmado")

static func _build() -> int:
	return int(Versao.NUMERO)
