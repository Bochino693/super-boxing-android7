extends Node2D

## UM EMISSOR DE PARTÍCULAS CALCULADAS PELA PLACA DE VÍDEO (build 121).
## (Carregado com `preload` por `scripts/fx.gd`.)
##
## POR QUE NÃO `CPUParticles2D`. No Godot 3 com OpenGL ES 2.0 não há
## desenho de muitas cópias numa chamada só (instancing): o motor desenha
## CADA partícula de um `CPUParticles2D` com a sua própria chamada à placa
## de vídeo (`rasterizer_canvas_gles2.cpp`, o laço do TYPE_MULTIMESH) — e
## enquanto o efeito dura, desenha também as que já morreram. No soco mais
## forte eram umas 400 chamadas por quadro só de faísca, brasa e raio, e o
## processador da TV Box passava o quadro conversando com o driver da
## Mali-450. Era o "lento nos efeitos".
##
## AQUI CADA EXPLOSÃO É UMA MALHA SÓ, guardada na placa de vídeo uma vez,
## e o shader de vértice calcula onde cada partícula está a partir do
## tempo: posição, desaceleração, gravidade, giro, tamanho, cor e sumiço.
## Por quadro, o script só avança um número (`tempo`); a placa desenha a
## explosão inteira numa chamada.
##
## Cada partícula da malha carrega números sorteados (nos vértices: o
## ângulo e a posição na fila; na cor: velocidade, vida, tamanho e lugar de
## nascimento), e `semente` embaralha esses números a cada disparo — duas
## explosões seguidas nunca saem iguais.

## As malhas, por número de partículas: são as mesmas para todos os
## emissores do mesmo tamanho (os sorteios mudam com a semente).
const _MALHAS = {}
## Os dois shaders (soma de luz e mistura comum), compilados uma vez.
const _SHADERS = {}

