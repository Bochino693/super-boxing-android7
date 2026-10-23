class_name PunchFX
extends Reference

## EFEITOS 2D: faíscas, brasas, raios, estilhaços, poeira, confete e as
## ondas de choque.
##
## A PLACA DE VÍDEO CALCULA E DESENHA (build 121). Cada disparo é UMA
## malha de partículas cujo movimento inteiro sai do shader de vértice
## (ver `scripts/fx/emissor_gpu.gd`): uma chamada à placa por explosão, e
## nenhum laço por partícula — nem no script, nem no motor. Até a build 120
## eram `CPUParticles2D`, que no OpenGL ES 2.0 do Godot 3 desenham CADA
## partícula com uma chamada própria: o soco mais forte chegava a umas 400
## chamadas por quadro só de efeito, e a festa do TOP 20 a mais de 250.
##
## Cada tipo tem uma textura própria em alta resolução (`assets/fx`,
## gerada por `tools/gerar_fx.py`) e um pequeno banco de emissores usados
## em rodízio; nada é alocado depois do arranque. Duas camadas: FRENTE
## (impacto e ondas, por cima da tela) e FUNDO (confete do ranking, por
## trás dos cartões, para a festa nunca cobrir a informação).

const Emissor = preload("res://scripts/fx/emissor_gpu.gd")

enum Tipo { FAISCA, BRASA, CHUVA, RAIO, ESTILHACO, POEIRA, CONFETE }

## Por tipo: textura, partículas por disparo no máximo (`n`), quantos
## emissores no banco, vida (s), gravidade aparente (px/s²: o quanto a
## partícula cai depois de perder a velocidade), desaceleração (px/s²),
## escala (e como ela muda do nascer ao sumir), soma de luz, alinhar o
## rastro à velocidade, giro (graus/s) e o ponto em que começa a sumir.
## As faixas de escala são as que o `CPUParticles2D` do Godot 3 sorteava
## de fato (ele puxa o sorteio de `scale_amount` na direção de 1,0): a
## mesma explosão de antes, do mesmo tamanho.
const RECEITAS = {
	Tipo.FAISCA: {"tex": "faisca", "n": 96, "banco": 5, "vida": 0.85, "grav": 40.0,
		"amort": 520.0, "escala": [1.05, 1.10], "curva": [1.0, 0.35], "soma": true, "alinha": true},
	Tipo.BRASA: {"tex": "faisca", "n": 192, "banco": 5, "vida": 1.45, "grav": 470.0,
		"amort": 260.0, "escala": [1.18, 1.35], "curva": [1.0, 0.35], "soma": true, "alinha": true},
	Tipo.CHUVA: {"tex": "faisca", "n": 96, "banco": 3, "vida": 2.3, "grav": 540.0,
		"amort": 20.0, "escala": [1.05, 1.10], "curva": [1.0, 0.35], "soma": true, "alinha": true},
	Tipo.RAIO: {"tex": "raio", "n": 32, "banco": 3, "vida": 1.2, "grav": 200.0,
		"amort": 380.0, "escala": [0.42, 0.64], "giro": 300.0},
	Tipo.ESTILHACO: {"tex": "estilhaco", "n": 16, "banco": 2, "vida": 1.6, "grav": 1090.0,
		"amort": 60.0, "escala": [0.30, 0.63], "giro": 300.0},
	Tipo.POEIRA: {"tex": "fumaca", "n": 16, "banco": 4, "vida": 1.5, "grav": -10.0,
		"amort": 180.0, "escala": [0.65, 0.84], "curva": [0.55, 1.25]},
	Tipo.CONFETE: {"tex": "confete", "n": 32, "banco": 3, "vida": 3.4, "grav": 370.0,
		"amort": 150.0, "escala": [0.72, 0.84], "giro": 260.0, "quadros": 8, "sumir": [0.85, 1.0]},
}
## A chuva de confete do TOP 20 (contínua, por trás dos cartões).
const CHUVA_DE_CONFETE_N = 176
## Quantas ondas de choque podem estar no ar ao mesmo tempo.
const ONDAS = 8

var vigia: Desempenho = null

