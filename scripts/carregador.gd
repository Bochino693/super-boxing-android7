extends Node

## A PRIMEIRA TELA: DE PÉ, VIVA E MOSTRANDO O QUANTO FALTA.
##
## Antes o Android abria direto na cena do jogo. Tudo o que ela precisa —
## sons, lutador, arena, fontes, efeitos — era carregado DENTRO do
## `_ready`, na linha do jogo, e enquanto isso a TV mostrava o selo de
## abertura DEITADO (o Android ainda não tinha recebido o giro) e depois
## uma tela parada por vários segundos.
##
## Agora:
##   1. o selo de abertura (boot splash) já vem girado no arquivo, então
##      aparece em pé no monitor vertical desde o primeiro instante;
##   2. esta cena é minúscula: sobe em um piscar, desenha o mesmo selo no
##      mesmo lugar e uma barra de progresso lisa por baixo;
##   3. os recursos pesados carregam em THREADS (`load_threaded_request`),
##      com o progresso real na barra, sem congelar a animação;
##   4. o jogo nasce por baixo desta tela, aquece shaders e texturas
##      coberto, e só então a tela some num esmaecer.

const CENA_DO_JOGO = "res://scenes/main.tscn"
const PASTAS = ["res://assets/"]
const EXTENSOES = ["png", "jpg", "webp", "svg", "wav", "ogg", "mp3", "ttf", "otf", "tres", "res", "glb", "gltf", "fbx"]

## Mesma geometria do jogo: quadro lógico 1080x1920.
const TELA = Vector2(1080.0, 1920.0)
const FUNDO = Color("10091d")
const SELO_CENTRO = Vector2(540.0, 900.0)
const SELO_TAMANHO = 560.0

## Quadros e tempo MÍNIMOS com o jogo já montado por baixo, aquecendo. O
## fim de verdade é o jogo dizer que o ensaio acabou
## (`aquecimento_pronto`): numa TV Box ele leva o tempo que levar, e a
## barra acompanha etapa por etapa em vez de parar num número.
const AQUECER_QUADROS = 20
const AQUECER_SEGUNDOS = 0.6
## Teto de segurança: se por algum motivo o jogo não responder, a tela
## some mesmo assim (melhor jogo um pouco engasgado que tela parada).
const AQUECER_TETO_SEGUNDOS = 45.0

## A BARRA É UM SHADER. Faixas diagonais e um brilho varrendo o TRILHO
## INTEIRO (o fundo da barra, e não só a parte cheia), movidos pelo
## relógio da GPU: a barra continua viva mesmo quando o número demora a
## subir — barra parada é o que dá a impressão de travamento.
## A BARRA É UM MEDIDOR DE ENERGIA DE JOGO DE LUTA: pontas chanfradas,
## moldura de metal com fio de ouro, células que acendem uma a uma, energia
## correndo por dentro e a ponta em brasa. Tudo no shader — sempre em
## movimento, sem custo de processador, mesmo quando o jogo está ocupado
## montando a próxima peça.
const SHADER_BARRA = """
shader_type canvas_item;
uniform float progresso = 0.0;
uniform vec2 tamanho = vec2(720.0, 44.0);
void fragment() {
	vec2 p = UV * tamanho;
	float w = tamanho.x;
	float h = tamanho.y;
	float s = 0.5;
	float esq = p.x - (h - p.y) * s;
	float dir = (w - p.y * s) - p.x;
	float dist = min(min(esq, dir), min(p.y, h - p.y));
	float dentro = smoothstep(0.0, 1.2, dist);
	float moldura = 1.0 - smoothstep(4.5, 5.5, dist);
	float fio = smoothstep(0.2, 1.0, dist) * (1.0 - smoothstep(1.8, 2.8, dist));
	float iw = w - h * s;
	float ix = esq;
	float u = clamp(ix / iw, 0.0, 1.0);
	float listra = step(0.5, fract((ix * 0.5 - p.y) / 16.0 - TIME * 1.2));
	vec3 trilho = vec3(0.07, 0.035, 0.17) * (0.8 + 0.3 * listra);
	float fc = fract(ix / 22.0);
	float celula = smoothstep(0.10, 0.16, fc) * (1.0 - smoothstep(0.94, 0.99, fc));
	float cheio = step(u, progresso);
	vec3 fill = mix(vec3(1.0, 0.12, 0.62), vec3(1.0, 0.84, 0.10), u);
	float brilho_topo = 1.0 - smoothstep(0.0, 0.6, (p.y - 5.0) / (h - 10.0));
	fill *= 0.72 + 0.42 * brilho_topo;
	float onda = 0.5 + 0.5 * sin(ix * 0.055 - TIME * 7.0);
	onda *= onda; onda *= onda; onda *= onda;
	fill += vec3(1.0, 0.92, 0.75) * onda * 0.28;
	vec3 cor = mix(trilho, mix(trilho * 0.6, fill, celula), cheio);
	float ponta = exp(-pow((u - progresso) * iw / 9.0, 2.0)) * step(0.001, progresso);
	cor += vec3(1.0, 0.95, 0.80) * ponta * (0.8 + 0.2 * sin(TIME * 20.0));
	float varre = fract(TIME * 0.35) * 1.6 - 0.3;
	cor += vec3(0.6, 0.5, 1.0) * exp(-pow((u - varre) / 0.05, 2.0)) * 0.22;
	vec3 metal = mix(vec3(0.10, 0.07, 0.20), vec3(0.38, 0.30, 0.55), 1.0 - p.y / h);
	cor = mix(cor, metal, moldura);
	cor = mix(cor, vec3(1.0, 0.82, 0.10), fio * 0.95);
	COLOR = vec4(cor, dentro * COLOR.a);
}
"""
const BARRA_LARGURA = 720.0
const BARRA_ALTURA = 44.0
var _barra: ColorRect = null
var _barra_mat: ShaderMaterial = null
const SUMIR_SEGUNDOS = 0.45

