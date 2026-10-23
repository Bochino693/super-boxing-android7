extends MeshInstance

## PARTÍCULAS DA ARENA CALCULADAS PELA PLACA DE VÍDEO (build 121).
## (Carregado com `preload` por `scripts/arena/arena3d.gd`.)
##
## O mesmo motivo das partículas 2D (ver `scripts/fx/emissor_gpu.gd`): no
## OpenGL ES 2.0 do Godot 3, `CPUParticles` e `MultiMesh` desenham cada
## cópia com uma chamada própria à placa de vídeo — os flashes da plateia
## eram 16 chamadas em todo quadro, a poeira no ar mais 24, e o soco
## somava 48 estrelas e 18 nuvens de poeira. Aqui cada efeito é uma malha
## só, com números sorteados nos vértices, e o shader de vértice calcula a
## posição de cada partícula a partir do tempo (e a vira para a câmera).
##
## Três usos: EXPLOSÃO (uma vez, `disparar`), CONTÍNUO (a poeira dançando
## na luz, que renasce em outro lugar a cada volta) e FLASHES (pontos fixos
## na plateia que piscam — o brilho deles também é conta do shader).

const _MALHAS = {}
const _SHADERS = {}

const CORPO = """
uniform sampler2D textura : hint_albedo;
uniform float tempo = 0.0;
uniform float semente = 0.0;
uniform float quantos = 1.0;
uniform float vida = 1.0;
uniform float vida_aleatoria = 0.0;
uniform vec3 dir_base = vec3(0.0, 1.0, 0.0);
uniform vec3 eixo_u = vec3(1.0, 0.0, 0.0);
uniform vec3 eixo_v = vec3(0.0, 0.0, 1.0);
uniform float abertura = 3.1416;
uniform float vel_max = 1.0;
uniform float vel_min = 0.3;
uniform float amort = 0.0;
uniform vec3 grav = vec3(0.0, 0.0, 0.0);
uniform float esfera = 0.0;
uniform vec3 caixa = vec3(0.0, 0.0, 0.0);
uniform float tam = 0.1;
uniform float esc_min = 1.0;
uniform float esc_max = 1.0;
uniform vec4 cor_ini : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cor_fim : hint_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float continuo = 0.0;
uniform float flashes = 0.0;
uniform float relogio = 0.0;
uniform float festa = 0.0;

varying vec4 v_cor;

float sorteio(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void vertex() {
	vec2 canto = UV;
	vec3 s = VERTEX;
	vec3 centro;
	float esc;
	vec4 cor;
	if (flashes > 0.5) {
		// um flash de câmera parado na plateia: a posição vem pronta no
		// vértice, e o brilho é a mesma conta que o script fazia
		centro = s;
		float fase = UV2.x;
		float base = max(0.0, sin(relogio * 1.7 + fase) - 0.93) * 12.0;
		float agito = festa * max(0.0, sin(fase * 3.1 + relogio * 22.0));
		float a = clamp(base + agito, 0.0, 1.0);
		cor = vec4(a, a * 0.97, a * 0.92, a);
		esc = 1.0;
	} else {
		float s_a = fract(s.x + semente);
		float s_b = fract(s.y + semente * 1.6180);
		float s_v = fract(s.z + semente * 2.4142);
		float s_vida = fract(COLOR.r + semente * 3.3028);
		float s_tam = fract(COLOR.g + semente * 4.2361);
		float s_px = fract(COLOR.b + semente * 5.1231);
		float s_py = fract(COLOR.a + semente * 6.0827);
		float s_pz = fract(UV2.x + semente * 7.0711);
		float indice = UV2.y;
		float t = tempo;
		float vida_p = vida * (1.0 - vida_aleatoria * s_vida);
		float aparece = step(indice, quantos - 0.0001);
		if (continuo > 0.5) {
			float fase = s_vida * vida;
			float total = tempo + vida - fase;
			float volta = floor(total / vida);
			t = total - volta * vida;
			s_px = fract(s_px + volta * 0.7549);
			s_py = fract(s_py + volta * 0.5698);
			s_pz = fract(s_pz + volta * 0.6180);
			s_a = fract(s_a + volta * 0.4142);
			vida_p = vida;
		}
		aparece *= step(t, vida_p);
		float x = clamp(t / vida_p, 0.0, 1.0);
		// direção sorteada num cone em volta de `dir_base`
		float th = s_a * abertura;
		float ph = s_b * 6.2832;
		vec3 dir = dir_base * cos(th) + (eixo_u * cos(ph) + eixo_v * sin(ph)) * sin(th);
		float v0 = vel_max * mix(vel_min, 1.0, s_v);
		float d = amort * mix(0.5, 1.0, s_tam);
		float tr = t;
		if (d > 0.0) {
			tr = min(t, v0 / d);
		}
		float dist = v0 * tr - 0.5 * d * tr * tr;
		vec3 origem = (vec3(s_px, s_py, s_pz) * 2.0 - 1.0) * caixa;
		vec3 n = normalize(vec3(s_px, s_py, s_pz) * 2.0 - 1.0 + vec3(0.0001));
		origem += n * esfera * s_v;
		centro = origem + dir * dist + 0.5 * grav * t * t;
		esc = mix(esc_min, esc_max, s_tam) * aparece;
		cor = mix(cor_ini, cor_fim, x);
		cor.a *= aparece;
	}
	// virado para a câmera: os cantos crescem no espaço da vista
	vec4 vista = MODELVIEW_MATRIX * vec4(centro, 1.0);
	vista.xy += (canto - 0.5) * tam * esc;
	VERTEX = vista.xyz;
	v_cor = cor;
}

void fragment() {
	vec4 t = texture(textura, UV);
	ALBEDO = t.rgb * v_cor.rgb;
	ALPHA = t.a * v_cor.a;
}
"""

