class_name Arena3D
extends Viewport

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

## Resolução cheia do quadro (1:1 na tela): o ringue sai nítido.
const TELA_LOGICA = Vector2(1008.0, 1422.0)
## Degrau magro para quando o vigia de desempenho apertar.
const FATOR_MAGRO = 0.75
const DESCE_PARA_MAGRO = 0.50
const SOBE_PARA_CHEIO = 0.62

## Enquadramento: quanto da altura da janela o lutador em pé ocupa, e
## quanto a câmera fica acima da mira (a leve inclinação de transmissão).
const OCUPACAO_DO_LUTADOR = 0.66
const CAMERA_ACIMA_DA_MIRA = 0.21

## O ringue (metros). A meia largura põe os postes de trás nas bordas do
## quadro, que é o que faz a imagem ler como ringue.
const MEIO_RINGUE = 1.6
const ALTURAS_DAS_CORDAS = [0.42, 0.82, 1.22]
const PISO_DO_LUTADOR = 0.004

const TEX_FUNDO = "res://assets/arena/fundo.png"
const TEX_LONA = "res://assets/arena/lona.png"
const TEX_BRILHO = "res://assets/arena/brilho.png"
const TEX_FACHO = "res://assets/arena/facho.png"
const TEX_SAIA = "res://assets/arena/saia.png"

const COR_FUNDO = Color("07051a")
const TEX_TORCIDA_BAIXO = "res://assets/arena/torcida_baixo.png"
const TEX_TORCIDA_CIMA = "res://assets/arena/torcida_cima.png"

## A PLATEIA MEXE. Colunas de gente pulam e levantam os braços conforme
## `agito`; o telão de LED do fundo rola devagar o tempo todo.
## A TORCIDA NUNCA FICA PARADA. Uma plateia de ginásio mexe o tempo todo:
## cada coluna de gente balança no seu ritmo, braços sobem e descem em
## ondas ("ola") e, quando o golpe entra (`agito`), todo mundo pula. Tudo
## no shader: nenhum custo de processador.
const SHADER_TORCIDA = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D baixo : hint_albedo;
uniform sampler2D cima : hint_albedo;
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
const SHADER_FUNDO = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : hint_albedo;
uniform float tempo = 0.0;
uniform float acende = 1.0;
uniform float agito = 0.0;
// quanto o telão já rolou (0..1), calculado fora: meia precisão na Mali-450
uniform float rolagem = 0.0;
void fragment() {
	vec2 uv = UV;
	float faixa = step(0.155, uv.y) * step(uv.y, 0.265);
	uv.x = fract(uv.x + faixa * rolagem);
	vec3 c = texture(tex, uv).rgb;
	float pisca = 1.0 + faixa * agito * 0.35 * sin(tempo * 9.0);
	ALBEDO = c * acende * pisca;
}
"""

const SHADER_SAIA = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : hint_albedo;
uniform float tempo = 0.0;
uniform float acende = 1.0;
uniform float rolagem = 0.0;
void fragment() {
	// o letreiro rola devagar; a tinta é a textura (luz já assada)
	vec2 uv = vec2(fract(UV.x * 1.6 + rolagem), UV.y);
	ALBEDO = texture(tex, uv).rgb * acende;
}
"""

## A luz do lutador de uma passada, na mesma escala da luz da arena.
const LUZ_DO_LUTADOR = 0.52
const AMBIENTE_DO_LUTADOR = Color(0.15, 0.16, 0.26)

var lutador: Lutador3D = null
var camera: Camera = null
## 1.0 = tudo; abaixo de `DESCE_PARA_MAGRO` a janela encolhe.
var qualidade = 1.0

var _mundo: Spatial = null
var _luz_chave: DirectionalLight = null
var _rim_quente: OmniLight = null
var _rim_frio: OmniLight = null
var _mat_fundo: ShaderMaterial = null
var _mat_torcida: ShaderMaterial = null
var _gente: Spatial = null
var _mats_torcida: Array = []
## A torcida: quanto ela está agitada (0..1) e para onde vai.
var _agito = 0.0
var _agito_alvo = 0.0
var _agito_ate = 0.0
var _mat_lona: SpatialMaterial = null
var _mat_saia: ShaderMaterial = null
var _flashes: MultiMeshInstance = null
var _flash_fase = PoolRealArray()
var _fachos: Array = []
var _impacto: CPUParticles = null
var _poeira: CPUParticles = null
var _sombra: MeshInstance = null
var _mat_sombra: SpatialMaterial = null

var _distancia = 0.0
var _altura_da_camera = 0.0
var _altura_da_mira = 0.0

var _relogio = 0.0
var _tremor = 0.0
var _clarao = 0.0
var _empurrao = 0.0
var _publico = 0.0
var _ativa = false
var _magro = false
var _aquecendo = 0


func _ready() -> void:
	own_world = true
	transparent_bg = false
	handle_input_locally = false
	shadow_atlas_size = 0
	# Godot 3: sem HDR (o OpenGL ES 2.0 não tem) e a imagem já de pé para
	# ser colada no quadro 2D.
	hdr = false
	usage = Viewport.USAGE_3D
	render_target_v_flip = true
	# A arena é desenhada menor e ampliada no quadro: com filtro, e não em
	# blocos (no Godot 4 o filtro vinha do projeto).
	get_texture().flags = Texture.FLAG_FILTER
	_aplicar_tamanho()
	render_target_update_mode = Viewport.UPDATE_DISABLED
	_montar_mundo()