enum Fase { PERMISSOES, CARREGANDO, MONTANDO, AQUECENDO, SUMINDO, PRONTO }

var fase = Fase.PERMISSOES
var _pendentes: Array = []
var _guardados: Array = []
var _total = 0
var _progresso = 0.0      ## real, 0..1
var _mostrado = 0.0       ## o que a barra mostra, correndo atrás do real
var _relogio = 0.0
var _fase_tempo = 0.0
var _quadros_aquecendo = 0
var _jogo: Node = null

var _camada: CanvasLayer
var _tela: Control
var _selo: Texture
var _fonte: Resource
var _fonte_numero: Resource


func _ready() -> void:
	Diario.inicio()
	Diario.marca("CARREGADOR: abriu")
	_configurar_janela()
	_selo = load("res://assets/branding/selo_lazer.png")
	_fonte = _carregar_fonte("res://assets/fonts/SairaCondensed-ExtraBold.ttf")
	_fonte_numero = _carregar_fonte("res://assets/fonts/Bungee-Regular.ttf")

	_camada = CanvasLayer.new()
	_camada.layer = 120
	add_child(_camada)
	_tela = Control.new()
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.rect_size = TELA
	if OS.get_name() == "Android":
		# O MESMO GIRO de `main.gd`: jogo (x, y) -> tela (y, 1080 - x).
		_tela.rect_rotation = -90.0
		_tela.rect_position = Vector2(0.0, 1080.0)
	_tela.connect("draw", self, "_desenhar")
	_camada.add_child(_tela)
	_barra_mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SHADER_BARRA
	_barra_mat.shader = sh
	_barra_mat.set_shader_param("tamanho", Vector2(BARRA_LARGURA, BARRA_ALTURA))
	_barra = ColorRect.new()
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.material = _barra_mat
	_barra.color = Color(1, 1, 1, 1)
	_barra.rect_size = Vector2(BARRA_LARGURA, BARRA_ALTURA)
	_barra.rect_position = Vector2(540.0 - BARRA_LARGURA * 0.5, _topo_da_barra())
	_tela.add_child(_barra)
	if OS.get_name() == "Android":
		Diario.marca("PERMISSOES: inicio")
	else:
		_iniciar_carga()


