extends Reference

## A TELA DA MÁQUINA: EM PÉ, NUMA TV DEITADA (build 121).
## (Carregado com `preload`: `const TelaGirada = preload("res://scripts/tela_girada.gd")`.)
##
## O jogo é vertical (1080x1920) e a TV Box entrega uma imagem deitada
## (1920x1080) — a TV é que fica de pé no gabinete. Há dois jeitos de
## desenhar:
##
##   DIRETO: o jogo inteiro é desenhado já girado 90° na janela. Com a TV
##   em 1920x1080 cada pixel do jogo cai num pixel da tela (o giro de 90°
##   é exato) e a placa de vídeo pinta a tela UMA vez por quadro.
##
##   PELA TELA INTERMEDIÁRIA: o jogo é desenhado em pé numa imagem à parte
##   e só a imagem pronta é girada. Na Mali-450 isso custava duas passadas
##   de tela cheia a mais por quadro (escrever a imagem de 2 milhões de
##   pixels e lê-la de novo) — até a build 120 era sempre assim. Continua
##   sendo o caminho quando a TV não está em 1920x1080 (uma TV Box em
##   720p): girar e reduzir ao mesmo tempo entortava as letras (o
##   "chuviscado"). Nesse caso a imagem intermediária é feita JÁ no tamanho
##   da TV, e não em 1080x1920 para depois encolher.

const TELA = Vector2(1080.0, 1920.0)
const JANELA = Vector2(1920.0, 1080.0)


## A máquina mostra o jogo girado (TV Box), ou o PC em teste
## (`PUNCH_GIRADO=1`)?
static func girada() -> bool:
	return OS.get_name() == "Android" or OS.has_environment("PUNCH_GIRADO")


## Precisa da tela intermediária? Só com a TV fora de 1920x1080 (ou
## pedida para teste com `PUNCH_SUBVIEWPORT=1`).
static func intermediaria() -> bool:
	if OS.has_environment("PUNCH_SUBVIEWPORT"):
		return true
	if not girada():
		return false
	# no Android o tamanho da janela É o da tela (a superfície do jogo); no
	# PC em teste vale a janela aberta (`--resolution`)
	var tela = OS.get_window_size()
	return tela.x > 0.0 and tela != JANELA


## O tamanho em que a tela intermediária é desenhada: o da TV (em pé), sem
## passar de 1080x1920.
static func tamanho_intermediario() -> Vector2:
	var tela = OS.get_window_size()
	var curto = min(tela.x, tela.y)
	if curto <= 0.0 or curto >= TELA.x:
		return TELA
	return Vector2(round(curto), round(curto * TELA.y / TELA.x))


## Monta a tela intermediária dentro de `pai` e devolve o Viewport onde o
## jogo entra.
static func montar_intermediaria(pai: Node) -> Viewport:
	var tam = tamanho_intermediario()
	var caixa = ViewportContainer.new()
	caixa.name = "TelaVertical"
	caixa.stretch = false
	caixa.rect_size = tam
	# a imagem do tamanho da TV é ampliada até o espaço lógico de 1080x1920
	# (que a janela, por sua vez, reduz de volta à TV: um pixel por pixel)
	caixa.rect_scale = TELA / tam
	if girada():
		# jogo (x, y) -> tela (y, 1080 - x)
		caixa.rect_rotation = -90.0
		caixa.rect_position = Vector2(0.0, 1080.0)
	var vp = Viewport.new()
	vp.name = "Jogo"
	vp.size = tam
	if tam != TELA:
		vp.set_size_override(true, TELA)
		vp.size_override_stretch = true
	# SÓ 2D: a arena (o único 3D do jogo) é uma janela própria, com o seu
	# buffer. Aqui um buffer de profundidade de 1080x1920 era memória
	# parada — e na TV Box de 1 GB cada MB a menos é o launcher do Android
	# que não é derrubado.
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.handle_input_locally = false
	vp.usage = Viewport.USAGE_2D
	caixa.add_child(vp)
	pai.add_child(caixa)
	# imagem pronta girada com filtro
	vp.get_texture().flags = Texture.FLAG_FILTER
	return vp
