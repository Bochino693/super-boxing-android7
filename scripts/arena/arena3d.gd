class_name Arena3D
extends SubViewport

## A ARENA: um mundo 3D pequeno, renderizado numa janela própria e colado
## na tela 2D pelo `main.gd` (ver `ArenaQuadro`).
##
## Feita para TV Box:
##   • fundo, lona e luzes são TEXTURAS prontas (`tools/gerar_arena.py`)
##     em materiais sem iluminação: cada superfície é um desenho só;
##   • cordas e postes são malhas redondas com luz de verdade, e a janela
##     usa MSAA 4x — contorno liso sem supersample;
##   • a janela tem o tamanho real, em pixels, do buraco da moldura na
##     tela (nada de esticar textura pequena);
##   • partículas com quantidade fixa (mudar `amount` realoca buffers e
##     engasga) e shaders compilados no arranque (`aquecer`).

## Resolução cheia do quadro (1:1 na tela): o ringue sai nítido. 4.6 PRO:
## a arena vai de ponta a ponta na largura da tela (ver `ArenaQuadro`).
const TELA_LOGICA := Vector2(1080.0, 1540.0)
## Degrau magro para quando o vigia de desempenho apertar.
const FATOR_MAGRO := 0.75
const DESCE_PARA_MAGRO := 0.50
const SOBE_PARA_CHEIO := 0.62

## Enquadramento: quanto da altura da janela o lutador em pé ocupa, e
## quanto a câmera fica acima da mira (a leve inclinação de transmissão).
## 4.6 PRO: a câmera abriu — o lutador ocupa pouco mais da metade da
## altura e sobra lugar para o ringue inteiro, a treliça de luz e a torcida.
const OCUPACAO_DO_LUTADOR := 0.54
const CAMERA_ACIMA_DA_MIRA := 0.26
## O ângulo de abertura (vertical) da câmera.
const CAMPO_DE_VISAO := 50.0

## O ringue (metros). A meia largura põe os postes de trás nas bordas do
## quadro, que é o que faz a imagem ler como ringue.
const MEIO_RINGUE := 1.6
const ALTURAS_DAS_CORDAS := [0.42, 0.82, 1.22]
const PISO_DO_LUTADOR := 0.004

const TEX_FUNDO := "res://assets/arena/fundo.png"
const TEX_LONA := "res://assets/arena/lona.png"
const TEX_BRILHO := "res://assets/arena/brilho.png"
const TEX_FACHO := "res://assets/arena/facho.png"
const TEX_SAIA := "res://assets/arena/saia.png"

const COR_FUNDO := Color("07051a")
const TEX_TORCIDA_BAIXO := "res://assets/arena/torcida_baixo.png"
const TEX_TORCIDA_CIMA := "res://assets/arena/torcida_cima.png"

