extends Reference

## MUITAS FORMAS, UMA CHAMADA SÓ. (Carregado com `preload` por quem usa:
## `const Lote = preload("res://scripts/lote.gd")`.)
##
## No Godot (o 4.6 da versão PRO e o 3.6 desta, OpenGL ES 2.0) só os
## retângulos com textura são juntados num desenho; CADA polígono, linha
## lisa, arco e círculo vira uma chamada separada à placa de vídeo. Na luta isso dava
## 229 chamadas por quadro só no 2D: a faixa zebrada (30 listras por
## tarja), as barras de vida, os cartões e o medidor redondo, peça por
## peça. Num PC não se nota; na TV Box cada chamada custa tempo do
## processador e do driver da Mali — e era esse tempo que deixava a luta
## lenta.
##
## Aqui as formas viram triângulos coloridos num vetor só, e
## `descarregar` manda tudo numa chamada. A BORDA LISA é feita na própria
## geometria: uma faixa de um pixel em volta de cada forma, da cor dela
## até transparente — o mesmo efeito do `antialiased` do Godot, sem a
## chamada extra.
##
## E POUCA CONTA POR QUADRO (build 208). A primeira versão do lote (206)
## tirou as chamadas da placa de vídeo e pôs a conta no processador: cada
## vértice e cada triângulo passava por uma função do script, os círculos
## tinham até 192 lados, e a luta montava uns 7.000 triângulos por quadro
## em GDScript — 4,5 ms num Xeon, algo como 25 ms no processador da TV
## Box, quase o quadro inteiro de 30 por segundo. Agora:
##   • os lados de cada curva vêm do ERRO que se vê: no máximo 0,3 pixel
##     entre a corda e o arco verdadeiro (um círculo de raio 170 fica com
##     ~50 lados, e não 192 — a diferença não aparece);
##   • os vértices entram direto nos vetores, sem uma chamada por ponto, e
##     o círculo e o anel saem de uma volta unitária guardada, levada ao
##     lugar por uma transformação feita no motor (não no script);
##   • um lote com NOME (`Lote.new("medidor")`) guarda o que desenhou: se
##     no quadro seguinte as formas pedidas forem as mesmas — o placar
##     parado, o cartão de um soco já feito —, ele reaproveita os vetores
##     prontos e não calcula nada.
##
##
## E NA TV BOX, O QUE NÃO MUDOU NÃO É REFEITO (build 116). Numa forma que
## anima, quase sempre só muda a COR (o cartão que pulsa) ou só a POSIÇÃO
## (o gomo que acende, o arco que enche) — e o mais caro em GDScript é a
## lista de triângulos (uma conta por índice: milhares por quadro). Um lote
## com nome guarda três coisas do quadro anterior e refaz só o que precisa:
##   • a mesma forma, outra cor: refaz só as cores (cópias feitas no motor);
##   • os mesmos tipos e números de pontos (a "topologia"), outra posição:
##     refaz pontos e cores e REAPROVEITA os triângulos;
##   • qualquer outra coisa: refaz tudo.
## Por isso o arco usa sempre o número de lados da volta inteira: crescendo
## (o medidor enchendo), ele muda de posição, mas não de topologia.
##
## Ordem: o lote é desenhado no ponto em que é descarregado. Quem desenha
## texto ou imagem por cima de uma forma descarrega o lote antes.

## A largura da borda lisa, em pixels.
const BORDA := 1.0
## Quanto a corda de um segmento pode se afastar do arco verdadeiro, em
## pixels. Abaixo de meio pixel a faceta não se vê, nem parada.
const ERRO := 0.3
## O teto de lados de uma volta. Era 128; só os anéis enormes dos efeitos
## (o túnel do impacto, de até 1300 px de raio) chegavam lá, e cada lado a
## mais é um punhado de números copiados do script para o motor a cada
## quadro (build 120). Com 72, o anel de 1300 px erra 1,2 px — num anel
## que voa translúcido pela tela.
const LADOS_MAXIMOS := 72

enum { _QUAD, _POLIGONO, _LINHA, _CONTORNO, _ARCO, _ANEL, _CIRCULO, _LEQUE, _SEGMENTOS, _FAIXA }
## O que refazer de cada forma (ver o topo): tudo, pontos e cores, ou só
## as cores.
enum { _TUDO, _SEM_TRIANGULOS, _SO_CORES }
const _SEM_COR := Color(0, 0, 0, -1)

var _pontos = PoolVector2Array()
var _cores = PoolColorArray()
var _indices = PoolIntArray()
var _modo = _TUDO

