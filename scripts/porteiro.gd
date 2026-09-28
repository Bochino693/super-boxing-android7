class_name Porteiro
extends Reference

## AS JANELAS DE PERMISSÃO DO ANDROID, UMA DE CADA VEZ.
##
## O jogo pede três coisas ao Android: o Arduino (USB), a câmera e, quando
## a webcam não passa pelo sistema, a própria webcam (USB). Pedidas juntas,
## as janelas se atropelavam — a da câmera ainda aberta, a do Arduino
## chegando por cima — e na TV Box isso travava a tela. Agora há uma fila:
##
##   1. ARDUINO  — o jogo não funciona sem ele; vai primeiro.
##   2. CÂMERA   — só depois que o Arduino respondeu (ou não está ligado).
##   3. WEBCAM   — só depois que a câmera foi autorizada.
##
## E, enquanto QUALQUER janela do sistema estiver na frente do jogo (o jogo
## perdeu o foco), nada de USB é chamado: nem abrir porta, nem listar, nem
## pedir câmera. Quando o foco volta, espera-se um instante para o Android
## terminar de fechar a janela antes de mexer de novo.

## Quanto esperar depois que o foco volta (ms).
const RESPIRO_MS = 900
## Sem Arduino à vista por este tempo, a câmera não espera mais por ele.
const PACIENCIA_DO_ARDUINO_MS = 15000

## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
const _E = {
	"_foco": true,
	"_foco_voltou_ms": 0,
	"_foco_perdido_ms": 0,
	"_arduino_resolvido": false,
	"_inicio_ms": -1,
}
## SEM FOCO POR MAIS QUE ISTO, SEGUE A VIDA. Algumas TV Boxes não avisam
## o jogo quando o foco volta; esperar o aviso para sempre deixava câmera
## e Arduino parados. Janela de verdade na frente dura poucos segundos.
const FOCO_PERDIDO_MAXIMO_MS = 6000

static func foco(tem: bool) -> void:
	if tem and not _E._foco:
		_E._foco_voltou_ms = Time.get_ticks_msec()
	if not tem and _E._foco:
		_E._foco_perdido_ms = Time.get_ticks_msec()
	_E._foco = tem

## Pode mexer em USB e em câmera agora?
static func livre() -> bool:
	var agora = Time.get_ticks_msec()
	if not _E._foco:
		return agora - _E._foco_perdido_ms >= FOCO_PERDIDO_MAXIMO_MS
	return agora - _E._foco_voltou_ms >= RESPIRO_MS

## O Arduino respondeu (ou o jogo desistiu de esperar por ele).
static func arduino_resolvido() -> void:
	_E._arduino_resolvido = true

## É a vez da câmera?
static func vez_da_camera() -> bool:
	if not livre():
		return false
	if _E._arduino_resolvido or OS.get_name() != "Android":
		return true
	if _E._inicio_ms < 0:
		_E._inicio_ms = Time.get_ticks_msec()
	return Time.get_ticks_msec() - _E._inicio_ms >= PACIENCIA_DO_ARDUINO_MS