var _frente: Node2D = null
var _fundo: Node2D = null
var _bancos = {}          # Tipo -> Array de emissores
var _proximo = {}         # Tipo -> índice do próximo emissor
var _chuva_confete = null
var _chuva_confete_ate = 0.0
var _brisas = {}          # nome -> emissor (poeira contínua)
var _brisa_estado = {}    # nome -> [área, cor, por_segundo] já aplicados
var _ondas: Array = []    # nós das ondas de choque
var _proxima_onda = 0
var _relogio = 0.0
var _aquecendo = 0

## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
const _E = {
	"_texturas": {},
	"_anel": null,
	"_shader_onda": null,
}


static func _textura(nome: String) -> Texture:
	if not _E._texturas.has(nome):
		_E._texturas[nome] = load("res://assets/fx/%s.png" % nome)
	return _E._texturas[nome]


## Cria as camadas e todos os emissores. Chamar uma vez, no `_ready` de
## quem vai exibir os efeitos.
func montar(pai: CanvasItem, z_frente := 1, z_fundo := -1) -> void:
	if _frente != null:
		return
	_frente = _camada(pai, "EfeitosFrente", z_frente)
	_fundo = _camada(pai, "EfeitosFundo", z_fundo)
	for tipo in RECEITAS:
		var banco: Array = []
		for i in range(int(RECEITAS[tipo]["banco"])):
			# O confete é só do ranking: mora no fundo, atrás dos cartões.
			banco.append(_emissor(tipo, int(RECEITAS[tipo]["n"]), _fundo if tipo == Tipo.CONFETE else _frente))
		_bancos[tipo] = banco
		_proximo[tipo] = 0
	_chuva_confete = _emissor(Tipo.CONFETE, CHUVA_DE_CONFETE_N, _fundo)
	for i in range(ONDAS):
		_ondas.append(_nova_onda())


static func _camada(pai: CanvasItem, nome: String, z: int) -> Node2D:
	var camada = Node2D.new()
	camada.name = nome
	Compat.z(camada, z)
	pai.add_child(camada)
	return camada


func _emissor(tipo: int, n: int, camada: Node2D):
	var r: Dictionary = RECEITAS[tipo]
	var e = Emissor.new()
	camada.add_child(e)
	e.preparar(n, _textura(str(r["tex"])), bool(r.get("soma", false)))
	var tex: Texture = e.textura
	var quadros = int(r.get("quadros", 1))
	var sumir: Array = r.get("sumir", [0.7, 0.85])
	var curva: Array = r.get("curva", [1.0, 1.0])
	var giro = deg2rad(float(r.get("giro", 0.0)))
	# O que não muda de um disparo para o outro vai uma vez só.
	e.disparar_config({
		"vida": float(r["vida"]), "vida_aleatoria": 0.45,
		"grav": float(r["grav"]), "amort": float(r["amort"]),
		"esc_min": float(r["escala"][0]), "esc_max": float(r["escala"][1]),
		"esc_ini": float(curva[0]), "esc_fim": float(curva[1]),
		"tam": Vector2(tex.get_width() / float(quadros), tex.get_height()),
		"alinhar": 1.0 if bool(r.get("alinha", false)) else 0.0,
		"giro_ini": TAU if giro > 0.0 else 0.0, "giro_vel": giro,
		"fade_ponto": float(sumir[0]), "fade_alfa": float(sumir[1]),
		"quadros": float(quadros),
		# o papel picado vira de 3 a 7 vezes por vida, oito quadros cada
		"quadros_vel": 5.0 * float(quadros) / float(r["vida"]) if quadros > 1 else 0.0,
	})
	e.set_meta("tipo", tipo)
	e.set_meta("n", n)
	return e


# ------------------------------------------------------------ controle
func limpar() -> void:
	for banco in _bancos.values():
		for e in banco:
			e.apagar()
	if _chuva_confete != null:
		_chuva_confete.apagar()
	for o in _ondas:
		o.set_meta("vivo", false)
		o.visible = false


func vivo() -> bool:
	for o in _ondas:
		if o.visible:
			return true
	return false


## A frente acompanha o tremor e o zoom da tela, como o resto do desenho.
func seguir(origem: Vector2, escala: Vector2) -> void:
	if _frente != null:
		_frente.position = origem
		_frente.scale = escala


