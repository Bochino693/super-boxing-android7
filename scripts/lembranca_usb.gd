extends Reference

## O QUE O OPERADOR JÁ AUTORIZOU, GUARDADO NA TV BOX.
##
## A câmera e o Arduino são autorizados UMA VEZ. Depois disso o jogo não
## pergunta mais: numa abertura nova ele primeiro espera o próprio Android
## devolver a permissão (com "Usar por padrão" marcado, o Android a dá
## sozinho no boot) e só abre uma janela se ela não voltar — ou seja, se
## foi negada ou se o aparelho é outro.
##
## Também guarda POR ONDE a webcam do gabinete abriu (câmera do sistema):
## sabendo disso, o jogo nunca mais pede a janela USB da webcam, que só
## serve para o caminho de reserva.
##
## Sem `class_name` de propósito: é usado por `preload` no carregador e na
## câmera, e não entra na lista de classes globais do projeto.

const ARQUIVO = "user://permissoes_usb.cfg"
const SECAO = "autorizado"

## Chaves.
const ARDUINO = "arduino"
const CAMERA_DO_SISTEMA = "camera_do_sistema"
const WEBCAM_USB = "webcam_usb"

static func sabe(chave: String) -> bool:
	var cfg = ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return false
	return bool(cfg.get_value(SECAO, chave, false))

static func guardar(chave: String, valor: bool = true) -> void:
	var cfg = ConfigFile.new()
	cfg.load(ARQUIVO)
	if bool(cfg.get_value(SECAO, chave, not valor)) == valor:
		return
	cfg.set_value(SECAO, chave, valor)
	cfg.save(ARQUIVO)

## O relatório do plugin diz, para cada aparelho USB, se o jogo já tem a
## permissão — SEM abrir janela nenhuma (ao contrário de `openPort`).
## `porta` é a chave do plugin: "usb:VVVV:PPPP:id".
static func porta_tem_permissao(plugin: Object, porta: String) -> bool:
	var partes = porta.split(":")
	if plugin == null or partes.size() < 3:
		return false
	var marca = "USB %s:%s" % [partes[1].to_upper(), partes[2].to_upper()]
	for linha in str(plugin.call("getCameraReport")).split("\n", false):
		if linha.begins_with(marca):
			return "com permiss" in linha
	return false