func _iniciar_carga() -> void:
	_mudar(Fase.CARREGANDO)
	_pedir(CENA_DO_JOGO)
	# Na TV Box de 1 GB (ver `Perfil.PRECARREGAR_TUDO`) só a cena do jogo é
	# carregada aqui: o que ela usa vem junto, e o ensaio do aquecimento
	# passa por todas as telas. Carregar a pasta inteira punha na memória, ao
	# mesmo tempo, imagens que o jogo nunca mostra (os logos em todos os
	# tamanhos) — e o Android derrubava o launcher para abrir espaço.
	if Perfil.PRECARREGAR_TUDO:
		for pasta in PASTAS:
			_listar(pasta)
	_total = _pendentes.size()


# ------------------------------------------------------------ permissões
## AS PERMISSÕES VÊM PRIMEIRO, ANTES DE CARREGAR QUALQUER COISA, uma de
## cada vez: a janela da CÂMERA, espera a resposta; a janela do ARDUINO,
## espera a resposta; só então o jogo carrega. Nesse momento só existe a
## tela do carregador — nada pesado pausado no meio, nada aberto à toa — e
## o jogo, depois, já encontra tudo autorizado: nenhuma janela no meio da
## abertura nem da partida.
enum Perm { CAMERA, ARDUINO, WEBCAM, FIM }
var _perm = Perm.CAMERA
var _perm_pedido = false
var _perm_t0 = 0.0
var _saiu_foco = false
var _voltou_foco = false
var _perm_texto = "VERIFICANDO PERMISSÕES"
var _arduino_tentativas = 0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_FOCUS_OUT, NOTIFICATION_APP_PAUSED:
			_saiu_foco = true
		NOTIFICATION_WM_FOCUS_IN, NOTIFICATION_APP_RESUMED:
			if _saiu_foco:
				_voltou_foco = true

func _proxima_permissao() -> void:
	_perm = int(_perm) + 1
	_perm_pedido = false
	_perm_t0 = _relogio
	_saiu_foco = false
	_voltou_foco = false

## A janela foi respondida? (o jogo saiu de foco e voltou), ou nem abriu.
func _respondida() -> bool:
	var espera = _relogio - _perm_t0
	if _voltou_foco:
		return espera > 0.6
	if not _saiu_foco and espera > 3.0:
		return true   # nenhuma janela apareceu (já decidida antes)
	return espera > 45.0

func _passo_das_permissoes() -> void:
	match _perm:
		Perm.CAMERA:
			if OS.get_granted_permissions().has("android.permission.CAMERA"):
				Diario.marca("PERMISSOES: camera ok")
				_proxima_permissao()
				return
			if not _perm_pedido:
				_perm_pedido = true
				_perm_t0 = _relogio
				_saiu_foco = false
				_voltou_foco = false
				_perm_texto = "AUTORIZE A CÂMERA NA JANELA"
				Diario.marca("PERMISSOES: pedindo camera")
				OS.request_permission("CAMERA")
				return
			if _respondida():
				Diario.marca("PERMISSOES: camera respondida (%s)" % (
					"ok" if OS.get_granted_permissions().has("android.permission.CAMERA") else "sem permissao"))
				_proxima_permissao()
		Perm.ARDUINO:
			_passo_do_arduino()
		Perm.WEBCAM:
			_passo_da_webcam()
		Perm.FIM:
			Diario.marca("PERMISSOES: fim")
			_perm = Perm.FIM
			_iniciar_carga()