func atualizar(delta: float) -> void:
	_relogio += delta
	for banco in _bancos.values():
		for e in banco:
			if e.ativo:
				e.avancar(delta)
	if _chuva_confete != null and _chuva_confete.ativo:
		if _chuva_confete.emitindo() and _relogio > _chuva_confete_ate:
			_chuva_confete.parar()
		_chuva_confete.avancar(delta)
	for e in _brisas.values():
		if e.ativo:
			e.avancar(delta)
	for o in _ondas:
		if o.visible:
			_avancar_onda(o, delta)
	if _aquecendo > 0:
		_aquecendo -= 1
		if _aquecendo == 0:
			limpar()
			_frente.modulate = Color.white
			_fundo.modulate = Color.white


## Dispara um disparo de cada tipo quase invisível: compila os shaders e
## sobe as texturas antes do primeiro soco.
func aquecer() -> void:
	if _frente == null:
		return
	_frente.modulate = Color(1, 1, 1, 0.004)
	_fundo.modulate = Color(1, 1, 1, 0.004)
	var meio = Vector2(540.0, 960.0)
	for tipo in RECEITAS:
		_disparar(tipo, meio, 2, Color.white, 300.0)
	chuva_de_confete(1080.0, 10, [Color.white])
	onda(meio, 10.0, 100.0, Color.white)
	_aquecendo = 4


# ------------------------------------------------------------ disparo
func _quantas(pedido: int) -> int:
	return pedido if vigia == null else vigia.quantas(pedido)


func _proximo_emissor(tipo: int):
	var banco: Array = _bancos[tipo]
	var i: int = _proximo[tipo]
	_proximo[tipo] = (i + 1) % banco.size()
	return banco[i]


## Os uniformes das cores: `cores` (uma sorteada por partícula, até seis)
## ou nenhuma (todas tingidas por `cor`).
static func _cores(params: Dictionary, cor: Color, cores: Array) -> void:
	params["tinta"] = cor
	params["n_cores"] = float(min(cores.size(), 6))
	for i in range(min(cores.size(), 6)):
		params["cor%d" % i] = cores[i]


## Configura e solta um emissor do tipo, no ponto. `cor` tinge; se
## `cores` vier, cada partícula sorteia uma delas.
func _disparar(
	tipo: int, onde: Vector2, quantidade: int, cor: Color, forca: float,
	cores: Array = [], direcao := Vector2.ZERO, abertura := 180.0, espalhar := 0.0,
	retangulo := Vector2.ZERO, vel_min := 0.30
) -> void:
	if _frente == null:
		return
	var e = _proximo_emissor(tipo)
	var n = int(e.get_meta("n"))
	var params = {
		"quantos": clamp(float(_quantas(quantidade)) / float(n), 0.0, 1.0),
		"vel_max": forca, "vel_min": vel_min,
		"dir_ang": (direcao if direcao != Vector2.ZERO else Vector2.RIGHT).angle(),
		"abertura": deg2rad(abertura),
		"espalhar": espalhar, "retangulo": retangulo,
	}
	_cores(params, cor, cores)
	e.position = onde
	e.disparar(params, float(RECEITAS[tipo]["vida"]) + 0.05)


# --------------------------------------------------- a API dos efeitos
## A ONDA DE CHOQUE: um anel que abre e some. É uma malha fixa (raio 1),
## guardada na placa; por quadro só mudam o raio e a cor (ver `_nova_onda`).
func onda(centro: Vector2, raio_inicial: float, raio_final: float, cor: Color, _espessura: float = 8.0, duracao: float = 0.7) -> void:
	if _ondas.empty():
		return
	var o = _ondas[_proxima_onda]
	_proxima_onda = (_proxima_onda + 1) % _ondas.size()
	o.position = centro
	o.set_meta("tempo", 0.0)
	o.set_meta("duracao", max(0.05, duracao))
	o.set_meta("raio_inicial", raio_inicial)
	o.set_meta("raio_final", raio_final)
	o.set_meta("cor", cor)
	o.visible = true
	_avancar_onda(o, 0.0)


func faiscas(centro: Vector2, quantidade: int, cor: Color, forca: float = 1000.0) -> void:
	_disparar(Tipo.FAISCA, centro, quantidade, cor, forca)


func explosao(centro: Vector2, quantidade: int, cores: Array, forca: float = 1100.0) -> void:
	_disparar(Tipo.BRASA, centro, quantidade, Color.white, forca, cores, Vector2.ZERO, 180.0, 40.0)