# ----------------------------------------------------------- montagem
func _montar_mundo() -> void:
	_mundo = Spatial.new()
	_mundo.name = "Mundo"
	add_child(_mundo)

	var ambiente = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
	env.ambient_light_color = Color("39456a")
	env.ambient_light_energy = 0.55
	ambiente.environment = env
	_mundo.add_child(ambiente)

	camera = Camera.new()
	camera.name = "Camera"
	camera.fov = 44.0
	# Plano de corte bem perto: no soco na tela a luva chega a um palmo da
	# lente, e com o corte longe ela aparecia oca, "transparente".
	camera.near = 0.10
	camera.far = 30.0
	_mundo.add_child(camera)
	_calcular_enquadramento()
	camera.translation = Vector3(0.0, _altura_da_camera, _distancia)
	camera.look_at_from_position(camera.translation, Vector3(0.0, _altura_da_mira, 0.0), Vector3.UP)

	_luz_chave = DirectionalLight.new()
	_luz_chave.light_energy = 1.6
	_luz_chave.light_color = Color("fff1d8")
	_luz_chave.rotation = Vector3(deg2rad(-52.0), deg2rad(28.0), 0.0)
	_mundo.add_child(_luz_chave)
	# As luzes de recorte (rosa e azul) redesenham o lutador uma vez cada:
	# na S905L ficam de fora (ver `Perfil.LUZES_DE_RECORTE`).
	if Perfil.LUZES_DE_RECORTE:
		_rim_quente = _luz_pontual(Color("ff2aa0"), Vector3(-2.3, 1.9, -0.6))
		_rim_frio = _luz_pontual(Color("33d6ff"), Vector3(2.3, 1.8, -0.6))

	_montar_fundo()
	_montar_ringue()
	_montar_fachos()
	_montar_flashes()
	_montar_particulas()


func _luz_pontual(cor: Color, onde: Vector3) -> OmniLight:
	var luz = OmniLight.new()
	luz.light_color = cor
	luz.light_energy = 2.0
	luz.omni_range = 6.0
	luz.translation = onde
	_mundo.add_child(luz)
	return luz


static func _material_plano(textura: Texture, aditivo := false) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	m.flags_unshaded = true
	m.albedo_texture = textura
	if aditivo:
		m.flags_transparent = true
		m.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
		m.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
		m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	return m


static func _material_solido(cor: Color, rugosidade := 0.5, brilho := 0.0) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	m.metallic_specular = 0.6
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy = brilho
	return m


## Uma fileira da plateia: um quadro por pessoa, lado a lado, do mesmo
## tamanho do plano antigo. Em cada quadro: UV de 0 a 1 (a pessoa inteira),
## a coluna em UV2.x e dois sorteios fixos na cor do vértice.
static func _malha_da_fileira(colunas: int, largura: float, altura: float, semente: float) -> ArrayMesh:
	var v = PoolVector3Array()
	var uv = PoolVector2Array()
	var uv2 = PoolVector2Array()
	var cor = PoolColorArray()
	var idx = PoolIntArray()
	for c in colunas:
		var x0 = (float(c) / float(colunas) - 0.5) * largura
		var x1 = (float(c + 1) / float(colunas) - 0.5) * largura
		var r = fposmod(sin(float(c) * 0.731 + semente * 1.37) * 47.53, 1.0)
		var r2 = fposmod(sin(float(c) * 1.279 + semente * 0.71) * 31.17, 1.0)
		var base = v.size()
		for canto in [[x0, 0.5, 0.0, 0.0], [x1, 0.5, 1.0, 0.0], [x1, -0.5, 1.0, 1.0], [x0, -0.5, 0.0, 1.0]]:
			v.append(Vector3(canto[0], canto[1] * altura, 0.0))
			uv.append(Vector2(canto[2], canto[3]))
			uv2.append(Vector2(float(c), 0.0))
			cor.append(Color(r, r2, 0.0, 1.0))
		for t in [0, 1, 2, 0, 2, 3]:
			idx.append(base + t)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cor
	arrays[Mesh.ARRAY_INDEX] = idx
	var malha = ArrayMesh.new()
	# Sem compressão: a coluna (até 52) e o sorteio chegam exatos.
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], 0)
	return malha


func _peca(malha: Mesh, material: Material, onde: Vector3, giro := Vector3.ZERO) -> MeshInstance:
	var mi = MeshInstance.new()
	mi.mesh = malha
	mi.material_override = material
	mi.translation = onde
	mi.rotation = giro
	mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(mi)
	return mi