var tempo = 0.0
var ativo = false
var _dura = 1.0
var _continuo = false
var _vida = 1.0
var _mat: ShaderMaterial = null


static func _shader(soma: bool) -> Shader:
	var chave = "soma" if soma else "mistura"
	if not _SHADERS.has(chave):
		var sh = Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, %s, depth_draw_never, cull_disabled, skip_vertex_transform;\n%s" % [
			"blend_add" if soma else "blend_mix", CORPO]
		_SHADERS[chave] = sh
	return _SHADERS[chave]


## `n` partículas com sorteios fixos (a semente embaralha a cada disparo).
static func _malha_de(n: int) -> ArrayMesh:
	if _MALHAS.has(n):
		return _MALHAS[n]
	var rng = RandomNumberGenerator.new()
	rng.seed = 104729 + n
	var v = PoolVector3Array()
	var c = PoolColorArray()
	var uv2 = PoolVector2Array()
	for i in n:
		var s = Vector3(rng.randf(), rng.randf(), rng.randf())
		var k = Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		var u2 = Vector2(rng.randf(), (float(i) + 0.5) / float(n))
		for j in 4:
			v.append(s)
			c.append(k)
			uv2.append(u2)
	return _montar(n, v, c, uv2)


static func _montar(n: int, v: PoolVector3Array, c: PoolColorArray, uv2: PoolVector2Array, guardar := true) -> ArrayMesh:
	var uv = PoolVector2Array()
	var idx = PoolIntArray()
	var cantos = PoolVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	for i in n:
		uv.append_array(cantos)
		var b = i * 4
		idx.append_array(PoolIntArray([b, b + 1, b + 2, b, b + 2, b + 3]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], 0)
	# a malha guarda sorteios, não posições: a caixa dela não diz onde as
	# partículas estão, e o Godot não deve achar que está fora da câmera
	m.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	if guardar:
		_MALHAS[n] = m
	return m


## Monta o efeito com `n` partículas, a textura e a mistura.
func preparar(n: int, textura: Texture, soma: bool, config: Dictionary) -> void:
	mesh = _malha_de(n)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader(soma)
	_mat.set_shader_param("textura", textura)
	for k in config:
		_mat.set_shader_param(k, config[k])
	_vida = float(config.get("vida", 1.0))
	material_override = _mat
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	visible = false


## Os flashes: um quadrado por posição, cada um com a sua fase.
func preparar_flashes(posicoes: Array, fases: Array, textura: Texture, tamanho: float) -> void:
	var n = posicoes.size()
	var v = PoolVector3Array()
	var c = PoolColorArray()
	var uv2 = PoolVector2Array()
	for i in n:
		for j in 4:
			v.append(posicoes[i])
			c.append(Color.white)
			uv2.append(Vector2(float(fases[i]), 0.0))
	mesh = _montar(n, v, c, uv2, false)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader(true)
	_mat.set_shader_param("textura", textura)
	_mat.set_shader_param("flashes", 1.0)
	_mat.set_shader_param("tam", tamanho)
	material_override = _mat
	cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF


## O brilho dos flashes neste quadro: dois números, e não 16 cores.
func piscar(relogio: float, festa: float) -> void:
	_mat.set_shader_param("relogio", fmod(relogio, 3600.0))
	_mat.set_shader_param("festa", festa)


## Solta as partículas (`quantos` de 0 a 1 é a parte que sai neste soco).
func disparar(quantos: float, dura: float, continuo := false) -> void:
	tempo = 0.0
	_dura = dura
	_continuo = continuo
	_mat.set_shader_param("tempo", 0.0)
	_mat.set_shader_param("semente", randf() * 61.0)
	_mat.set_shader_param("quantos", clamp(quantos, 0.0, 1.0))
	_mat.set_shader_param("continuo", 1.0 if continuo else 0.0)
	ativo = true
	visible = true


func avancar(delta: float) -> void:
	if not ativo:
		return
	tempo += delta
	if not _continuo and tempo > _dura:
		ativo = false
		visible = false
		return
	# a poeira contínua não deixa o relógio crescer sem fim (precisão do
	# shader): recua um número inteiro de vidas
	if _continuo and tempo > 600.0:
		tempo -= floor(500.0 / _vida) * _vida
	_mat.set_shader_param("tempo", tempo)


func set_uniforme(nome: String, valor) -> void:
	_mat.set_shader_param(nome, valor)


## A direção do cone em três vetores (o eixo e dois perpendiculares).
static func cone(direcao: Vector3, abertura_graus: float) -> Dictionary:
	var d = direcao.normalized()
	var ref = Vector3.UP if abs(d.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var u = d.cross(ref).normalized()
	var v = d.cross(u).normalized()
	return {"dir_base": d, "eixo_u": u, "eixo_v": v, "abertura": deg2rad(abertura_graus)}