## O nome do lote que se lembra do quadro anterior ("" = não se lembra).
var _nome = ""
## As formas pedidas neste quadro, na ordem — o que se compara com o
## quadro anterior —, e as mesmas sem a cor (`_forma`) e só com o tipo e o
## número de pontos (`_topologia`).
var _receita: Array = []
var _forma: Array = []
var _topologia: Array = []
## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
##   guardados: nome -> [receita, forma, topologia, pontos, cores, índices]
##   do último quadro;
##   voltas: lados -> a volta unitária com esse número de lados.
##   nativo: as formas avulsas (`disco`, `aro`, `traco`, `borda`) vão
##   direto às funções do Godot (para medir; ver `PUNCH_LOTE_NATIVO`).
const _E = {
	"guardados": {},
	"voltas": {},
	"nativo": null,
	"formas": {},
}

## AS FORMAS AVULSAS JÁ FEITAS: [tipo e medidas] -> pontos. Quase tudo na
## tela fica parado de um quadro para o outro (os ícones, as placas, os
## aros da abertura) e só muda de cor; achar a forma pronta custa menos que
## refazer os pontos. Com muitas formas novas (uma animação), a lista é
## esvaziada e recomeça.
static func _forma(chave: Array) -> PoolVector2Array:
	return _E.formas.get(chave, PoolVector2Array())

static func _guardar(chave: Array, pontos: PoolVector2Array) -> void:
	if _E.formas.size() > 700:
		_E.formas.clear()
	_E.formas[chave] = pontos

static func _nativo() -> bool:
	if _E.nativo == null:
		_E.nativo = OS.get_environment("PUNCH_LOTE_NATIVO") == "1"
	return _E.nativo

func _init(nome = "") -> void:
	_nome = nome

func vazio() -> bool:
	return _indices.empty() and _receita.empty()

## A forma montada (pontos e triângulos), sem desenhar: para quem guarda
## uma forma fixa e troca só as cores a cada quadro (os gomos do medidor).
func forma_pronta() -> Array:
	return [_pontos, _indices]

## Manda tudo o que foi juntado numa chamada e esvazia o lote.
func descarregar(ci: CanvasItem) -> void:
	if not _nome.empty():
		var g: Array = _E.guardados.get(_nome, [])
		if not g.empty() and g[0] == _receita:
			# o mesmo desenho do quadro anterior: nada a calcular
			_pontos = g[3]
			_cores = g[4]
			_indices = g[5]
		else:
			_modo = _TUDO
			if not g.empty() and g[1] == _forma:
				_modo = _SO_CORES
			elif not g.empty() and g[2] == _topologia:
				_modo = _SEM_TRIANGULOS
			for item in _receita:
				_executar(item)
			if _modo == _SO_CORES:
				_pontos = g[3]
			if _modo != _TUDO:
				_indices = g[5]
			_modo = _TUDO
			_E.guardados[_nome] = [_receita, _forma, _topologia, _pontos, _cores, _indices]
		_receita = []
		_forma = []
		_topologia = []
	if not _indices.empty():
		VisualServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _indices, _pontos, _cores)
	_pontos = PoolVector2Array()
	_cores = PoolColorArray()
	_indices = PoolIntArray()

## Quantos lados uma curva de `raio` precisa para o erro ficar abaixo de
## `ERRO`; `fatia` é a fração da volta (1 = círculo inteiro).
static func passos(raio: float, fatia := 1.0) -> int:
	var r = max(raio, ERRO * 2.0)
	var por_volta = PI / acos(1.0 - ERRO / r)
	return int(clamp(int(ceil(por_volta * abs(fatia))), 4 if fatia < 1.0 else 12, LADOS_MAXIMOS))

static func _volta(lados: int) -> PoolVector2Array:
	var v: PoolVector2Array = _E.voltas.get(lados, PoolVector2Array())
	if v.empty():
		v.resize(lados)
		for i in lados:
			v[i] = polar2cartesian(1.0, float(i) / float(lados) * TAU)
		_E.voltas[lados] = v
	return v

## `quantas` cópias da cor. O Godot 3 não tem `fill`: dobra o vetor até
## passar do tamanho (poucas chamadas, nenhuma por elemento) e corta.
static func _tinta(cor: Color, quantas: int) -> PoolColorArray:
	var c = PoolColorArray([cor])
	while c.size() < quantas:
		c.append_array(c)
	c.resize(quantas)
	return c

## `volta` levada ao `centro` com raio `r`, na conta do motor.
static func _levar(volta: PoolVector2Array, r: float, centro: Vector2) -> PoolVector2Array:
	return Transform2D(Vector2(r, 0.0), Vector2(0.0, r), centro).xform(volta)

static func _transparente(cor: Color) -> Color:
	return Color(cor.r, cor.g, cor.b, 0.0)