## A PLATEIA MEXE. Colunas de gente pulam e levantam os braços conforme
## `agito`; o telão de LED do fundo rola devagar o tempo todo.
## A TORCIDA NUNCA FICA PARADA. Uma plateia de ginásio mexe o tempo todo:
## cada coluna de gente balança no seu ritmo, braços sobem e descem em
## ondas ("ola") e, quando o golpe entra (`agito`), todo mundo pula. Tudo
## no shader: nenhum custo de processador.
const SHADER_TORCIDA := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D baixo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D cima : source_color, filter_linear_mipmap, repeat_disable;
uniform float agito = 0.0;
uniform float tempo = 0.0;
uniform float acende = 1.0;
// A FILEIRA: quantas pessoas (uma por coluna) e em que faixa da imagem.
uniform float colunas = 40.0;
uniform float v0 = 0.0;
uniform float v1 = 1.0;
uniform float semente = 0.0;
// CADA PESSOA É UM QUADRO DA MALHA (`_malha_da_fileira`): a coluna vem
// em UV2.x e o sorteio dela na cor do vértice. TODA conta com o relógio é
// feita aqui no VÉRTICE: a placa da S905L faz o vértice em 32 bits e o
// pixel em 16 — no pixel, `sin(tempo * 9)` andava aos saltos de meio
// radiano e a torcida tremia em vez de balançar.
varying float v_col;
varying float v_balanco;
varying float v_sobe;
varying float v_mao;
varying float v_celular;
void vertex() {
	float r = COLOR.r;
	float r2 = COLOR.g;
	v_col = UV2.x;
	float vida = 0.60 + agito * 0.40;
	float respira = sin(tempo * (1.6 + r2 * 1.4) + r * 6.2831) * 0.012 * vida;
	float pulo = max(0.0, sin(tempo * (3.0 + r * 3.6 + agito * 3.0) + r * 6.2831));
	pulo *= step(0.35 - agito * 0.3, r2) * (0.03 + 0.07 * agito);
	v_sobe = respira + pulo;
	// balanço de lado, dentro da própria coluna
	v_balanco = sin(tempo * (1.1 + r) + r * 9.0) * 0.05 * vida;
	// braços para o alto em ONDA ("ola") e, no golpe, todo mundo
	float centro = (v_col + 0.5) / colunas;
	float ola = 0.5 + 0.5 * sin(centro * 7.0 - tempo * 1.7 + semente);
	float braco = 0.5 + 0.5 * sin(tempo * (2.4 + r * 2.0) + r * 12.0);
	v_mao = step(0.55, braco * (0.35 + 0.65 * ola) + agito * 0.5) * step(0.25 - agito * 0.2, r);
	// flash de celular: um pontinho na mão de alguém, de vez em quando
	v_celular = step(0.985, fract(sin(v_col * 1.2989 + fract(floor(tempo * 2.2 + r * 7.0) * 0.137) * 37.0 + semente) * 53.71));
}
void fragment() {
	float dentro = clamp(UV.x + v_balanco, 0.0, 1.0);
	float y = UV.y + v_sobe;
	vec2 uv = vec2((v_col + dentro) / colunas, mix(v0, v1, clamp(y, 0.004, 0.996)));
	vec4 c = mix(texture(baixo, uv), texture(cima, uv), v_mao);
	vec2 celula = vec2(dentro - 0.5, (UV.y - 0.30) * 5.0);
	float celular = v_celular * c.a * (1.0 - smoothstep(0.04, 0.12, length(celula)));
	ALBEDO = c.rgb * acende * (1.0 + agito * 0.35) + vec3(0.9, 0.95, 1.0) * celular * 1.2;
	ALPHA = c.a * (0.86 + 0.14 * agito);
}
"""

## A TORCIDA DA S905L: o mesmo tipo de shader da build 97 (tudo no pixel,
## sem nada no vértice), com três correções:
##   • O ENCOSTO da arquibancada (faixa de baixo de cada fileira, ver
##     `tools/gerar_torcida.py`) fica PARADO: as pessoas pulam e balançam
##     atrás dele. Antes cada pessoa era uma barra que acabava num corte
##     reto, e o pé da faixa esticava em listras quando alguém pulava.
##   • FOLGA em cima da fileira: quem pula não perde a cabeça na borda.
##   • O movimento some na borda de cada coluna: sem a linha fina que o
##     salto de uma coluna para a outra desenhava entre as pessoas.
## E o RITMO vem pronto do processador, como fração de 0 a 1
## (`_fases_da_torcida`): a Mali-450 faz a conta do pixel em meia
## precisão, e `sin(tempo * 9)` com o relógio correndo andava aos saltos.
const SHADER_TORCIDA_SEGURA = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D baixo : hint_albedo;
uniform sampler2D cima : hint_albedo;
uniform float agito = 0.0;
uniform float acende = 1.0;
// A FILEIRA: quantas pessoas (uma por coluna) e em que faixa da imagem.
uniform float colunas = 40.0;
uniform float v0 = 0.0;
uniform float v1 = 1.0;
uniform float semente = 0.0;
// folga em cima (fração da faixa) e onde começa o encosto parado
uniform float folga = 0.12;
uniform float assento = 0.80;
// o ritmo: quatro velocidades de cada movimento, frações de 0 a 1
uniform vec4 f_respira = vec4(0.0);
uniform vec4 f_pulo = vec4(0.0);
uniform vec4 f_balanco = vec4(0.0);
uniform vec4 f_braco = vec4(0.0);
uniform float f_ola = 0.0;
uniform float tique = 0.0;

// Uma das quatro velocidades, pelo sorteio da pessoa.
vec4 escolhe(float r) {
	float a = step(0.25, r);
	float b = step(0.50, r);
	float c = step(0.75, r);
	return vec4(1.0 - a, a - b, b - c, c);
}

void fragment() {
	// CADA COLUNA É UMA PESSOA INTEIRA.
	float col = floor(UV.x * colunas);
	float r = fract(sin(col * 78.233 + semente * 13.7) * 43758.5453);
	float r2 = fract(sin(col * 12.9898 + semente * 7.1) * 24634.6345);
	float vida = 0.60 + agito * 0.40;
	float respira = sin(6.2831 * (dot(f_respira, escolhe(r2)) + r)) * 0.012 * vida;
	float pulo = max(0.0, sin(6.2831 * (dot(f_pulo, escolhe(r)) + r)));
	pulo *= step(0.35 - agito * 0.3, r2) * (0.03 + 0.07 * agito);
	float balanco = sin(6.2831 * (dot(f_balanco, escolhe(fract(r * 3.7))) + r * 1.43)) * 0.035 * vida;
	float dentro = fract(UV.x * colunas);
	// altura dentro da faixa: negativa na folga de cima
	float yb = UV.y * (1.0 + folga) - folga;
	float parado = step(assento, yb);
	float anda = smoothstep(0.0, 0.08, dentro) * (1.0 - smoothstep(0.92, 1.0, dentro)) * (1.0 - parado);
	float x = clamp(dentro + balanco * anda, 0.0, 1.0);
	// quem sobe mostra um pouco mais da camisa acima do encosto
	float y = mix(min(yb + (respira + pulo) * anda, assento - 0.004), yb, parado);
	vec2 uv = vec2((col + x) / colunas, mix(v0, v1, clamp(y, 0.004, 0.996)));
	vec4 a = texture(baixo, uv);
	vec4 b = texture(cima, uv);
	// braços para o alto em ONDA ("ola") e, no golpe, todo mundo
	float ola = 0.5 + 0.5 * sin(UV.x * 7.0 - 6.2831 * f_ola + semente);
	float braco = 0.5 + 0.5 * sin(6.2831 * (dot(f_braco, escolhe(r2)) + r * 1.91));
	float mao = step(0.55, braco * (0.35 + 0.65 * ola) + agito * 0.5) * step(0.25 - agito * 0.2, r);
	vec4 c = mix(a, b, mao);
	// acima da faixa (a folga) é ar
	c.a *= step(0.0, y);
	// flash de celular: um pontinho na mão de alguém, de vez em quando
	float celular = step(0.985, fract(sin(col * 12.9898 + floor(tempo * 2.2 + r * 7.0) * 3.7 + semente) * 43758.5)) * c.a;
	vec2 celula = vec2(dentro - 0.5, (UV.y - 0.30) * 5.0);
	celular *= 1.0 - smoothstep(0.04, 0.12, length(celula));
	ALBEDO = c.rgb * acende * (1.0 + agito * 0.35) + vec3(0.9, 0.95, 1.0) * celular * 1.2;
	ALPHA = c.a * (0.86 + 0.14 * agito);
}
"""
const SHADER_FUNDO := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float tempo = 0.0;
uniform float acende = 1.0;
uniform float agito = 0.0;
void fragment() {
	vec2 uv = UV;
	float faixa = step(0.155, uv.y) * step(uv.y, 0.265);
	uv.x = fract(uv.x + faixa * tempo * 0.018);
	vec3 c = texture(tex, uv).rgb;
	float pisca = 1.0 + faixa * agito * 0.35 * sin(tempo * 9.0);
	ALBEDO = c * acende * pisca;
}
"""

const SHADER_SAIA := """
shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float tempo = 0.0;
uniform float acende = 1.0;
void fragment() {
	// o letreiro rola devagar; a tinta é a textura (luz já assada)
	vec2 uv = vec2(fract(UV.x * 1.6 + tempo * 0.05), UV.y);
	ALBEDO = texture(tex, uv).rgb * acende;
}
"""

const ModoSeguro = preload("res://scripts/modo_seguro.gd")
const ARENA_ESCALA_SEGURA = 0.55
## A torcida da S905L (`SHADER_TORCIDA_SEGURA`): folga em cima da fileira e
## onde começa o encosto (o mesmo `ASSENTO` de `tools/gerar_torcida.py`).
const FOLGA_DA_TORCIDA = 0.12
const ASSENTO_DA_TORCIDA = 0.80
## As quatro velocidades de cada movimento (voltas por segundo).
const RITMO_RESPIRA = [0.25, 0.32, 0.40, 0.48]
const RITMO_PULO = [0.50, 0.65, 0.80, 0.95]
const RITMO_BALANCO = [0.17, 0.22, 0.27, 0.33]
const RITMO_BRACO = [0.38, 0.48, 0.58, 0.70]
var _fase_pulo = [0.0, 0.31, 0.62, 0.87]
var _relogio_da_torcida = -1.0

## A luz do lutador de uma passada, na mesma escala da luz da arena.
const LUZ_DO_LUTADOR = 0.52
const AMBIENTE_DO_LUTADOR = Color(0.15, 0.16, 0.26)

var lutador: Lutador3D = null
var camera: Camera3D = null
## 1.0 = tudo; abaixo de `DESCE_PARA_MAGRO` a janela encolhe.
var qualidade := 1.0

## A ESCALA DO 3D É SEMPRE 1. A build 202 tinha resolução dinâmica
## (`scaling_3d_scale`): abaixo de 100% o Godot 4.6 passa o 3D por uma
## imagem intermediária e um pós-processamento a cada quadro, e o lutador
## saía serrilhado e "quebrado" (a 60%). Saiu.
## O tamanho da arena acompanha só a tela real da TV Box (`Tela.fator`).
const ARQUIVO_DA_ESCALA_ANTIGO := "user://escala_3d.cfg"

var _mundo: Node3D = null
var _luz_chave: DirectionalLight3D = null
var _rim_quente: OmniLight3D = null
var _rim_frio: OmniLight3D = null
var _luz_rosto: OmniLight3D = null
const LUZ_DO_ROSTO := 0.85
const LUZ_DE_RECORTE := 1.45
var _mat_fundo: ShaderMaterial = null
var _mat_torcida: ShaderMaterial = null
var _gente: Node3D = null
var _mats_torcida: Array = []
## A torcida: quanto ela está agitada (0..1) e para onde vai.
var _agito := 0.0
var _agito_alvo := 0.0
var _agito_ate := 0.0
var _mat_lona: StandardMaterial3D = null
var _mat_saia: ShaderMaterial = null
var _flashes: MultiMeshInstance3D = null
var _flash_fase := PackedFloat32Array()
var _fachos: Array[MeshInstance3D] = []
var _impacto: GPUParticles3D = null
var _poeira: GPUParticles3D = null
var _sombra: MeshInstance3D = null
var _mat_sombra: StandardMaterial3D = null

var _distancia := 0.0
var _altura_da_camera := 0.0
var _altura_da_mira := 0.0

var _relogio := 0.0
var _tremor := 0.0
var _clarao := 0.0
var _empurrao := 0.0
var _publico := 0.0
var _ativa := false
var _magro := false
var _aquecendo := 0


func _ready() -> void:
	own_world_3d = true
	transparent_bg = false
	handle_input_locally = false
	screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	use_taa = false
	positional_shadow_atlas_size = 0
	scaling_3d_scale = 1.0
	# SEM NÍVEL DE DETALHE (LOD): o lutador é desenhado sempre com a malha
	# inteira. A malha simplificada mantinha a forma mas embaralhava a cor
	# pintada nos vértices — os cadarços da bota, as listras da luva e o
	# cabelo viravam um "xxxx" serrilhado.
	mesh_lod_threshold = 0.0
	if FileAccess.file_exists(ARQUIVO_DA_ESCALA_ANTIGO):
		DirAccess.remove_absolute(ARQUIVO_DA_ESCALA_ANTIGO)
	_aplicar_tamanho()
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_montar_mundo()


# ----------------------------------------------------------- montagem
func _montar_mundo() -> void:
	_mundo = Node3D.new()
	_mundo.name = "Mundo"
	add_child(_mundo)

	var ambiente := WorldEnvironment.new()
	ambiente.environment = _ambiente_de_ginasio()
	_mundo.add_child(ambiente)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMPO_DE_VISAO
	# Plano de corte bem perto: no soco na tela a luva chega a um palmo da
	# lente, e com o corte longe ela aparecia oca, "transparente".
	camera.near = 0.10
	camera.far = 30.0
	_mundo.add_child(camera)
	_calcular_enquadramento()
	camera.position = Vector3(0.0, _altura_da_camera, _distancia)
	camera.look_at_from_position(camera.position, Vector3(0.0, _altura_da_mira, 0.0), Vector3.UP)

	_luz_chave = DirectionalLight3D.new()
	_luz_chave.light_energy = LUZ_CHAVE
	_luz_chave.light_color = Color("fff1d8")
	# DE CIMA, como os refletores de um ringue: a sombra cai embaixo do
	# lutador (na lona, à vista) e o corpo ganha volume de cima para baixo.
	_luz_chave.rotation = Vector3(deg_to_rad(-68.0), deg_to_rad(22.0), 0.0)
	# SOMBRA DE VERDADE (4.6 PRO): o lutador projeta a sombra na lona e os
	# braços sombreiam o próprio corpo. Ortogonal: a cena é pequena e a
	# sombra fica firme, sem tremer quando a câmera passeia.
	# Ligada ou desligada UMA VEZ, pelo perfil da placa, e nunca mais:
	# trocar a sombra com o jogo rodando recompila os shaders de luz de
	# tudo o que ela ilumina (ver os degraus, mais abaixo).
	_luz_chave.shadow_enabled = Perfil.sombra_real()
	_luz_chave.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_luz_chave.directional_shadow_max_distance = Perfil.SOMBRA_DISTANCIA
	# Com o mapa mais justo, a borda sai firme: pouco desfoque, e o viés
	# mínimo para não "descolar" a sombra do braço no peito.
	_luz_chave.shadow_bias = 0.03
	_luz_chave.shadow_normal_bias = 1.0
	_luz_chave.shadow_blur = 1.0
	_mundo.add_child(_luz_chave)
	# As luzes de recorte (rosa e azul) redesenham o lutador uma vez cada:
	# na S905L ficam de fora (ver `Perfil.LUZES_DE_RECORTE`).
	if Perfil.LUZES_DE_RECORTE:
		_rim_quente = _luz_pontual(Color("ff2aa0"), Vector3(-2.3, 1.9, -0.6))
		_rim_frio = _luz_pontual(Color("33d6ff"), Vector3(2.3, 1.8, -0.6))
		# A LUZ DO ROSTO (4.6 PRO): com o refletor principal lá em cima, o
		# rosto ficava na sombra da testa. Uma luz quente e fraca, da altura
		# da câmera, devolve os olhos e a expressão — só no lutador.
		_luz_rosto = _luz_pontual(Color("ffd8b8"), Vector3(0.7, 2.1, 2.4))
		_luz_rosto.light_energy = LUZ_DO_ROSTO
		_luz_rosto.omni_range = 5.5

	_montar_fundo()
	_montar_ringue()
	_montar_ginasio()
	_montar_fachos()
	_montar_flashes()
	_montar_particulas()


func _luz_pontual(cor: Color, onde: Vector3) -> OmniLight3D:
	var luz := OmniLight3D.new()
	# SÓ NO LUTADOR. No renderizador da TV Box cada luz a mais é mais uma
	# passada de desenho em TUDO o que ela alcança: com alcance de 6 m as
	# três luzes redesenhavam a lona, o fundo, a torcida e o ringue inteiro
	# a cada quadro. Elas existem para recortar o lutador; agora só ele as
	# recebe (`Lutador3D.CAMADA_DAS_LUZES`).
	luz.light_cull_mask = Lutador3D.CAMADA_DAS_LUZES
	luz.light_color = cor
	luz.light_energy = 2.0
	luz.omni_range = 6.0
	luz.position = onde
	_mundo.add_child(luz)
	return luz


static func _material_plano(textura: Texture2D, aditivo := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = textura
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if aditivo:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _material_solido(cor: Color, rugosidade := 0.5, brilho := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	m.metallic_specular = 0.6
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


func _peca(malha: Mesh, material: Material, onde: Vector3, giro := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = material
	mi.position = onde
	mi.rotation = giro
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(mi)
	return mi


func _montar_fundo() -> void:
	# A plateia pintada: um plano grande bem atrás do ringue.
	_mat_fundo = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_FUNDO
	_mat_fundo.shader = sh
	_mat_fundo.set_shader_parameter("tex", load(TEX_FUNDO))
	var quadro := QuadMesh.new()
	quadro.size = Vector2(10.4, 7.8)
	_peca(quadro, _mat_fundo, Vector3(0.0, 1.9, -4.8))
	# A GENTE da plateia, em silhueta, na frente do fundo pintado.
	if ResourceLoader.exists(TEX_TORCIDA_BAIXO) and ResourceLoader.exists(TEX_TORCIDA_CIMA):
		var sh2 := Shader.new()
		sh2.code = SHADER_TORCIDA
		var baixo: Texture2D = load(TEX_TORCIDA_BAIXO)
		var cima: Texture2D = load(TEX_TORCIDA_CIMA)
		# TRÊS FILEIRAS, cada uma no seu plano (a de trás mais alta e mais
		# longe): colunas e faixas iguais às de `tools/gerar_torcida.py`.
		_gente = Node3D.new()
		_gente.name = "Torcida"
		_mundo.add_child(_gente)
		_mats_torcida.clear()
		var fileiras := [
			[52.0, 0.0, 150.0, Vector3(0.0, 0.60, -4.45)],
			[40.0, 150.0, 320.0, Vector3(0.0, 0.20, -4.32)],
			[30.0, 320.0, 512.0, Vector3(0.0, -0.24, -4.20)],
		]
		for k in fileiras.size():
			var fl: Array = fileiras[k]
			var mat := ShaderMaterial.new()
			mat.shader = sh2
			mat.set_shader_parameter("baixo", baixo)
			mat.set_shader_parameter("cima", cima)
			mat.set_shader_parameter("colunas", fl[0])
			mat.set_shader_parameter("v0", float(fl[1]) / 512.0)
			mat.set_shader_parameter("v1", float(fl[2]) / 512.0)
			mat.set_shader_parameter("semente", float(k) * 3.3)
			_mats_torcida.append(mat)
			var altura := 2.5 * (float(fl[2]) - float(fl[1])) / 512.0
			var mi := _peca(_malha_da_fileira(int(fl[0]), 10.0, altura, k), mat, fl[3])
			_mundo.remove_child(mi)
			_gente.add_child(mi)
		_mat_torcida = _mats_torcida[0]
	# O chão do ginásio entre o ringue e a plateia: escuro, só para o
	# tablado parecer suspenso.
	var chao := PlaneMesh.new()
	# (vai até a frente da câmera: descendo no nocaute, ela via o vazio)
	chao.size = Vector2(14.0, 12.0)
	_peca(chao, _material_solido(Color("0b0810"), 0.9), Vector3(0.0, -0.62, -0.6))


## A FILEIRA DA TORCIDA: UM QUADRO POR PESSOA. O shader (`SHADER_TORCIDA`)
## lê a coluna de cada pessoa em UV2.x e o sorteio dela (ritmo do pulo, do
## braço, do balanço) na cor do vértice. Num quadro só (QuadMesh, até a
## build 203) toda a fileira caía na coluna 0: UMA pessoa esticada por dez
## metros de arquibancada, balançando — a faixa borrada que corria atrás
## do ringue no lugar da torcida.
static func _malha_da_fileira(colunas: int, largura: float, altura: float, semente: int) -> ArrayMesh:
	var sorteio := RandomNumberGenerator.new()
	sorteio.seed = 7919 + semente * 104729
	var pos := PackedVector3Array()
	var normais := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cores := PackedColorArray()
	var indices := PackedInt32Array()
	var passo := largura / float(colunas)
	for c in colunas:
		var x0 := -largura * 0.5 + passo * float(c)
		var x1 := x0 + passo
		var cor := Color(sorteio.randf(), sorteio.randf(), 0.0, 1.0)
		var base := pos.size()
		for canto in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
			pos.append(Vector3(lerpf(x0, x1, canto.x), altura * (0.5 - canto.y), 0.0))
			normais.append(Vector3.BACK)
			uv.append(canto)
			uv2.append(Vector2(float(c), 0.0))
			cores.append(cor)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha


func _montar_ringue() -> void:
	var m := MEIO_RINGUE
	# A LONA RECEBE A SOMBRA (4.6 PRO): parte da pintura acende sozinha
	# (emissão, a luz já assada na textura) e parte só onde a luz chega —
	# na sombra do lutador ela escurece.
	var tex_lona: Texture2D = load(TEX_LONA)
	_mat_lona = StandardMaterial3D.new()
	_mat_lona.albedo_texture = tex_lona
	_mat_lona.albedo_color = Color(LONA_LUZ, LONA_LUZ, LONA_LUZ)
	_mat_lona.roughness = 1.0
	_mat_lona.metallic_specular = 0.0
	_mat_lona.emission_enabled = true
	_mat_lona.emission_texture = tex_lona
	_mat_lona.emission = Color.WHITE
	_mat_lona.emission_energy_multiplier = LONA_PROPRIA
	_mat_lona.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var lona := PlaneMesh.new()
	lona.size = Vector2(m * 2.0, m * 2.0)
	_peca(lona, _mat_lona, Vector3.ZERO)
	# A borda do tablado: faixa escura sob a lona.
	var tablado := BoxMesh.new()
	tablado.size = Vector3(m * 2.0 + 0.12, 0.6, m * 2.0 + 0.12)
	# O topo do tablado fica 3 cm abaixo da lona (e não 2 mm): na TV Box a
	# profundidade tem menos precisão e os dois planos colados "brigavam"
	# — era o chão piscando embaixo dos pés do lutador.
	_peca(tablado, _material_solido(Color("120a12"), 0.8), Vector3(0.0, -0.33, 0.0))
	# A SAIA DO RINGUE: letreiro de LED na frente do tablado. Quando a
	# câmera desce (nocaute, jogador no chão) era a lateral lisa do tablado
	# que aparecia embaixo do quadro — uma faixa cinza sem desenho.
	if ResourceLoader.exists(TEX_SAIA):
		_mat_saia = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER_SAIA
		_mat_saia.shader = sh
		_mat_saia.set_shader_parameter("tex", load(TEX_SAIA))
		var saia := QuadMesh.new()
		saia.size = Vector2(m * 2.0 + 0.12, 0.60)
		_peca(saia, _mat_saia, Vector3(0.0, -0.31, m + 0.062))

	# Postes de trás: vermelho à esquerda, azul à direita, com protetor.
	var poste := CylinderMesh.new()
	poste.top_radius = 0.055
	poste.bottom_radius = 0.055
	poste.height = 1.5
	# REDONDOS DE VERDADE em 1080p: com 16/20 lados os postes e os
	# protetores mostravam as faces ("quadrados") na TV. Os lados a mais
	# são poucos triângulos — nada perto do lutador.
	poste.radial_segments = 28
	var protetor := CylinderMesh.new()
	protetor.top_radius = 0.10
	protetor.bottom_radius = 0.10
	protetor.height = 1.02
	protetor.radial_segments = 36
	var metal := _material_solido(Color("9aa3b5"), 0.28)
	metal.metallic = 0.8
	for lado in [-1.0, 1.0]:
		var cor := Color("d3162f") if lado < 0.0 else Color("1f4fd1")
		_peca(poste, metal, Vector3(lado * m, 0.75, -m))
		_peca(protetor, _material_solido(cor, 0.45, 0.12), Vector3(lado * m, 0.86, -m))

	# Cordas: tubos redondos. Só as de trás e as laterais — nada cruza a
	# frente do lutador.
	var corda := CylinderMesh.new()
	corda.top_radius = 0.024
	corda.bottom_radius = 0.024
	corda.height = m * 2.0
	corda.radial_segments = 16
	corda.rings = 1
	var tintas := [
		_material_solido(Color("ffd014"), 0.35, 0.12),
		_material_solido(Color("ff2ab0"), 0.35, 0.22),
		_material_solido(Color("46dcff"), 0.35, 0.12),
	]
	# AS CORDAS DE TRÁS ESTICAM DE VERDADE: malha com anéis ao longo do
	# comprimento e um shader que as curva para trás no meio (as pontas
	# ficam presas nos postes). Ver `_mexer_cordas`.
	var corda_fundo := corda.duplicate() as CylinderMesh
	corda_fundo.rings = 24
	var cores_cordas := [Color("ffd014"), Color("ff2ab0"), Color("46dcff")]
	var brilhos := [0.12, 0.22, 0.12]
	_cordas_fundo.clear()
	_mat_cordas.clear()
	for i in range(ALTURAS_DAS_CORDAS.size()):
		var y: float = ALTURAS_DAS_CORDAS[i]
		var mat := ShaderMaterial.new()
		mat.shader = _shader_corda()
		mat.set_shader_parameter("cor", cores_cordas[i])
		mat.set_shader_parameter("brilho", brilhos[i])
		mat.set_shader_parameter("meia", m)
		_mat_cordas.append(mat)
		_cordas_fundo.append(_peca(corda_fundo, mat, Vector3(0.0, y, -m), Vector3(0.0, 0.0, PI * 0.5)))
		for lado in [-1.0, 1.0]:
			_peca(corda, tintas[i], Vector3(lado * m, y, 0.0), Vector3(PI * 0.5, 0.0, 0.0))


## AS CORDAS DE TRÁS CEDEM quando o lutador cai nelas — E A CADA SOCO DO
## JOGADOR (ver `golpe`): esticam para trás no meio e voltam com um
## balanço de mola (passam um pouco do lugar e assentam).
var _cordas_fundo: Array = []
var _mat_cordas: Array = []
static var _shader_da_corda: Shader = null

static func _shader_corda() -> Shader:
	if _shader_da_corda == null:
		_shader_da_corda = Shader.new()
		_shader_da_corda.code = """