func _passo_do_arduino() -> void:
	if not Engine.has_singleton("PunchUsbSerial"):
		_proxima_permissao()
		return
	var plugin = Engine.get_singleton("PunchUsbSerial")
	if _perm_pedido:
		if _respondida():
			# O ARDUINO É A ALMA DO JOGO: sem ele não há ficha, START nem
			# soco. Se a janela foi fechada sem permitir, pergunta DE NOVO
			# (a próxima volta testa a porta e, sem permissão, reabre a
			# janela). Só desiste se nenhuma janela chegou a aparecer.
			var apareceu = _saiu_foco
			Diario.marca("PERMISSOES: arduino respondido (janela %s)" % ("sim" if apareceu else "nao"))
			_perm_pedido = false
			_arduino_tentativas += 1
			if not apareceu or _arduino_tentativas >= 12:
				_proxima_permissao()
				return
			plugin.call("allowPermissionRetry")
			_perm_t0 = _relogio
		return
	# A lista pode vir vazia no primeiro pedido (o plugin novo a monta em
	# segundo plano): tenta por 3 s; sem Arduino ligado, segue.
	var lista = str(plugin.call("listPorts")).strip_edges()
	if lista.empty():
		_perm_texto = "PROCURANDO O ARDUINO"
		if _relogio - _perm_t0 > 3.0:
			Diario.marca("PERMISSOES: nenhum arduino na USB")
			_proxima_permissao()
		return
	var porta = lista.split("\n")[0].strip_edges()
	Diario.marca("PERMISSOES: arduino %s" % porta)
	if bool(plugin.call("openPort", porta, GameDef.SERIAL_BAUD)):
		plugin.call("closePort")
		Diario.marca("PERMISSOES: arduino ok")
		_proxima_permissao()
		return
	var erro = str(plugin.call("getLastError")).to_lower()
	if "autoriz" in erro:
		_perm_pedido = true
		_perm_t0 = _relogio
		_saiu_foco = false
		_voltou_foco = false
		_perm_texto = "ARDUINO: MARQUE \"USAR POR PADRÃO\" E TOQUE OK" if _arduino_tentativas == 0 \
			else "O JOGO PRECISA DO ARDUINO: MARQUE \"USAR POR PADRÃO\" E TOQUE OK"
		Diario.marca("PERMISSOES: pedindo arduino")
		return
	Diario.marca("PERMISSOES: arduino erro (%s)" % erro)
	_proxima_permissao()


## A WEBCAM USB, SE PRECISAR. Quando o Android enxerga a webcam como
## câmera do sistema (o caso comum), a permissão CAMERA já basta. Só quando
## ela aparece apenas como aparelho USB é que o Android pede uma janela a
## mais — e ela vem aqui, no carregamento, e não no meio do jogo.
func _passo_da_webcam() -> void:
	if not Engine.has_singleton("PunchUsbSerial") \
			or not OS.get_granted_permissions().has("android.permission.CAMERA"):
		_proxima_permissao()
		return
	var plugin = Engine.get_singleton("PunchUsbSerial")
	if _perm_pedido:
		if _respondida():
			Diario.marca("PERMISSOES: webcam respondida")
			_proxima_permissao()
		return
	# A contagem das câmeras do sistema sai em segundo plano no plugin:
	# pergunta agora e dá um instante para a resposta chegar.
	var sistema = int(plugin.call("getSystemCameraCount"))
	if sistema > 0:
		Diario.marca("PERMISSOES: webcam pelo sistema (%d)" % sistema)
		_proxima_permissao()
		return
	_perm_texto = "PROCURANDO A CÂMERA"
	if _relogio - _perm_t0 < 1.5:
		return
	var situacao = str(plugin.call("getUsbCameraStatus"))
	if not "AGUARDANDO" in situacao:
		Diario.marca("PERMISSOES: webcam (%s)" % situacao)
		_proxima_permissao()
		return
	_perm_pedido = true
	_perm_t0 = _relogio
	_saiu_foco = false
	_voltou_foco = false
	_perm_texto = "CÂMERA USB: MARQUE A CAIXA E TOQUE OK"
	Diario.marca("PERMISSOES: pedindo webcam usb")
	plugin.call("requestUsbCameraAccess")


func _configurar_janela() -> void:
	if OS.get_name() == "Android":
		Compat.enquadrar(get_tree(), Vector2(1920, 1080))
	else:
		Compat.enquadrar(get_tree(), TELA)


func _carregar_fonte(caminho: String) -> Resource:
	if ResourceLoader.exists(caminho):
		return load(caminho)
	return Compat.fonte_padrao()


## Dentro do APK os arquivos originais não existem: só os `.import` ao
## lado de onde eles estavam. É pelo `.import` que se acha cada recurso.
func _listar(pasta: String) -> void:
	var d = Directory.new()
	if d.open(pasta) != OK:
		return
	d.list_dir_begin(true, true)
	var nome = d.get_next()
	while nome != "":
		if d.current_is_dir():
			_listar(pasta + nome + "/")
		else:
			var original = nome.trim_suffix(".import")
			if original.get_extension().to_lower() in EXTENSOES:
				_pedir(pasta + original)
		nome = d.get_next()
	d.list_dir_end()