# ------------------------------------------------------------- formas
## Quadrilátero com uma cor por canto (degradê de graça), sem borda lisa.
func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb := _SEM_COR, cc := _SEM_COR, cd := _SEM_COR) -> void:
	if cb.a < 0.0:
		cb = ca
	if cc.a < 0.0:
		cc = cb
	if cd.a < 0.0:
		cd = ca
	if not _nome.empty():
		_receita.append([_QUAD, a, b, c, d, ca, cb, cc, cd])
		_forma.append([_QUAD, a, b, c, d])
		_topologia.append(_QUAD)
		return
	_quad(a, b, c, d, ca, cb, cc, cd)

func retangulo(r: Rect2, cor: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), cor)

## Polígono CONVEXO cheio, com a borda lisa. `cores` (opcional) dá uma cor
## por vértice; o miolo é a média delas.
func poligono(pts: PoolVector2Array, cor: Color, cores = PoolColorArray(), borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_POLIGONO, pts, cor, cores, borda])
		_forma.append([_POLIGONO, pts, borda])
		_topologia.append([_POLIGONO, pts.size(), borda > 0.0])
		return
	_poligono(pts, cor, cores, borda)

## Faixa ao longo de uma linha aberta (`pts`), com largura e borda lisa.
func linha_aberta(pts: PoolVector2Array, cor: Color, largura: float, borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_LINHA, pts, cor, largura, borda])
		_forma.append([_LINHA, pts, largura, borda])
		_topologia.append([_LINHA, pts.size()])
		return
	_linha_aberta(pts, cor, largura, borda)

func linha(a: Vector2, b: Vector2, cor: Color, largura: float) -> void:
	linha_aberta(PoolVector2Array([a, b]), cor, largura)

## MUITOS TRAÇOS SOLTOS DE UMA VEZ, da mesma cor e largura (os riscos e
## os raios do impacto): o traço `i` vai de `inicios[i]` a `fins[i]`. Um
## laço curto por traço e os triângulos já prontos — eram vinte chamadas
## de `traco`, cada uma com o seu desenho na placa. Só em lote SEM nome
## (é coisa que muda a cada quadro). Com `cores` (uma por traço), cada um
## tem a sua; senão todos têm `cor`.
func segmentos(inicios: PoolVector2Array, fins: PoolVector2Array, cor: Color, largura: float,
		cores_dos_tracos := PoolColorArray()) -> void:
	var n = int(min(inicios.size(), fins.size()))
	var cada = cores_dos_tracos.size() >= n
	if n == 0 or (cor.a <= 0.0 and not cada):
		return
	if cada:
		for i in n:
			var c: Color = cores_dos_tracos[i]
			var tc = _transparente(c)
			_cores.append_array(PoolColorArray([tc, tc, c, c, c, c, tc, tc]))
	else:
		var t = _transparente(cor)
		var cores = PoolColorArray([t, t, cor, cor, cor, cor, t, t])
		while cores.size() < n * 8:
			cores.append_array(cores)
		cores.resize(n * 8)
		_cores.append_array(cores)
	var meia = max(largura, 1.0) * 0.5
	var pts = PoolVector2Array()
	pts.resize(n * 8)
	for i in n:
		var a: Vector2 = inicios[i]
		var b: Vector2 = fins[i]
		var normal = (b - a).tangent().normalized()
		var fora = normal * (meia + BORDA)
		var dentro = normal * meia
		var k = i * 8
		pts[k] = a + fora
		pts[k + 1] = b + fora
		pts[k + 2] = a + dentro
		pts[k + 3] = b + dentro
		pts[k + 4] = a - dentro
		pts[k + 5] = b - dentro
		pts[k + 6] = a - fora
		pts[k + 7] = b - fora
	var inicio = _pontos.size()
	_pontos.append_array(pts)
	_indices.append_array(_deslocado(_SEGMENTOS, n, inicio))

## UM ANEL DE EFEITO: sem a borda lisa e com lados para errar até 1,5 px
## (`ERRO_LEVE`). Para os anéis translúcidos que atravessam a tela em
## décimos de segundo (o túnel do impacto) — lá a faceta e o serrilhado
## não se veem, e o anel cheio custava quatro voltas de pontos e o triplo
## de triângulos. Só em lote SEM nome.
const ERRO_LEVE := 1.5

func anel_leve(centro: Vector2, raio: float, cor: Color, espessura: float) -> void:
	if raio <= 0.0 or cor.a <= 0.0:
		return
	var meia = espessura * 0.5
	var r = max(raio + meia, ERRO_LEVE * 2.0)
	var lados = int(clamp(ceil(PI / acos(1.0 - ERRO_LEVE / r)), 12, LADOS_MAXIMOS))
	var volta = _volta(lados)
	_cores.append_array(_tinta(cor, lados * 2))
	var inicio = _pontos.size()
	_pontos.append_array(_levar(volta, raio + meia, centro))
	_pontos.append_array(_levar(volta, max(raio - meia, 0.0), centro))
	_indices.append_array(_deslocado(_FAIXA, lados, inicio))

