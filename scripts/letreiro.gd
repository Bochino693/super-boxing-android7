class_name Letreiro
extends Control

## O NOME DO JOGO, NUM NÓ SÓ PARA ELE — e o motivo é o shader.
##
## No Godot, material é propriedade do NÓ: não existe trocar de shader
## entre duas chamadas dentro do mesmo `_draw`. Como o resto da tela é
## desenhado à mão num único Control, pôr o brilho no nó principal
## aplicaria o efeito a tudo — fundo, cartões, placar. Então o nome sai
## do desenho geral e passa a morar aqui, sozinho, com o shader dele.

const SHADER = preload("res://shaders/brilho_letras.shader")
const PASSAGEM = 1.15
const DESCANSO = 3.10
const CICLO = PASSAGEM + DESCANSO
const DE = -0.22
const ATE = 1.22

var fonte: Resource
var _linhas: Array = []
var _tempo = 0.0
var _material = ShaderMaterial.new()
var _inicio_x = -1.0
var _extensao_x = -1.0

func _ready() -> void:
	_material.shader = SHADER
	material = _material
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# O relógio vem de `main.gd`, em `avancar`. Um nó com brilho correndo
	# por cima das letras no seu próprio tempo é mais uma camada
	# chacoalhando por conta própria. Ver `Ritmo`.
	set_process(false)

## O PASSO VEM DE FORA, e é o mesmo do jogo inteiro.
func avancar(passo: float) -> void:
	_tempo += passo
	var fase = fmod(_tempo, CICLO)
	var posicao = DE - 0.5
	if fase < PASSAGEM:
		posicao = lerp(DE, ATE, fase / PASSAGEM)
	_material.set_shader_param("posicao", posicao)
	# Uniformes atualizam o material sem reconstruir os comandos de texto.

## Recebe o que desenhar neste quadro. Cada entrada é
## {texto, y, tamanho, cor}. Chamado pelo desenho da tela: assim o nome
## continua obedecendo à mesma animação de entrada de antes, e este nó
## não precisa saber nada sobre estados do jogo.
func mostrar(linhas: Array, inicio_x: float, extensao_x: float) -> void:
	if _linhas == linhas and _inicio_x == inicio_x and _extensao_x == extensao_x:
		return
	_linhas = linhas
	_inicio_x = inicio_x
	_extensao_x = extensao_x
	_material.set_shader_param("inicio_x", inicio_x)
	_material.set_shader_param("extensao_x", extensao_x)
	update()

func esconder() -> void:
	if not _linhas.empty():
		_linhas = []
		update()

func _draw() -> void:
	if fonte == null or _linhas.empty():
		return
	for linha in _linhas:
		var texto: String = linha["texto"]
		var tamanho: int = int(linha["tamanho"])
		var cor: Color = linha["cor"]
		var medida = Compat.medida(fonte, texto, tamanho)
		var pos = Vector2(float(linha["x"]) - medida.x * 0.5, float(linha["y"]))
		# As mesmas três passadas do letreiro de sempre: halo, contorno
		# grosso e a letra. O shader trata as três — e é por isso que ele
		# exige luminância além do alfa, para não acender o contorno.
		Compat.contorno(self, fonte, pos, texto, Compat.ESQUERDA, -1, tamanho, int(tamanho * 0.34), Compat.cor(cor, cor.a * 0.28))
		Compat.contorno(self, fonte, pos, texto, Compat.ESQUERDA, -1, tamanho, int(max(6, int(tamanho * 0.17))), Compat.cor(Paleta.CONTORNO, cor.a))
		Compat.texto(self, fonte, pos - Vector2(0.0, tamanho * 0.055), texto, Compat.ESQUERDA, -1, tamanho, Compat.cor(cor.lightened(0.42), cor.a))
		Compat.texto(self, fonte, pos, texto, Compat.ESQUERDA, -1, tamanho, cor)