func _pedir(caminho: String) -> void:
	if caminho in _pendentes or not ResourceLoader.exists(caminho):
		return
	_pendentes.append(caminho)


func _process(delta: float) -> void:
	_relogio += delta
	_fase_tempo += delta
	match fase:
		Fase.PERMISSOES:
			_passo_das_permissoes()
		Fase.CARREGANDO:
			_acompanhar_carga()
		Fase.MONTANDO:
			# Um quadro com o texto "MONTANDO" já na tela antes do
			# instanciar, que é o único passo que precisa da linha do jogo.
			if _fase_tempo > 0.05:
				_montar_jogo()
		Fase.AQUECENDO:
			_quadros_aquecendo += 1
			var minimo = min(float(_quadros_aquecendo) / AQUECER_QUADROS, _fase_tempo / AQUECER_SEGUNDOS)
			var parte = minimo
			var pronto = minimo >= 1.0
			if _jogo != null and _jogo.has_method("aquecimento_progresso"):
				parte = min(minimo, float(_jogo.aquecimento_progresso()))
				pronto = pronto and bool(_jogo.aquecimento_pronto())
			if _fase_tempo > AQUECER_TETO_SEGUNDOS:
				pronto = true
				parte = 1.0
			_progresso = lerp(0.9, 1.0, clamp(parte, 0.0, 1.0))
			if pronto and _mostrado > 0.995:
				_mudar(Fase.SUMINDO)
				if _jogo != null and _jogo.has_method("soltar_entrada"):
					_jogo.soltar_entrada()
		Fase.SUMINDO:
			_camada_alfa(1.0 - clamp(_fase_tempo / SUMIR_SEGUNDOS, 0.0, 1.0))
			if _fase_tempo >= SUMIR_SEGUNDOS:
				_mudar(Fase.PRONTO)
				_camada.queue_free()
				# O jogo já segura o que usa: o resto do que o carregador
				# guardou sai da memória.
				_guardados.clear()
				set_process(false)
				return
	# A barra corre atrás do progresso real, sem saltos. O passo por quadro
	# tem teto: depois de um quadro demorado ela não pula, continua
	# andando — e o brilho do shader nunca para.
	_mostrado = move_toward(_mostrado, _progresso, min(delta, 0.05) * max(0.35, (_progresso - _mostrado) * 5.0))
	if _barra_mat != null:
		_barra_mat.set_shader_param("progresso", _mostrado)
		_barra.modulate.a = clamp(_relogio / 0.35, 0.0, 1.0)
	_tela.update()


## A CARGA EM PEDAÇOS. O Godot 3 não tem a carga em segundo plano do 4:
## os recursos são lidos um a um e cada quadro gasta no máximo
## `CARGA_MS_POR_QUADRO` nisso — a barra anda e a tela não congela.
const CARGA_MS_POR_QUADRO = 14
var _carga_indice = 0

func _acompanhar_carga() -> void:
	# `ResourceLoader.load` (e não `load_interactive`): o recurso entra no
	# cache com o MESMO nome que o jogo usa. Com o carregamento interativo o
	# Godot 3 o registrava pelo nome interno do cache, e o jogo carregava a
	# mesma imagem DE NOVO — tudo ficava em dobro na memória.
	var inicio = OS.get_ticks_msec()
	while OS.get_ticks_msec() - inicio < CARGA_MS_POR_QUADRO and _carga_indice < _pendentes.size():
		var recurso = ResourceLoader.load(_pendentes[_carga_indice])
		if recurso != null:
			_guardados.append(recurso)
		_carga_indice += 1
	_progresso = 0.85 * (float(_carga_indice) / float(int(max(1, _total))))
	if _carga_indice >= _pendentes.size():
		_mudar(Fase.MONTANDO)
		_progresso = 0.87