func _montar_fundo() -> void:
	# A plateia pintada: um plano grande bem atrás do ringue.
	_mat_fundo = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SHADER_FUNDO
	_mat_fundo.shader = sh
	_mat_fundo.set_shader_param("tex", load(TEX_FUNDO))
	var quadro = QuadMesh.new()
	quadro.size = Vector2(10.4, 7.8)
	_peca(quadro, _mat_fundo, Vector3(0.0, 1.9, -4.8))
	# A GENTE da plateia, em silhueta, na frente do fundo pintado.
	if ResourceLoader.exists(TEX_TORCIDA_BAIXO) and ResourceLoader.exists(TEX_TORCIDA_CIMA):
		var sh2 = Shader.new()
		sh2.code = SHADER_TORCIDA
		var baixo: Texture = load(TEX_TORCIDA_BAIXO)
		var cima: Texture = load(TEX_TORCIDA_CIMA)
		# TRÊS FILEIRAS, cada uma no seu plano (a de trás mais alta e mais
		# longe): colunas e faixas iguais às de `tools/gerar_torcida.py`.
		_gente = Spatial.new()
		_gente.name = "Torcida"
		_mundo.add_child(_gente)
		_mats_torcida.clear()
		var fileiras = [
			[52.0, 0.0, 150.0, Vector3(0.0, 0.60, -4.45)],
			[40.0, 150.0, 320.0, Vector3(0.0, 0.20, -4.32)],
			[30.0, 320.0, 512.0, Vector3(0.0, -0.24, -4.20)],
		]
		for k in fileiras.size():
			var fl: Array = fileiras[k]
			var mat = ShaderMaterial.new()
			mat.shader = sh2
			mat.set_shader_param("baixo", baixo)
			mat.set_shader_param("cima", cima)
			mat.set_shader_param("colunas", fl[0])
			mat.set_shader_param("v0", float(fl[1]) / 512.0)
			mat.set_shader_param("v1", float(fl[2]) / 512.0)
			mat.set_shader_param("semente", float(k) * 3.3)
			_mats_torcida.append(mat)
			var quad = _malha_da_fileira(int(fl[0]), 10.0, 2.5 * (float(fl[2]) - float(fl[1])) / 512.0, float(k) * 3.3)
			var mi = _peca(quad, mat, fl[3])
			_mundo.remove_child(mi)
			_gente.add_child(mi)
		_mat_torcida = _mats_torcida[0]
	# O chão do ginásio entre o ringue e a plateia: escuro, só para o
	# tablado parecer suspenso.
	var chao = PlaneMesh.new()
	# (vai até a frente da câmera: descendo no nocaute, ela via o vazio)
	chao.size = Vector2(14.0, 12.0)
	_peca(chao, _material_solido(Color("0b0810"), 0.9), Vector3(0.0, -0.62, -0.6))


func _montar_ringue() -> void:
	var m = MEIO_RINGUE
	_mat_lona = _material_plano(load(TEX_LONA))
	var lona = PlaneMesh.new()
	lona.size = Vector2(m * 2.0, m * 2.0)
	_peca(lona, _mat_lona, Vector3.ZERO)
	# A borda do tablado: faixa escura sob a lona.
	var tablado = CubeMesh.new()
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
		var sh = Shader.new()
		sh.code = SHADER_SAIA
		_mat_saia.shader = sh
		_mat_saia.set_shader_param("tex", load(TEX_SAIA))
		var saia = QuadMesh.new()
		saia.size = Vector2(m * 2.0 + 0.12, 0.60)
		_peca(saia, _mat_saia, Vector3(0.0, -0.31, m + 0.062))

	# Postes de trás: vermelho à esquerda, azul à direita, com protetor.
	var poste = CylinderMesh.new()
	poste.top_radius = 0.055
	poste.bottom_radius = 0.055
	poste.height = 1.5
	poste.radial_segments = 16
	var protetor = CylinderMesh.new()
	protetor.top_radius = 0.10
	protetor.bottom_radius = 0.10
	protetor.height = 1.02
	protetor.radial_segments = 20
	var metal = _material_solido(Color("9aa3b5"), 0.28)
	metal.metallic = 0.8
	for lado in [-1.0, 1.0]:
		var cor = Color("d3162f") if lado < 0.0 else Color("1f4fd1")
		_peca(poste, metal, Vector3(lado * m, 0.75, -m))
		_peca(protetor, _material_solido(cor, 0.45, 0.12), Vector3(lado * m, 0.86, -m))

	# Cordas: tubos redondos. Só as de trás e as laterais — nada cruza a
	# frente do lutador.
	var corda = CylinderMesh.new()
	corda.top_radius = 0.024
	corda.bottom_radius = 0.024
	corda.height = m * 2.0
	corda.radial_segments = 12
	corda.rings = 1
	var tintas = [
		_material_solido(Color("ffd014"), 0.35, 0.12),
		_material_solido(Color("ff2ab0"), 0.35, 0.22),
		_material_solido(Color("46dcff"), 0.35, 0.12),
	]
	# AS CORDAS DE TRÁS ESTICAM DE VERDADE: malha com anéis ao longo do
	# comprimento e um shader que as curva para trás no meio (as pontas
	# ficam presas nos postes). Ver `_mexer_cordas`.
	var corda_fundo = corda.duplicate() as CylinderMesh
	corda_fundo.rings = 24
	var cores_cordas = [Color("ffd014"), Color("ff2ab0"), Color("46dcff")]
	var brilhos = [0.12, 0.22, 0.12]
	_cordas_fundo.clear()
	_mat_cordas.clear()
	for i in range(ALTURAS_DAS_CORDAS.size()):
		var y: float = ALTURAS_DAS_CORDAS[i]
		var mat = ShaderMaterial.new()
		mat.shader = _shader_corda()
		mat.set_shader_param("cor", cores_cordas[i])
		mat.set_shader_param("brilho", brilhos[i])
		mat.set_shader_param("meia", m)
		_mat_cordas.append(mat)
		_cordas_fundo.append(_peca(corda_fundo, mat, Vector3(0.0, y, -m), Vector3(0.0, 0.0, PI * 0.5)))
		for lado in [-1.0, 1.0]:
			_peca(corda, tintas[i], Vector3(lado * m, y, 0.0), Vector3(PI * 0.5, 0.0, 0.0))