func raios(centro: Vector2, quantidade: int, cor: Color, forca: float = 780.0) -> void:
	_disparar(Tipo.RAIO, centro, quantidade, cor, forca)


func estilhacos(centro: Vector2, quantidade: int, cor: Color) -> void:
	_disparar(Tipo.ESTILHACO, centro, quantidade, cor, 420.0, [], Vector2.UP, 55.0, 90.0)


func poeira(centro: Vector2, quantidade: int, cor: Color, alcance: float = 420.0) -> void:
	_disparar(Tipo.POEIRA, centro, quantidade, cor, alcance, [], Vector2.ZERO, 180.0, 40.0)


## Brasas caindo do teto, espalhadas pela largura da tela.
func chuva_de_brasas(largura: float, quantidade: int, cores: Array) -> void:
	_disparar(Tipo.CHUVA, Vector2(largura * 0.5, -120.0), quantidade, Color.white, 900.0, cores,
		Vector2.DOWN, 8.0, 0.0, Vector2(largura * 0.5, 120.0), 480.0 / 900.0)


## Canhão de confete: sai do ponto para cima, abre e cai girando.
func confete(centro: Vector2, quantidade: int, cores: Array, forca: float = 900.0) -> void:
	_disparar(Tipo.CONFETE, centro, quantidade, Color.white, forca * 1.25, cores, Vector2.UP, 24.0, 30.0)


## Chuva contínua de confete (por trás dos cartões). Cada chamada mantém
## a chuva ligada por mais um instante; parar de chamar é parar a chuva.
func chuva_de_confete(largura: float, _quantidade: int, cores: Array, intensidade := 1.0) -> void:
	var e = _chuva_confete
	if e == null:
		return
	_chuva_confete_ate = _relogio + 0.45
	if e.emitindo():
		return
	if e.ativo:
		# parou há pouco e as últimas ainda caem: volta a soltar
		e.continuar()
		return
	var escala = clamp(intensidade, 0.35, 1.4)
	var params = {
		"quantos": 1.0, "vida": 4.6, "grav": 140.0, "amort": 8.0,
		"vel_max": 220.0 * escala, "vel_min": 90.0 / 220.0,
		"dir_ang": Vector2.DOWN.angle(), "abertura": deg2rad(18.0),
		"espalhar": 0.0, "retangulo": Vector2(560.0, 30.0),
	}
	_cores(params, Color.white, cores)
	e.position = Vector2(largura * 0.5, -60.0)
	e.disparar(params, 4.6, true)


func fogos(centro: Vector2, cores: Array) -> void:
	var cor: Color = cores[randi() % cores.size()]
	onda(centro, 6.0, rand_range(120.0, 210.0), Compat.cor(cor, 0.55), 5.0, 0.55)
	faiscas(centro, 40, cor, 780.0)


## Desliga (e esconde) uma brisa já criada, sem mexer no resto dela: na
## luta a poeira do palco fica atrás da arena e não precisa ser desenhada.
func pausar_brisa(nome: String, pausada: bool) -> void:
	var e = _brisas.get(nome)
	if e == null:
		return
	if pausada:
		e.apagar()
	elif not e.ativo:
		_ligar_brisa(nome)


## Poeira ambiente contínua (a respiração do cenário). Um emissor por
## nome, criado na primeira chamada; `ligada` liga e desliga. Pode ser
## chamada a cada quadro: só mexe no emissor quando algo mudou.
func brisa(nome: String, area: Rect2, cor: Color, por_segundo := 3.0, ligada := true) -> void:
	if _fundo == null:
		return
	var e = _brisas.get(nome)
	if e == null:
		e = _emissor(Tipo.POEIRA, 16, _fundo)
		_brisas[nome] = e
	var estado = [area, cor, por_segundo]
	if _brisa_estado.get(nome) != estado:
		_brisa_estado[nome] = estado
		e.position = area.get_center()
		if e.ativo:
			_ligar_brisa(nome)
	if ligada and not e.emitindo():
		if e.ativo:
			e.continuar()
		else:
			_ligar_brisa(nome)
	elif not ligada and e.emitindo():
		e.parar()