func _montar_jogo() -> void:
	var cena: PackedScene = null
	for r in _guardados:
		if r is PackedScene and r.resource_path == CENA_DO_JOGO:
			cena = r
	if cena == null:
		cena = load(CENA_DO_JOGO)
	Diario.marca("MONTANDO: criando a cena do jogo")
	_jogo = cena.instance()
	if "entrada_segurada" in _jogo:
		_jogo.entrada_segurada = true
	if OS.get_name() == "Android" or OS.has_environment("PUNCH_SUBVIEWPORT"):
		_tela_vertical().add_child(_jogo)
	else:
		add_child(_jogo)
	move_child(_camada, get_child_count() - 1)
	Diario.marca("MONTANDO: cena do jogo criada")
	_progresso = 0.9
	_mudar(Fase.AQUECENDO)


## A TELA EM PÉ, DESENHADA INTEIRA E SÓ DEPOIS GIRADA.
##
## Antes o jogo era desenhado JÁ GIRADO na janela deitada: cada letra era
## rasterizada de pé e colada de lado, e em tela com escala fracionária
## (TV Box em 720p, por exemplo) os pixels da letra entortavam — o
## "chuviscado". Agora o jogo inteiro é desenhado num Viewport de
## 1080x1920, sem giro nenhum (as letras saem exatamente como no PC), e o
## que gira é a IMAGEM pronta, uma vez só, no contêiner. Pixel de letra
## nunca mais passa por rotação.
func _tela_vertical() -> Viewport:
	var caixa = ViewportContainer.new()
	caixa.name = "TelaVertical"
	caixa.stretch = false
	caixa.rect_size = TELA
	if OS.get_name() == "Android":
		# jogo (x, y) -> tela (y, 1080 - x), igual ao giro antigo.
		caixa.rect_rotation = -90.0
		caixa.rect_position = Vector2(0.0, 1080.0)
	var vp = Viewport.new()
	vp.name = "Jogo"
	vp.size = Vector2(int(TELA.x), int(TELA.y))
	vp.disable_3d = false
	vp.transparent_bg = false
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	vp.usage = Viewport.USAGE_3D
	caixa.add_child(vp)
	add_child(caixa)
	# Imagem pronta ampliada/girada com filtro (o `texture_filter` do 4).
	vp.get_texture().flags = Texture.FLAG_FILTER
	return vp


func _topo_da_barra() -> float:
	return SELO_CENTRO.y + SELO_TAMANHO * 0.5 + 150.0


func _mudar(nova: int) -> void:
	fase = nova
	_fase_tempo = 0.0
	Diario.marca("CARREGADOR: fase %s" % Fase.keys()[nova])


func _camada_alfa(a: float) -> void:
	_tela.modulate.a = a


func _texto_status() -> String:
	match fase:
		Fase.PERMISSOES:
			return _perm_texto
		Fase.CARREGANDO:
			if _progresso < 0.30:
				return "CARREGANDO SONS E IMAGENS"
			if _progresso < 0.65:
				return "CARREGANDO O LUTADOR"
			return "CARREGANDO A ARENA"
		Fase.MONTANDO:
			return "MONTANDO O JOGO"
		_:
			return "PREPARANDO OS EFEITOS"


