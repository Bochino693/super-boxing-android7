class_name ArenaQuadro
extends Reference

## Formas juntadas numa chamada só (ver `scripts/lote.gd`).
const Lote = preload("res://scripts/lote.gd")

## A ARENA PENDURADA NA PAREDE, COMO UM QUADRO.
##
## Foi assim que o pedido veio, e a palavra é exata: o mundo 3D não
## invade a tela toda nem fica flutuando solto no meio dela — ele mora
## dentro de uma MOLDURA, no lugar que o fundo do jogo já reservava para
## si, e o resto da interface (placar, cartões, frases) continua em volta
## como sempre esteve.
##
## POR QUE A MOLDURA IMPORTA TANTO. Uma imagem 3D colada crua num fundo
## 2D desenhado à mão lê como erro de montagem: dois desenhos diferentes
## brigando. Com moldura, a diferença vira INTENÇÃO — é uma janela, e
## janelas mostram outro lugar mesmo. É o mesmo truque de um telão no
## fundo do palco.
##
## AS BARRAS LATERAIS FICARAM, E MUDARAM DE ASSUNTO. Elas já existiam na
## versão original, medindo a pontuação do soco; aqui medem o DANO do
## adversário, que é a mesma leitura de longe (coluna cheia contra coluna
## pela metade) contando uma história melhor: a rodada tem dois socos, e
## agora os dois se somam em cima de alguém.
##
## As medidas são constantes públicas porque três lugares dependem delas
## — o desenho, o `Viewport` (que precisa da proporção certa para a
## imagem não esticar) e os testes.

## A moldura inteira, borda incluída. O QUADRO OCUPA A LARGURA TODA: o
## lutador e o ringue são o espetáculo, e as colunas laterais de dano
## saíram para dar lugar a eles (a vida agora é a barra de cima).
## A ARENA GRANDE: o quadro ocupa quase a tela inteira, e o que é da
## luta (as duas vidas no alto, os socos embaixo) mora DENTRO dele, como
## o painel de um jogo de luta — e não espalhado em volta.
##
## 4.6 PRO: A ARENA VAI DE PONTA A PONTA na largura.
## BUILD 119: E DE CIMA A BAIXO. O 3D ocupa a tela inteira (1080 x 1920):
## não sobra faixa do fundo 2D em cima nem embaixo — em cima aparece a
## treliça de luz, embaixo a borda do ringue com a saia. O placar, as
## vidas e os textos ficam por cima do 3D, como o painel de um jogo de
## luta. A faixa zebrada do gabinete fecha a TELA nos quatro lados, por
## cima dos 16 px da borda da imagem. A câmera abriu junto (ver `Arena3D`): cabe o ringue
## inteiro, a torcida dos lados, a treliça de luz e o telão.
const MOLDURA := Rect2(0.0, 0.0, 1080.0, 1920.0)
## O buraco da moldura: é aqui que a imagem da arena é desenhada.
const TELA := Rect2(0.0, 0.0, 1080.0, 1920.0)
## O quadro da build 118 (1080 x 1540, a 116 px do alto): o enquadramento
## da câmera foi acertado nele, e o lutador continua no mesmo lugar e do
## mesmo tamanho na tela (ver `Arena3D._calcular_enquadramento`).
const QUADRO_DO_LUTADOR := Rect2(0.0, 116.0, 1080.0, 1540.0)
## A espessura das tarjas zebradas, nas quatro bordas da tela.
const TARJA := 16.0
## AS DUAS VIDAS, dentro do quadro, no alto: a do JOGADOR à esquerda e a
## do ADVERSÁRIO à direita (espelhada), como num jogo de luta.
const VIDA_JOGADOR := Rect2(40.0, 178.0, 462.0, 44.0)
const VIDA := Rect2(578.0, 178.0, 462.0, 44.0)
## A faixa escura atrás das vidas (legibilidade sobre a torcida).
const FAIXA_DO_ALTO := Rect2(0.0, 0.0, 1080.0, 256.0)
## Os painéis dos socos, dentro do quadro, embaixo (vidro escuro sobre a
## frente do ringue).
const PAINEIS_Y := 1468.0
const PAINEIS_X := 30.0
const PAINEIS_LARGURA := 1020.0
const PAINEIS_ALTURA := 168.0
## As duas colunas de dano, uma de cada lado da moldura.
const BARRA_E := Rect2(24.0, 520.0, 44.0, 760.0)
const BARRA_D := Rect2(1012.0, 520.0, 44.0, 760.0)
## A plaqueta do placar, montada a cavaleiro na borda de baixo.
const PLACA = Rect2(268.0, 1244.0, 544.0, 170.0)
## Quantos degraus tem cada coluna.
const DEGRAUS = 20