func _ligar_brisa(nome: String) -> void:
	var e = _brisas[nome]
	var estado: Array = _brisa_estado.get(nome, [Rect2(), Color.white, 3.0])
	var area: Rect2 = estado[0]
	var params = {
		"quantos": clamp(ceil(float(estado[2]) * 3.2) / 16.0, 0.0, 1.0),
		"vida": 3.2, "grav": -15.0, "amort": 6.0,
		"vel_max": 70.0, "vel_min": 20.0 / 70.0,
		"dir_ang": Vector2.UP.angle(), "abertura": deg2rad(35.0),
		"espalhar": 0.0, "retangulo": area.size * 0.5,
	}
	_cores(params, estado[1], [])
	e.position = area.get_center()
	e.disparar(params, 3.2, true)


# ------------------------------------------------------------ as ondas
## Anel de raio 1 feito de triângulos, com borda que some para dentro e
## para fora — só os pixels do anel são pintados (um quadrado com
## textura de anel preencheria a tela inteira a cada onda).
static func _malha_do_anel() -> Dictionary:
	if _E._anel != null:
		return _E._anel
	var LADOS = 96
	var RAIOS = [0.86, 0.955, 1.0]
	# o degradê da borda: u = 0 por dentro, 0,5 no meio (opaco), 1 por fora
	var US = [0.0, 0.5, 1.0]
	var v = PoolVector2Array()
	var uv = PoolVector2Array()
	var idx = PoolIntArray()
	for i in range(LADOS):
		var dir = polar2cartesian(1.0, float(i) / float(LADOS) * TAU)
		for k in range(3):
			v.append(dir * float(RAIOS[k]))
			uv.append(Vector2(float(US[k]), 0.5))
	for i in range(LADOS):
		var a = i * 3
		var b = ((i + 1) % LADOS) * 3
		for k in range(2):
			for n in [a + k, b + k, b + k + 1, a + k, b + k + 1, a + k + 1]:
				idx.append(n)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var malha = ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], 0)
	# alfa 0 -> 1 -> 0 ao longo de u
	var LARGURA = 64
	var img = Image.new()
	img.create(LARGURA, 2, false, Image.FORMAT_RGBA8)
	img.lock()
	for x in range(LARGURA):
		var u = (float(x) + 0.5) / float(LARGURA)
		var a = clamp(1.0 - abs(u * 2.0 - 1.0), 0.0, 1.0)
		for y in range(2):
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	var sh = Shader.new()
	sh.code = """shader_type canvas_item;
uniform float raio = 1.0;
uniform vec4 cor : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
void vertex() {
	VERTEX *= raio;
}
void fragment() {
	COLOR = texture(TEXTURE, UV) * cor;
}
"""
	_E._anel = {"malha": malha, "tex": tex, "shader": sh}
	return _E._anel


## Um nó por onda: a malha do anel é desenhada uma vez, e o raio e a cor
## mudam pelo material.
func _nova_onda() -> Node2D:
	var anel = _malha_do_anel()
	var o = Node2D.new()
	o.name = "Onda"
	var mat = ShaderMaterial.new()
	mat.shader = anel["shader"]
	o.material = mat
	o.visible = false
	_frente.add_child(o)
	VisualServer.canvas_item_set_custom_rect(o.get_canvas_item(), true, Rect2(-4000, -4000, 8000, 8000))
	# desenhado pelo sinal `draw`: o Godot refaz o desenho do nó toda vez
	# que ele aparece, e o anel tem de voltar junto
	o.connect("draw", self, "_desenhar_onda", [o])
	o.set_meta("vivo", false)
	return o


func _desenhar_onda(o: Node2D) -> void:
	var anel = _malha_do_anel()
	o.draw_mesh(anel["malha"], anel["tex"])


func _avancar_onda(o: Node2D, delta: float) -> void:
	var tempo: float = float(o.get_meta("tempo")) + delta
	var duracao: float = o.get_meta("duracao")
	if tempo >= duracao:
		o.visible = false
		return
	o.set_meta("tempo", tempo)
	var t = tempo / duracao
	var cor: Color = o.get_meta("cor")
	cor.a *= (1.0 - t) * (1.0 - t)
	var mat: ShaderMaterial = o.material
	mat.set_shader_param("raio", lerp(float(o.get_meta("raio_inicial")), float(o.get_meta("raio_final")), ease(t, 0.35)))
	mat.set_shader_param("cor", cor)
