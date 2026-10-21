class_name Compat
extends RefCounted

## PONTE ENTRE AS DUAS VERSÕES DO JOGO.
##
## A versão TV Box S905L roda no Godot 3.6 e chama estas funções no lugar
## do que o Godot 4 já tem pronto. Esta é a versão Godot 4.6: as mesmas
## funções, agora finas, direto na chamada nativa. Assim o código das
## duas versões continua igual e uma correção vale para as duas.

const ESQUERDA = 0
const CENTRO = 1
const DIREITA = 2

const _FONTE_PADRAO = "res://assets/fonts/SairaCondensed-ExtraBold.ttf"

static var _dados := {}


static func cor(c, alfa: float) -> Color:
	var k: Color = Color(c) if typeof(c) == TYPE_STRING else c
	k.a = alfa
	return k


static func fonte_padrao() -> Font:
	if not _dados.has("padrao"):
		_dados["padrao"] = load(_FONTE_PADRAO)
	return _dados["padrao"]


## No Godot 4 o tamanho vai na chamada de desenho: a fonte é a mesma.
static func fonte(dados, _tamanho: int = 16, _contorno: int = 0) -> Font:
	if dados == null:
		return fonte_padrao()
	return dados


static func medida(dados, texto: String, tamanho: int) -> Vector2:
	return fonte(dados).get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho)


static func ascent(dados, tamanho: int) -> float:
	return fonte(dados).get_ascent(tamanho)


static func altura(dados, tamanho: int) -> float:
	return fonte(dados).get_height(tamanho)


static func _alinhar(alinhamento: int) -> int:
	if alinhamento == CENTRO:
		return HORIZONTAL_ALIGNMENT_CENTER
	if alinhamento == DIREITA:
		return HORIZONTAL_ALIGNMENT_RIGHT
	return HORIZONTAL_ALIGNMENT_LEFT


static func texto(alvo: CanvasItem, dados, pos: Vector2, texto: String, alinhamento: int = ESQUERDA,
		largura: float = -1.0, tamanho: int = 16, cor: Color = Color(1, 1, 1)) -> void:
	if texto.is_empty() or cor.a <= 0.0:
		return
	alvo.draw_string(fonte(dados), pos, texto, _alinhar(alinhamento), largura, tamanho, cor)


static func contorno(alvo: CanvasItem, dados, pos: Vector2, texto: String, alinhamento: int = ESQUERDA,
		largura: float = -1.0, tamanho: int = 16, espessura: int = 1, cor: Color = Color(1, 1, 1)) -> void:
	if texto.is_empty() or cor.a <= 0.0 or espessura <= 0:
		return
	alvo.draw_string_outline(fonte(dados), pos, texto, _alinhar(alinhamento), largura, tamanho, espessura, cor)


static func tamanho_padrao(tamanho: int) -> int:
	return tamanho


static func transformar(alvo: CanvasItem, pos: Vector2, rotacao: float, escala: Vector2) -> void:
	alvo.draw_set_transform(pos, rotacao, escala)


static func transformar_matriz(alvo: CanvasItem, matriz: Transform2D) -> void:
	alvo.draw_set_transform_matrix(matriz)


static func z(item: CanvasItem, valor: int) -> void:
	item.z_index = valor


static func enquadrar(arvore: SceneTree, tamanho: Vector2) -> void:
	var janela := arvore.root
	janela.content_scale_size = Vector2i(tamanho)
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	janela.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE if OS.get_name() == "Android" \
		else Window.CONTENT_SCALE_ASPECT_KEEP


static func randi_range(de: int, ate: int) -> int:
	return mini(de, ate) + randi() % (absi(ate - de) + 1)


static func vmin(a: Vector2, b: Vector2) -> Vector2:
	return a.min(b)


static func vmax(a: Vector2, b: Vector2) -> Vector2:
	return a.max(b)