const ESCURO = Color("110a1e")
const MADEIRA = Color("2a1a46")
const OURO = Color("ffdc27")
const OURO_ESC = Color("8a6a10")

## O fundo do buraco, desenhado ANTES da imagem: sem câmera 3D (o GLB
## faltando, a janela desligada) o quadro continua sendo um quadro escuro
## e não um retângulo transparente com o cenário aparecendo no meio.
static func fundo(alvo: CanvasItem) -> void:
	alvo.draw_rect(TELA, ESCURO)

## A imagem do mundo 3D. `textura` é a do `Viewport`.
##
## O TREMOR E O ZOOM DO GOLPE MORAM AQUI, e só aqui: a imagem balança
## DENTRO da moldura (recortando a textura), e nada fora do quadro se
## mexe. `desloc` em pixels de tela; `zoom` >= 1.
static func imagem(alvo: CanvasItem, textura: Texture, alpha := 1.0, desloc := Vector2.ZERO, zoom := 1.0) -> void:
	if textura == null:
		return
	if desloc == Vector2.ZERO and zoom <= 1.0001:
		alvo.draw_texture_rect(textura, TELA, false, Color(1, 1, 1, alpha))
		return
	var tam = Vector2(textura.get_size())
	var folga = 1.0 + 2.0 * max(abs(desloc.x) / TELA.size.x, abs(desloc.y) / TELA.size.y) + 0.002
	var z = max(zoom, folga)
	var fonte = tam / z
	var px = tam / TELA.size
	var inicio = (tam - fonte) * 0.5 - desloc * px / z
	inicio = Compat.vclamp(inicio, Vector2.ZERO, tam - fonte)
	alvo.draw_texture_rect_region(textura, TELA, Rect2(inicio, fonte), Color(1, 1, 1, alpha))

## A MOLDURA. Quatro barras e não um retângulo vazado, porque um
## retângulo com contorno grosso pinta o miolo inteiro por baixo da
## imagem — desperdício de preenchimento numa máquina que já é o gargalo.
##
## `pulso` (0 a 1) acende o ouro: é o golpe fazendo a moldura tremer
## junto, como um telão que estremece com o baque.
static func moldura(alvo: CanvasItem, cor: Color, pulso := 0.0) -> void:
	tarjas(alvo, cor, pulso)

## AS TARJAS ZEBRADAS E O FIO DE LUZ, sozinhos. `main.gd` chama de novo
## depois dos efeitos de tela cheia (clarão, pancada, rachadura, K.O.):
## a faixa amarela e preta fica sempre por cima, nítida, e nunca é
## ofuscada nem coberta por eles.
static func tarjas(alvo: CanvasItem, cor: Color, pulso := 0.0) -> void:
	var t = TELA
	var brilho = clamp(pulso, 0.0, 1.0)
	# AS QUATRO TARJAS ZEBRADAS, nas bordas da tela. O amarelo acende um
	# pouco na cor do nível quando o golpe entra.
	var amarelo = OURO.linear_interpolate(cor.lightened(0.35), brilho * 0.45)
	for y0 in [t.position.y, t.end.y - TARJA]:
		_tarja(alvo, Rect2(t.position.x, y0, t.size.x, TARJA), amarelo)
	# Os lados, de cima a baixo: a mesma faixa em pé, a da direita
	# espelhada — as listras descem simétricas.
	var lado = Rect2(t.position.x, t.position.y, TARJA, t.size.y)
	alvo.draw_texture_rect(ZEBRA_V, lado, false, amarelo)
	alvo.draw_texture_rect(ZEBRA_V, Rect2(t.end.x - TARJA, t.position.y, -TARJA, t.size.y), false, amarelo)
	# o fio de luz na borda de dentro das tarjas, na cor do nível
	var fio = Compat.cor(cor, 0.55 + brilho * 0.45)
	var g = 3.0 + brilho * 3.0
	var dentro = t.grow(-TARJA)
	alvo.draw_rect(Rect2(dentro.position.x, dentro.position.y, dentro.size.x, g), fio)
	alvo.draw_rect(Rect2(dentro.position.x, dentro.end.y - g, dentro.size.x, g), fio)
	alvo.draw_rect(Rect2(dentro.position.x, dentro.position.y + g, g, dentro.size.y - g * 2.0), fio)
	alvo.draw_rect(Rect2(dentro.end.x - g, dentro.position.y + g, g, dentro.size.y - g * 2.0), fio)

