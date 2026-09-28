class_name Compat
extends Reference

## O QUE O GODOT 4 FAZIA SOZINHO E O GODOT 3 NÃO FAZ.
##
## Esta versão roda no Godot 3.6 porque a placa de vídeo da TV Box S905L
## (Mali-450) só tem OpenGL ES 2.0, e o Godot 4 exige o 3.0. O jogo foi
## escrito no Godot 4; as poucas coisas que o 4 tinha pronto e o 3 não
## tem moram aqui, com o mesmo resultado na tela:
##
##   • texto com alinhamento e tamanho na própria chamada de desenho (no 3
##     o tamanho mora na fonte, então cada tamanho usado vira uma fonte);
##   • contorno de texto desenhado à parte, na cor pedida;
##   • cor com transparência trocada, `Color(cor, alfa)`.

const ESQUERDA = 0
const CENTRO = 1
const DIREITA = 2

## Tamanho de referência para MEDIR texto. Medir em todos os tamanhos
## criaria uma fonte (e uma textura de letras) por tamanho só para medir;
## a medida cresce em linha reta com o tamanho, então mede-se em um e
## multiplica-se.
const _REFERENCIA = 64

const _FONTE_PADRAO = "res://assets/fonts/SairaCondensed-ExtraBold.ttf"

## Fontes prontas, por (dados, tamanho, contorno). Um `const` com
## dicionário é compartilhado e pode ser preenchido: é o jeito do Godot 3
## de ter uma variável estática.
const _fontes = {}
const _dados = {}


static func cor(c, alfa: float) -> Color:
	var k: Color = Color(c) if typeof(c) == TYPE_STRING else c
	k.a = alfa
	return k


static func fonte_padrao() -> Resource:
	if not _dados.has("padrao"):
		_dados["padrao"] = load(_FONTE_PADRAO)
	return _dados["padrao"]


## A fonte de desenho: `dados` é o .ttf carregado (DynamicFontData). Quem
## já passa uma DynamicFont pronta recebe ela mesma.
static func fonte(dados, tamanho: int, contorno: int = 0) -> Font:
	if dados == null:
		dados = fonte_padrao()
	if dados is Font:
		return dados
	tamanho = int(max(1, tamanho))
	var chave = "%s|%d|%d" % [dados.resource_path, tamanho, contorno]
	var pronta: DynamicFont = _fontes.get(chave)
	if pronta == null:
		pronta = DynamicFont.new()
		pronta.font_data = dados
		pronta.size = tamanho
		pronta.use_filter = true
		if contorno > 0:
			pronta.outline_size = contorno
			pronta.outline_color = Color(1, 1, 1, 1)
		_fontes[chave] = pronta
	return pronta


## Largura e altura do texto no tamanho pedido.
static func medida(dados, texto: String, tamanho: int) -> Vector2:
	var ref = fonte(dados, _REFERENCIA)
	return ref.get_string_size(texto) * (float(tamanho) / float(_REFERENCIA))


static func ascent(dados, tamanho: int) -> float:
	return fonte(dados, _REFERENCIA).get_ascent() * (float(tamanho) / float(_REFERENCIA))


static func altura(dados, tamanho: int) -> float:
	return fonte(dados, _REFERENCIA).get_height() * (float(tamanho) / float(_REFERENCIA))


static func _deslocamento(dados, texto: String, alinhamento: int, largura: float, tamanho: int) -> float:
	if largura <= 0.0 or alinhamento == ESQUERDA:
		return 0.0
	var w = medida(dados, texto, tamanho).x
	if alinhamento == CENTRO:
		return (largura - w) * 0.5
	return largura - w


## `draw_string` do Godot 4: posição na linha de base, alinhamento dentro
## de `largura`, tamanho em pixels.
##
## TAMANHOS PADRÃO. No Godot 3 cada tamanho de letra é uma fonte com a sua
## própria imagem de letras, e essa imagem cresce com o tamanho: de 100 px
## para cima ela tem 2048x2048 (8 MB cada, mais outra para o contorno). O
## jogo pede dezenas de tamanhos — só as letras passavam de 60 MB, e numa
## TV Box de 1 GB isso derrubava o Android. Aqui a fonte vem de poucos
## tamanhos padrão (no máximo 128 px) e o desenho é esticado até o tamanho
## pedido.
static func texto(alvo: CanvasItem, dados, pos: Vector2, texto: String, alinhamento: int = ESQUERDA,
		largura: float = -1.0, tamanho: int = 16, cor: Color = Color(1, 1, 1)) -> void:
	if texto.empty() or cor.a <= 0.0:
		return
	var real = tamanho_padrao(tamanho)
	var x = _deslocamento(dados, texto, alinhamento, largura, tamanho)
	_escrever(alvo, fonte(dados, real), pos + Vector2(x, 0.0), float(tamanho) / float(real), texto, cor, Color(1, 1, 1, 0))