# ------------------------------------------------------------ arquivos
static func existe(caminho: String) -> bool:
	return FileAccess.file_exists(caminho)


static func abrir(caminho: String, modo: int) -> FileAccess:
	return FileAccess.open(caminho, modo)


static func bytes_do_arquivo(caminho: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(caminho)


static func texto_do_arquivo(caminho: String) -> String:
	return FileAccess.get_file_as_string(caminho)


static func abrir_pasta(caminho: String) -> DirAccess:
	return DirAccess.open(caminho)


static func renomear(de: String, para: String) -> int:
	return DirAccess.rename_absolute(de, para)


static func apagar(caminho: String) -> int:
	return DirAccess.remove_absolute(caminho)


static func criar_pasta(caminho: String) -> int:
	return DirAccess.make_dir_recursive_absolute(caminho)


static func pasta_existe(caminho: String) -> bool:
	return DirAccess.dir_exists_absolute(caminho)


# ------------------------------------------------------------ trabalho em segundo plano
## Devolve o id da tarefa do WorkerThreadPool (ou -1 se rodou na hora).
static func tarefa(alvo: Object, metodo: String, args: Array = []) -> int:
	return WorkerThreadPool.add_task(Callable(alvo, metodo).bindv(args))


static func terminou(linha) -> bool:
	return linha == null or int(linha) < 0 or WorkerThreadPool.is_task_completed(int(linha))


static func esperar(linha) -> void:
	if linha != null and int(linha) >= 0:
		WorkerThreadPool.wait_for_task_completion(int(linha))


static func t2d(rotacao: float, escala: Vector2, inclinacao: float, posicao: Vector2) -> Transform2D:
	return Transform2D(rotacao, escala, inclinacao, posicao)


static func circulo(alvo: CanvasItem, centro: Vector2, raio: float, cor: Color, cheio: bool = true,
		espessura: float = -1.0, liso: bool = false) -> void:
	if raio <= 0.0 or cor.a <= 0.0:
		return
	alvo.draw_circle(centro, raio, cor, cheio, espessura, liso)


# ------------------------------------------------------------ imagens
static func imagem(largura: int, altura: int, mipmaps: bool, formato: int, dados: PackedByteArray) -> Image:
	return Image.create_from_data(largura, altura, mipmaps, formato, dados)


static func imagem_vazia(largura: int, altura: int, mipmaps: bool, formato: int) -> Image:
	return Image.create_empty(largura, altura, mipmaps, formato)


static func textura(img: Image) -> ImageTexture:
	if img == null or img.is_empty():
		return ImageTexture.new()
	return ImageTexture.create_from_image(img)


static func filhos_do_tipo(no: Node, classe: String) -> Array:
	return no.find_children("*", classe, true, false)


static func atribuir(lista: Array, conteudo) -> void:
	lista.assign(conteudo)


# ------------------------------------------------------------ partículas
## No Godot 4 cada grandeza já é uma faixa: `<grandeza>_min` e `_max`.
static func faixa_min(p: Object, grandeza: String, valor: float) -> void:
	p.set(grandeza + "_min", valor)


static func faixa_max(p: Object, grandeza: String, valor: float) -> void:
	p.set(grandeza + "_max", valor)


static func vclamp(v: Vector2, de: Vector2, ate: Vector2) -> Vector2:
	return v.clamp(de, ate)


static func slerp3(de: Vector3, para: Vector3, peso: float) -> Vector3:
	return de.slerp(para, peso)


# ------------------------------------------------------------ relógios de shader
static func agora() -> float:
	return float(Time.get_ticks_usec()) * 0.000001


static func fase(t: float, velocidade: float) -> float:
	return fposmod(t * velocidade, TAU)


static func fracao(t: float, velocidade: float) -> float:
	var v := t * velocidade
	return v - floor(v)


static func sorteio(n: float) -> float:
	var v := sin(n * 12.9898) * 43758.5453
	return v - floor(v)