## Uma tarja zebrada: listras diagonais pretas sobre o amarelo.
##
## UMA IMAGEM, NÃO TRINTA POLÍGONOS. Cada listra era um polígono — e no
## renderizador de compatibilidade cada polígono é uma chamada à placa de
## vídeo: 30 por tarja, duas tarjas, desenhadas duas vezes por quadro
## (120 chamadas, metade de todo o 2D da luta). A faixa agora é pintada
## uma vez, numa imagem com as bordas das listras lisas, e desenhada como
## um retângulo com textura (que o Godot junta com os outros). O branco
## da imagem toma a cor do amarelo do momento (o pulso do golpe).
##
## No Godot 3 a imagem vem pronta (`assets/arena/tarja_zebra.png`, 1080x16,
## pintada fora do jogo com a mesma conta: listras a cada 40 px, preto
## 120a1c, 4x4 amostras por pixel e o fio escuro em cima e embaixo) — o
## jogo não gasta a abertura pintando 17 mil pixels em GDScript.
const ZEBRA = preload("res://assets/arena/tarja_zebra.png")
## A mesma faixa em pé (16 x 1920, a altura da tela), para os lados.
const ZEBRA_V = preload("res://assets/arena/tarja_zebra_v.png")

static func _tarja(alvo: CanvasItem, r: Rect2, amarelo: Color) -> void:
	alvo.draw_texture_rect(ZEBRA, r, false, amarelo)

## AS DUAS COLUNAS DE DANO.
##
## Enchem de baixo para cima e mudam de cor no caminho — âmbar enquanto
## ele aguenta, vermelho quando está por um fio. A cor é o que faz a
## coluna ser lida sem contar degrau: o olho vê "ficou vermelho" antes de
## conseguir avaliar altura nenhuma.
##
## `pisca` faz o degrau da vez piscar, e só ele: uma coluna inteira
## piscando é alarme, e alarme é o que a tela NÃO quer dizer aqui — ela
## quer dizer progresso.
static func barras(alvo: CanvasItem, dano: float, tempo: float) -> void:
	var d = clamp(dano, 0.0, 1.0)
	var cor = Paleta.AMBAR.linear_interpolate(Paleta.VERMELHO, clamp((d - 0.35) / 0.55, 0.0, 1.0))
	var pisca = 0.55 + 0.45 * sin(tempo * 7.0)
	for rect in [BARRA_E, BARRA_D]:
		alvo.draw_rect(rect.grow(4.0), Compat.cor(ESCURO, 0.75))
		var passo = rect.size.y / float(DEGRAUS)
		for i in range(DEGRAUS):
			var fatia = float(i) / float(DEGRAUS)
			var caixa = Rect2(
				rect.position.x, rect.end.y - float(i + 1) * passo + 5.0,
				rect.size.x, passo - 10.0
			)
			if fatia + 1.0 / float(DEGRAUS) <= d:
				alvo.draw_rect(caixa, cor)
				alvo.draw_rect(caixa.grow(3.0), Compat.cor(cor, 0.16))
			elif fatia < d:
				# o degrau em que o dano parou: é ele que pisca
				alvo.draw_rect(caixa, Compat.cor(cor, pisca))
			else:
				alvo.draw_rect(caixa, Color("2a1b43"))

## A BARRA DE VIDA — a leitura de jogo de luta, de longe.
##
## Barra INCLINADA, como nos jogos de luta: um paralelogramo com degradê
## feito por cor de vértice (quatro pontos, custo nenhum para a GPU),
## brilho de vidro na metade de cima e o rastro do golpe atrás.
##
## `vida` é o que sobrou (1 = inteiro); `fantasma` é a vida de um instante
## atrás, que desce devagar e deixa à mostra o pedaço que o soco acabou de
## arrancar. É esse rastro que faz o golpe "doer" na tela.
const INCLINA = 26.0

## As faixas da barra entram num lote (ver `Lote`): a barra inteira, com
## moldura, rastro, vidro e reflexo, sai numa chamada só.
static func _faixa(lote, x0: float, x1: float, y0: float, y1: float, c0: Color, c1: Color, inclina := INCLINA) -> void:
	if x1 - x0 < 1.0:
		return
	var h = y1 - y0
	var d = inclina * h / VIDA.size.y
	lote.quad(Vector2(x0 + d, y0), Vector2(x1 + d, y0), Vector2(x1, y1), Vector2(x0, y1), c0, c1, c1, c0)