## AS CORDAS DE TRÁS CEDEM quando o lutador cai nelas — E A CADA SOCO DO
## JOGADOR (ver `golpe`): esticam para trás no meio e voltam com um
## balanço de mola (passam um pouco do lugar e assentam).
var _cordas_fundo: Array = []
var _mat_cordas: Array = []
## Estado compartilhado (as `static var` do Godot 4): um `const` com
## dicionário é único para a classe e pode ser alterado.
const _E = {
	"_shader_da_corda": null,
}

static func _shader_corda() -> Shader:
	if _E._shader_da_corda == null:
		_E._shader_da_corda = Shader.new()
		_E._shader_da_corda.code = """
shader_type spatial;
uniform vec4 cor : hint_color = vec4(1.0);
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
	return _E._shader_da_corda
var _cordas_pos = 0.0
var _cordas_vel = 0.0

func _mexer_cordas(delta: float) -> void:
	var alvo = lutador.pressao_nas_cordas() if lutador != null else 0.0
	if alvo <= 0.0 and abs(_cordas_pos) < 0.001 and abs(_cordas_vel) < 0.001:
		return
	var d = min(delta, 0.05)
	_cordas_vel += (alvo - _cordas_pos) * 140.0 * d
	_cordas_vel *= exp(-7.0 * d)
	_cordas_pos += _cordas_vel * d
	for i in range(_mat_cordas.size()):
		# a corda do meio (na altura das costas) cede mais
		var peso: float = [0.55, 1.0, 0.75][int(min(i, 2))]
		var mat = _mat_cordas[i] as ShaderMaterial
		mat.set_shader_param("empurra", 0.55 * _cordas_pos * peso)
		# cada corda balança num tempo um pouco diferente (não em bloco)
		mat.set_shader_param("sobe", 0.24 * _cordas_vel / 11.8 * peso * (1.0 if i % 2 == 0 else -0.8))
	if alvo > 0.6:
		_publico = max(_publico, 0.4)


func _montar_fachos() -> void:
	# Fachos de refletor varrendo a plateia, aditivos e baratos.
	var textura: Texture = load(TEX_FACHO)
	var malha = QuadMesh.new()
	malha.size = Vector2(1.5, 6.0)
	for i in range(3):
		var mat = _material_plano(textura, true)
		mat.albedo_color = [Color("ff3ab4"), Color("b58cff"), Color("48d6ff")][i]
		var f = _peca(malha, mat, Vector3(-2.4 + 2.4 * float(i), 3.2, -4.3))
		_fachos.append(f)


func _montar_flashes() -> void:
	# Flashes de câmera na plateia: estrela com halo (nunca quadrado).
	var quantos = 16
	var malha = QuadMesh.new()
	malha.size = Vector2(0.42, 0.42)
	var tinta = _material_plano(load(TEX_BRILHO), true)
	tinta.vertex_color_use_as_albedo = true
	tinta.params_billboard_mode = SpatialMaterial.BILLBOARD_ENABLED
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.color_format = MultiMesh.COLOR_FLOAT
	mm.mesh = malha
	mm.instance_count = quantos
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260923
	_flash_fase.resize(quantos)
	for i in range(quantos):
		var t = Transform()
		t.origin = Vector3(rng.randf_range(-3.6, 3.6), rng.randf_range(0.2, 2.6), rng.randf_range(-4.6, -4.3))
		mm.set_instance_transform(i, t)
		mm.set_instance_color(i, Color(0, 0, 0, 0))
		_flash_fase[i] = rng.randf() * TAU
	_flashes = MultiMeshInstance.new()
	_flashes.multimesh = mm
	_flashes.material_override = tinta
	_flashes.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	_mundo.add_child(_flashes)


func _montar_particulas() -> void:
	var brilho = _material_plano(load(TEX_BRILHO), true)
	brilho.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES
	brilho.vertex_color_use_as_albedo = true
	var estrela = QuadMesh.new()
	estrela.size = Vector2(0.13, 0.13)
	estrela.material = brilho
	var processo = {
		"forma": CPUParticles.EMISSION_SHAPE_SPHERE, "raio": 0.14,
		"direcao": Vector3(0.0, 0.2, 1.0), "abertura": 80.0,
		"vel_min": 2.4, "vel_max": 6.8, "gravidade": Vector3(0.0, -5.5, 0.0),
		"amort_min": 1.5, "amort_max": 3.0, "escala_min": 0.35, "escala_max": 1.0,
		"cor": Color("ffe7a8"), "rampa": [Color(1, 1, 1, 1), Color(1, 0.5, 0.2, 0)],
	}
	_impacto = _particulas("ParticulasImpacto", int(96 * Perfil.PARTICULAS_3D), 0.75, 0.96, processo, estrela, Vector3(0.0, 1.34, 0.36))

	var po = _material_plano(_mancha_redonda(), true)
	po.params_blend_mode = SpatialMaterial.BLEND_MODE_MIX
	po.params_billboard_mode = SpatialMaterial.BILLBOARD_PARTICLES
	po.vertex_color_use_as_albedo = true
	var disco = QuadMesh.new()
	disco.size = Vector2(0.34, 0.34)
	disco.material = po
	var po_proc = {
		"forma": CPUParticles.EMISSION_SHAPE_BOX, "caixa": Vector3(0.7, 0.04, 0.38),
		"direcao": Vector3(0.0, 1.0, 0.0), "abertura": 65.0,
		"vel_min": 0.45, "vel_max": 1.3, "gravidade": Vector3(0.0, -0.6, 0.0),
		"escala_min": 0.6, "escala_max": 1.6,
		"cor": Color(0.62, 0.68, 0.85, 0.30), "rampa": [Color(1, 1, 1, 1), Color(1, 1, 1, 0)],
	}
	_poeira = _particulas("PoeiraDaLona", int(36 * Perfil.PARTICULAS_3D), 1.35, 0.88, po_proc, disco, Vector3(0.0, 0.08, -0.35))


func _particulas(
	nome: String, quantidade: int, vida: float, explosao: float,
	processo: Dictionary, malha: Mesh, onde: Vector3
) -> CPUParticles:
	var p = CPUParticles.new()
	p.name = nome
	# A quantidade é FIXA. A força do golpe muda `amount_ratio`, que não
	# realoca nada; mudar `amount` refazia os buffers a cada soco.
	p.amount = quantidade
	p.lifetime = vida
	p.one_shot = true
	p.explosiveness = explosao
	# O mesmo comportamento do material de processo do Godot 4: faixa
	# [mín, máx] vira "valor máximo com sorteio" no Godot 3.
	p.emission_shape = processo["forma"]
	if processo.has("raio"):
		p.emission_sphere_radius = processo["raio"]
	if processo.has("caixa"):
		p.emission_box_extents = processo["caixa"]
	p.direction = processo["direcao"]
	p.spread = processo["abertura"]
	p.gravity = processo["gravidade"]
	p.initial_velocity = processo["vel_max"]
	p.initial_velocity_random = 1.0 - processo["vel_min"] / processo["vel_max"]
	if processo.has("amort_max"):
		p.damping = processo["amort_max"]
		p.damping_random = 1.0 - processo["amort_min"] / processo["amort_max"]
	p.scale_amount = processo["escala_max"]
	p.scale_amount_random = 1.0 - processo["escala_min"] / processo["escala_max"]
	p.color = processo["cor"]
	var rampa = Gradient.new()
	rampa.set_color(0, processo["rampa"][0])
	rampa.set_color(1, processo["rampa"][1])
	p.color_ramp = rampa
	p.mesh = malha
	p.translation = onde
	p.emitting = false
	_mundo.add_child(p)
	return p


## `amount_ratio` do Godot 4: a fração das partículas que sai neste golpe.
## As partículas de processador do Godot 3 trocam a quantidade sem custo
## de placa de vídeo (é só uma lista na memória).
func _quantidade(p: CPUParticles, fracao: float) -> void:
	if not p.has_meta("cheio"):
		p.set_meta("cheio", p.amount)
	var n = int(max(1, round(float(p.get_meta("cheio")) * fracao)))
	if p.amount != n:
		p.amount = n


## Mancha redonda e macia (branco no centro, transparente na borda),
## feita pela própria GPU: sombra de contato e poeira.
static func _mancha_redonda() -> Texture:
	# O mesmo degradê radial (opaco no centro, 55% a 45% do raio, some na
	# borda), pintado pixel a pixel uma vez só.
	if _E.has("_mancha") and _E["_mancha"] != null:
		return _E["_mancha"]
	var lado = 128
	var img = Image.new()
	img.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.lock()
	for y in range(lado):
		for x in range(lado):
			var d = Vector2(float(x) + 0.5 - lado * 0.5, float(y) + 0.5 - lado * 0.5).length() / (lado * 0.5)
			var a = 0.0
			if d < 0.45:
				a = lerp(1.0, 0.55, d / 0.45)
			elif d < 1.0:
				a = lerp(0.55, 0.0, (d - 0.45) / 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	_E["_mancha"] = tex
	return tex


func instalar() -> bool:
	# O LUTADOR 3D: o boxeador (`LutadorBoxeador3D`, corpo humano com IK e
	# expressões). Nesta versão para a TV Box S905L os lutadores reserva
	# (guerreiro animado, Vanguard, Mixamo) ficaram de fora: nunca eram
	# usados e só ocupavam espaço no APK.
	var modelo = LutadorBoxeador3D.new()
	modelo.name = "Lutador"
	modelo.translation.y = PISO_DO_LUTADOR
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
const CAMADA_DO_LUTADOR = 2

func _luzes_de_recorte_so_no_lutador() -> void:
	if lutador == null:
		return
	for no in Compat.filhos_do_tipo(lutador, "VisualInstance"):
		(no as VisualInstance).layers |= CAMADA_DO_LUTADOR
	for luz in [_rim_quente, _rim_frio]:
		if luz != null:
			luz.light_cull_mask = CAMADA_DO_LUTADOR


func _montar_sombra() -> void:
	var malha = PlaneMesh.new()
	malha.size = Vector2(1.0, 0.52)
	_mat_sombra = SpatialMaterial.new()
	_mat_sombra.flags_unshaded = true
	_mat_sombra.flags_transparent = true
	_mat_sombra.albedo_texture = _mancha_redonda()
	_mat_sombra.albedo_color = Color(0.0, 0.0, 0.02, 0.9)
	_mat_sombra.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_DISABLED
	# 1,5 cm acima da lona (2 mm piscava na TV Box, colado no chão).
	_sombra = _peca(malha, _mat_sombra, Vector3(0.0, 0.015, 0.0))


# -------------------------------------------------------- tamanho/MSAA
func _aplicar_tamanho() -> void:
	# TAMANHO FIXO, O DO PERFIL DA S905L: a arena é desenhada numa fração da
	# resolução lógica e ampliada no quadro (ver `Perfil.ARENA_ESCALA`).
	# Nunca muda no meio da luta — trocar o tamanho realoca a imagem, e no
	# quadro da troca o lutador sumia.
	var novo = Vector2((TELA_LOGICA * Perfil.ARENA_ESCALA).round())
	if size != novo:
		size = novo
	msaa = Viewport.MSAA_2X if Perfil.ARENA_MSAA else Viewport.MSAA_DISABLED


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
		render_target_update_mode = Viewport.UPDATE_DISABLED


func ativa() -> bool:
	return _ativa


## PRÉ-AQUECIMENTO. Renderiza a arena fora da tela por alguns quadros
## com todas as poses e as partículas no ar: shaders compilam e texturas
## sobem para a GPU no arranque, e não no primeiro soco da noite.
func aquecer(quadros := 24) -> void:
	_aquecendo = quadros
	render_target_update_mode = Viewport.UPDATE_ALWAYS
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
const ETAPAS_DE_AQUECIMENTO = 7
var _etapa = -1

func _enfeites_visiveis(sim: bool) -> void:
	if _gente != null:
		_gente.visible = sim
	if _flashes != null:
		_flashes.visible = sim
	for f in _fachos:
		f.visible = sim

func etapa_de_aquecimento(n: int) -> void:
	_etapa = n
	match n:
		0:
			# o ringue e o fundo, sem lutador, torcida nem luzes
			if lutador != null:
				lutador.visible = false
			_enfeites_visiveis(false)
			render_target_update_mode = Viewport.UPDATE_ALWAYS
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
				lutador.mostrar_pose("celebra")
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
			render_target_update_mode = Viewport.UPDATE_ONCE if _ativa else Viewport.UPDATE_DISABLED


func golpe(forca: float, derruba := false, pontos := -1, ultimo := false) -> Dictionary:
	_tremor = clamp(0.35 + forca, 0.0, 1.35)
	_clarao = clamp(0.4 + forca * 0.6, 0.0, 1.0)
	_empurrao = forca
	# O SOCO ESTICA AS CORDAS DE TRÁS: o baque passa pelo lutador e chega
	# nelas — mais forte o soco, mais longe elas vão (e voltam balançando).
	_cordas_vel += 2.5 + clamp(forca, 0.0, 1.2) * 6.5
	_publico = max(_publico, clamp(0.08 + forca * (1.15 if derruba else 0.85), 0.0, 1.0))
	var economia = 1.0 if qualidade >= 0.55 else 0.55
	if _impacto != null:
		_quantidade(_impacto, clamp(lerp(0.22, 1.0, forca) * economia, 0.05, 1.0))
		_impacto.restart()
	if derruba and _poeira != null:
		_quantidade(_poeira, economia)
		_poeira.restart()
	if lutador == null:
		return {"nocaute": false, "dano": 0.0, "reacao": "", "desdenhou": false}
	var resposta = lutador.bater(forca, derruba, pontos, ultimo)
	if bool(resposta.get("desdenhou", false)):
		_publico = max(_publico, 0.66)
		_clarao = max(_clarao, 0.28)
	return resposta


## O CAMBALEIO do soco na tela: a câmera balança e rola um pouco, e o
## balanço morre em `segundos`. Frequências e fases sorteadas: nunca
## igual. Liso de propósito — nada de congelar a imagem.
var _camb_t = -1.0
var _camb_dur = 1.6
var _camb = PoolRealArray()

func cambalear(segundos: float) -> void:
	_camb_t = 0.0
	_camb_dur = max(segundos, 0.3)
	_camb = PoolRealArray([
		rand_range(2.6, 4.6), randf() * TAU, rand_range(0.05, 0.09),
		rand_range(2.0, 3.8), randf() * TAU, rand_range(0.03, 0.06),
		rand_range(1.6, 3.0), randf() * TAU, rand_range(0.05, 0.10),
	])
	_tremor = max(_tremor, 0.9)
	_clarao = max(_clarao, 0.35)


## A TORCIDA REAGE: `intensidade` 0..1 por `segundos`, depois acalma.
func agitar(intensidade: float, segundos := 4.0) -> void:
	_agito_alvo = max(_agito_alvo, clamp(intensidade, 0.0, 1.0))
	_agito_ate = max(_agito_ate, _relogio + segundos)


func fim_de_rodada(desfecho: String) -> void:
	if lutador != null:
		lutador.fim_de_rodada(desfecho)


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
		render_target_update_mode = Viewport.UPDATE_ALWAYS
		return
	if _aquecendo > 0:
		_passo_do_aquecimento()
		if not _ativa:
			return
	if not _ativa:
		return
	_relogio += delta
	_tremor = max(0.0, _tremor - delta * 2.2)
	_clarao = max(0.0, _clarao - delta * 2.4)
	_empurrao = max(0.0, _empurrao - delta * 1.6)
	_publico = max(0.0, _publico - delta * 0.72)
	if _camb_t >= 0.0:
		_camb_t += delta
		if _camb_t > _camb_dur:
			_camb_t = -1.0
	if _relogio > _agito_ate:
		_agito_alvo = max(0.0, _agito_alvo - delta * 0.35)
	_agito = lerp(_agito, max(_agito_alvo, _publico * 0.6), 1.0 - exp(-delta * 4.0))
	if lutador != null:
		lutador.ponto_da_camera = camera.global_position
		lutador.atualizar(delta)
	_mexer_cordas(delta)
	_sombra_de_contato()
	_camera(delta)
	_luzes()
	_piscar()
	render_target_update_mode = Viewport.UPDATE_ONCE
	_ajustar_tamanho()


func _passo_do_aquecimento() -> void:
	_aquecendo -= 1
	if lutador != null:
		var poses = lutador.poses()
		if not poses.empty():
			lutador.mostrar_pose(String(poses[_aquecendo % poses.size()]))
	if _aquecendo <= 0:
		if lutador != null:
			lutador.preparar()
		render_target_update_mode = Viewport.UPDATE_ONCE if _ativa else Viewport.UPDATE_DISABLED


# ------------------------------------------------------------ a cena
func _calcular_enquadramento() -> void:
	var figura = Lutador3D.ALTURA_DA_FIGURA
	var janela = figura / OCUPACAO_DO_LUTADOR
	var meia = deg2rad(camera.fov) * 0.5
	_distancia = janela / (2.0 * tan(meia))
	var base = PISO_DO_LUTADOR - (janela - figura) * 0.5
	var inclinacao = atan(CAMERA_ACIMA_DA_MIRA / _distancia)
	_altura_da_camera = base + _distancia * tan(inclinacao + meia)
	_altura_da_mira = _altura_da_camera - CAMERA_ACIMA_DA_MIRA


## A CÂMERA ANDA, NÃO PULA. Empurrão do golpe, queda, soco na tela e o
## passeio lento viram um ALVO; a câmera persegue esse alvo com uma mola
## amortecida (sem ultrapassar). Antes o empurrão do soco entrava inteiro
## num quadro só e a imagem dava um pulo seco a cada golpe — e de novo
## quando o segundo soco era armado. O tremor fica de fora da mola: ele é
## para ser seco.
var _cam_pos = Vector3.INF
var _cam_mira = Vector3.ZERO
var _chao = 0.0
var _chao_alvo = 0.0

## O jogador foi nocauteado (câmera vai ao chão) ou levantou (volta).
func jogador_no_chao(sim: bool) -> void:
	_chao_alvo = 1.0 if sim else 0.0
const CAMERA_MOLA = 7.5

func _camera(delta := 0.0) -> void:
	var passeio = sin(_relogio * 0.33) * 0.16
	var sacode = Vector3.ZERO
	if _tremor > 0.02:
		sacode = Vector3(rand_range(-1.0, 1.0), rand_range(-1.0, 1.0), rand_range(-0.4, 0.4)) * _tremor * 0.05
	var extra = lutador.camera_extra() if lutador != null else Vector2.ZERO
	var pos = Vector3(passeio * (1.0 - clamp(extra.x * 1.5, 0.0, 1.0)), _altura_da_camera + sin(_relogio * 0.21) * 0.05 - extra.y, _distancia - _empurrao * 0.30 - extra.x)
	var mira = Vector3(0.0, _altura_da_mira + _empurrao * 0.06, 0.0)
	# NO SOCO NA TELA A CÂMERA OLHA NO ROSTO. Ela chegava perto do lutador
	# ainda mirando o meio do corpo — de perto, o meio do corpo é a
	# cintura, e o quadro enchia de calção. Agora, conforme ela se
	# aproxima, sobe até a altura dos olhos e mira o rosto: o soco vem na
	# cara de quem joga, com a expressão do lutador no centro.
	var perto = clamp(extra.x / 0.72, 0.0, 1.0)
	if perto > 0.001:
		var rosto = Lutador3D.ALTURA_DA_FIGURA * 0.90 + deslocamento_vertical()
		var k = perto * perto * (3.0 - 2.0 * perto)
		pos.y = lerp(pos.y, rosto + 0.03, k)
		mira.y = lerp(mira.y, rosto - 0.04, k)
	var caido = lutador.queda if lutador != null else 0.0
	if caido > 0.001:
		# No nocaute a câmera afasta e desce: um corpo caído é largo.
		var t = ease(caido, 0.5)
		pos = pos.linear_interpolate(Vector3(0.0, _altura_da_camera * 0.54, _distancia * 1.07), t)
		mira = mira.linear_interpolate(Vector3(0.0, _altura_da_mira * 0.58, 0.0), t)
	var rolo = 0.0
	# O JOGADOR NO CHÃO: depois do nocaute a câmera cai até a lona, meio
	# de lado, olhando o lutador de baixo — quem perdeu vê o ginásio do
	# chão. Cai rápido (com um quique) e só levanta na próxima rodada.
	_chao = move_toward(_chao, _chao_alvo, delta * (2.4 if _chao_alvo > _chao else 1.2))
	if _chao > 0.001:
		var t = _chao * _chao * (3.0 - 2.0 * _chao)
		var quique = sin(clamp(_chao, 0.0, 1.0) * PI) * 0.05 * (1.0 if _chao_alvo > 0.5 else 0.0)
		var pos_chao = Vector3(0.42, 0.14 + quique, _distancia * 0.74)
		var mira_chao = Vector3(-0.05, Lutador3D.ALTURA_DA_FIGURA * 0.78 + deslocamento_vertical(), 0.0)
		pos = pos.linear_interpolate(pos_chao, t)
		mira = mira.linear_interpolate(mira_chao, t)
		rolo += 0.30 * t
	var balanco = Vector3.ZERO
	if _camb_t >= 0.0 and _camb.size() >= 9:
		var t = _camb_t
		var some = pow(1.0 - clamp(t / _camb_dur, 0.0, 1.0), 1.6)
		var c = _camb
		sacode += Vector3(sin(t * c[0] * TAU * 0.5 + c[1]) * c[2], sin(t * c[3] * TAU * 0.5 + c[4]) * c[5], 0.0) * some
		balanco = Vector3(sin(t * c[3] * TAU * 0.4 + c[1]) * c[2] * 0.6, 0.0, 0.0) * some
		rolo = sin(t * c[6] * TAU * 0.5 + c[7]) * c[8] * some
	if _cam_pos == Vector3.INF or delta <= 0.0:
		_cam_pos = pos
		_cam_mira = mira
	else:
		var k = 1.0 - exp(-CAMERA_MOLA * min(delta, 0.05))
		_cam_pos = _cam_pos.linear_interpolate(pos, k)
		_cam_mira = _cam_mira.linear_interpolate(mira, k)
	camera.translation = _cam_pos + sacode
	camera.look_at(_cam_mira + balanco, Vector3.UP)
	if abs(rolo) > 0.0001:
		camera.rotate_object_local(Vector3.FORWARD, rolo)


## Quanto o corpo do lutador subiu/desceu (agachado na guarda, pulando).
func deslocamento_vertical() -> float:
	if lutador != null and lutador.has_method("deslocamento"):
		return float(lutador.deslocamento().y)
	return 0.0


func _luzes() -> void:
	if lutador != null:
		lutador.clarao(_clarao)
	var extra = _clarao * 5.0
	if _rim_quente != null:
		_rim_quente.light_energy = 2.0 + extra
		_rim_frio.light_energy = 2.0 + extra
	_luz_chave.light_energy = 1.6 + _clarao * 1.0
	# O lutador de uma passada (`Perfil.LUTADOR_LEVE`) faz a própria luz:
	# recebe a direção da luz principal já no espaço da câmera.
	if lutador != null and lutador.has_method("luz"):
		var para_a_luz = camera.global_transform.basis.xform_inv(_luz_chave.global_transform.basis.z)
		lutador.call("luz", para_a_luz.normalized(), _luz_chave.light_color,
			LUZ_DO_LUTADOR * _luz_chave.light_energy, AMBIENTE_DO_LUTADOR)
	# Materiais sem luz acendem pelo albedo: o salão inteiro pisca junto.
	var acende = 1.0 + _clarao * 0.55
	# MEIA PRECISÃO NA MALI-450: o relógio dos shaders dá a volta a cada
	# 20π segundos (a torcida só balança em senos; a volta não se nota) e o
	# que ROLA (telão, saia) chega já como fração, calculada aqui.
	var tempo_curto = fposmod(_relogio, TAU * 10.0)
	_mat_fundo.set_shader_param("acende", acende)
	_mat_fundo.set_shader_param("tempo", tempo_curto)
	_mat_fundo.set_shader_param("rolagem", Compat.fracao(_relogio, 0.018))
	_mat_fundo.set_shader_param("agito", _agito)
	# A torcida faz as contas do relógio no vértice (32 bits): o relógio dela
	# dá a volta só a cada ~10 min, e a volta é um instante só.
	var tempo_da_torcida = fposmod(_relogio, TAU * 100.0)
	for mat in _mats_torcida:
		(mat as ShaderMaterial).set_shader_param("acende", acende)
		(mat as ShaderMaterial).set_shader_param("tempo", tempo_da_torcida)
		(mat as ShaderMaterial).set_shader_param("agito", _agito)
	_mat_lona.albedo_color = Color(acende, acende, acende)
	if _mat_saia != null:
		_mat_saia.set_shader_param("rolagem", Compat.fracao(_relogio, 0.05))
		_mat_saia.set_shader_param("acende", acende)
	for i in range(_fachos.size()):
		var f = _fachos[i]
		f.rotation.z = sin(_relogio * (0.35 + 0.1 * float(i)) + float(i) * 2.1) * 0.35
		var mat = f.material_override as SpatialMaterial
		mat.albedo_color.a = 0.20 + _publico * 0.35 + _clarao * 0.25 + _agito * 0.25
		f.rotation.z += sin(_relogio * 2.6 + float(i)) * 0.25 * _agito


func _piscar() -> void:
	var mm = _flashes.multimesh
	for i in range(mm.instance_count):
		var fase: float = _flash_fase[i]
		var base = max(0.0, sin(_relogio * 1.7 + fase) - 0.93) * 12.0
		var festa = (_clarao + _publico * 0.6 + _agito * 0.5) * max(0.0, sin(fase * 3.1 + _relogio * 22.0))
		var a = clamp(base + festa, 0.0, 1.0)
		mm.set_instance_color(i, Color(a, a * 0.97, a * 0.92, a))


func _sombra_de_contato() -> void:
	if _sombra == null or lutador == null:
		return
	var desloc = lutador.deslocamento()
	var caido = clamp(lutador.queda, 0.0, 1.0)
	_sombra.translation = Vector3(desloc.x, 0.015, desloc.z * 0.6)
	_sombra.scale = Vector3(lerp(1.0, 1.5, caido), 1.0, lerp(1.0, 1.3, caido))
	_mat_sombra.albedo_color.a = lerp(0.9, 0.6, caido)