shader_type spatial;
uniform vec4 cor : source_color = vec4(1.0);
uniform float brilho = 0.12;
uniform float empurra = 0.0;
uniform float sobe = 0.0;
uniform float meia = 1.6;
void vertex() {
	// O comprimento da corda é o eixo Y da malha; as pontas (nos postes)
	// não se mexem, o meio vai mais longe — uma curva de corda esticada.
	float t = clamp(abs(VERTEX.y) / meia, 0.0, 1.0);
	float curva = 1.0 - t * t;
	VERTEX.z -= empurra * curva;
	// e balança na vertical (o eixo X da malha é o "para cima" da corda
	// deitada): é o balanço que se vê de frente, como corda de ringue.
	VERTEX.x += sobe * curva;
}
void fragment() {
	ALBEDO = cor.rgb;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
	EMISSION = cor.rgb * brilho;
}
"""
	return _shader_da_corda
var _cordas_pos := 0.0
var _cordas_vel := 0.0

func _mexer_cordas(delta: float) -> void:
	var alvo := lutador.pressao_nas_cordas() if lutador != null else 0.0
	if alvo <= 0.0 and absf(_cordas_pos) < 0.001 and absf(_cordas_vel) < 0.001:
		return
	var d := minf(delta, 0.05)
	_cordas_vel += (alvo - _cordas_pos) * 140.0 * d
	_cordas_vel *= exp(-7.0 * d)
	_cordas_pos += _cordas_vel * d
	for i in range(_mat_cordas.size()):
		# a corda do meio (na altura das costas) cede mais
		var peso: float = [0.55, 1.0, 0.75][mini(i, 2)]
		var mat := _mat_cordas[i] as ShaderMaterial
		mat.set_shader_parameter("empurra", 0.55 * _cordas_pos * peso)
		# cada corda balança num tempo um pouco diferente (não em bloco)
		mat.set_shader_parameter("sobe", 0.24 * _cordas_vel / 11.8 * peso * (1.0 if i % 2 == 0 else -0.8))
	if alvo > 0.6:
		_publico = maxf(_publico, 0.4)


func _montar_fachos() -> void:
	# Fachos de refletor varrendo a plateia, aditivos e baratos.
	var textura: Texture2D = load(TEX_FACHO)
	var malha := QuadMesh.new()
	malha.size = Vector2(1.5, 6.0)
	for i in range(3):
		var mat := _material_plano(textura, true)
		mat.albedo_color = [Color("ff3ab4"), Color("b58cff"), Color("48d6ff")][i]
		var f := _peca(malha, mat, Vector3(-2.4 + 2.4 * float(i), 3.2, -4.3))
		_fachos.append(f)


func _montar_flashes() -> void:
	# Flashes de câmera na plateia: estrela com halo (nunca quadrado).
	var quantos := 16
	var malha := QuadMesh.new()
	malha.size = Vector2(0.42, 0.42)
	var tinta := _material_plano(load(TEX_BRILHO), true)
	tinta.vertex_color_use_as_albedo = true
	tinta.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha
	mm.instance_count = quantos
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	_flash_fase.resize(quantos)
	for i in range(quantos):
		var t := Transform3D()
		t.origin = Vector3(rng.randf_range(-3.6, 3.6), rng.randf_range(0.2, 2.6), rng.randf_range(-4.6, -4.3))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color(0, 0, 0, 0))
		_flash_fase[i] = rng.randf() * TAU
	_flashes = MultiMeshInstance3D.new()
	_flashes.multimesh = mm
	_flashes.material_override = tinta
	_flashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(_flashes)


func _montar_particulas() -> void:
	var brilho := _material_plano(load(TEX_BRILHO), true)
	brilho.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	brilho.vertex_color_use_as_albedo = true
	var estrela := QuadMesh.new()
	estrela.size = Vector2(0.13, 0.13)
	estrela.material = brilho
	var processo := ParticleProcessMaterial.new()
	processo.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	processo.emission_sphere_radius = 0.14
	processo.direction = Vector3(0.0, 0.2, 1.0)
	processo.spread = 80.0
	processo.initial_velocity_min = 2.4
	processo.initial_velocity_max = 6.8
	processo.gravity = Vector3(0.0, -5.5, 0.0)
	processo.damping_min = 1.5
	processo.damping_max = 3.0
	processo.scale_min = 0.35
	processo.scale_max = 1.0
	processo.color = Color("ffe7a8")
	var some := Gradient.new()
	some.set_color(0, Color(1, 1, 1, 1))
	some.set_color(1, Color(1, 0.5, 0.2, 0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = some
	processo.color_ramp = rampa
	_impacto = _particulas("ParticulasImpacto", int(96 * Perfil.particulas_3d()), 0.75, 0.96, processo, estrela, Vector3(0.0, 1.34, 0.36))

	var po := _material_plano(_mancha_redonda(), true)
	po.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	po.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	po.vertex_color_use_as_albedo = true
	var disco := QuadMesh.new()
	disco.size = Vector2(0.34, 0.34)
	disco.material = po
	var po_proc := ParticleProcessMaterial.new()
	po_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	po_proc.emission_box_extents = Vector3(0.7, 0.04, 0.38)
	po_proc.direction = Vector3(0.0, 1.0, 0.0)
	po_proc.spread = 65.0
	po_proc.initial_velocity_min = 0.45
	po_proc.initial_velocity_max = 1.3
	po_proc.gravity = Vector3(0.0, -0.6, 0.0)
	po_proc.scale_min = 0.6
	po_proc.scale_max = 1.6
	po_proc.color = Color(0.62, 0.68, 0.85, 0.30)
	var desvanece := Gradient.new()
	desvanece.set_color(0, Color(1, 1, 1, 1))
	desvanece.set_color(1, Color(1, 1, 1, 0))
	var rampa_po := GradientTexture1D.new()
	rampa_po.gradient = desvanece
	po_proc.color_ramp = rampa_po
	_poeira = _particulas("PoeiraDaLona", int(36 * Perfil.particulas_3d()), 1.35, 0.88, po_proc, disco, Vector3(0.0, 0.08, -0.35))


func _particulas(
	nome: String, quantidade: int, vida: float, explosao: float,
	processo: ParticleProcessMaterial, malha: Mesh, onde: Vector3
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = nome
	# A quantidade é FIXA. A força do golpe muda `amount_ratio`, que não
	# realoca nada; mudar `amount` refazia os buffers a cada soco.
	p.amount = quantidade
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = explosao
	p.process_material = processo
	p.draw_pass_1 = malha
	p.position = onde
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	_mundo.add_child(p)
	return p


## Mancha redonda e macia (branco no centro, transparente na borda),
## feita pela própria GPU: sombra de contato e poeira.
static func _mancha_redonda() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func instalar() -> bool:
	# O LUTADOR 3D: o boxeador (`LutadorBoxeador3D`, corpo humano com IK e
	# expressões). Nesta versão para a TV Box S905L os lutadores reserva
	# (guerreiro animado, Vanguard, Mixamo) ficaram de fora: nunca eram
	# usados e só ocupavam espaço no APK.
	var modelo := LutadorBoxeador3D.new()
	modelo.name = "Lutador"
	modelo.position.y = PISO_DO_LUTADOR
	_mundo.add_child(modelo)
	modelo.montar()
	if modelo.completo():
		lutador = modelo
	else:
		_mundo.remove_child(modelo)
		modelo.queue_free()
	_montar_sombra()
	_luzes_de_recorte_so_no_lutador()
	return lutador != null and lutador.completo()


## AS LUZES DE RECORTE (rosa e azul) SÓ ACENDEM O LUTADOR.
##
## No renderizador da TV Box cada luz pontual é mais uma PASSADA inteira
## em tudo o que ela alcança: ringue, cordas, lona e lutador eram
## desenhados três vezes por quadro. O recorte colorido só importa no
## contorno do lutador — então só ele está na camada dessas luzes. O
## resto da arena fica com a luz principal, numa passada só.
const CAMADA_DO_LUTADOR := 2

func _luzes_de_recorte_so_no_lutador() -> void:
	if lutador == null:
		return
	for no in lutador.find_children("*", "VisualInstance3D", true, false):
		(no as VisualInstance3D).layers |= CAMADA_DO_LUTADOR
	for luz in [_rim_quente, _rim_frio, _luz_rosto]:
		if luz != null:
			luz.light_cull_mask = CAMADA_DO_LUTADOR


func _montar_sombra() -> void:
	var malha := PlaneMesh.new()
	malha.size = Vector2(1.0, 0.52)
	_mat_sombra = StandardMaterial3D.new()
	_mat_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_sombra.albedo_texture = _mancha_redonda()
	# Com a sombra de verdade (4.6 PRO), a mancha fica só como contato.
	_mat_sombra.albedo_color = Color(0.0, 0.0, 0.02, 0.55 if Perfil.sombra_real() else 0.9)
	_mat_sombra.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# 1,5 cm acima da lona (2 mm piscava na TV Box, colado no chão).
	_sombra = _peca(malha, _mat_sombra, Vector3(0.0, 0.015, 0.0))


# ---------------------------------------------------------- degraus
## OS DEGRAUS DO GRÁFICO. A arena é a conta mais cara do jogo, e a mesma
## cena não cabe em toda TV Box. Cada degrau tira UMA coisa, a que menos
## se vê primeiro:
##
##   0 COMPLETO      tudo;
##   1 SEM FACHOS    os cones de luz e os flashes da plateia
##                   (transparentes, cobrem boa parte da tela);
##   2 3D A 85%      a arena desenhada com 85% dos pixels de cada lado
##                   (com o antisserrilhado, a borda continua lisa; a
##                   imagem fica um pouco mais macia);
##   3 3D A 70%      idem, 70%;
##   4 SEM MSAA      a borda do lutador sem antisserrilhado — por último,
##                   porque é o que mais aparece (escadinha).
##
## A LUZ NÃO É DEGRAU (build 208). Até a 207 os degraus também desligavam
## a sombra real, a luz do rosto e as luzes de recorte — e no Godot 4.6
## (renderizador de compatibilidade) ligar ou desligar uma luz ou uma
## sombra troca a VARIANTE do shader de tudo o que ela ilumina: o lutador,
## a lona, as cordas compilavam de novo, e na Mali da TV Box cada
## compilação é a tela parada por um instante. Com o degrau ajustado no
## meio da luta, era o engasgo que aparecia justamente na luta. Agora as
## luzes e a sombra são escolhidas uma vez, pelo perfil da placa
## (`Perfil.sombra_real`), e nunca mudam com o jogo rodando.
##
## O degrau 1 entra na hora (é só esconder uma peça já compilada). O
## tamanho e o antisserrilhado (2 a 4) realocam a imagem da arena — no
## quadro da troca o lutador sumiria —, então eles esperam a arena sair da
## tela (`ligar`).
##
## O jogo escolhe sozinho (`main.gd`, `_ajustar_degrau`): mede a luta em
## janelas de 4 s e, se ela ficou abaixo da meta de quadros, desce um
## degrau.
const DEGRAUS := ["COMPLETO", "SEM FACHOS", "3D A 85%", "3D A 70%", "SEM MSAA"]
var degrau := 0

func aplicar_degrau(n: int) -> void:
	degrau = clampi(n, 0, DEGRAUS.size() - 1)
	var enfeites := _enfeites_do_degrau()
	for f in _fachos:
		f.visible = enfeites
	for c in _cones:
		c.visible = enfeites
	if _flashes != null:
		_flashes.visible = enfeites
	if not _ativa:
		_aplicar_tamanho()

func _enfeites_do_degrau() -> bool:
	return degrau < 1

func _msaa() -> Viewport.MSAA:
	return Perfil.ARENA_MSAA if degrau < 4 else Viewport.MSAA_DISABLED

func _escala_do_degrau() -> float:
	if degrau >= 3:
		return 0.70
	if degrau == 2:
		return 0.85
	return 1.0

## A sombra do mapa está desenhada? (Sem ela a sombra de contato escurece.)
func _sombra_real() -> bool:
	return Perfil.sombra_real()


# -------------------------------------------------------- tamanho/MSAA
func _aplicar_tamanho() -> void:
	# O TAMANHO DA ARENA: a resolução lógica (1080x1540) na escala da SAÍDA
	# da TV Box (`Perfil.fator_3d`: 1,0 com o Android em 1080p, 0,67 em
	# 720p — desenhar mais pixels do que a TV recebe é trabalho jogado
	# fora) e na do degrau. Nunca muda no meio da luta — trocar o tamanho
	# realoca a imagem, e no quadro da troca o lutador sumia.
	var novo := _tamanho_do_degrau()
	if size != novo:
		size = novo
	msaa_3d = _msaa()


func _tamanho_do_degrau() -> Vector2i:
	return Vector2i((TELA_LOGICA * Perfil.ARENA_ESCALA * Perfil.fator_3d * _escala_do_degrau()).round())


## O degrau pede um tamanho ou antisserrilhado que ainda não entrou (a
## arena está na tela; entra na próxima vez que ela ligar). Enquanto isso,
## medir de novo a mesma luta e descer mais um degrau seria descer às
## cegas — `main._ajustar_degrau` espera.
func degrau_pendente() -> bool:
	return size != _tamanho_do_degrau() or msaa_3d != _msaa()


func _ajustar_tamanho() -> void:
	pass


# ---------------------------------------------------------- interface
func modelo_avancado() -> bool:
	return lutador != null and lutador.completo()


func ligar(ativa: bool) -> void:
	if _ativa == ativa:
		return
	_ativa = ativa
	if ativa:
		_aplicar_tamanho()
	elif _aquecendo <= 0 and _etapa < 0:
		render_target_update_mode = SubViewport.UPDATE_DISABLED


func ativa() -> bool:
	return _ativa


## PRÉ-AQUECIMENTO. Renderiza a arena fora da tela por alguns quadros
## com todas as poses e as partículas no ar: shaders compilam e texturas
## sobem para a GPU no arranque, e não no primeiro soco da noite.
func aquecer(quadros := 24) -> void:
	_aquecendo = quadros
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _impacto != null:
		_impacto.restart()
	if _poeira != null:
		_poeira.restart()


## O AQUECIMENTO EM ETAPAS, UMA COISA NOVA POR VEZ.
##
## Renderizar tudo de uma vez no primeiro quadro (mundo, lutador com
## clarão e expressões, partículas) compila dezenas de shaders e sobe
## todas as texturas no MESMO quadro — numa TV Box isso é a tela parada
## por vários segundos, e era o "trava em 87%". Em etapas, cada quadro só
## traz uma novidade, e o carregador continua animando entre elas.
const ETAPAS_DE_AQUECIMENTO := 7
var _etapa := -1

func _enfeites_visiveis(sim: bool) -> void:
	if _gente != null:
		_gente.visible = sim
	var enfeites := sim and _enfeites_do_degrau()
	if _flashes != null:
		_flashes.visible = enfeites
	for f in _fachos:
		f.visible = enfeites
	for c in _cones:
		c.visible = enfeites

func etapa_de_aquecimento(n: int) -> void:
	_etapa = n
	match n:
		0:
			# o ringue e o fundo, sem lutador, torcida nem luzes
			if lutador != null:
				lutador.visible = false
			_enfeites_visiveis(false)
			render_target_update_mode = SubViewport.UPDATE_ALWAYS
		1:
			# a torcida (shader próprio), os fachos e os flashes
			_enfeites_visiveis(true)
		2:
			if lutador != null:
				lutador.visible = true
				lutador.atualizar(0.0)
		3:
			# o clarão do golpe (a passada aditiva por cima do corpo)
			if lutador != null:
				lutador.clarao(1.0)
				lutador.atualizar(0.0)
		4:
			# as expressões do rosto
			if lutador != null:
				lutador.mostrar_pose(&"celebra")
		5:
			if _impacto != null:
				_impacto.restart()
			if _poeira != null:
				_poeira.restart()
		_:
			_etapa = -1
			_enfeites_visiveis(true)
			preparar()
			if lutador != null:
				lutador.visible = true
			render_target_update_mode = SubViewport.UPDATE_ONCE if _ativa else SubViewport.UPDATE_DISABLED


func golpe(forca: float, derruba := false, pontos := -1, ultimo := false) -> Dictionary:
	_tremor = clampf(0.35 + forca, 0.0, 1.35)
	_clarao = clampf(0.4 + forca * 0.6, 0.0, 1.0)
	_empurrao = forca
	# O SOCO ESTICA AS CORDAS DE TRÁS: o baque passa pelo lutador e chega
	# nelas — mais forte o soco, mais longe elas vão (e voltam balançando).
	_cordas_vel += 2.5 + clampf(forca, 0.0, 1.2) * 6.5
	_publico = maxf(_publico, clampf(0.08 + forca * (1.15 if derruba else 0.85), 0.0, 1.0))
	var economia := 1.0 if qualidade >= 0.55 else 0.55
	if _impacto != null:
		_impacto.amount_ratio = clampf(lerpf(0.22, 1.0, forca) * economia, 0.05, 1.0)
		_impacto.restart()
	if derruba and _poeira != null:
		_poeira.amount_ratio = economia
		_poeira.restart()
	if lutador == null:
		return {"nocaute": false, "dano": 0.0, "reacao": "", "desdenhou": false}
	var resposta := lutador.bater(forca, derruba, pontos, ultimo)
	if bool(resposta.get("desdenhou", false)):
		_publico = maxf(_publico, 0.66)
		_clarao = maxf(_clarao, 0.28)
	return resposta


## O CAMBALEIO do soco na tela: a câmera balança e rola um pouco, e o
## balanço morre em `segundos`. Frequências e fases sorteadas: nunca
## igual. Liso de propósito — nada de congelar a imagem.
var _camb_t := -1.0
var _camb_dur := 1.6
var _camb := PackedFloat32Array()

func cambalear(segundos: float) -> void:
	_camb_t = 0.0
	_camb_dur = maxf(segundos, 0.3)
	_camb = PackedFloat32Array([
		randf_range(2.6, 4.6), randf() * TAU, randf_range(0.05, 0.09),
		randf_range(2.0, 3.8), randf() * TAU, randf_range(0.03, 0.06),
		randf_range(1.6, 3.0), randf() * TAU, randf_range(0.05, 0.10),
	])
	_tremor = maxf(_tremor, 0.9)
	_clarao = maxf(_clarao, 0.35)


## A TORCIDA REAGE: `intensidade` 0..1 por `segundos`, depois acalma.
func agitar(intensidade: float, segundos := 4.0) -> void:
	_agito_alvo = maxf(_agito_alvo, clampf(intensidade, 0.0, 1.0))
	_agito_ate = maxf(_agito_ate, _relogio + segundos)


func fim_de_rodada(desfecho: String) -> void:
	if lutador != null:
		lutador.fim_de_rodada(desfecho)


## O soco final acertou o jogador: quem ganhou comemora (ver `Lutador3D.venceu`).
func venceu(festa := "") -> void:
	if lutador != null:
		lutador.venceu(festa)


## Pede ao lutador o soco na câmera. Falso se ele não pode agora.
func soco_na_tela() -> bool:
	return lutador != null and _ativa and lutador.soco_na_tela()


## O lutador que venceu nocauteia o jogador (soco final na câmera).
func nocaute_no_jogador() -> bool:
	return lutador != null and _ativa and lutador.soco_final()


## Verdadeiro uma vez, no quadro em que a luva "acerta" a tela.
func tela_atingida() -> bool:
	return lutador != null and lutador.tela_atingida()


func preparar() -> void:
	_cam_pos = Vector3.INF
	_chao = 0.0
	_chao_alvo = 0.0
	_agito_alvo = 0.0
	_agito_ate = 0.0
	if lutador != null:
		lutador.preparar()
	_tremor = 0.0
	_clarao = 0.0
	_publico = 0.0


func guardar(ativo: bool) -> void:
	if lutador != null:
		lutador.guardar(ativo)


func dano() -> float:
	return lutador.dano if lutador != null else 0.0


func na_lona() -> bool:
	return lutador != null and lutador.queda > 0.35


func avancar(delta: float) -> void:
	if _etapa >= 0 and not _ativa:
		render_target_update_mode = SubViewport.UPDATE_ALWAYS
		return
	if _aquecendo > 0:
		_passo_do_aquecimento()
		if not _ativa:
			return
	if not _ativa:
		return
	_relogio += delta
	_tremor = maxf(0.0, _tremor - delta * 2.2)
	_clarao = maxf(0.0, _clarao - delta * 2.4)
	_empurrao = maxf(0.0, _empurrao - delta * 1.6)
	_publico = maxf(0.0, _publico - delta * 0.72)
	if _camb_t >= 0.0:
		_camb_t += delta
		if _camb_t > _camb_dur:
			_camb_t = -1.0
	if _relogio > _agito_ate:
		_agito_alvo = maxf(0.0, _agito_alvo - delta * 0.35)
	_agito = lerpf(_agito, maxf(_agito_alvo, _publico * 0.6), 1.0 - exp(-delta * 4.0))
	if lutador != null:
		lutador.ponto_da_camera = camera.global_position
		lutador.atualizar(delta)
	_mexer_cordas(delta)
	_sombra_de_contato()
	_camera(delta)
	_luzes()
	_piscar()
	render_target_update_mode = SubViewport.UPDATE_ONCE
	_ajustar_tamanho()


func escala_3d() -> float:
	return float(size.x) / TELA_LOGICA.x


func _passo_do_aquecimento() -> void:
	_aquecendo -= 1
	if lutador != null:
		var poses := lutador.poses()
		if not poses.is_empty():
			lutador.mostrar_pose(StringName(poses[_aquecendo % poses.size()]))
	if _aquecendo <= 0:
		if lutador != null:
			lutador.preparar()
		render_target_update_mode = SubViewport.UPDATE_ONCE if _ativa else SubViewport.UPDATE_DISABLED


# ------------------------------------------------------------ a cena
func _calcular_enquadramento() -> void:
	var figura := Lutador3D.ALTURA_DA_FIGURA
	var janela := figura / OCUPACAO_DO_LUTADOR
	var meia := deg_to_rad(camera.fov) * 0.5
	_distancia = janela / (2.0 * tan(meia))
	var base := PISO_DO_LUTADOR - (janela - figura) * 0.5
	var inclinacao := atan(CAMERA_ACIMA_DA_MIRA / _distancia)
	_altura_da_camera = base + _distancia * tan(inclinacao + meia)
	_altura_da_mira = _altura_da_camera - CAMERA_ACIMA_DA_MIRA


## A CÂMERA ANDA, NÃO PULA. Empurrão do golpe, queda, soco na tela e o
## passeio lento viram um ALVO; a câmera persegue esse alvo com uma mola
## amortecida (sem ultrapassar). Antes o empurrão do soco entrava inteiro
## num quadro só e a imagem dava um pulo seco a cada golpe — e de novo
## quando o segundo soco era armado. O tremor fica de fora da mola: ele é
## para ser seco.
var _cam_pos := Vector3.INF
var _cam_mira := Vector3.ZERO
var _chao := 0.0
var _chao_alvo := 0.0

## O jogador foi nocauteado (câmera vai ao chão) ou levantou (volta).
func jogador_no_chao(sim: bool) -> void:
	_chao_alvo = 1.0 if sim else 0.0
const CAMERA_MOLA := 7.5

func _camera(delta := 0.0) -> void:
	var passeio := sin(_relogio * 0.33) * 0.16
	var sacode := Vector3.ZERO
	if _tremor > 0.02:
		sacode = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.4, 0.4)) * _tremor * 0.05
	var extra := lutador.camera_extra() if lutador != null else Vector2.ZERO
	var pos := Vector3(passeio * (1.0 - clampf(extra.x * 1.5, 0.0, 1.0)), _altura_da_camera + sin(_relogio * 0.21) * 0.05 - extra.y, _distancia - _empurrao * 0.30 - extra.x)
	var mira := Vector3(0.0, _altura_da_mira + _empurrao * 0.06, 0.0)
	# NO SOCO NA TELA A CÂMERA OLHA NO ROSTO. Ela chegava perto do lutador
	# ainda mirando o meio do corpo — de perto, o meio do corpo é a
	# cintura, e o quadro enchia de calção. Agora, conforme ela se
	# aproxima, sobe até a altura dos olhos e mira o rosto: o soco vem na
	# cara de quem joga, com a expressão do lutador no centro.
	var perto := clampf(extra.x / 0.72, 0.0, 1.0)
	if perto > 0.001:
		var rosto := Lutador3D.ALTURA_DA_FIGURA * 0.90 + deslocamento_vertical()
		var k := perto * perto * (3.0 - 2.0 * perto)
		pos.y = lerpf(pos.y, rosto + 0.03, k)
		mira.y = lerpf(mira.y, rosto - 0.04, k)
	var caido := lutador.queda if lutador != null else 0.0
	if caido > 0.001:
		# No nocaute a câmera afasta e desce: um corpo caído é largo.
		var t := ease(caido, 0.5)
		pos = pos.lerp(Vector3(0.0, _altura_da_camera * 0.54, _distancia * 1.07), t)
		mira = mira.lerp(Vector3(0.0, _altura_da_mira * 0.58, 0.0), t)
	var rolo := 0.0
	# O JOGADOR NO CHÃO: depois do nocaute a câmera cai até a lona, meio
	# de lado, olhando o lutador de baixo — quem perdeu vê o ginásio do
	# chão. Cai rápido (com um quique) e só levanta na próxima rodada.
	_chao = move_toward(_chao, _chao_alvo, delta * (2.4 if _chao_alvo > _chao else 1.2))
	if _chao > 0.001:
		var t := _chao * _chao * (3.0 - 2.0 * _chao)
		var quique := sin(clampf(_chao, 0.0, 1.0) * PI) * 0.05 * (1.0 if _chao_alvo > 0.5 else 0.0)
		var pos_chao := Vector3(0.42, 0.14 + quique, _distancia * 0.74)
		var mira_chao := Vector3(-0.05, Lutador3D.ALTURA_DA_FIGURA * 0.78 + deslocamento_vertical(), 0.0)
		pos = pos.lerp(pos_chao, t)
		mira = mira.lerp(mira_chao, t)
		rolo += 0.30 * t
	var balanco := Vector3.ZERO
	if _camb_t >= 0.0 and _camb.size() >= 9:
		var t := _camb_t
		var some := pow(1.0 - clampf(t / _camb_dur, 0.0, 1.0), 1.6)
		var c := _camb
		sacode += Vector3(sin(t * c[0] * TAU * 0.5 + c[1]) * c[2], sin(t * c[3] * TAU * 0.5 + c[4]) * c[5], 0.0) * some
		balanco = Vector3(sin(t * c[3] * TAU * 0.4 + c[1]) * c[2] * 0.6, 0.0, 0.0) * some
		rolo = sin(t * c[6] * TAU * 0.5 + c[7]) * c[8] * some
	if _cam_pos == Vector3.INF or delta <= 0.0:
		_cam_pos = pos
		_cam_mira = mira
	else:
		var k := 1.0 - exp(-CAMERA_MOLA * minf(delta, 0.05))
		_cam_pos = _cam_pos.lerp(pos, k)
		_cam_mira = _cam_mira.lerp(mira, k)
	camera.position = _cam_pos + sacode
	camera.look_at(_cam_mira + balanco, Vector3.UP)
	if absf(rolo) > 0.0001:
		camera.rotate_object_local(Vector3.FORWARD, rolo)


## Quanto o corpo do lutador subiu/desceu (agachado na guarda, pulando).
func deslocamento_vertical() -> float:
	if lutador != null and lutador.has_method("deslocamento"):
		return float(lutador.deslocamento().y)
	return 0.0


func _luzes() -> void:
	if lutador != null:
		lutador.clarao(_clarao)
	var extra := _clarao * 5.0
	if _rim_quente != null:
		_rim_quente.light_energy = LUZ_DE_RECORTE + extra
		_rim_frio.light_energy = LUZ_DE_RECORTE + extra
	_luz_chave.light_energy = LUZ_CHAVE + _clarao * 1.0
	# O lutador de uma passada (`Perfil.LUTADOR_LEVE`) faz a própria luz:
	# recebe a direção da luz principal já no espaço da câmera.
	if lutador != null and lutador.has_method("luz"):
		var para_a_luz = _luz_chave.global_transform.basis.z * camera.global_transform.basis
		lutador.call("luz", para_a_luz.normalized(), _luz_chave.light_color,
			LUZ_DO_LUTADOR * _luz_chave.light_energy, AMBIENTE_DO_LUTADOR)
	# Materiais sem luz acendem pelo albedo: o salão inteiro pisca junto.
	var acende := 1.0 + _clarao * 0.55
	_mat_fundo.set_shader_parameter("acende", acende)
	_mat_fundo.set_shader_parameter("tempo", _relogio)
	_mat_fundo.set_shader_parameter("agito", _agito)
	for mat in _mats_torcida:
		(mat as ShaderMaterial).set_shader_parameter("acende", acende)
		(mat as ShaderMaterial).set_shader_parameter("tempo", _relogio)
		(mat as ShaderMaterial).set_shader_parameter("agito", _agito)
	_mat_lona.emission_energy_multiplier = LONA_PROPRIA * acende
	_animar_ginasio()
	if _mat_saia != null:
		_mat_saia.set_shader_parameter("tempo", _relogio)
		_mat_saia.set_shader_parameter("acende", acende)
	for i in range(_fachos.size()):
		var f := _fachos[i]
		f.rotation.z = sin(_relogio * (0.35 + 0.1 * float(i)) + float(i) * 2.1) * 0.35
		var mat := f.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.20 + _publico * 0.35 + _clarao * 0.25 + _agito * 0.25
		f.rotation.z += sin(_relogio * 2.6 + float(i)) * 0.25 * _agito


## O RITMO DA TORCIDA, pronto: cada movimento em quatro velocidades, como
## fração da volta (0 a 1). A conta com o relógio grande é feita aqui, em
## 64 bits; a placa de vídeo só recebe números pequenos. O pulo acelera com
## o agito sem dar tranco: a fase é somada quadro a quadro.
func _fases_da_torcida() -> void:
	var dt = 0.0 if _relogio_da_torcida < 0.0 else clamp(_relogio - _relogio_da_torcida, 0.0, 0.25)
	_relogio_da_torcida = _relogio
	for k in 4:
		_fase_pulo[k] = fposmod(_fase_pulo[k] + dt * (RITMO_PULO[k] + _agito * 0.48), 1.0)
	var respira = _quatro_fases(RITMO_RESPIRA)
	var balanco = _quatro_fases(RITMO_BALANCO)
	var braco = _quatro_fases(RITMO_BRACO)
	var pulo = Color(_fase_pulo[0], _fase_pulo[1], _fase_pulo[2], _fase_pulo[3])
	var ola = fposmod(_relogio * 1.7 / TAU, 1.0)
	var tique = fposmod(floor(_relogio * 2.2), 64.0)
	for mat in _mats_torcida:
		var m = mat as ShaderMaterial
		m.set_shader_parameter("f_respira", respira)
		m.set_shader_parameter("f_pulo", pulo)
		m.set_shader_parameter("f_balanco", balanco)
		m.set_shader_parameter("f_braco", braco)
		m.set_shader_parameter("f_ola", ola)
		m.set_shader_parameter("tique", tique)

func _quatro_fases(ritmo: Array) -> Color:
	return Color(fposmod(_relogio * ritmo[0], 1.0), fposmod(_relogio * ritmo[1], 1.0),
		fposmod(_relogio * ritmo[2], 1.0), fposmod(_relogio * ritmo[3], 1.0))


func _piscar() -> void:
	var mm := _flashes.multimesh
	for i in range(mm.instance_count):
		var fase: float = _flash_fase[i]
		var base := maxf(0.0, sin(_relogio * 1.7 + fase) - 0.93) * 12.0
		var festa := (_clarao + _publico * 0.6 + _agito * 0.5) * maxf(0.0, sin(fase * 3.1 + _relogio * 22.0))
		var a := clampf(base + festa, 0.0, 1.0)
		mm.set_instance_color(i, Color(a, a * 0.97, a * 0.92, a))


func _sombra_de_contato() -> void:
	if _sombra == null or lutador == null:
		return
	var desloc := lutador.deslocamento()
	var caido := clampf(lutador.queda, 0.0, 1.0)
	_sombra.position = Vector3(desloc.x, 0.015, desloc.z * 0.6)
	_sombra.scale = Vector3(lerpf(1.0, 1.5, caido), 1.0, lerpf(1.0, 1.3, caido))
	_mat_sombra.albedo_color.a = lerpf(0.9, 0.6, caido) * (0.6 if _sombra_real() else 1.0)


# ------------------------------------------------------------ 4.6 PRO
## A LUZ PRINCIPAL (o refletor de cima, que faz a sombra).
const LUZ_CHAVE := 1.75
const TEX_FAIXA := "res://assets/arena/faixa_lateral.png"

## A lona: quanto da pintura vem da luz (e escurece na sombra) e quanto
## acende sozinha.
## A LONA TINHA LUZ PRÓPRIA DEMAIS (0,62) e quase nenhuma do refletor:
## com o brilho por cima, na TV ela saía branca, "pálida", sem a sombra do
## lutador. Agora metade da luz é dela e o resto vem do refletor — a cor
## da arte volta e a sombra aparece.
const LONA_LUZ := 0.34
const LONA_PROPRIA := 0.38

## O facho de luz de um refletor: um cone transparente que acende o ar
## (mais forte perto da lâmpada, sumindo na borda e no chão). Só a face da
## frente do cone é desenhada, com o dobro da força: o mesmo brilho de
## antes (frente + costas) pela metade dos pixels.
const SHADER_FACHO := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 cor : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float forca = 0.10;
uniform float meia_altura = 1.5;
varying float v_h;
void vertex() {
	v_h = VERTEX.y;
}
void fragment() {
	float t = clamp(v_h / meia_altura * 0.5 + 0.5, 0.0, 1.0);
	float meio = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.7);
	float a = forca * meio * (0.18 + 0.82 * t * t) * smoothstep(0.0, 0.22, t);
	ALBEDO = cor.rgb;
	ALPHA = clamp(a * 2.0, 0.0, 1.0);
}
"""