## Trecho [a, b] da barra (0 = começo do enchimento) em x de tela.
static func _trecho(espelho: bool, x0: float, larg: float, a: float, b: float) -> Vector2:
	if espelho:
		return Vector2(x0 + larg * (1.0 - b), x0 + larg * (1.0 - a))
	return Vector2(x0 + larg * a, x0 + larg * b)

## `espelho`: a barra enche da DIREITA para a esquerda e inclina para o
## outro lado — a do adversário, de frente para a do jogador.
static func vida(alvo: CanvasItem, fonte: Resource, vida: float, fantasma: float, tempo: float, rotulo: String,
		r: Rect2 = VIDA, espelho := false, cor_base := Color(0, 0, 0, 0)) -> void:
	var v = clamp(vida, 0.0, 1.0)
	var f = clamp(max(fantasma, v), 0.0, 1.0)
	var inc = -INCLINA if espelho else INCLINA
	var larg = r.size.x - INCLINA
	var x0 = r.position.x + (INCLINA if espelho else 0.0)
	var y0 = r.position.y
	var y1 = r.end.y
	var lote = Lote.new()
	# moldura: sombra, aro de ouro e trilho escuro
	_faixa(lote, x0 - 10.0, x0 + larg + 10.0, y0 - 7.0, y1 + 7.0, Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55), inc)
	_faixa(lote, x0 - 6.0, x0 + larg + 6.0, y0 - 4.0, y1 + 4.0, OURO_ESC, OURO, inc)
	_faixa(lote, x0, x0 + larg, y0, y1, Color("0c0615"), Color("1c1030"), inc)
	# o rastro do golpe: vermelho vivo que clareia para o branco
	if f > v:
		var t: Vector2 = _trecho(espelho, x0, larg, v, f)
		_faixa(lote, t.x, t.y, y0, y1, Color("ff3baa"), Color(1, 1, 1, 0.9), inc)
	var cor = Paleta.VERDE.linear_interpolate(Paleta.AMBAR, clamp((1.0 - v) / 0.5, 0.0, 1.0))
	cor = cor.linear_interpolate(Paleta.VERMELHO, clamp((0.5 - v) / 0.35, 0.0, 1.0))
	if cor_base.a > 0.0:
		cor = cor_base.linear_interpolate(Paleta.VERMELHO, clamp((0.45 - v) / 0.35, 0.0, 1.0))
	if v < 0.25:
		cor = cor.linear_interpolate(Color.white, 0.30 * (0.5 + 0.5 * sin(tempo * 12.0)))
	var cheio: Vector2 = _trecho(espelho, x0, larg, 0.0, v)
	var c0 = cor.darkened(0.35)
	var c1 = cor.lightened(0.15)
	_faixa(lote, cheio.x, cheio.y, y0, y1, c1 if espelho else c0, c0 if espelho else c1, inc)
	# vidro: faixa clara na metade de cima e um reflexo correndo
	_faixa(lote, cheio.x, cheio.y, y0, y0 + r.size.y * 0.42, Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.10), inc)
	var brilho = fmod(tempo * 0.45, 1.6) - 0.3
	if brilho > 0.0 and brilho < v:
		var b: Vector2 = _trecho(espelho, x0, larg, brilho, min(brilho + 70.0 / larg, v))
		_faixa(lote, b.x, b.y, y0, y1, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.35), inc)
	lote.descarregar(alvo)
	if fonte != null:
		var base = y0 - 14.0
		var lado_rot = Compat.DIREITA if espelho else Compat.ESQUERDA
		var lado_pct = Compat.ESQUERDA if espelho else Compat.DIREITA
		var xr = r.position.x
		Compat.contorno(alvo, fonte, Vector2(xr, base), rotulo, lado_rot, r.size.x, 26, 8, ESCURO)
		Compat.texto(alvo, fonte, Vector2(xr, base), rotulo, lado_rot, r.size.x, 26, Color.white)
		var pct = "%d%%" % int(round(v * 100.0))
		# o número fica na ponta de dentro (perto do centro do quadro)
		Compat.contorno(alvo, fonte, Vector2(xr, y1 + 34.0), pct, lado_pct, r.size.x, 28, 8, ESCURO)
		Compat.texto(alvo, fonte, Vector2(xr, y1 + 34.0), pct, lado_pct, r.size.x, 28, cor.lightened(0.2))

## A cor que a coluna está mostrando. O texto do medidor usa a mesma,
## senão o número e a barra parecem falar de coisas diferentes.
static func cor_do_dano(dano: float) -> Color:
	return Paleta.AMBAR.linear_interpolate(Paleta.VERMELHO, clamp((clamp(dano, 0.0, 1.0) - 0.35) / 0.55, 0.0, 1.0))