## `draw_string_outline` do Godot 4: só o contorno, na cor pedida. No
## Godot 4 o número é a espessura total do traço; no 3 é quanto o
## contorno avança para fora da letra — metade (e na escala da fonte
## padrão usada).
static func contorno(alvo: CanvasItem, dados, pos: Vector2, texto: String, alinhamento: int = ESQUERDA,
		largura: float = -1.0, tamanho: int = 16, espessura: int = 1, cor: Color = Color(1, 1, 1)) -> void:
	if texto.empty() or cor.a <= 0.0 or espessura <= 0:
		return
	var real = tamanho_padrao(tamanho)
	var escala = float(tamanho) / float(real)
	# O raio do contorno também em poucos valores: cada raio diferente é
	# mais uma imagem de letras na memória.
	var raio = _raio_padrao(espessura * 0.5 / escala)
	var x = _deslocamento(dados, texto, alinhamento, largura, tamanho)
	_escrever(alvo, fonte(dados, real, raio), pos + Vector2(x, 0.0), escala, texto, Color(1, 1, 1, 0), cor)


## Os tamanhos padrão: até 32 px, de 2 em 2; até 64, de 8 em 8; depois
## 80, 96 e 128. Acima de 128 o desenho é ampliado a partir de 128.
static func tamanho_padrao(tamanho: int) -> int:
	if tamanho <= 32:
		return int(max(8, tamanho + tamanho % 2))
	if tamanho <= 64:
		return int(ceil(tamanho / 8.0) * 8)
	if tamanho <= 80:
		return 80
	if tamanho <= 96:
		return 96
	return 128


static func _raio_padrao(raio: float) -> int:
	for padrao in [1, 2, 3, 4, 6, 8, 12, 16]:
		if raio <= padrao * 1.2:
			return padrao
	return 20


static func _escrever(alvo: CanvasItem, f: Font, pos: Vector2, escala: float, texto: String, cor: Color, cor_contorno: Color) -> void:
	var rid = alvo.get_canvas_item()
	if abs(escala - 1.0) < 0.01:
		f.draw(rid, pos, texto, cor, -1, cor_contorno)
		return
	# O desenho do texto esticado vai por cima da transformação que o jogo
	# já estiver usando neste item (tremor, zoom, rolagem da Central).
	var base = _transformacao(alvo)
	alvo.draw_set_transform_matrix(base * Transform2D(Vector2(escala, 0.0), Vector2(0.0, escala), pos))
	f.draw(rid, Vector2.ZERO, texto, cor, -1, cor_contorno)
	alvo.draw_set_transform_matrix(base)


# ------------------------------------------------------------ transformação do desenho
## O Godot 3 não devolve a transformação de desenho em uso. O jogo a muda
## por aqui (`transformar`), e o texto esticado sabe por cima do que
## desenhar. Vale só no quadro em que foi posta: cada `_draw` começa do zero.
const _transformacoes := {}


static func transformar(alvo: CanvasItem, pos: Vector2, rotacao: float, escala: Vector2) -> void:
	alvo.draw_set_transform(pos, rotacao, escala)
	var t = Transform2D(rotacao, pos)
	t.x *= escala.x
	t.y *= escala.y
	_transformacoes[alvo.get_instance_id()] = [Engine.get_idle_frames(), t]


static func transformar_matriz(alvo: CanvasItem, matriz: Transform2D) -> void:
	alvo.draw_set_transform_matrix(matriz)
	_transformacoes[alvo.get_instance_id()] = [Engine.get_idle_frames(), matriz]


static func _transformacao(alvo: CanvasItem) -> Transform2D:
	var e = _transformacoes.get(alvo.get_instance_id())
	if e == null or e[0] != Engine.get_idle_frames():
		return Transform2D.IDENTITY
	return e[1]


## `z_index` de um Control: no Godot 3 só o Node2D tem a propriedade, mas o
## servidor de desenho aceita a ordem para qualquer item.
static func z(item: CanvasItem, valor: int) -> void:
	VisualServer.canvas_item_set_z_index(item.get_canvas_item(), valor)


