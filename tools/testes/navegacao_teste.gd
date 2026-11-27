extends Node

## TESTE DA NAVEGAÇÃO DA CENTRAL PELO CONTROLE REMOTO (só no PC).
##   godot3 --path . res://tools/testes/navegacao_teste.tscn
## Abre a Central em cada página e, de CADA botão, aperta as quatro setas.
## Aponta o que o técnico chamaria de "desregulado":
##   SENTIDO   a seta levou para o lado contrário (baixo que sobe...);
##   COLUNA    para baixo/cima saiu da coluna havendo um botão nela;
##   PULOU     para baixo/cima pulou uma linha que tinha botão na coluna;
##   LINHA     para o lado mudou de linha;
##   PRESO     havia botão naquela direção e a seta não andou.
## No fim: "NAVEGACAO OK" ou o número de problemas.

var main
var _quadros = 0
const SETAS = {KEY_DOWN: Vector2.DOWN, KEY_UP: Vector2.UP, KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT}
const NOMES = {KEY_DOWN: "BAIXO", KEY_UP: "CIMA", KEY_LEFT: "ESQUERDA", KEY_RIGHT: "DIREITA"}


func _ready() -> void:
	main = load("res://scenes/main.tscn").instance()
	add_child(main)


func _process(_d: float) -> void:
	_quadros += 1
	# alguns quadros para a Central ser desenhada (mede o fim de cada página)
	if _quadros == 30:
		main._toggle_central()
	if _quadros < 40:
		return
	set_process(false)
	var problemas = 0
	for pagina in main.PAGINAS.size():
		main.central_pagina = pagina
		main.central_rolagem = 0.0
		main.update()
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		var lista = main._alvos_da_central()
		for i in lista.size():
			for tecla in SETAS:
				main._foco_central = i
				main._navegar_central_pelo_controle(tecla, false)
				var j = main._foco_central
				var erro = _julgar(lista, i, j, SETAS[tecla])
				if erro != "":
					problemas += 1
					print("NAVEGACAO: pagina %s  %-8s de %s para %s: %s" % [
						main.PAGINAS[pagina], NOMES[tecla], _nome(lista, i), _nome(lista, j), erro])
	main._fechar_central()
	print("NAVEGACAO OK" if problemas == 0 else "NAVEGACAO: %d problemas" % problemas)
	get_tree().quit()


func _r(alvo: Dictionary) -> Rect2:
	var r: Rect2 = alvo["r"]
	var c = main._centro_na_pagina(alvo)
	return Rect2(c - r.size * 0.5, r.size)


func _nome(lista: Array, i: int) -> String:
	var r = _r(lista[i])
	return "(%d,%d %dx%d)" % [r.position.x, r.position.y, r.size.x, r.size.y]


## Está na direção `d` saindo de `a`: o centro andou para lá e a borda de
## lá dele passou da borda de lá do atual.
static func _na_direcao(a: Rect2, b: Rect2, d: Vector2) -> bool:
	var ca = a.get_center()
	var cb = b.get_center()
	if d == Vector2.DOWN:
		return cb.y > ca.y + 4.0 and b.end.y > a.end.y
	if d == Vector2.UP:
		return cb.y < ca.y - 4.0 and b.position.y < a.position.y
	if d == Vector2.RIGHT:
		return cb.x > ca.x + 4.0 and b.end.x > a.end.x
	return cb.x < ca.x - 4.0 and b.position.x < a.position.x


static func _sobrepoe(a: Rect2, b: Rect2, vertical: bool) -> float:
	if vertical:
		return min(a.end.x, b.end.x) - max(a.position.x, b.position.x)
	return min(a.end.y, b.end.y) - max(a.position.y, b.position.y)


## Do atual até a borda de perto / de longe do outro.
static func _perto(a: Rect2, b: Rect2, d: Vector2) -> float:
	if d == Vector2.DOWN:
		return max(0.0, b.position.y - a.end.y)
	return max(0.0, a.position.y - b.end.y)


static func _longe(a: Rect2, b: Rect2, d: Vector2) -> float:
	if d == Vector2.DOWN:
		return b.end.y - a.end.y
	return a.position.y - b.position.y


func _julgar(lista: Array, i: int, j: int, d: Vector2) -> String:
	var a = _r(lista[i])
	var vertical = d.y != 0.0
	var abas = main.PAGINAS.size()
	var na_faixa = []
	var qualquer = false
	for k in lista.size():
		if k == i:
			continue
		var b = _r(lista[k])
		if not _na_direcao(a, b, d):
			continue
		qualquer = true
		if _sobrepoe(a, b, vertical) > 0.0:
			na_faixa.append(k)
	if j == i:
		if vertical:
			return "PRESO" if qualquer else ""
		return "PRESO" if not na_faixa.empty() else ""
	var b = _r(lista[j])
	if not _na_direcao(a, b, d):
		return "SENTIDO"
	if not vertical:
		return "LINHA" if _sobrepoe(a, b, false) <= 0.0 else ""
	# subindo para as abas, a aba da página aberta é a resposta certa
	if j < abas and i >= abas and d == Vector2.UP:
		return "" if j == main.central_pagina else "ABA"
	var dentro = _sobrepoe(a, b, true) > 0.0
	for k in na_faixa:
		var c = _r(lista[k])
		if not dentro and _perto(a, c, d) < _longe(a, b, d):
			return "COLUNA"
		if dentro and _longe(a, c, d) <= _perto(a, b, d):
			return "PULOU"
	return ""
