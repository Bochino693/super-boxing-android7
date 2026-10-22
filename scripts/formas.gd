extends Reference

## (Carregado com `preload` por quem usa:
## `const Formas = preload("res://scripts/formas.gd")`.)

## PEÇAS DE INTERFACE POR TEXTURA (build 120).
##
## A placa de cantos redondos, a pílula do cartão do soco e o anel dele eram
## montados no script a cada quadro: pontos do contorno, triângulos, a
## borda lisa de um pixel em volta. Cada peça custava de 20 a 40
## microssegundos num PC — uns 200 a 300 no processador da TV Box —, e uma
## tela do TOP 20 tem umas vinte delas.
##
## Aqui elas são TEXTURAS BRANCAS tingidas com a cor pedida
## (`tools/gerar_icones.py`, em `assets/ui/`). As placas vão em "nove
## pedaços": os quatro cantos ficam do tamanho certo, no pixel, e só o meio
## estica — e a placa de vídeo junta os retângulos com textura no mesmo
## desenho. Uma placa custa um ou dois microssegundos, e a borda sai lisa
## porque foi desenhada oito vezes maior e reduzida.
##
## Um raio que não tem textura (ou um retângulo pequeno demais para os
## cantos) volta para o desenho no script, que continua valendo.

const PLACAS = {
	10: preload("res://assets/ui/placa_r10.png"),
	12: preload("res://assets/ui/placa_r12.png"),
	16: preload("res://assets/ui/placa_r16.png"),
	17: preload("res://assets/ui/placa_r17.png"),
	19: preload("res://assets/ui/placa_r19.png"),
	22: preload("res://assets/ui/placa_r22.png"),
}
const PILULA = preload("res://assets/ui/pilula_r84.png")
const PILULA_BRILHO = preload("res://assets/ui/pilula_r94.png")
const PILULA_BORDA_GROSSA = preload("res://assets/ui/pilula_borda_r84_w4.png")
const PILULA_BORDA_FINA = preload("res://assets/ui/pilula_borda_r84_w2.png")
const PILULA_RAIO = 84.0
const PILULA_BRILHO_RAIO = 94.0
## O anel do cartão do soco (raio de referência 62): o halo, o trilho e o
## arco que gira chamando o soco (2,2 rad a partir do ângulo 0).
const CARTAO_HALO = preload("res://assets/ui/cartao_halo.png")
const CARTAO_TRILHO = preload("res://assets/ui/cartao_trilho.png")
const CARTAO_GIRO = preload("res://assets/ui/cartao_giro.png")
const CARTAO_RAIO = 62.0
## O boneco de quem não tem foto, na medida da linha do TOP 20 (ver
## `main._draw_avatar`): a cabeça e os ombros, e as cantoneiras.
const AVATAR_TRACO = preload("res://assets/ui/avatar_traco.png")
const AVATAR_CANTOS = preload("res://assets/ui/avatar_cantos.png")
## O medidor redondo do impacto (raio 158): os arcos que giram lendo o
## sensor (raios 160 e 118, a partir do ângulo 0) e o aro do vidro (170).
const MEDIDOR_GIRO_FORA = preload("res://assets/ui/medidor_giro_fora.png")
const MEDIDOR_GIRO_DENTRO = preload("res://assets/ui/medidor_giro_dentro.png")
const MEDIDOR_ARO = preload("res://assets/ui/medidor_aro.png")
## Um disco liso de raio 254 numa imagem de 512 (potência de 2, com
## mipmaps), para círculos de qualquer raio até uns 300 px: das faíscas às
## bolhas de luz. Acima disso a borda começa a ficar macia.
const DISCO = preload("res://assets/ui/disco.png")
const DISCO_RAIO = 254.0
const DISCO_RAIO_MAXIMO = 300.0


## Retângulo de cantos redondos cheio. Devolve `false` quando não há
## textura para esse raio (quem chamou desenha do jeito antigo).
static func placa(ci: CanvasItem, rect: Rect2, raio: float, cor: Color) -> bool:
	var r = int(round(raio))
	var tex = PLACAS.get(r)
	if tex == null or rect.size.x < r * 2 or rect.size.y < r * 2:
		return false
	if cor.a > 0.0:
		_nove(ci, rect, tex, r, cor)
	return true

## A pílula do cartão (cantos de 84 px) e o brilho em volta dela (94 px).
static func pilula(ci: CanvasItem, rect: Rect2, cor: Color) -> void:
	_nove(ci, rect, PILULA, int(PILULA_RAIO), cor)

static func pilula_brilho(ci: CanvasItem, rect: Rect2, cor: Color) -> void:
	_nove(ci, rect, PILULA_BRILHO, int(PILULA_BRILHO_RAIO), cor)

## A borda da pílula: 4 px (o melhor soco) ou 2,5 px.
static func pilula_borda(ci: CanvasItem, rect: Rect2, cor: Color, grossa: bool) -> void:
	_nove(ci, rect, PILULA_BORDA_GROSSA if grossa else PILULA_BORDA_FINA, int(PILULA_RAIO), cor)

## Uma das peças redondas do cartão, centrada em `centro`; `raio` é o raio
## do anel (a peça é ampliada na mesma medida quando o cartão cresce).
static func peca_do_cartao(ci: CanvasItem, tex: Texture, centro: Vector2, raio: float, cor: Color) -> void:
	peca(ci, tex, centro, raio / CARTAO_RAIO, cor)

## Uma peça redonda qualquer, centrada em `centro`, na `escala` pedida.
static func peca(ci: CanvasItem, tex: Texture, centro: Vector2, escala: float, cor: Color) -> void:
	if cor.a <= 0.0:
		return
	var lado = Vector2(tex.get_size()) * escala
	ci.draw_texture_rect(tex, Rect2(centro - lado * 0.5, lado), false, cor)

## Um círculo cheio de `raio` px.
static func disco(ci: CanvasItem, centro: Vector2, raio: float, cor: Color) -> void:
	peca(ci, DISCO, centro, raio / DISCO_RAIO, cor)

static func _nove(ci: CanvasItem, rect: Rect2, tex: Texture, margem: int, cor: Color) -> void:
	if cor.a <= 0.0:
		return
	var m = Vector2(margem, margem)
	VisualServer.canvas_item_add_nine_patch(
		ci.get_canvas_item(), rect, Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(),
		m, m, VisualServer.NINE_PATCH_STRETCH, VisualServer.NINE_PATCH_STRETCH, true, cor
	)