## UM POLÍGONO GUARDADO, LEVADO PELA TRANSFORMAÇÃO `xf` (o estrelão que
## cresce): a borda lisa é calculada uma vez, no tamanho original, e a
## cada quadro só se aplica a transformação — no motor. A borda cresce
## junto com a forma. Só em lote SEM nome.
func poligono_movel(pts: PoolVector2Array, xf: Transform2D, cor: Color) -> void:
	var n = pts.size()
	if n < 3 or cor.a <= 0.0:
		return
	_cores.append(cor)
	_cores.append_array(_tinta(cor, n))
	_cores.append_array(_tinta(_transparente(cor), n))
	var inicio = _pontos.size()
	_pontos.append_array(xf.xform(_pontos_do_poligono(pts, BORDA)))
	_indices.append_array(_deslocado(_CIRCULO, n, inicio))

## O contorno fechado de um polígono guardado, levado por `xf` (a linha
## engrossa junto com a forma). Só em lote SEM nome.
func contorno_movel(pts: PoolVector2Array, xf: Transform2D, cor: Color, largura: float) -> void:
	var n = pts.size()
	if n < 3 or cor.a <= 0.0:
		return
	var chave = [_CONTORNO, pts, largura]
	var faixa = _forma(chave)
	if faixa.empty():
		faixa = _pontos_de_faixa(pts, max(largura, 1.0), BORDA, true)
		_guardar(chave, faixa)
	var t = _transparente(cor)
	_cores.append_array(_tinta(t, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(t, n))
	var inicio = _pontos.size()
	_pontos.append_array(xf.xform(faixa))
	_indices.append_array(_deslocado(_CONTORNO, n, inicio))

## Contorno fechado (`pts` sem repetir o primeiro ponto).
func contorno(pts: PoolVector2Array, cor: Color, largura: float, borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_CONTORNO, pts, cor, largura, borda])
		_forma.append([_CONTORNO, pts, largura, borda])
		_topologia.append([_CONTORNO, pts.size()])
		return
	_contorno(pts, cor, largura, borda)

## Pedaço de anel de `de` a `ate` (radianos), com espessura.
func arco(centro: Vector2, raio: float, de: float, ate: float, cor: Color, espessura: float) -> void:
	if not _nome.empty():
		_receita.append([_ARCO, centro, raio, de, ate, cor, espessura])
		_forma.append([_ARCO, centro, raio, de, ate, espessura])
		_topologia.append([_ARCO, _pontos_do_arco(de, ate, passos(raio + espessura * 0.5))])
		return
	_arco(centro, raio, de, ate, cor, espessura)

## Anel inteiro.
func anel(centro: Vector2, raio: float, cor: Color, espessura: float) -> void:
	if not _nome.empty():
		_receita.append([_ANEL, centro, raio, cor, espessura])
		_forma.append([_ANEL, centro, raio, espessura])
		_topologia.append([_ANEL, passos(raio + espessura * 0.5)])
		return
	_anel(centro, raio, cor, espessura)

## Disco cheio.
func circulo(centro: Vector2, raio: float, cor: Color) -> void:
	if not _nome.empty():
		_receita.append([_CIRCULO, centro, raio, cor])
		_forma.append([_CIRCULO, centro, raio])
		_topologia.append([_CIRCULO, passos(raio)])
		return
	_circulo(centro, raio, cor)

