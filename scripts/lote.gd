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
## Ordem: o lote é desenhado no ponto em que é descarregado. Quem desenha
## texto ou imagem por cima de uma forma descarrega o lote antes.

## A largura da borda lisa, em pixels.
const BORDA := 1.0
## Quanto a corda de um segmento pode se afastar do arco verdadeiro, em
## pixels. Abaixo de meio pixel a faceta não se vê, nem parada.
const ERRO := 0.3
const LADOS_MAXIMOS := 128

enum { _QUAD, _POLIGONO, _LINHA, _CONTORNO, _ARCO, _ANEL, _CIRCULO }
const _SEM_COR := Color(0, 0, 0, -1)

var _pontos = PoolVector2Array()
var _cores = PoolColorArray()
var _indices = PoolIntArray()

## O nome do lote que se lembra do quadro anterior ("" = não se lembra).
var _nome = ""
## As formas pedidas neste quadro, na ordem — o que se compara com o
## quadro anterior.
var _receita: Array = []
## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
##   guardados: nome -> [receita, pontos, cores, índices] do último quadro;
##   voltas: lados -> a volta unitária com esse número de lados.
const _E = {
	"guardados": {},
	"voltas": {},
}

func _init(nome = "") -> void:
	_nome = nome

func vazio() -> bool:
	return _indices.empty() and _receita.empty()

## Manda tudo o que foi juntado numa chamada e esvazia o lote.
func descarregar(ci: CanvasItem) -> void:
	if not _nome.empty():
		var guardado: Array = _E.guardados.get(_nome, [])
		if not guardado.empty() and guardado[0] == _receita:
			# o mesmo desenho do quadro anterior: nada a calcular
			_pontos = guardado[1]
			_cores = guardado[2]
			_indices = guardado[3]
		else:
			for item in _receita:
				_executar(item)
			_E.guardados[_nome] = [_receita, _pontos, _cores, _indices]
		_receita = []
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
		return
	_quad(a, b, c, d, ca, cb, cc, cd)

func retangulo(r: Rect2, cor: Color) -> void:
	quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), cor)

## Polígono CONVEXO cheio, com a borda lisa. `cores` (opcional) dá uma cor
## por vértice; o miolo é a média delas.
func poligono(pts: PoolVector2Array, cor: Color, cores = PoolColorArray(), borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_POLIGONO, pts, cor, cores, borda])
		return
	_poligono(pts, cor, cores, borda)

## Faixa ao longo de uma linha aberta (`pts`), com largura e borda lisa.
func linha_aberta(pts: PoolVector2Array, cor: Color, largura: float, borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_LINHA, pts, cor, largura, borda])
		return
	_linha_aberta(pts, cor, largura, borda)

func linha(a: Vector2, b: Vector2, cor: Color, largura: float) -> void:
	linha_aberta(PoolVector2Array([a, b]), cor, largura)

## Contorno fechado (`pts` sem repetir o primeiro ponto).
func contorno(pts: PoolVector2Array, cor: Color, largura: float, borda = BORDA) -> void:
	if not _nome.empty():
		_receita.append([_CONTORNO, pts, cor, largura, borda])
		return
	_contorno(pts, cor, largura, borda)

## Pedaço de anel de `de` a `ate` (radianos), com espessura.
func arco(centro: Vector2, raio: float, de: float, ate: float, cor: Color, espessura: float) -> void:
	if not _nome.empty():
		_receita.append([_ARCO, centro, raio, de, ate, cor, espessura])
		return
	_arco(centro, raio, de, ate, cor, espessura)

## Anel inteiro.
func anel(centro: Vector2, raio: float, cor: Color, espessura: float) -> void:
	if not _nome.empty():
		_receita.append([_ANEL, centro, raio, cor, espessura])
		return
	_anel(centro, raio, cor, espessura)

## Disco cheio.
func circulo(centro: Vector2, raio: float, cor: Color) -> void:
	if not _nome.empty():
		_receita.append([_CIRCULO, centro, raio, cor])
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
	var i = _pontos.size()
	_pontos.append(a)
	_pontos.append(b)
	_pontos.append(c)
	_pontos.append(d)
	_cores.append(ca)
	_cores.append(cb)
	_cores.append(cc)
	_cores.append(cd)
	_indices.append(i)
	_indices.append(i + 1)
	_indices.append(i + 2)
	_indices.append(i)
	_indices.append(i + 2)
	_indices.append(i + 3)

## Os triângulos entre duas voltas de `lados` pontos que começam em `a` e
## `b` (a faixa de um anel, a borda lisa de um disco).
func _faixa_fechada(a: int, b: int, lados: int) -> void:
	for i in lados:
		var j = i + 1 if i + 1 < lados else 0
		_indices.append(a + i)
		_indices.append(b + i)
		_indices.append(b + j)
		_indices.append(a + i)
		_indices.append(b + j)
		_indices.append(a + j)

## O mesmo, para faixas abertas (sem ligar o último ao primeiro).
func _faixa_aberta(a: int, b: int, pontos: int) -> void:
	for i in pontos - 1:
		_indices.append(a + i)
		_indices.append(b + i)
		_indices.append(b + i + 1)
		_indices.append(a + i)
		_indices.append(b + i + 1)
		_indices.append(a + i + 1)