## `content_scale` da janela do Godot 4: o quadro lógico e o modo de
## esticar ficam na árvore no Godot 3. Na TV Box o quadro 1920x1080 cobre a
## tela inteira: numa saída 16:9 é igual ao KEEP, e se o sistema entregar uma
## superfície um pouco diferente (barra de navegação, overscan) não sobra
## faixa preta.
static func enquadrar(arvore: SceneTree, tamanho: Vector2) -> void:
	var aspecto = SceneTree.STRETCH_ASPECT_KEEP
	if OS.get_name() == "Android":
		aspecto = SceneTree.STRETCH_ASPECT_IGNORE
	arvore.set_screen_stretch(SceneTree.STRETCH_MODE_2D, aspecto, tamanho)


static func randi_range(de: int, ate: int) -> int:
	if ate < de:
		var t = de
		de = ate
		ate = t
	return de + int(randi() % (ate - de + 1))


static func vmin(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(min(a.x, b.x), min(a.y, b.y))


static func vmax(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(max(a.x, b.x), max(a.y, b.y))


# ------------------------------------------------------------ arquivos
## `FileAccess`/`DirAccess` do Godot 4 são `File`/`Directory` no 3, que
## precisam de um objeto para cada operação. Estas funções devolvem o mesmo
## que as do 4: o arquivo aberto (ou null) e o código de erro.

static func existe(caminho: String) -> bool:
	return File.new().file_exists(caminho)


static func abrir(caminho: String, modo: int) -> File:
	var f = File.new()
	if f.open(caminho, modo) != OK:
		return null
	return f


static func bytes_do_arquivo(caminho: String) -> PoolByteArray:
	var f = abrir(caminho, File.READ)
	if f == null:
		return PoolByteArray()
	var b = f.get_buffer(f.get_len())
	f.close()
	return b


static func texto_do_arquivo(caminho: String) -> String:
	var f = abrir(caminho, File.READ)
	if f == null:
		return ""
	var s = f.get_as_text()
	f.close()
	return s


static func abrir_pasta(caminho: String) -> Directory:
	var d = Directory.new()
	if d.open(caminho) != OK:
		return null
	return d


static func renomear(de: String, para: String) -> int:
	return Directory.new().rename(de, para)


static func apagar(caminho: String) -> int:
	return Directory.new().remove(caminho)


static func criar_pasta(caminho: String) -> int:
	return Directory.new().make_dir_recursive(caminho)


static func pasta_existe(caminho: String) -> bool:
	return Directory.new().dir_exists(caminho)


# ------------------------------------------------------------ trabalho em segundo plano
## `WorkerThreadPool.add_task` do Godot 4: uma linha de trabalho por tarefa.
## As tarefas "soltas" (ninguém espera por elas) são recolhidas na próxima
## chamada, quando já terminaram — uma Thread do Godot 3 precisa de
## `wait_to_finish` para devolver a memória.

class _Tarefa:
	extends Reference
	var alvo: Object
	var metodo := ""
	var args := []

	func rodar(_nada) -> void:
		alvo.callv(metodo, args)

const _tarefas := {}


static func tarefa(alvo: Object, metodo: String, args: Array = []) -> Thread:
	_recolher()
	var t = _Tarefa.new()
	t.alvo = alvo
	t.metodo = metodo
	t.args = args
	var linha = Thread.new()
	if linha.start(t, "rodar", null) != OK:
		t.rodar(null)
		return null
	_tarefas[linha] = t
	return linha


static func terminou(linha: Thread) -> bool:
	return linha == null or not linha.is_alive()


static func esperar(linha: Thread) -> void:
	if linha != null and linha.is_active():
		linha.wait_to_finish()
	_tarefas.erase(linha)


static func _recolher() -> void:
	for linha in _tarefas.keys():
		if not linha.is_alive():
			linha.wait_to_finish()
			_tarefas.erase(linha)


## `Transform2D(rotação, escala, inclinação, posição)` do Godot 4 (a
## inclinação não é usada no jogo).
static func t2d(rotacao: float, escala: Vector2, _inclinacao: float, posicao: Vector2) -> Transform2D:
	var x = Vector2(cos(rotacao), sin(rotacao)) * escala.x
	var y = Vector2(-sin(rotacao), cos(rotacao)) * escala.y
	return Transform2D(x, y, posicao)


## `draw_circle(centro, raio, cor, cheio, espessura, liso)` do Godot 4.
## No 3 o círculo cheio não tem borda lisa: um arco fino e liso por cima
## da borda faz o mesmo papel.
static func circulo(alvo: CanvasItem, centro: Vector2, raio: float, cor: Color, cheio: bool = true,
		espessura: float = -1.0, liso: bool = false) -> void:
	if raio <= 0.0 or cor.a <= 0.0:
		return
	var pontos = int(clamp(raio * 0.7, 12.0, 64.0))
	if cheio:
		alvo.draw_circle(centro, raio, cor)
		if liso and raio > 1.5:
			alvo.draw_arc(centro, raio - 0.5, 0.0, TAU, pontos, cor, 1.0, true)
	else:
		alvo.draw_arc(centro, raio, 0.0, TAU, pontos, cor, max(espessura, 1.0), liso)


# ------------------------------------------------------------ imagens
## `Image.create_from_data` e `ImageTexture.create_from_image` eram
## estáticas no Godot 4. A textura sai só com filtro: sem mipmaps e sem
## repetição, que o OpenGL ES 2.0 não faz em imagem de tamanho qualquer.

static func imagem(largura: int, altura: int, mipmaps: bool, formato: int, dados: PoolByteArray) -> Image:
	var img = Image.new()
	img.create_from_data(largura, altura, mipmaps, formato, dados)
	return img


static func imagem_vazia(largura: int, altura: int, mipmaps: bool, formato: int) -> Image:
	var img = Image.new()
	img.create(largura, altura, mipmaps, formato)
	return img


static func textura(img: Image) -> ImageTexture:
	var t = ImageTexture.new()
	if img != null and not img.is_empty():
		t.create_from_image(img, Texture.FLAG_FILTER)
	return t


## `find_children("*", classe)` do Godot 4.
static func filhos_do_tipo(no: Node, classe: String) -> Array:
	var achados = []
	for filho in no.get_children():
		if filho.is_class(classe):
			achados.append(filho)
		achados += filhos_do_tipo(filho, classe)
	return achados


## `Array.assign` do Godot 4: troca o conteúdo mantendo a MESMA lista (quem
## guardou a referência vê a mudança).
static func atribuir(lista: Array, conteudo) -> void:
	lista.clear()
	for item in conteudo:
		lista.append(item)


# ------------------------------------------------------------ partículas
## As partículas do Godot 4 sorteiam cada grandeza numa faixa [mín, máx];
## as do Godot 3 usam "valor" e "quanto sortear" (0 = sempre o valor, 1 =
## de zero ao valor). A faixa vira: valor = máx, sorteio = 1 - mín/máx.
static func faixa_min(p: Object, grandeza: String, valor: float) -> void:
	p.set_meta(grandeza + "_min", valor)
	_aplicar_faixa(p, grandeza)


static func faixa_max(p: Object, grandeza: String, valor: float) -> void:
	p.set_meta(grandeza + "_max", valor)
	_aplicar_faixa(p, grandeza)


static func _aplicar_faixa(p: Object, grandeza: String) -> void:
	var maximo = p.get_meta(grandeza + "_max") if p.has_meta(grandeza + "_max") else p.get_meta(grandeza + "_min")
	var minimo = p.get_meta(grandeza + "_min") if p.has_meta(grandeza + "_min") else 0.0
	p.set(grandeza, maximo)
	var sorteio = 0.0
	if abs(maximo) > 0.000001:
		sorteio = clamp(1.0 - minimo / maximo, 0.0, 1.0)
	p.set(grandeza + "_random", sorteio)


static func vclamp(v: Vector2, de: Vector2, ate: Vector2) -> Vector2:
	return Vector2(clamp(v.x, de.x, ate.x), clamp(v.y, de.y, ate.y))


## `Vector3.slerp` do Godot 4, que aceita vetores já alinhados (o do 3
## erra quando os dois apontam para o mesmo lado: o eixo do giro é nulo).
static func slerp3(de: Vector3, para: Vector3, peso: float) -> Vector3:
	var eixo = de.cross(para)
	if eixo.length_squared() < 0.0000001:
		return de.linear_interpolate(para, peso)
	return de.rotated(eixo.normalized(), de.angle_to(para) * peso)


# ------------------------------------------------------------ relógios de shader
## A placa de vídeo da S905L (Mali-450) calcula o pixel em MEIA PRECISÃO:
## um relógio que só cresce (o TIME) anda aos pulos depois de alguns
## minutos. Os shaders recebem as fases já calculadas aqui, em precisão
## dupla, e sempre pequenas.

## Segundos desde que o jogo abriu (o mesmo relógio do TIME do Godot).
static func agora() -> float:
	return float(OS.get_ticks_usec()) * 0.000001


## Fase de um seno de `velocidade` rad/s, dentro de uma volta.
static func fase(t: float, velocidade: float) -> float:
	return fposmod(t * velocidade, TAU)


## Parte fracionária de `t * velocidade` (0..1).
static func fracao(t: float, velocidade: float) -> float:
	var v = t * velocidade
	return v - floor(v)


## O `fract(sin(n * 12.9898) * 43758.5453)` de sempre, em precisão dupla.
static func sorteio(n: float) -> float:
	var v = sin(n * 12.9898) * 43758.5453
	return v - floor(v)