# ------------------------------------------------------------- desenho
func _desenhar() -> void:
	var t = _tela
	t.draw_rect(Rect2(Vector2.ZERO, TELA), FUNDO)
	# Luz suave atrás do selo, respirando devagar.
	var pulso = 0.5 + 0.5 * sin(_relogio * 2.2)
	for i in range(6):
		var r = SELO_TAMANHO * (0.42 + float(i) * 0.09)
		Compat.circulo(t, SELO_CENTRO, r, Color(0.55, 0.2, 1.0, (0.020 + 0.010 * pulso) * (1.0 - float(i) / 6.0) * clamp(_relogio / 0.35, 0.0, 1.0)), true, -1.0, true)
	if _selo != null:
		var lado = SELO_TAMANHO
		t.draw_texture_rect(_selo, Rect2(SELO_CENTRO - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)

	# A BARRA é o nó com shader (`_barra`); aqui só o número e o texto.
	var aparece = clamp(_relogio / 0.35, 0.0, 1.0)
	var largura = BARRA_LARGURA
	var topo = _topo_da_barra()
	var caixa = Rect2(Vector2(540.0 - largura * 0.5, topo), Vector2(largura, BARRA_ALTURA))
	# Brilho por baixo da barra, respirando, e o número numa plaqueta.
	for i in range(4):
		var cresce = float(i) * 10.0
		t.draw_rect(caixa.grow(6.0 + cresce), Color(1.0, 0.2, 0.7, (0.05 - float(i) * 0.011) * (0.6 + 0.4 * pulso) * aparece))
	var pct = "%d%%" % int(round(_mostrado * 100.0))
	Compat.contorno(t, _fonte_numero, Vector2(caixa.position.x, topo + 100.0), pct, Compat.CENTRO, largura, 46, 8, Color(0.05, 0.02, 0.12, aparece))
	Compat.texto(t, _fonte_numero, Vector2(caixa.position.x, topo + 100.0), pct, Compat.CENTRO, largura, 46, Compat.cor("ffd014", aparece))
	var pontos = ".".repeat(1 + int(_relogio * 2.5) % 3)
	Compat.texto(t, _fonte, Vector2(caixa.position.x, topo + 150.0), _texto_status() + pontos, Compat.CENTRO, largura, 28, Compat.cor("d9d1ff", 0.9 * aparece))
	# ONDE A ABERTURA ANTERIOR PAROU, se parou: logo aqui, na primeira tela,
	# para dar para fotografar mesmo que o jogo trave de novo adiante.
	var travou = Diario.travou_em()
	if not travou.empty():
		var aviso = Rect2(40.0, 1790.0, 1000.0, 92.0)
		t.draw_rect(aviso, Compat.cor("0c0615", 0.92 * aparece))
		t.draw_rect(aviso, Compat.cor("ffb000", aparece), false, 2.0)
		Compat.texto(t, _fonte, Vector2(aviso.position.x, 1826.0), "A ÚLTIMA ABERTURA PAROU EM:", Compat.CENTRO, aviso.size.x, 24, Compat.cor("ffb000", aparece))
		Compat.texto(t, _fonte, Vector2(aviso.position.x + 12.0, 1864.0), travou, Compat.CENTRO, aviso.size.x - 24.0, 26, Compat.cor("ffffff", aparece))
	Compat.texto(t, _fonte, Vector2(0.0, 1906.0), "BUILD %d  •  %s" % [Versao.NUMERO, Perfil.NOME], Compat.DIREITA, 1060.0, 18, Compat.cor("8f86b8", 0.7 * aparece))


## Retângulo com as pontas totalmente redondas, borda lisa, com gradiente
## horizontal opcional.
func _capsula(r: Rect2, cor: Color, cor_fim: Color = Color(0, 0, 0, 0)) -> void:
	# Mais estreita que alta, as duas pontas redondas se cruzariam e o
	# polígono deixaria de ser válido: nesse caso vira um círculo.
	if r.size.x <= r.size.y + 0.5:
		Compat.circulo(_tela, r.get_center(), r.size.y * 0.5, cor.linear_interpolate(cor_fim, 0.5) if cor_fim.a > 0.0 else cor, true, -1.0, true)
		return
	var raio = r.size.y * 0.5
	var pontos = PoolVector2Array()
	var cores = PoolColorArray()
	var gradiente = cor_fim.a > 0.0
	var LADOS = 20
	for i in range(LADOS + 1):
		var a = PI * 0.5 + PI * float(i) / LADOS
		pontos.append(Vector2(r.position.x + raio, r.position.y + raio) + polar2cartesian(1.0, a) * raio)
	for i in range(LADOS + 1):
		var a = -PI * 0.5 + PI * float(i) / LADOS
		pontos.append(Vector2(r.end.x - raio, r.position.y + raio) + polar2cartesian(1.0, a) * raio)
	for p in pontos:
		var k = clamp((p.x - r.position.x) / max(1.0, r.size.x), 0.0, 1.0)
		cores.append(cor.linear_interpolate(cor_fim, k) if gradiente else cor)
	_tela.draw_polygon(pontos, cores)
	var fecho = pontos.duplicate()
	fecho.append(pontos[0])
	var cores_fecho = cores.duplicate()
	cores_fecho.append(cores[0])
	_tela.draw_polyline_colors(fecho, cores_fecho, 1.0, true)