const CORPO = """
uniform float tempo = 0.0;
uniform float semente = 0.0;
uniform float quantos = 1.0;
uniform float vida = 1.0;
uniform float vida_aleatoria = 0.45;
uniform float vel_max = 500.0;
uniform float vel_min = 0.3;
uniform float amort = 0.0;
uniform float grav = 0.0;
uniform float dir_ang = 0.0;
uniform float abertura = 3.1416;
uniform float espalhar = 0.0;
uniform vec2 retangulo = vec2(0.0, 0.0);
uniform float esc_min = 1.0;
uniform float esc_max = 1.0;
uniform float esc_ini = 1.0;
uniform float esc_fim = 1.0;
uniform vec2 tam = vec2(32.0, 32.0);
uniform float alinhar = 0.0;
uniform float giro_ini = 0.0;
uniform float giro_vel = 0.0;
uniform float fade_ponto = 0.7;
uniform float fade_alfa = 0.85;
uniform float quadros = 1.0;
uniform float quadros_vel = 0.0;
uniform float continuo = 0.0;
uniform float fim_emissao = 100000.0;
uniform float n_cores = 0.0;
uniform vec4 tinta : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor0 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor1 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor2 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor3 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor4 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor5 : hint_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec4 v_cor;

float sorteio(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	vec2 canto = UV;
	float indice = VERTEX.y;
	float s_ang = fract(VERTEX.x + semente);
	float s_vel = fract(COLOR.r + semente * 1.6180);
	float s_vida = fract(COLOR.g + semente * 2.4142);
	float s_tam = fract(COLOR.b + semente * 3.3028);
	float s_pos = fract(COLOR.a + semente * 4.2361);
	float t = tempo;
	float vida_p = vida * (1.0 - vida_aleatoria * s_vida);
	float aparece = step(indice, quantos - 0.0001);
	if (continuo > 0.5) {
		// emissão contínua: cada partícula nasce numa fase da vida e
		// renasce em outro lugar a cada volta; depois de `fim_emissao`
		// ninguém mais nasce e as que estão no ar terminam a queda
		float fase = s_vida * vida;
		float total = tempo - fase;
		float volta = floor(total / vida);
		t = total - volta * vida;
		aparece *= step(0.0, total) * step(tempo - t, fim_emissao);
		s_ang = fract(s_ang + volta * 0.6180);
		s_pos = fract(s_pos + volta * 0.7549);
		s_vel = fract(s_vel + volta * 0.5698);
		vida_p = vida;
	}
	aparece *= step(t, vida_p);
	float x = clamp(t / vida_p, 0.0, 1.0);
	float s_extra = sorteio(s_ang * 7.13 + s_pos * 3.71 + semente);
	float s_cor = sorteio(s_vel * 5.31 + s_tam * 9.17 + semente * 1.3);

	// a saída: direção dentro da abertura, velocidade sorteada e uma
	// desaceleração constante até parar; a gravidade puxa por cima
	float ang = dir_ang + (s_ang * 2.0 - 1.0) * abertura;
	vec2 dir = vec2(cos(ang), sin(ang));
	float v0 = vel_max * mix(vel_min, 1.0, s_vel);
	float d = amort * mix(0.6, 1.0, s_extra);
	float tr = t;
	if (d > 0.0) {
		tr = min(t, v0 / d);
	}
	float dist = v0 * tr - 0.5 * d * tr * tr;
	vec2 origem = (vec2(s_pos, s_extra) * 2.0 - 1.0) * retangulo;
	if (espalhar > 0.0) {
		float a2 = s_extra * 6.2832;
		origem += vec2(cos(a2), sin(a2)) * espalhar * sqrt(s_pos);
	}
	vec2 pos = origem + dir * dist + vec2(0.0, 0.5 * grav * t * t);

	// a orientação: o rastro segue a velocidade, ou a peça gira
	vec2 ex;
	vec2 ey;
	if (alinhar > 0.5) {
		vec2 v = dir * max(v0 - d * t, 0.0) + vec2(0.0, grav * t);
		vec2 n = v / max(length(v), 0.0001);
		ey = n;
		ex = vec2(n.y, -n.x);
	} else {
		float a = s_extra * giro_ini + (s_tam * 2.0 - 1.0) * giro_vel * t;
		ex = vec2(cos(a), sin(a));
		ey = vec2(-ex.y, ex.x);
	}
	float esc = mix(esc_min, esc_max, s_tam) * mix(esc_ini, esc_fim, x) * aparece;
	vec2 c = (canto - 0.5) * tam * esc;
	VERTEX = pos + ex * c.x + ey * c.y;

	// o papel picado vira (os quadros da textura)
	float q = floor(mod(s_extra * quadros + t * quadros_vel * mix(0.6, 1.4, s_pos), quadros));
	UV = vec2((canto.x + q) / quadros, canto.y);

	// a cor sorteada e o sumiço no fim da vida
	vec4 cor = tinta;
	if (n_cores > 0.5) {
		float k = floor(s_cor * n_cores);
		cor = cor0;
		if (k > 0.5) { cor = cor1; }
		if (k > 1.5) { cor = cor2; }
		if (k > 2.5) { cor = cor3; }
		if (k > 3.5) { cor = cor4; }
		if (k > 4.5) { cor = cor5; }
		cor *= tinta;
	}
	float antes = mix(1.0, fade_alfa, x / max(fade_ponto, 0.001));
	float depois = mix(fade_alfa, 0.0, (x - fade_ponto) / max(1.0 - fade_ponto, 0.001));
	float alfa = mix(antes, depois, step(fade_ponto, x));
	v_cor = vec4(cor.rgb, cor.a * alfa * aparece);
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * v_cor;
}
"""

var textura: Texture = null
var tempo = 0.0
var ativo = false
## Quando a última partícula some (s, a partir do disparo).
var _dura = 1.0
var _continuo = false
var _fim = 100000.0
var _vida = 1.0
var _malha: ArrayMesh = null
var _mat: ShaderMaterial = null