## Contorno arredondado num retângulo (a pílula dos cartões, os painéis).
static func pontos_arredondados(rect: Rect2, raio: float) -> PoolVector2Array:
	var r = min(raio, min(rect.size.x, rect.size.y) * 0.5)
	var pontos = PoolVector2Array()
	var cantos = [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	var lados = passos(r, 0.25)
	for c in cantos:
		var meio: Vector2 = c[0]
		var a0: float = c[1]
		for i in range(lados + 1):
			pontos.append(meio + polar2cartesian(r, a0 + float(i) / float(lados) * PI * 0.5))
	return pontos

# ------------------------------------------------------ a montagem
## Cada forma abaixo anexa pontos, cores e triângulos — e, conforme
## `_modo`, pula o que o quadro anterior já deixou pronto (ver o topo). A
## ordem das cores é sempre a mesma dos pontos.
func _executar(item: Array) -> void:
	match int(item[0]):
		_QUAD:
			_quad(item[1], item[2], item[3], item[4], item[5], item[6], item[7], item[8])
		_POLIGONO:
			_poligono(item[1], item[2], item[3], item[4])
		_LINHA:
			_linha_aberta(item[1], item[2], item[3], item[4])
		_CONTORNO:
			_contorno(item[1], item[2], item[3], item[4])
		_ARCO:
			_arco(item[1], item[2], item[3], item[4], item[5], item[6])
		_ANEL:
			_anel(item[1], item[2], item[3], item[4])
		_CIRCULO:
			_circulo(item[1], item[2], item[3])

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_cores.append_array(PoolColorArray([ca, cb, cc, cd]))
	if _modo == _SO_CORES:
		return
	var i = _pontos.size()
	_pontos.append_array(PoolVector2Array([a, b, c, d]))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(PoolIntArray([i, i + 1, i + 2, i, i + 2, i + 3]))

func _circulo(centro: Vector2, raio: float, cor: Color) -> void:
	var lados = passos(raio)
	_cores.append_array(_tinta(cor, lados + 1))
	_cores.append_array(_tinta(_transparente(cor), lados))
	if _modo == _SO_CORES:
		return
	var volta = _volta(lados)
	var ic = _pontos.size()
	_pontos.append(centro)
	_pontos.append_array(_levar(volta, raio, centro))
	_pontos.append_array(_levar(volta, raio + BORDA, centro))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(_deslocado(_CIRCULO, lados, ic))

func _anel(centro: Vector2, raio: float, cor: Color, espessura: float) -> void:
	var lados = passos(raio + espessura * 0.5)
	var transparente = _transparente(cor)
	_cores.append_array(_tinta(transparente, lados))
	_cores.append_array(_tinta(cor, lados * 2))
	_cores.append_array(_tinta(transparente, lados))
	if _modo == _SO_CORES:
		return
	var volta = _volta(lados)
	var meia = espessura * 0.5
	var a = _pontos.size()
	for r in [raio + meia + BORDA, raio + meia, max(raio - meia, 0.0), max(raio - meia - BORDA, 0.0)]:
		_pontos.append_array(_levar(volta, r, centro))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(_deslocado(_ANEL, lados, a))

## O arco usa SEMPRE os lados da volta inteira (e não os do pedaço): o arco
## que cresce muda de posição, mas não de topologia (ver o topo).
func _arco(centro: Vector2, raio: float, de: float, ate: float, cor: Color, espessura: float) -> void:
	var meia = espessura * 0.5
	var lados = passos(raio + meia)
	var n = _pontos_do_arco(de, ate, lados)
	var transparente = _transparente(cor)
	_cores.append_array(_tinta(transparente, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(transparente, n))
	if _modo == _SO_CORES:
		return
	var a = _pontos.size()
	var dirs = _direcoes_do_arco(de, ate, lados)
	for r in [raio + meia + BORDA, raio + meia, max(raio - meia, 0.0), max(raio - meia - BORDA, 0.0)]:
		_pontos.append_array(_levar(dirs, r, centro))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(_deslocado(_ARCO, n, a))

## O ARCO ANDA NOS PASSOS DA VOLTA INTEIRA, e não em `lados` fatias do
## próprio tamanho (build 120). As direções saem de uma cópia da volta
## unitária guardada (cortada no motor, `resize`) mais a ponta exata,
## giradas por uma transformação — e não de um seno e um cosseno por
## vértice no script, que era o grosso do custo do medidor enchendo e do
## anel do cartão. Um arco curto fica com poucos pontos; o inteiro, com os
## da volta. A topologia (quantos pontos) muda enquanto ele cresce, mas
## os triângulos de cada tamanho já estão guardados (`_deslocado`).
static func _pontos_do_arco(de: float, ate: float, lados: int) -> int:
	return int(min(floor(min(abs(ate - de), TAU) / TAU * lados), lados - 1)) + 2

static func _direcoes_do_arco(de: float, ate: float, lados: int) -> PoolVector2Array:
	var abertura = min(abs(ate - de), TAU)
	var d: PoolVector2Array = _volta(lados)
	d.resize(_pontos_do_arco(de, ate, lados) - 1)
	d.append(polar2cartesian(1.0, abertura))
	var x = polar2cartesian(1.0, de)
	var y = Vector2(-x.y, x.x) * (1.0 if ate >= de else -1.0)
	return Transform2D(x, y, Vector2.ZERO).xform(d)

func _poligono(pts: PoolVector2Array, cor: Color, cores: PoolColorArray, borda: float) -> void:
	var n = pts.size()
	if n < 3:
		return
	var por_vertice = cores.size() == n
	var cor_centro = cor
	if por_vertice:
		cor_centro = Color(0, 0, 0, 0)
		for i in n:
			cor_centro += cores[i]
		cor_centro /= float(n)
	_cores.append(cor_centro)
	if por_vertice:
		_cores.append_array(cores)
	else:
		_cores.append_array(_tinta(cor, n))
	if borda > 0.0:
		if por_vertice:
			for i in n:
				_cores.append(_transparente(cores[i]))
		else:
			_cores.append_array(_tinta(_transparente(cor), n))
	if _modo == _SO_CORES:
		return
	var ic = _pontos.size()
	_pontos.append_array(_pontos_do_poligono(pts, borda))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(_deslocado(_CIRCULO if borda > 0.0 else _LEQUE, n, ic))

## O centro, o contorno e a borda lisa de um polígono — guardados, porque
## os mesmos polígonos (a pílula do cartão, a plaqueta) voltam a cada quadro
## e a conta da borda é um laço por vértice no script.
static func _pontos_do_poligono(pts: PoolVector2Array, borda: float) -> PoolVector2Array:
	var chave = [_POLIGONO, pts, borda]
	var prontos = _forma(chave)
	if not prontos.empty():
		return prontos
	var n = pts.size()
	var centro = Vector2.ZERO
	var area = 0.0
	for i in n:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1 if i + 1 < n else 0]
		centro += p
		area += p.x * q.y - q.x * p.y
	centro /= float(n)
	# o sentido do polígono decide para que lado a borda cresce
	var sinal = 1.0 if area > 0.0 else -1.0
	prontos = PoolVector2Array([centro])
	prontos.append_array(pts)
	if borda > 0.0:
		for i in n:
			var p: Vector2 = pts[i]
			var anterior: Vector2 = pts[i - 1 if i > 0 else n - 1]
			var seguinte: Vector2 = pts[i + 1 if i + 1 < n else 0]
			var n1 = (p - anterior).tangent().normalized() * -sinal
			var n2 = (seguinte - p).tangent().normalized() * -sinal
			var normal = n1 + n2
			var tam = normal.length()
			normal = normal / tam if tam > 0.0001 else n1
			# o canto vivo não estica a borda para longe
			var escala = clamp(1.0 / max(normal.dot(n1), 0.35), 1.0, 2.5)
			prontos.append(p + normal * borda * escala)
	_guardar(chave, prontos)
	return prontos

## As quatro fileiras de pontos de uma faixa (borda, cor, cor, borda) e as
## cores delas; `fechada` liga o último ponto ao primeiro.
func _faixa_de_linha(pts: PoolVector2Array, cor: Color, largura: float, borda: float, fechada: bool) -> void:
	var n = pts.size()
	var transparente = _transparente(cor)
	_cores.append_array(_tinta(transparente, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(transparente, n))
	if _modo == _SO_CORES:
		return
	var a = _pontos.size()
	_pontos.append_array(_pontos_de_faixa(pts, largura, borda, fechada))
	if _modo == _SEM_TRIANGULOS:
		return
	_indices.append_array(_deslocado(_CONTORNO if fechada else _LINHA, n, a))

## As quatro fileiras (fora, cor, cor, fora) ao longo de `pts`.
static func _pontos_de_faixa(pts: PoolVector2Array, largura: float, borda: float, fechada: bool) -> PoolVector2Array:
	var n = pts.size()
	var meia = largura * 0.5
	var f0 = PoolVector2Array()
	var f1 = PoolVector2Array()
	var f2 = PoolVector2Array()
	var f3 = PoolVector2Array()
	for i in n:
		var dir: Vector2
		if fechada:
			dir = pts[i + 1 if i + 1 < n else 0] - pts[i - 1 if i > 0 else n - 1]
		elif i == 0:
			dir = pts[1] - pts[0]
		elif i == n - 1:
			dir = pts[n - 1] - pts[n - 2]
		else:
			dir = pts[i + 1] - pts[i - 1]
		var normal = dir.tangent().normalized()
		var p: Vector2 = pts[i]
		f0.append(p + normal * (meia + borda))
		f1.append(p + normal * meia)
		f2.append(p - normal * meia)
		f3.append(p - normal * (meia + borda))
	f0.append_array(f1)
	f0.append_array(f2)
	f0.append_array(f3)
	return f0

func _linha_aberta(pts: PoolVector2Array, cor: Color, largura: float, borda: float) -> void:
	if pts.size() >= 2:
		_faixa_de_linha(pts, cor, largura, borda, false)

func _contorno(pts: PoolVector2Array, cor: Color, largura: float, borda: float) -> void:
	if pts.size() >= 3:
		_faixa_de_linha(pts, cor, largura, borda, true)


# ================================================== formas avulsas
## LINHA, CÍRCULO E ARCO QUE SE JUNTAM (build 116, para a TV Box).
##
## No Godot 3 (OpenGL ES 2.0) os polígonos seguidos são juntados numa
## chamada à placa de vídeo, mas `draw_line`, `draw_circle`, `draw_arc` e
## `draw_polyline` NÃO: cada um é uma chamada sozinha (o diagnóstico de
## lotes do Godot mostra "l", "c" e "PL" fora dos lotes). A abertura tinha
## dezenas delas por quadro — os aros dos ícones, as bordas lisas dos
## polígonos (`Traco`), os raios, as luzes da moldura —, e na TV Box cada
## chamada é tempo do processador e do driver da Mali.
##
## As funções abaixo desenham a mesma coisa como POLÍGONO (com a borda
## lisa feita na geometria, como o resto do lote), e o Godot as junta com
## os polígonos vizinhos. Os triângulos de cada forma vêm de um molde
## guardado por número de lados (os índices começam em 0 em cada
## chamada), então nada é contado ponto a ponto em GDScript: os pontos
## saem de `Transform2D.xform` e as cores de `_tinta`, as duas no motor.

## Os moldes de triângulos: [tipo, lados] -> PoolIntArray (feitos uma vez).
static func _molde(tipo: int, lados: int) -> PoolIntArray:
	var chave = tipo * 100000 + lados
	var m: PoolIntArray = _E.guardados.get(chave, PoolIntArray())
	if not m.empty():
		return m
	m = PoolIntArray()
	match tipo:
		_CIRCULO:
			# o centro, a volta de dentro e a volta da borda
			for i in lados:
				m.append(0)
				m.append(1 + i)
				m.append(1 + (i + 1 if i + 1 < lados else 0))
			m.append_array(_faixa(1, 1 + lados, lados, true))
		_ANEL, _CONTORNO:
			# `lados` pontos por volta, quatro voltas
			for k in 3:
				m.append_array(_faixa(lados * k, lados * (k + 1), lados, true))
		_ARCO, _LINHA:
			# `lados` aqui é o número de PONTOS ao longo da faixa aberta
			for k in 3:
				m.append_array(_faixa(lados * k, lados * (k + 1), lados, false))
		_LEQUE:
			# só o leque, para o polígono sem borda lisa
			for i in lados:
				m.append(0)
				m.append(1 + i)
				m.append(1 + (i + 1 if i + 1 < lados else 0))
		_FAIXA:
			# uma volta só entre duas fileiras (o anel sem borda lisa)
			m.append_array(_faixa(0, lados, lados, true))
		_SEGMENTOS:
			# `lados` traços de 8 pontos: as três faixas de cada um
			for i in lados:
				var b = i * 8
				for k in 3:
					var f = b + k * 2
					m.append_array(PoolIntArray([f, f + 2, f + 3, f, f + 3, f + 1]))
	_E.guardados[chave] = m
	return m

## OS TRIÂNGULOS JÁ NO LUGAR (build 120). O molde acima começa do vértice
## 0; dentro de um lote a forma começa em `a`. Somar `a` a cada índice era
## um laço no script por forma e por quadro (milhares de contas na luta) —
## e como cada tela pede as mesmas formas na mesma ordem a cada quadro, a
## lista deslocada é guardada e só copiada (no motor) para o lote.
const _DESLOCADOS = {}

static func _deslocado(tipo: int, lados: int, a: int) -> PoolIntArray:
	if lados >= 8192:
		return _somar(_molde(tipo, lados), a)
	var chave = (a * 16 + tipo) * 8192 + lados
	var m = _DESLOCADOS.get(chave)
	if m != null:
		return m
	m = _somar(_molde(tipo, lados), a)
	if _DESLOCADOS.size() > 1200:
		_DESLOCADOS.clear()
	_DESLOCADOS[chave] = m
	return m

static func _somar(molde: PoolIntArray, a: int) -> PoolIntArray:
	var m = PoolIntArray(molde)
	if a != 0:
		for i in m.size():
			m[i] += a
	return m

static func _faixa(a: int, b: int, n: int, fechada: bool) -> PoolIntArray:
	var m = PoolIntArray()
	for i in (n if fechada else n - 1):
		var j = (i + 1 if i + 1 < n else 0) if fechada else i + 1
		m.append(a + i)
		m.append(b + i)
		m.append(b + j)
		m.append(a + i)
		m.append(b + j)
		m.append(a + j)
	return m

static func _desenhar(ci: CanvasItem, indices: PoolIntArray, pontos: PoolVector2Array, cores: PoolColorArray) -> void:
	VisualServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, pontos, cores)

## Disco cheio com a borda lisa (o `draw_circle`).
static func disco(ci: CanvasItem, centro: Vector2, raio: float, cor: Color) -> void:
	if raio <= 0.0 or cor.a <= 0.0:
		return
	if _nativo():
		ci.draw_circle(centro, raio, cor)
		return
	var chave = [_CIRCULO, centro, raio]
	var pontos = _forma(chave)
	var lados: int
	if pontos.empty():
		lados = passos(raio)
		var volta = _volta(lados)
		pontos = PoolVector2Array([centro])
		pontos.append_array(_levar(volta, raio, centro))
		pontos.append_array(_levar(volta, raio + BORDA, centro))
		_guardar(chave, pontos)
	else:
		lados = (pontos.size() - 1) / 2
	var cores = _tinta(cor, lados + 1)
	cores.append_array(_tinta(_transparente(cor), lados))
	_desenhar(ci, _molde(_CIRCULO, lados), pontos, cores)

## Anel inteiro (`de`/`ate` omitidos) ou pedaço de anel, com espessura e
## borda lisa (o `draw_arc`).
static func aro(ci: CanvasItem, centro: Vector2, raio: float, cor: Color, espessura: float, de := 0.0, ate := TAU) -> void:
	if raio <= 0.0 or cor.a <= 0.0 or espessura <= 0.0 or de == ate:
		return
	if _nativo():
		ci.draw_arc(centro, raio, de, ate, passos(raio, (ate - de) / TAU), cor, espessura, true)
		return
	var inteiro = abs(ate - de) >= TAU - 0.0001
	var chave = [_ANEL, centro, raio, espessura] if inteiro else [_ARCO, centro, raio, espessura, de, ate]
	var pontos = _forma(chave)
	if pontos.empty():
		var meia = espessura * 0.5
		var raios = [raio + meia + BORDA, raio + meia, max(raio - meia, 0.0), max(raio - meia - BORDA, 0.0)]
		if inteiro:
			var volta = _volta(passos(raio + meia))
			for r in raios:
				pontos.append_array(_levar(volta, r, centro))
		else:
			var lados = passos(raio + meia, (ate - de) / TAU)
			var unidade = _pedaco_de_volta(abs(ate - de), lados)
			var sentido = 1.0 if ate >= de else -1.0
			var x = polar2cartesian(1.0, de)
			var y = Vector2(-x.y, x.x) * sentido
			for r in raios:
				pontos.append_array(Transform2D(x * r, y * r, centro).xform(unidade))
		_guardar(chave, pontos)
	var transparente = _transparente(cor)
	var n = pontos.size() / 4
	var indices = _molde(_ANEL, n) if inteiro else _molde(_ARCO, n)
	var cores = _tinta(transparente, n)
	cores.append_array(_tinta(cor, n * 2))
	cores.append_array(_tinta(transparente, n))
	_desenhar(ci, indices, pontos, cores)

## Os pontos de um pedaço de volta unitária de 0 a `abertura` (guardados:
## o pedaço que gira é o mesmo, só girado pela transformação).
static func _pedaco_de_volta(abertura: float, lados: int) -> PoolVector2Array:
	var chave = "%d|%.4f" % [lados, abertura]
	var v: PoolVector2Array = _E.voltas.get(chave, PoolVector2Array())
	if v.empty():
		if _E.voltas.size() > 400:
			_E.voltas.clear()
		v.resize(lados + 1)
		for i in lados + 1:
			v[i] = polar2cartesian(1.0, abertura * float(i) / float(lados))
		_E.voltas[chave] = v
	return v

## Segmento de reta com largura e borda lisa (o `draw_line`).
static func traco(ci: CanvasItem, a: Vector2, b: Vector2, cor: Color, largura := 1.0) -> void:
	if cor.a <= 0.0 or a == b:
		return
	if _nativo():
		ci.draw_line(a, b, cor, largura, true)
		return
	var normal = (b - a).tangent().normalized()
	var meia = max(largura, 1.0) * 0.5
	var fora = normal * (meia + BORDA)
	var dentro = normal * meia
	var t = _transparente(cor)
	_desenhar(ci, _molde(_LINHA, 2), PoolVector2Array([a + fora, b + fora, a + dentro, b + dentro, a - dentro, b - dentro, a - fora, b - fora]),
		PoolColorArray([t, t, cor, cor, cor, cor, t, t]))

## Linha de vários pontos, aberta ou fechada, com borda lisa (o
## `draw_polyline`).
static func borda(ci: CanvasItem, pts: PoolVector2Array, cor: Color, largura := 1.0, fechada := false) -> void:
	var n = pts.size()
	if n < 2 or cor.a <= 0.0 or (fechada and n < 3):
		return
	if _nativo():
		var p = PoolVector2Array(pts)
		if fechada:
			p.append(pts[0])
		ci.draw_polyline(p, cor, largura, true)
		return
	var chave = [_CONTORNO if fechada else _LINHA, pts, largura]
	var pontos = _forma(chave)
	if pontos.empty():
		pontos = _pontos_de_faixa(pts, max(largura, 1.0), BORDA, fechada)
		_guardar(chave, pontos)
	var t = _transparente(cor)
	var cores = _tinta(t, n)
	cores.append_array(_tinta(cor, n * 2))
	cores.append_array(_tinta(t, n))
	_desenhar(ci, _molde(_CONTORNO if fechada else _LINHA, n), pontos, cores)