## A treliça de alumínio: um quadro vazado (dois tubos e os zigue-zagues)
## desenhado no próprio material — nada de dezenas de peças.
const SHADER_TRELICA := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 cor : source_color = vec4(0.30, 0.31, 0.38, 1.0);
uniform float gomos = 14.0;
void fragment() {
	float u = fract(UV.x * gomos);
	float v = UV.y;
	float tubo = step(v, 0.14) + step(0.86, v);
	float d1 = abs(v - u);
	float d2 = abs(v - (1.0 - u));
	float zig = step(min(d1, d2), 0.07);
	float coluna = step(u, 0.05);
	if (clamp(tubo + zig + coluna, 0.0, 1.0) < 0.5) {
		discard;
	}
	ALBEDO = cor.rgb;
	METALLIC = 0.75;
	ROUGHNESS = 0.38;
}
"""

var _lampadas: Array[StandardMaterial3D] = []
var _mats_fachos: Array[ShaderMaterial] = []
## Os cones de luz dos refletores (ver `_facho`): somem no degrau 1.
var _cones: Array[MeshInstance3D] = []
var _poeira_no_ar: GPUParticles3D = null


## O AMBIENTE DE GINÁSIO: névoa das luzes, brilho (bloom), reflexo da
## plateia no couro e no ouro, contraste e cor de transmissão.
func _ambiente_de_ginasio() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a3f66")
	env.ambient_light_energy = 0.42
	if ResourceLoader.exists(TEX_FUNDO):
		var ceu := Sky.new()
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(TEX_FUNDO)
		ceu.sky_material = pano
		ceu.radiance_size = Sky.RADIANCE_SIZE_128
		env.sky = ceu
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("24163f")
	env.fog_light_energy = 1.0
	env.fog_density = 0.045
	env.fog_sky_affect = 0.0
	# Brilho só nas placas que aguentam (ver `Perfil.brilho`): sem ele o 3D
	# é desenhado direto na imagem final, sem cópia intermediária.
	env.glow_enabled = Perfil.brilho()
	env.glow_intensity = 0.75
	env.glow_strength = 1.05
	# Brilho só no que é luz de verdade (luvas, LEDs, refletores). Com o
	# limiar em 0,92 e o "bloom" ligado, a lona e a pele também acendiam e a
	# cena inteira ficava lavada.
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.tonemap_white = 6.0
	# SEM AJUSTE DE CONTRASTE/SATURAÇÃO (build 208). No Godot 4.6 de
	# compatibilidade esse ajuste não cabe no desenho do 3D: ele obriga a
	# arena a ser desenhada numa imagem intermediária, copiada (com o
	# antisserrilhado, mais uma cópia para resolver as amostras) e
	# repassada inteira por um shader de pós-processo — três passadas de
	# tela cheia por quadro, só para 6% de contraste e 12% de cor. Sem ele
	# o 3D é desenhado direto na imagem final, e o antisserrilhado se
	# resolve dentro da própria placa (Mali), de graça. O vigor que o
	# ajuste dava vem agora da exposição e da cor do ambiente.
	env.adjustment_enabled = false
	return env


## O GINÁSIO EM VOLTA DO RINGUE: a treliça de luz com os refletores e os
## fachos, as faixas dos lados, os protetores das cordas, as luzes dos
## postes e a poeira dançando na luz.
func _montar_ginasio() -> void:
	var trelica := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_TRELICA
	trelica.shader = sh
	# duas vigas, uma atrás da outra, sobre o fundo do ringue
	var viga := QuadMesh.new()
	viga.size = Vector2(5.4, 0.30)
	_peca(viga, trelica, Vector3(0.0, 3.30, -3.0))
	_peca(viga, trelica, Vector3(0.0, 3.86, -3.62))
	var baixo := QuadMesh.new()
	baixo.size = Vector2(5.4, 0.62)
	_peca(baixo, trelica, Vector3(0.0, 3.15, -3.31), Vector3(-PI * 0.5, 0.0, 0.0))
	# OS REFLETORES pendurados na treliça, e os fachos até o ringue
	var carcaca := CylinderMesh.new()
	carcaca.top_radius = 0.055
	carcaca.bottom_radius = 0.075
	carcaca.height = 0.20
	carcaca.radial_segments = 14
	var lente := CylinderMesh.new()
	lente.top_radius = 0.062
	lente.bottom_radius = 0.062
	lente.height = 0.02
	lente.radial_segments = 14
	var metal := _material_solido(Color("1d1e26"), 0.4)
	metal.metallic = 0.6
	var cores := [Color("fff1d8"), Color("ff4fb8"), Color("fff1d8"), Color("6fe2ff"), Color("fff1d8"), Color("ff4fb8"), Color("fff1d8")]
	for i in range(7):
		var x := -2.25 + 0.75 * float(i)
		var onde := Vector3(x, 3.02, -2.92)
		var alvo := Vector3(x * 0.32, 0.0, -0.35 + 0.15 * absf(x))
		var giro := _giro_para(onde, alvo)
		var corpo := _peca(carcaca, metal, onde)
		corpo.basis = giro
		var vidro := StandardMaterial3D.new()
		vidro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		vidro.albedo_color = cores[i]
		vidro.emission_enabled = true
		vidro.emission = cores[i]
		vidro.emission_energy_multiplier = 3.0
		var luz := _peca(lente, vidro, onde - giro.y * 0.105)
		luz.basis = giro
		_lampadas.append(vidro)
		# o facho (só os de luz branca e os coloridos de dentro)
		if i >= 1 and i <= 5:
			_facho(onde - giro.y * 0.11, alvo, cores[i], 0.30 if cores[i] == Color("fff1d8") else 0.22)
	# DOIS FACHOS DE CIMA, de refletores fora do quadro, cruzando no ringue
	_facho(Vector3(-1.9, 5.2, 1.2), Vector3(0.15, 0.0, -0.2), Color("fff3e0"), 0.07)
	_facho(Vector3(1.9, 5.2, 1.2), Vector3(-0.15, 0.0, -0.2), Color("fff3e0"), 0.07)
	# AS FAIXAS DOS LADOS, penduradas da treliça
	if ResourceLoader.exists(TEX_FAIXA):
		var faixa := QuadMesh.new()
		faixa.size = Vector2(0.56, 1.54)
		var pano := _material_plano(load(TEX_FAIXA))
		for lado in [-1.0, 1.0]:
			_peca(faixa, pano, Vector3(lado * 2.30, 2.62, -3.95), Vector3(0.0, -lado * 0.30, 0.0))
	# OS PROTETORES DAS CORDAS nos postes de trás (vermelho e azul) e a
	# luz no alto de cada poste
	var almofada := CapsuleMesh.new()
	almofada.radius = 0.062
	almofada.height = 0.26
	almofada.radial_segments = 20
	almofada.rings = 6
	var tampa := CylinderMesh.new()
	tampa.top_radius = 0.07
	tampa.bottom_radius = 0.07
	tampa.height = 0.05
	tampa.radial_segments = 24
	for lado in [-1.0, 1.0]:
		var cor := Color("d3162f") if lado < 0.0 else Color("1f4fd1")
		var mat := _material_solido(cor, 0.35, 0.18)
		var centro := Vector3(lado * MEIO_RINGUE, 0.0, -MEIO_RINGUE)
		var para_dentro := (Vector3(0.0, 0.0, 0.0) - centro).normalized()
		for y in ALTURAS_DAS_CORDAS:
			var pad := _peca(almofada, mat, centro + Vector3(0.0, float(y), 0.0) + para_dentro * 0.09)
			pad.basis = _giro_para(Vector3.ZERO, -para_dentro)
		var led := StandardMaterial3D.new()
		led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led.albedo_color = cor.lightened(0.4)
		led.emission_enabled = true
		led.emission = cor.lightened(0.2)
		led.emission_energy_multiplier = 2.5
		_peca(tampa, led, centro + Vector3(0.0, 1.52, 0.0))
		_lampadas.append(led)
	# A POEIRA DANÇANDO NA LUZ (bem pouca, devagar)
	var ponto := _material_plano(_mancha_redonda(), true)
	ponto.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	ponto.vertex_color_use_as_albedo = true
	var grao := QuadMesh.new()
	grao.size = Vector2(0.035, 0.035)
	grao.material = ponto
	var ar := ParticleProcessMaterial.new()
	ar.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	ar.emission_box_extents = Vector3(2.0, 1.3, 1.6)
	ar.direction = Vector3(0.2, 1.0, 0.0)
	ar.spread = 180.0
	ar.initial_velocity_min = 0.02
	ar.initial_velocity_max = 0.08
	ar.gravity = Vector3(0.0, -0.01, 0.0)
	ar.scale_min = 0.5
	ar.scale_max = 1.4
	ar.color = Color(1.0, 0.92, 0.8, 0.35)
	_poeira_no_ar = GPUParticles3D.new()
	_poeira_no_ar.name = "PoeiraNoAr"
	_poeira_no_ar.amount = int(48 * Perfil.particulas_3d())
	_poeira_no_ar.lifetime = 9.0
	_poeira_no_ar.preprocess = 9.0
	_poeira_no_ar.process_material = ar
	_poeira_no_ar.draw_pass_1 = grao
	_poeira_no_ar.position = Vector3(0.0, 2.1, -1.2)
	_poeira_no_ar.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 4.5, 6))
	_mundo.add_child(_poeira_no_ar)


## Um giro cujo eixo Y aponta de `alvo` para `de` (o "para cima" de um
## cilindro apontado para o alvo).
static func _giro_para(de: Vector3, alvo: Vector3) -> Basis:
	var y := (de - alvo).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


## Um facho de luz de `de` até `alvo`.
func _facho(de: Vector3, alvo: Vector3, cor: Color, forca: float) -> void:
	var comprimento := de.distance_to(alvo)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.07
	cone.bottom_radius = 0.42 + comprimento * 0.10
	cone.height = comprimento
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER_FACHO
	mat.shader = sh
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("forca", forca)
	mat.set_shader_parameter("meia_altura", comprimento * 0.5)
	mat.set_meta("base", forca)
	var mi := _peca(cone, mat, (de + alvo) * 0.5)
	mi.basis = _giro_para(de, alvo)
	_mats_fachos.append(mat)
	_cones.append(mi)


## Os refletores respiram com a torcida e acendem no golpe.
func _animar_ginasio() -> void:
	var vivo := 1.0 + _clarao * 1.6 + _agito * 0.35 + _publico * 0.4
	for i in range(_mats_fachos.size()):
		var mat := _mats_fachos[i]
		var onda := 0.92 + 0.08 * sin(_relogio * (0.7 + 0.13 * float(i)) + float(i))
		mat.set_shader_parameter("forca", float(mat.get_meta("base")) * vivo * onda)
	for i in range(_lampadas.size()):
		_lampadas[i].emission_energy_multiplier = 2.6 + _clarao * 3.0 + 0.4 * sin(_relogio * 2.0 + float(i) * 1.7)