func _circulo(centro: Vector2, raio: float, cor: Color) -> void:
	var lados = passos(raio)
	var volta = _volta(lados)
	var ic = _pontos.size()
	_pontos.append(centro)
	_pontos.append_array(_levar(volta, raio, centro))
	_pontos.append_array(_levar(volta, raio + BORDA, centro))
	_cores.append_array(_tinta(cor, lados + 1))
	_cores.append_array(_tinta(_transparente(cor), lados))
	var d0 = ic + 1
	for i in lados:
		_indices.append(ic)
		_indices.append(d0 + i)
		_indices.append(d0 + (i + 1 if i + 1 < lados else 0))
	_faixa_fechada(d0, d0 + lados, lados)

func _anel(centro: Vector2, raio: float, cor: Color, espessura: float) -> void:
	var lados = passos(raio + espessura * 0.5)
	var volta = _volta(lados)
	var meia = espessura * 0.5
	var transparente = _transparente(cor)
	var a = _pontos.size()
	for r in [raio + meia + BORDA, raio + meia, max(raio - meia, 0.0), max(raio - meia - BORDA, 0.0)]:
		_pontos.append_array(_levar(volta, r, centro))
	_cores.append_array(_tinta(transparente, lados))
	_cores.append_array(_tinta(cor, lados * 2))
	_cores.append_array(_tinta(transparente, lados))
	for k in 3:
		_faixa_fechada(a + lados * k, a + lados * (k + 1), lados)

func _arco(centro: Vector2, raio: float, de: float, ate: float, cor: Color, espessura: float) -> void:
	var meia = espessura * 0.5
	var lados = passos(raio + meia, (ate - de) / TAU)
	var n = lados + 1
	var transparente = _transparente(cor)
	var a = _pontos.size()
	var raios = [raio + meia + BORDA, raio + meia, max(raio - meia, 0.0), max(raio - meia - BORDA, 0.0)]
	var dirs = PoolVector2Array()
	dirs.resize(n)
	for i in n:
		dirs[i] = polar2cartesian(1.0, lerp(de, ate, float(i) / float(lados)))
	for r in raios:
		_pontos.append_array(_levar(dirs, r, centro))
	_cores.append_array(_tinta(transparente, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(transparente, n))
	for k in 3:
		_faixa_aberta(a + n * k, a + n * (k + 1), n)

func _poligono(pts: PoolVector2Array, cor: Color, cores: PoolColorArray, borda: float) -> void:
	var n = pts.size()
	if n < 3:
		return
	var por_vertice = cores.size() == n
	var centro = Vector2.ZERO
	var cor_centro = Color(0, 0, 0, 0)
	var area = 0.0
	for i in n:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[i + 1 if i + 1 < n else 0]
		centro += p
		area += p.x * q.y - q.x * p.y
		if por_vertice:
			cor_centro += cores[i]
	centro /= float(n)
	if por_vertice:
		cor_centro /= float(n)
	else:
		cor_centro = cor
	# o sentido do polígono decide para que lado a borda cresce
	var sinal = 1.0 if area > 0.0 else -1.0
	var ic = _pontos.size()
	_pontos.append(centro)
	_cores.append(cor_centro)
	var d0 = ic + 1
	_pontos.append_array(pts)
	if por_vertice:
		_cores.append_array(cores)
	else:
		_cores.append_array(_tinta(cor, n))
	for i in n:
		_indices.append(ic)
		_indices.append(d0 + i)
		_indices.append(d0 + (i + 1 if i + 1 < n else 0))
	if borda <= 0.0:
		return
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
		_pontos.append(p + normal * borda * escala)
		_cores.append(_transparente(cores[i] if por_vertice else cor))
	_faixa_fechada(d0, d0 + n, n)

func _linha_aberta(pts: PoolVector2Array, cor: Color, largura: float, borda: float) -> void:
	var n = pts.size()
	if n < 2:
		return
	var meia = largura * 0.5
	var transparente = _transparente(cor)
	var a = _pontos.size()
	# quatro fileiras de pontos ao longo da linha: borda, cor, cor, borda
	var f0 = PoolVector2Array()
	var f1 = PoolVector2Array()
	var f2 = PoolVector2Array()
	var f3 = PoolVector2Array()
	for i in n:
		var dir: Vector2
		if i == 0:
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
	_pontos.append_array(f0)
	_pontos.append_array(f1)
	_pontos.append_array(f2)
	_pontos.append_array(f3)
	_cores.append_array(_tinta(transparente, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(transparente, n))
	for k in 3:
		_faixa_aberta(a + n * k, a + n * (k + 1), n)

func _contorno(pts: PoolVector2Array, cor: Color, largura: float, borda: float) -> void:
	var n = pts.size()
	if n < 3:
		return
	var meia = largura * 0.5
	var transparente = _transparente(cor)
	var a = _pontos.size()
	var f0 = PoolVector2Array()
	var f1 = PoolVector2Array()
	var f2 = PoolVector2Array()
	var f3 = PoolVector2Array()
	for i in n:
		var seguinte: Vector2 = pts[i + 1 if i + 1 < n else 0]
		var anterior: Vector2 = pts[i - 1 if i > 0 else n - 1]
		var normal = (seguinte - anterior).tangent().normalized()
		var p: Vector2 = pts[i]
		f0.append(p + normal * (meia + borda))
		f1.append(p + normal * meia)
		f2.append(p - normal * meia)
		f3.append(p - normal * (meia + borda))
	_pontos.append_array(f0)
	_pontos.append_array(f1)
	_pontos.append_array(f2)
	_pontos.append_array(f3)
	_cores.append_array(_tinta(transparente, n))
	_cores.append_array(_tinta(cor, n * 2))
	_cores.append_array(_tinta(transparente, n))
	for k in 3:
		_faixa_fechada(a + n * k, a + n * (k + 1), n)