static func _shader(soma: bool) -> Shader:
	var chave = "soma" if soma else "mistura"
	if not _SHADERS.has(chave):
		var sh = Shader.new()
		sh.code = "shader_type canvas_item;\nrender_mode %s;\n%s" % ["blend_add" if soma else "blend_mix", CORPO]
		_SHADERS[chave] = sh
	return _SHADERS[chave]


## A malha de `n` partículas: quatro cantos cada, com os sorteios fixos.
static func _malha_de(n: int) -> ArrayMesh:
	if _MALHAS.has(n):
		return _MALHAS[n]
	var rng = RandomNumberGenerator.new()
	rng.seed = 7919 + n
	var v = PoolVector2Array()
	var c = PoolColorArray()
	var uv = PoolVector2Array()
	var idx = PoolIntArray()
	var cantos = PoolVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for i in n:
		var s = Vector2(rng.randf(), (float(i) + 0.5) / float(n))
		var sorteios = Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		v.append_array(PoolVector2Array([s, s, s, s]))
		c.append_array(PoolColorArray([sorteios, sorteios, sorteios, sorteios]))
		uv.append_array(cantos)
		var b = i * 4
		idx.append_array(PoolIntArray([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	# sem compressão: os sorteios e as velocidades precisam da precisão inteira
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], 0)
	_MALHAS[n] = m
	return m


## Monta o emissor: `n` partículas no máximo, a textura e a mistura.
func preparar(n: int, tex: Texture, soma: bool) -> void:
	textura = tex
	_malha = _malha_de(n)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader(soma)
	material = _mat
	visible = false
	# A malha guarda sorteios, não posições: sem um retângulo próprio, o
	# Godot calcularia a caixa dela e poderia achar que está fora da tela.
	VisualServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(-4000, -4000, 8000, 8000))
	update()


func _draw() -> void:
	if _malha != null and textura != null:
		draw_mesh(_malha, textura)


## O que não muda de um disparo para o outro (a receita do tipo).
func disparar_config(params: Dictionary) -> void:
	for k in params:
		_mat.set_shader_param(k, params[k])
	_vida = float(params.get("vida", _vida))


## Solta as partículas: `params` são os uniformes do shader (só os que
## mudam), `dura` é quando a última some. Contínuo: até `parar`.
func disparar(params: Dictionary, dura: float, continuo := false) -> void:
	for k in params:
		_mat.set_shader_param(k, params[k])
	tempo = 0.0
	_dura = dura
	_vida = float(params.get("vida", _vida))
	_continuo = continuo
	_fim = 100000.0
	_mat.set_shader_param("tempo", 0.0)
	_mat.set_shader_param("semente", randf() * 61.0)
	_mat.set_shader_param("continuo", 1.0 if continuo else 0.0)
	_mat.set_shader_param("fim_emissao", _fim)
	ativo = true
	visible = true


## Contínuo: ninguém mais nasce; as que estão no ar terminam.
func parar() -> void:
	if _continuo and _fim > tempo:
		_fim = tempo
		_mat.set_shader_param("fim_emissao", _fim)


## Contínuo parado e ainda no ar: volta a soltar sem recomeçar do zero.
func continuar() -> void:
	if _continuo:
		_fim = 100000.0
		_mat.set_shader_param("fim_emissao", _fim)


func emitindo() -> bool:
	return ativo and _continuo and _fim > tempo


func avancar(delta: float) -> void:
	if not ativo:
		return
	tempo += delta
	if (_continuo and tempo > _fim + _dura) or (not _continuo and tempo > _dura):
		apagar()
		return
	# Uma brisa que nunca para (a poeira da abertura) não deixa o relógio
	# crescer sem fim: a precisão do shader cairia com o passar dos dias. O
	# recuo é um número inteiro de vidas — no máximo um grão de poeira muda
	# de lugar, uma vez a cada dez minutos.
	if _continuo and _fim > 50000.0 and tempo > 600.0:
		tempo -= floor(500.0 / _vida) * _vida
	_mat.set_shader_param("tempo", tempo)


func apagar() -> void:
	ativo = false
	visible = false


func set_uniforme(nome: String, valor) -> void:
	_mat.set_shader_param(nome, valor)
