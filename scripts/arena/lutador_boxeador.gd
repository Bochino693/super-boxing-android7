class_name LutadorBoxeador3D
extends Lutador3D

## O ADVERSÁRIO: UM BOXEADOR DE VERDADE, animado em código.
##
## O corpo é `assets/lutador3d/boxeador.glb`, gerado por
## `tools/gerar_boxeador.py` (corpo MakeHuman/Anny, livre para uso
## comercial): pele pintada em 4096 px, calção de cetim, botas, luvas e
## quatro expressões no rosto (deboche, dor, grito, apagado).
##
## A ANIMAÇÃO NÃO É GRAVADA. Cada quadro é montado assim:
##
##   1. A COREOGRAFIA diz onde cada coisa quer estar: o centro do corpo
##      no ringue, a altura e o giro da bacia, a inclinação do tronco e da
##      cabeça, e onde ficam as duas luvas (guarda, jab, direto, gancho,
##      cruzado de baixo, festa, deboche, soco na câmera).
##   2. OS PÉS SÃO PLANTADOS. Um pé só sai do chão quando o corpo se
##      afastou demais dele, e aí dá um PASSO de verdade (sobe em arco e
##      pousa noutro lugar). É isso que acaba com o pé deslizando na lona:
##      o recuo de um golpe forte vira dois ou três passos para trás, o
##      cambaleio vira passos tortos, e a ginga é um quicar na ponta dos
##      pés com os pés no lugar.
##   3. IK DE DOIS OSSOS nas pernas e nos braços: joelho e cotovelo saem da
##      conta, dobrando para onde devem (joelho sobre o pé, cotovelo para
##      baixo e para fora). Se a perna não alcança o pé, a bacia desce.
##   4. MOLAS para o que é reação: a cabeça que vai para trás no soco e
##      volta sozinha, o tronco que balança, a guarda que abre.

const MODELO = "res://assets/lutador3d/boxeador.glb"
const ModoSeguro = preload("res://scripts/modo_seguro.gd")
const MESCLA_EXPR = 7.0

## Base de luta (espaço do esqueleto, metros do modelo): pé esquerdo à
## frente (guarda ortodoxa), direito atrás.
const PE_FRENTE = Vector2(0.15, 0.15)
const PE_TRAS = Vector2(-0.17, -0.17)
const GIRO_DA_BASE = -0.34
const LIMIAR_DO_PASSO = 0.055
const TEMPO_DO_PASSO = 0.22
const ALTURA_DO_PASSO = 0.055
## Quanto o calcanhar sobe no máximo (rad, ~34°), girando na planta do pé.
const CALCANHAR_MAX = 0.60
## Quanto o corpo tomba para trás no nocaute (rad, ~86°: deitado de costas).
const QUEDA_ANGULO = 1.50
## Espessuras (metros do modelo) dos pontos que encostam na lona: a trava
## do chão mede o osso e desconta a carne/couro em volta dele.
const RAIO_DA_LUVA = 0.075
const RAIO_DA_BACIA = 0.10
const RAIO_DAS_COSTAS = 0.11
const RAIO_DA_CABECA = 0.10

## Os nomes dos ossos por lado, prontos: montar "Left" + "Arm" em todo
## quadro, para cada osso, era alocação de texto à toa.
const L_SHOULDER = ["LeftShoulder", "RightShoulder"]
const L_ARM = ["LeftArm", "RightArm"]
const L_FOREARM = ["LeftForeArm", "RightForeArm"]
const L_HAND = ["LeftHand", "RightHand"]
const L_UPLEG = ["LeftUpLeg", "RightUpLeg"]
const L_LEG = ["LeftLeg", "RightLeg"]
const L_FOOT = ["LeftFoot", "RightFoot"]
const L_TOE = ["LeftToeBase", "RightToeBase"]
const L_TOE_END = ["LeftToe_End", "RightToe_End"]
const COLUNA = ["Spine", "Spine1", "Spine2"]
const COLUNA_PESO = [0.3, 0.35, 0.35]

## Os golpes: duração total e a fração em que o braço chega esticado.
const GOLPES = {
	"jab": {"dur": 0.30, "pico": 0.36},
	"direto": {"dur": 0.40, "pico": 0.40},
	"gancho": {"dur": 0.46, "pico": 0.42},
	"upper": {"dur": 0.46, "pico": 0.44},
}
const COMBOS = [
	[["jab", 0]],
	[["jab", 0], ["jab", 0], ["direto", 1]],
	[["jab", 0], ["direto", 1]],
	[["jab", 0], ["direto", 1], ["gancho", 0]],
	[["direto", 1], ["gancho", 0], ["direto", 1]],
	[["jab", 0], ["upper", 1], ["gancho", 0]],
	[["gancho", 0], ["direto", 1]],
	[["jab", 0], ["jab", 0]],
]

var _modelo: Spatial = null
var _sk: Skeleton = null
var _pronto = false
var _i = {}                     ## nome curto -> índice do osso
var _R = {}                     ## nome curto -> posição de repouso
var _nomes = PoolStringArray()
var _pais = PoolIntArray()
var _secundario = {}            ## nome -> eixo secundário de repouso
var _l_braco = 0.0
var _l_ante = 0.0
var _l_coxa = 0.0
var _l_canela = 0.0
var _h0 = 0.0                   ## altura da bacia em pé
var _tornozelo = 0.0            ## altura do tornozelo com o pé no chão
var _desce_pe = 0.0             ## quanto o osso do pé aponta para baixo em repouso
var _desce_dedo = 0.0
var _pe_l = 0.0                 ## do tornozelo à planta (osso do pé)
var _sola_planta = 0.0          ## altura do osso da planta com o pé no chão
var _sola_ponta = 0.0           ## altura da ponta dos dedos com o pé no chão
var _calcanhar_ofs = Vector3.ZERO  ## do tornozelo à sola do calcanhar
## Base de repouso de cada osso já invertida (ver `_girar`), e quais ossos
## a pose comanda. Calculadas uma vez, na montagem.
var _repouso_t = {}
var _comandado = PoolByteArray()
var _gravou_fixos = false
## Godot 3: inverso do repouso de cada osso e a posição local de repouso.
var _repouso_inv = []
var _repouso_origem = []
## Os dicionários da pose são reaproveitados de um quadro para o outro.
var _G = {}
var _O = {}
## Saídas de `_resolver` para os pés, luvas e bacia do quadro.
var _r_pe = [Vector3.ZERO, Vector3.ZERO]
var _r_tomba = [0.0, 0.0]
var _r_mao = [Vector3.ZERO, Vector3.ZERO]
var _r_cot = [Vector3.DOWN, Vector3.DOWN]
var _r_bacia = Vector3.ZERO
var _r_rot = Basis.IDENTITY
## A queda e o levantar (ver `_pose_levantando`).
var _deitado_bacia = Vector3.ZERO
var _deitado_ang = 0.0
var _lev_ok = false
var _lev_bacia = Vector3.ZERO
var _lev_ang = 0.0
var _lev_pe = [Vector3.ZERO, Vector3.ZERO]

var _pele: MeshInstance = null
var _mat_pele: SpatialMaterial = null
var _expr = {}
var _expr_valor = {}
var _mat_clarao: SpatialMaterial = null
var _malhas: Array = []

## --- o estado do corpo (suavizado)
var _dt = 1.0 / 60.0
var _centro = Vector2.ZERO          ## x, z do corpo no ringue
## Até onde, a partir do centro, a lona está livre das cordas (m).
const RINGUE_LIVRE = 1.40
var _centro_alvo = Vector2.ZERO
var _centro_vel = Vector2.ZERO
var _bacia = Vector3.ZERO           ## posição da bacia
var _bacia_rot = Vector3.ZERO       ## pitch, yaw, roll
var _tronco = Vector3.ZERO
var _cabeca = Vector3.ZERO
var _mao = [Vector3.ZERO, Vector3.ZERO]
var _mao_dir = [Vector3.UP, Vector3.UP]
var _polegar = [Vector3.BACK, Vector3.BACK]
var _cotovelo = [Vector3.DOWN, Vector3.DOWN]
var _ombro = [Vector2.ZERO, Vector2.ZERO]
## --- os alvos do quadro (a coreografia escreve aqui)
var a_bacia = Vector3.ZERO
var a_bacia_rot = Vector3.ZERO
var a_tronco = Vector3.ZERO
var a_cabeca = Vector3.ZERO
var a_mao = [Vector3.ZERO, Vector3.ZERO]
var a_mao_dir = [Vector3.UP, Vector3.UP]
var a_polegar = [Vector3.BACK, Vector3.BACK]
var a_cotovelo = [Vector3.DOWN, Vector3.DOWN]
var a_ombro = [Vector2.ZERO, Vector2.ZERO]
var a_calcanhar = [0.0, 0.0]
var a_expr = {}
var _rapidez = 18.0

## --- os pés
var _pe = [Vector3.ZERO, Vector3.ZERO]
var _pe_giro = [0.0, 0.0]
var _passo_t = [-1.0, -1.0]
var _passo_de = [Vector3.ZERO, Vector3.ZERO]
var _passo_para = [Vector3.ZERO, Vector3.ZERO]
var _passo_giro_de = [0.0, 0.0]
var _passo_giro_para = [0.0, 0.0]
var _calcanhar = [0.0, 0.0]
var _pe_ultimo = 1
var _pes_livres = 0.0               ## 1 = pernas soltas (deitado)

## --- molas das reações
var _mola_cab = Vector3.ZERO
var _mola_cab_v = Vector3.ZERO
var _mola_tronco = Vector3.ZERO
var _mola_tronco_v = Vector3.ZERO
var _guarda_aberta = 0.0
var _guarda_aberta_v = 0.0
var _joelho = 0.0                   ## quanto os joelhos cedem (0..1)
var _joelho_v = 0.0
var _tonto = 0.0                    ## sobra de cambaleio (s)

## --- golpes no ar
var _fila: Array = []                ## [{tipo, lado, t}]
var _proximo_combo = 2.5
var _vagar_em = 1.5

## --- soco na tela
var _tela_ok = false
var _tela_bateu = false
var _dolly = 0.0

## --- queda
var _queda_vis = 0.0
var _rng = RandomNumberGenerator.new()


# ===================================================================
# MONTAGEM
# ===================================================================
func montar() -> void:
	.montar()
	_rng.randomize()
	if not ResourceLoader.exists(MODELO):
		return
	var cena = load(MODELO) as PackedScene
	if cena == null:
		return
	_modelo = cena.instance() as Spatial
	_corpo.add_child(_modelo)
	# No Godot 3 o importador chama o nó de "Skeleton" (no 4, "Skeleton3D").
	_sk = Compat.filhos_do_tipo(_modelo, "Skeleton")[0] if not Compat.filhos_do_tipo(_modelo, "Skeleton").empty() else null
	if _sk == null:
		return
	_mapear()
	for n in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm",
			"LeftHand", "LeftHandMiddle1", "LeftHandThumb1", "LeftUpLeg", "LeftLeg", "LeftFoot",
			"LeftToeBase", "LeftToe_End", "RightArm", "RightFoot", "HeadTop_End"]:
		if not _i.has(n):
			return
	var topo: float = (_R["HeadTop_End"] as Vector3).y
	_modelo.scale = Vector3.ONE * (ALTURA_DA_FIGURA / max(topo, 0.1))
	_l_braco = (_R["LeftForeArm"] - _R["LeftArm"]).length()
	_l_ante = (_R["LeftHand"] - _R["LeftForeArm"]).length()
	_l_coxa = (_R["LeftLeg"] - _R["LeftUpLeg"]).length()
	_l_canela = (_R["LeftFoot"] - _R["LeftLeg"]).length()
	_h0 = (_R["Hips"] as Vector3).y
	_tornozelo = (_R["LeftFoot"] as Vector3).y
	var dp: Vector3 = _R["LeftToeBase"] - _R["LeftFoot"]
	_desce_pe = atan2(-dp.y, Vector2(dp.x, dp.z).length())
	var dd: Vector3 = _R["LeftToe_End"] - _R["LeftToeBase"]
	_desce_dedo = atan2(-dd.y, Vector2(dd.x, dd.z).length())
	_pe_l = dp.length()
	_sola_planta = (_R["LeftToeBase"] as Vector3).y
	_sola_ponta = (_R["LeftToe_End"] as Vector3).y
	# O calcanhar: logo abaixo do tornozelo, um pouco para trás.
	_calcanhar_ofs = Vector3(0.0, -_tornozelo, -0.035)
	_preparar_ossos()
	for m in Compat.filhos_do_tipo(_modelo, "MeshInstance"):
		var mi = m as MeshInstance
		if _do_avesso(mi):
			_avessos.append(mi)
		_malhas.append(mi)
		mi.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
		if mi.name == "Pele":
			_pele = mi
	# EXPRESSÕES SÓ ONDE A PLACA DEFORMA O CORPO. A Mali-450 não lê textura
	# no vértice, e o Godot 3 então deforma o corpo no processador — onde
	# não há expressão (blend shape). Mexer nelas assim só enchia o logcat
	# de erro a cada quadro, gastando o processador da TV Box.
	var corpo_na_placa = not VisualServer.has_os_feature("skinning_fallback") \
		and not ProjectSettings.get_setting("rendering/quality/skinning/force_software_skinning")
	if _pele != null:
		if corpo_na_placa:
			for k in _pele.mesh.get_blend_shape_count():
				var nome = str(_pele.mesh.get_blend_shape_name(k))
				_expr[nome] = k
				_expr_valor[nome] = 0.0
		var mat = _pele.mesh.surface_get_material(0) as SpatialMaterial
		if mat != null:
			_mat_pele = mat.duplicate() as SpatialMaterial
			_definir(_mat_pele, 0.50, 0.22)
			# Pele suada: menos áspera e com o relevo mais marcado — é o
			# brilho nos músculos que desenha o corpo de longe.
			_mat_pele.normal_scale = 1.15
			_pele.set_surface_material(0, _mat_pele)
			# A PELE DE VERDADE: shader próprio (luz que atravessa a borda,
			# suor quebrado por poros, relevo dos músculos). Sem os mapas,
			# fica o material padrão acima.
			# Na S905L a pele fica no material padrão: a mesma pintura, sem a
			# luz calculada pixel a pixel (ver `Perfil.PELE_DETALHADA`).
			var pele = _material_da_pele(mat) if Perfil.PELE_DETALHADA else null
			if pele != null:
				_pele.set_surface_material(0, pele)
	# O RESTO DA ROUPA TAMBÉM GANHA CONTORNO. Couro das luvas e das botas,
	# cetim do calção e o metal do cinturão pegam a luz de recorte: o
	# personagem se descola do fundo e parece mais nítido sem custar um
	# pixel a mais de resolução.
	var feitos = {}
	for mi in _malhas:
		if mi == _pele or mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var base = mi.mesh.surface_get_material(k) as SpatialMaterial
			if base == null:
				continue
			# Casca fina (calção, cinturão, friso): duas faces. Luvas e botas
			# são sólidos fechados e ficam com uma.
			var casca = mi.name in ["Calcao", "Cinturao", "Friso", "Placa"]
			var avesso = mi in _avessos
			var chave = [base, casca, avesso]
			if not feitos.has(chave):
				var novo = base.duplicate() as SpatialMaterial
				var luva = mi.name.begins_with("Luva")
				# Couro da luva: menos recorte e menos espelho — com muito
				# dos dois ela estourava num vermelho chapado.
				_definir(novo, max(base.roughness, 0.42) if luva else base.roughness, 0.10 if luva else 0.18, casca)
				if luva:
					# o vermelho vivo da cor de vértice estourava no lado
					# iluminado: um pouco mais escuro, a forma aparece.
					novo.albedo_color = Color(0.72, 0.72, 0.72)
				if avesso and not casca:
					# Peça do avesso (`_do_avesso`): mostra a face de fora.
					novo.params_cull_mode = SpatialMaterial.CULL_FRONT
				feitos[chave] = novo
			mi.set_surface_material(k, feitos[chave])
	_mat_clarao = SpatialMaterial.new()
	_mat_clarao.flags_unshaded = true
	_mat_clarao.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
	_mat_clarao.albedo_color = Color.black
	if Perfil.LUTADOR_LEVE and not ModoSeguro.seguro():
		_trocar_por_materiais_leves()
	_pronto = true
	_reiniciar_corpo()
	_tocar("idle")


## PEÇA DO AVESSO. No `boxeador.glb` a luva e a bota ESQUERDAS vieram com
## os triângulos na ordem contrária à das outras peças (espelhadas no
## modelo sem virar as faces). O Godot descartava a face de fora e
## desenhava a de dentro: a luva aparecia com uma faixa escura e a cor
## "errada", a bota sem forma. A peça é conferida pelo próprio desenho —
## a normal de cada triângulo contra a ordem dos vértices — e a do avesso
## ganha um material que descarta a face da FRENTE (`cull_front`): a de
## fora aparece, com a luz certa.
##
## A MALHA NÃO É REFEITA. Refazer a malha em tempo de jogo (a build 98
## fazia) corrompe a memória quando o corpo é deformado pelo processador
## — o caso da Mali-450 — e a TV Box caía.
var _avessos = []

func _do_avesso(mi: MeshInstance) -> bool:
	var malha = mi.mesh
	if malha == null or malha.get_surface_count() != 1:
		return false
	if malha.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return false
	var arrays = malha.surface_get_arrays(0)
	var v: PoolVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nn: PoolVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PoolIntArray = arrays[Mesh.ARRAY_INDEX]
	if v.empty() or nn.empty() or idx.size() < 3:
		return false
	# Uma amostra basta: numa peça do avesso são praticamente todos.
	var avesso = 0
	var certo = 0
	var passo = int(max(3, (idx.size() / 3 / 200) * 3))
	var i = 0
	while i + 2 < idx.size():
		var p0 = v[idx[i]]
		var face = (v[idx[i + 1]] - p0).cross(v[idx[i + 2]] - p0)
		# No Godot a face da frente gira no sentido horário.
		if face.dot(nn[idx[i]] + nn[idx[i + 1]] + nn[idx[i + 2]]) > 0.0:
			avesso += 1
		else:
			certo += 1
		i += passo
	return avesso > certo * 4


## O LUTADOR NUMA PASSADA SÓ (ver `shaders/lutador_leve.shader` e
## `Perfil.LUTADOR_LEVE`): cada material do corpo vira o mesmo shader,
## com a pintura, a aspereza e o metal da peça. A luz principal chega
## pronta a cada quadro (`luz`), e o clarão e o dano são números no
## próprio material — sem a segunda passada do clarão por cima.
const SHADER_LEVE = "res://shaders/lutador_leve.shader"
var _mats_leves = []
var _mat_leve_pele: ShaderMaterial = null
var _clarao_pintado = -1.0

func _trocar_por_materiais_leves() -> void:
	if not ResourceLoader.exists(SHADER_LEVE):
		return
	var com_relevo: Shader = load(SHADER_LEVE)
	# SEM TANGENTE PARA QUEM NÃO TEM RELEVO. Na Mali-450 o corpo é
	# deformado pelo processador, e o Godot 3 só deforma a peça cujo
	# material lê TANGENT se a malha tiver tangentes — luvas, botas,
	# cabelo e calção não têm, e sumiam. Só a pele (que tem) usa o relevo.
	var codigo = com_relevo.code
	var de = codigo.find("// RELEVO>")
	var ate = codigo.find("// <RELEVO")
	if de < 0 or ate < de:
		return
	codigo = codigo.substr(0, de) + codigo.substr(ate + len("// <RELEVO"))
	var frente = Shader.new()
	frente.code = codigo
	# As cascas finas (calção, cinturão) são vistas dos dois lados.
	var dois_lados = Shader.new()
	dois_lados.code = codigo.replace("cull_back", "cull_disabled")
	# As peças do avesso (`_do_avesso`) mostram a face de fora assim.
	var do_avesso = Shader.new()
	do_avesso.code = codigo.replace("cull_back", "cull_front")
	var feitos = {}
	for mi in _malhas:
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var base = mi.get_surface_material(k) as SpatialMaterial
			if base == null:
				base = mi.mesh.surface_get_material(k) as SpatialMaterial
			if base == null:
				continue
			var avesso = mi in _avessos
			var chave = [base, avesso]
			if not feitos.has(chave):
				var m = ShaderMaterial.new()
				var eh_pele = mi == _pele
				if eh_pele and base.normal_enabled and base.normal_texture != null \
						and mi.mesh.surface_get_format(k) & Mesh.ARRAY_FORMAT_TANGENT:
					m.shader = com_relevo
				elif base.params_cull_mode == SpatialMaterial.CULL_DISABLED:
					m.shader = dois_lados
				elif avesso:
					m.shader = do_avesso
				else:
					m.shader = frente
				m.set_shader_param("tom", base.albedo_color)
				if base.albedo_texture != null:
					m.set_shader_param("pintura", base.albedo_texture)
					m.set_shader_param("tem_pintura", 1.0)
				if m.shader == com_relevo:
					m.set_shader_param("relevo", base.normal_texture)
					m.set_shader_param("tem_relevo", 1.0)
					m.set_shader_param("relevo_forca", 1.15)
				m.set_shader_param("aspereza", clamp(base.roughness, 0.0, 1.0))
				m.set_shader_param("metal", clamp(base.metallic, 0.0, 1.0))
				m.set_shader_param("pele", 1.0 if eh_pele else 0.0)
				# Couro da luva: menos recorte (estourava num vermelho chapado).
				if mi.name.begins_with("Luva") or mi.name.begins_with("Bota"):
					m.set_shader_param("rim_forca", 0.16)
				if mi.name.begins_with("Luva"):
					# Couro fosco: o brilho branco sobre o vermelho puxava
					# para o rosa.
					m.set_shader_param("aspereza", max(base.roughness, 0.66))
				elif mi.name == "Cabelo":
					m.set_shader_param("rim_forca", 0.30)
				if eh_pele:
					_mat_leve_pele = m
				feitos[chave] = m
				_mats_leves.append(m)
			mi.set_surface_material(k, feitos[chave])


## A luz principal da arena, no espaço da câmera, e a cor do ambiente.
func luz(direcao: Vector3, cor: Color, forca: float, ambiente: Color) -> void:
	for m in _mats_leves:
		m.set_shader_param("luz_dir", direcao)
		m.set_shader_param("luz_cor", cor)
		m.set_shader_param("luz_forca", forca)
		m.set_shader_param("ambiente", ambiente)


const SHADER_PELE = "res://shaders/pele.shader"
const RELEVO_PELE = "res://assets/lutador3d/pele_relevo.png"
const POROS_PELE = "res://assets/lutador3d/pele_poros.png"
var _shader_pele: ShaderMaterial = null
var _dano_pintado = -1.0

func _material_da_pele(base: SpatialMaterial) -> ShaderMaterial:
	if base.albedo_texture == null:
		return null
	for caminho in [SHADER_PELE, RELEVO_PELE, POROS_PELE]:
		if not ResourceLoader.exists(caminho):
			return null
	var m = ShaderMaterial.new()
	m.shader = load(SHADER_PELE)
	m.set_shader_param("pintura", base.albedo_texture)
	m.set_shader_param("relevo", load(RELEVO_PELE))
	m.set_shader_param("poros", load(POROS_PELE))
	_shader_pele = m
	return m


func completo() -> bool:
	return _pronto


## Recorte de luz, textura filtrada de lado e brilho do material: o que faz
## o lutador "ler" em alta definição na imagem pequena da arena.
static func _definir(m: SpatialMaterial, aspereza: float, recorte: float, dois_lados := false) -> void:
	# Opaco SEMPRE, e as cascas (calção, cinturão, luvas, botas) com as
	# duas faces: vista por baixo ou pela perna, a face de dentro sumia e
	# o calção parecia transparente.
	m.flags_transparent = false
	if dois_lados:
		m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	m.roughness = aspereza
	# O RECORTE FICOU DISCRETO: na Mali-450 a borda da silhueta com recorte
	# forte virava um pontilhado branco em volta do cabelo, dos ombros e das
	# luvas (visto na TV Box). Um pouco de recorte ainda descola o corpo do
	# fundo.
	m.rim_enabled = true
	m.rim = recorte
	m.rim_tint = 0.55


func _mapear() -> void:
	_nomes.resize(_sk.get_bone_count())
	_pais.resize(_sk.get_bone_count())
	for k in _sk.get_bone_count():
		var nome = _sk.get_bone_name(k)
		var curto = nome
		for sep in [":", "_"]:
			var p = nome.find(sep)
			if p >= 0 and nome.substr(0, p).to_lower().begins_with("mixamorig"):
				curto = nome.substr(p + 1)
				break
		_i[curto] = k
		_nomes[k] = curto
		_pais[k] = _sk.get_bone_parent(k)
	# O Godot 3 não dá o repouso global pronto: ele é o do pai vezes o
	# próprio. E a pose do Godot 3 é aplicada POR CIMA do repouso (no 4 ela
	# substitui) — guarda-se o inverso do repouso para converter.
	var global_rest = []
	_repouso_inv.clear()
	_repouso_origem.clear()
	for k in _sk.get_bone_count():
		var rest: Transform = _sk.get_bone_rest(k)
		var pai = _sk.get_bone_parent(k)
		global_rest.append(global_rest[pai] * rest if pai >= 0 else rest)
		_repouso_inv.append(rest.affine_inverse())
		_repouso_origem.append(rest.origin)
		_R[_nomes[k]] = (global_rest[k] as Transform).origin
	# Eixo secundário de repouso de cada osso de membro: é ele que decide
	# a torção (para onde aponta o bíceps, o joelho, o polegar).
	for s in ["Left", "Right"]:
		var polegar: Vector3 = _R[s + "HandThumb1"] - _R[s + "Hand"]
		# (+Z é a frente do lutador; em repouso o cotovelo aponta para trás
		# e o joelho para a frente.)
		_secundario[s + "Arm"] = Vector3(0, 0, -1)
		_secundario[s + "ForeArm"] = polegar
		_secundario[s + "Hand"] = polegar
		_secundario[s + "UpLeg"] = Vector3(0, 0, 1)
		_secundario[s + "Leg"] = Vector3(0, 0, 1)
		_secundario[s + "Foot"] = Vector3.UP
		_secundario[s + "ToeBase"] = Vector3.UP


func _reiniciar_corpo() -> void:
	_centro = Vector2.ZERO
	_centro_alvo = Vector2.ZERO
	_centro_vel = Vector2.ZERO
	for k in 2:
		var base = _base_do_pe(k)
		_pe[k] = Vector3(base.x, _tornozelo, base.y)
		_pe_giro[k] = _giro_do_pe(k)
		_passo_t[k] = -1.0
		_calcanhar[k] = 0.0
	_bacia = Vector3(0.0, _h0 - 0.05, 0.0)
	_bacia_rot = Vector3(0.0, GIRO_DA_BASE, 0.0)
	_tronco = Vector3.ZERO
	_cabeca = Vector3.ZERO
	_mola_cab = Vector3.ZERO
	_mola_cab_v = Vector3.ZERO
	_mola_tronco = Vector3.ZERO
	_mola_tronco_v = Vector3.ZERO
	_guarda_aberta = 0.0
	_guarda_aberta_v = 0.0
	_joelho = 0.0
	_joelho_v = 0.0
	_tonto = 0.0
	_fila.clear()
	_queda_vis = 0.0
	_pes_livres = 0.0
	_dolly = 0.0
	_tela_ok = false
	_tela_bateu = false
	for k in 2:
		_mao[k] = _no_tronco(_guarda_local(k, 1.0))
		_mao_dir[k] = Vector3(0, 0.8, 0.6).normalized()
		_polegar[k] = Vector3(0, 0.4, -1).normalized()
		_cotovelo[k] = Vector3(0.3 * _lado_s(k), -1, -0.3).normalized()


func preparar() -> void:
	.preparar()
	if _pronto:
		_reiniciar_corpo()
		for nome in _expr_valor:
			_expr_valor[nome] = 0.0
			if _pele != null:
				_pele.set("blend_shapes/" + nome, 0.0)
		_pintar()


## AQUECIMENTO: a arena mostra cada pose por um quadro no arranque. Aqui
## também acendem as expressões e o clarão do golpe — cada um é um
## caminho de shader que, sem isso, compilaria no primeiro soco.
func mostrar_pose(nome: String) -> void:
	.mostrar_pose(nome)
	if not _pronto:
		return
	for k in _expr:
		_pele.set("blend_shapes/" + k, 0.5)
	_clarao = 1.0
	_pintar()
	_resolver()


## O que não muda de um quadro para o outro, calculado uma vez: a base de
## repouso de cada osso comandado (já transposta) e a lista de quem a pose
## comanda — o resto (dedos, pontas) só segue o pai.
func _preparar_ossos() -> void:
	var comandados = ["Hips", "Neck", "Head"] + COLUNA
	for lista in [L_SHOULDER, L_ARM, L_FOREARM, L_HAND, L_UPLEG, L_LEG, L_FOOT, L_TOE]:
		comandados.append_array(lista)
	_comandado.resize(_nomes.size())
	for k in _nomes.size():
		_comandado[k] = 1 if _nomes[k] in comandados else 0
	for osso in comandados:
		var filho = _filho(osso)
		if filho == osso or not _R.has(filho):
			continue
		var dR: Vector3 = (_R[filho] - _R[osso]).normalized()
		var sR: Vector3 = _secundario.get(osso, Vector3.BACK)
		_repouso_t[osso] = _ortonormal(dR, sR).transposed()
	_gravou_fixos = false


static func _lado_s(k: int) -> float:
	return 1.0 if k == 0 else -1.0


static func _lado_n(k: int) -> String:
	return "Left" if k == 0 else "Right"


func _base_do_pe(k: int) -> Vector2:
	var b = PE_FRENTE if k == 0 else PE_TRAS
	return _centro + b


func _giro_do_pe(k: int) -> float:
	return -0.10 if k == 0 else -0.38


# ===================================================================
# INTERFACE
# ===================================================================
func poses() -> PoolStringArray:
	return PoolStringArray(["guard", "celebra", "deboche", "hit_heavy", "knockout", "soco_tela", "idle"])


func _sombra_da_base() -> bool:
	return false


func bater(forca: float, derruba := false, pontos := -1, ultimo := false) -> Dictionary:
	var r = .bater(forca, derruba, pontos, ultimo)
	if not _pronto:
		return r
	var f = clamp(forca, 0.0, 1.0)
	_fila.clear()
	_tela_ok = false
	var papel = str(r.get("reacao", ""))
	if papel == "taunt_weak":
		# Nem sentiu: o queixo mal mexe.
		_mola_cab_v += Vector3(-1.2, 0.8 * _lado, 0.0)
		_tempo_reacao = 2.3
		return r
	# O soco vem da câmera (de frente): a cabeça vai para trás e para o
	# lado, o tronco recua, a guarda abre e o corpo é empurrado — os pés
	# vão ter de dar passos para segurar o peso.
	var forte = 0.35 + f * 0.9
	_mola_cab_v += Vector3(-9.5 * forte, _lado * 5.5 * forte, _lado * 4.0 * forte)
	_mola_tronco_v += Vector3(-4.5 * forte, _lado * 2.2 * forte, _lado * 1.6 * forte)
	_guarda_aberta_v += 7.0 * forte
	_joelho_v += 3.5 * forte
	_centro_vel += Vector2(_lado * 0.35 * f, -(0.55 + 1.35 * f))
	if papel == "stagger" or bool(r.get("nocaute", false)):
		_tonto = 1.6
	return r


func soco_na_tela() -> bool:
	if not _pronto or _caindo or _papel in PAPEIS_DE_FESTA:
		return false
	if _papel != "guard" and _papel != "idle":
		return false
	_fila.clear()
	_tela_ok = true
	_tela_bateu = false
	_tempo_reacao = 2.9
	_tocar("soco_tela")
	return true


## O SOCO FINAL: quem perdeu leva o nocaute. É o mesmo direto na câmera,
## mas sai no fim da rodada (por cima da provocação), e depois dele o
## lutador vai para o deboche — a comemoração de quem ganhou a luta.
func soco_final() -> bool:
	if not _pronto or _caindo:
		return false
	if _comemora_depois_do_soco:
		_comemora_depois_do_soco = false
		_vai_comemorar = true
	_fila.clear()
	_tela_ok = true
	_tela_bateu = false
	_tempo_reacao = 2.4
	_papel = ""
	_tocar("soco_tela")
	return true


func tela_atingida() -> bool:
	if _tela_bateu:
		_tela_bateu = false
		return true
	return false


func camera_extra() -> Vector2:
	return Vector2(_dolly, _dolly * 0.08)


func deslocamento() -> Vector3:
	var s = _modelo.scale.x if _modelo != null else 1.0
	return Vector3(_centro.x * s, 0.0, _centro.y * s) + (_corpo.translation if _corpo != null else Vector3.ZERO)


# ===================================================================
# O QUADRO
# ===================================================================
## O CORPO NÃO ANDA EM CÂMERA LENTA. O passo do corpo tinha teto de
## 50 ms: numa TV Box rodando a 15–20 quadros por segundo cada quadro
## perdia um terço do tempo, e a luta inteira ficava lenta. Agora o quadro
## longo é fatiado em passos de até 1/30 s — as molas continuam estáveis e
## o relógio da luta anda junto com o relógio do jogo.
const SUBPASSO = 1.0 / 30.0
## O RITMO DA LUTA: o corpo inteiro anda 40% mais rápido que o relógio —
## guarda, passos, reações e comemoração. No tempo "real" o boxeador
## parecia em câmera lenta na tela da máquina.
const VELOCIDADE = 1.4

## Verdadeiro só no último subpasso do quadro: é nele que a pose é montada.
var _montar_pose = true
var _dt_do_quadro = 0.0

func atualizar(delta: float) -> void:
	var resto = clamp(delta, 0.0, 0.15) * VELOCIDADE
	_dt_do_quadro = resto
	while true:
		var d = min(resto, SUBPASSO)
		_dt = d
		resto -= d
		_montar_pose = resto <= 0.0005
		.atualizar(d)
		if _montar_pose:
			break
	_montar_pose = true


func _mover_o_corpo() -> void:
	if not _pronto:
		return
	var dt = _dt
	if _papel != "soco_tela":
		_dolly = lerp(_dolly, 0.0, 1.0 - exp(-dt * 5.0))
	_molas(dt)
	_coreografia(dt)
	_suavizar(dt)
	_andar(dt)
	_raiz()
	if not _montar_pose:
		return
	_resolver()
	_rosto(_dt_do_quadro)


func _molas(dt: float) -> void:
	# Mola amortecida: vai, passa um pouco e volta. É o "chacoalhar" que
	# faz um golpe parecer ter massa.
	var k = 95.0
	var c = 11.0
	_mola_cab_v += (-_mola_cab * k - _mola_cab_v * c) * dt
	_mola_cab += _mola_cab_v * dt
	_mola_tronco_v += (-_mola_tronco * 70.0 - _mola_tronco_v * 10.0) * dt
	_mola_tronco += _mola_tronco_v * dt
	_guarda_aberta_v += (-_guarda_aberta * 40.0 - _guarda_aberta_v * 9.0) * dt
	_guarda_aberta = clamp(_guarda_aberta + _guarda_aberta_v * dt, -0.2, 1.3)
	_joelho_v += (-_joelho * 45.0 - _joelho_v * 8.0) * dt
	_joelho = clamp(_joelho + _joelho_v * dt, -0.3, 1.2)
	_tonto = max(0.0, _tonto - dt)


# ===================================================================
# COREOGRAFIA
# ===================================================================
func _coreografia(dt: float) -> void:
	var t = _relogio
	var tp = _tempo_no_papel
	a_expr = {}
	_rapidez = 16.0
	for k in 2:
		a_calcanhar[k] = 0.0
		a_ombro[k] = Vector2.ZERO
	a_bacia_rot = Vector3(0.0, GIRO_DA_BASE, 0.0)
	a_tronco = Vector3(0.10, 0.0, 0.0)
	a_cabeca = Vector3(0.10, 0.0, 0.0)
	var guarda = 1.0

	# ---- a ginga: quique na ponta dos pés, peso indo e vindo.
	var compasso = 1.9 if _papel == "guard" else 1.35
	var fase = t * TAU * compasso * 0.5
	var quique = 0.5 - 0.5 * cos(fase * 2.0)
	var balanco = sin(fase)
	var ginga = 1.0
	var agacha = 0.075
	if _papel == "idle":
		agacha = 0.045
		guarda = 0.55
		ginga = 0.7
	a_bacia = Vector3(balanco * 0.018 * ginga, _h0 - agacha - quique * 0.022 * ginga, 0.0)
	a_bacia_rot.z = balanco * 0.035 * ginga
	a_tronco.z = -balanco * 0.03 * ginga
	a_tronco.x += quique * 0.02
	for k in 2:
		a_calcanhar[k] = quique * 0.35 * ginga
	# respiração
	a_tronco.x += sin(t * 2.4) * 0.012
	a_ombro[0].x = sin(t * 2.4) * 0.02
	a_ombro[1].x = sin(t * 2.4) * 0.02

	# ---- andar pelo ringue: um ponto novo de tempos em tempos.
	_vagar_em -= dt
	if _vagar_em <= 0.0 and (_papel == "guard" or _papel == "idle"):
		_vagar_em = _rng.randf_range(1.2, 2.8)
		_centro_alvo = Vector2(_rng.randf_range(-0.16, 0.16), _rng.randf_range(-0.12, 0.10))

	# ---- as luvas na guarda (no espaço do tronco)
	for k in 2:
		a_mao[k] = _guarda_local(k, guarda)
		a_mao_dir[k] = Vector3(0.12 * -_lado_s(k), 0.82, 0.55).normalized()
		a_polegar[k] = Vector3(-0.35 * _lado_s(k), 0.35, -0.85).normalized()
		a_cotovelo[k] = Vector3(0.35 * _lado_s(k), -1.0, -0.15).normalized()

	match _papel:
		"guard":
			_combos_no_ar(dt)
		"idle":
			# Solto, antes da luta: ombros girando, luvas batendo.
			if fmod(t, 7.0) < 1.2:
				var g = sin(fmod(t, 7.0) / 1.2 * PI)
				a_ombro[0].x += g * 0.12
				a_ombro[1].x += g * 0.12
				a_cabeca.z += sin(t * 5.0) * 0.18 * g
			if fmod(t + 3.0, 6.0) < 0.5:
				var g2 = sin(fmod(t + 3.0, 6.0) / 0.5 * PI)
				a_mao[0] += Vector3(-0.07, 0.0, 0.05) * g2
				a_mao[1] += Vector3(0.07, 0.0, 0.05) * g2
		"taunt_weak":
			_nem_sentiu(tp)
		"hit_light", "hit_medium", "hit_heavy":
			a_expr["dor"] = 1.0 if tp < 0.7 else 0.4
			_rapidez = 12.0
		"stagger":
			a_expr["dor"] = 1.0
			_rapidez = 9.0
		"celebra":
			_celebrar(tp)
		"deboche":
			_debochar(tp)
		"tonto":
			_zonzo(tp)
		"soco_tela":
			_socar_a_tela(tp)
		"cordas":
			_nas_cordas(tp)
		"knockout":
			# Apagou: os joelhos cedem, a cabeça vai para trás e a guarda cai
			# antes de o corpo tombar.
			a_expr["apagado"] = 1.0
			a_bacia.y -= 0.10
			a_tronco.x -= 0.15
			a_cabeca.x -= 0.35
			for k in 2:
				a_mao[k] = _guarda_local(k, 0.15)
			_rapidez = 14.0
		"get_up":
			# Levantando: o rosto ainda zonzo, o tronco curvado sobre os
			# joelhos no meio do caminho (a pose-chave está em
			# `_pose_levantando`).
			var g = _levantar_g()
			a_expr["apagado"] = 0.4 * (1.0 - g)
			a_expr["dor"] = 0.8
			a_tronco.x += 0.30 * sin(g * PI)
			a_cabeca.x += 0.12 * sin(g * PI)

	_golpes_em_andamento(dt)

	# ---- cambaleio: o corpo procura o equilíbrio em passos tortos.
	if _tonto > 0.0:
		var w = clamp(_tonto, 0.0, 1.0)
		_centro_alvo += Vector2(sin(t * 3.3) * 0.10, sin(t * 2.1) * 0.06) * w * dt * 4.0
		a_bacia_rot.z += sin(t * 4.1) * 0.10 * w
		a_tronco.z += sin(t * 3.2 + 1.0) * 0.12 * w
		a_cabeca += Vector3(sin(t * 2.7) * 0.15, sin(t * 1.9) * 0.2, sin(t * 3.1) * 0.2) * w
		for k in 2:
			a_mao[k] += Vector3(0.0, -0.16, -0.02) * w
		a_expr["dor"] = max(float(a_expr.get("dor", 0.0)), w)

	# ---- reações por cima de tudo (molas)
	var abre = clamp(_guarda_aberta, 0.0, 1.2)
	for k in 2:
		a_mao[k] += Vector3(0.10 * _lado_s(k), -0.18, -0.10) * abre
	a_bacia.y -= clamp(_joelho, -0.2, 1.0) * 0.09

	# ---- a cabeça olha para quem joga (compensa o giro da base)
	a_cabeca.y += -(a_bacia_rot.y + a_tronco.y) * 0.75

	# ---- o deslocamento do corpo: empurrão do golpe + vontade de andar
	var centro_antes = _centro
	_centro_vel *= exp(-dt * 3.2)
	var puxa = (_centro_alvo - _centro) * 2.2
	_centro += (_centro_vel + puxa) * dt
	_centro.x = clamp(_centro.x, -0.55, 0.55)
	# Nas cordas ele pode chegar até elas; fora disso, fica no miolo.
	_centro.y = clamp(_centro.y, -CORDAS_Z if _papel == "cordas" else -0.95, 1.05)
	# NA QUEDA, OS PÉS ESCORREGAM PARA A FRENTE. O corpo tomba para trás
	# em volta dos pés; caindo de onde o empurrão do soco o deixou, a
	# cabeça passava por baixo das cordas e ia parar FORA do ringue. Como
	# num nocaute de verdade, os pés deslizam para a frente enquanto o
	# tronco vai para trás — e o corpo inteiro deita dentro da lona.
	if _queda_vis > 0.0 and _modelo != null and _papel != "get_up":
		var livre = (ALTURA_DA_FIGURA * 1.02 - RINGUE_LIVRE) / max(_modelo.scale.x, 0.01)
		var junto = clamp(_queda_vis * 1.6, 0.0, 1.0)
		_centro.y = max(_centro.y, lerp(_centro.y, livre, junto))
		_centro.x = lerp(_centro.x, clamp(_centro.x, -0.35, 0.35), junto)
		_centro_vel.y = max(_centro_vel.y, 0.0)
	# Caindo, os pés não dão passo (`_andar` para): eles deslizam junto
	# com o corpo, que é o que um corpo desabando faz.
	if (_caindo or queda > 0.01) and _papel != "get_up":
		var arrasto = _centro - centro_antes
		for k in 2:
			_pe[k] += Vector3(arrasto.x, 0.0, arrasto.y)
	a_bacia.x += _centro.x
	a_bacia.z += _centro.y


## Onde a luva fica na guarda, no espaço do mundo, a partir do tronco.
func _guarda_local(k: int, fechada: float) -> Vector3:
	var s = _lado_s(k)
	var frente = k == 0
	var alvo = Vector3(0.115 * s, -0.035, 0.29) if frente else Vector3(-0.10, -0.055, 0.22)
	var baixa = Vector3(0.17 * s, -0.20, 0.12)
	return baixa.linear_interpolate(alvo, clamp(fechada, 0.0, 1.0))


# ---------------------------------------------------------- os golpes
func _combos_no_ar(dt: float) -> void:
	_proximo_combo -= dt
	if _proximo_combo <= 0.0 and _fila.empty():
		_proximo_combo = _rng.randf_range(2.2, 4.8)
		var combo: Array = COMBOS[_rng.randi_range(0, COMBOS.size() - 1)]
		var atraso = 0.0
		for g in combo:
			_fila.append({"tipo": g[0], "lado": g[1], "t": -atraso})
			atraso += float(GOLPES[g[0]]["dur"]) * _rng.randf_range(0.62, 0.8)


func _golpes_em_andamento(dt: float) -> void:
	if _fila.empty():
		return
	var vivos: Array = []
	for g in _fila:
		g["t"] = float(g["t"]) + dt
		var receita: Dictionary = GOLPES[g["tipo"]]
		var dur: float = receita["dur"]
		var tt: float = g["t"] / dur
		if tt < 0.0:
			vivos.append(g)
			continue
		if tt > 1.0:
			continue
		vivos.append(g)
		_aplicar_golpe(str(g["tipo"]), int(g["lado"]), tt, float(receita["pico"]))
	_fila = vivos


## Envelope de um golpe: recolhe um pouco, estica rápido, segura um
## instante e volta.
static func _envelope(tt: float, pico: float) -> float:
	if tt < 0.12:
		return -0.12 * sin(tt / 0.12 * PI * 0.5)
	if tt < pico:
		var u = (tt - 0.12) / (pico - 0.12)
		return -0.12 + 1.12 * (1.0 - pow(1.0 - u, 3.0))
	if tt < pico + 0.08:
		return 1.0
	var v = (tt - pico - 0.08) / (1.0 - pico - 0.08)
	return 1.0 - v * v * (3.0 - 2.0 * v)


func _aplicar_golpe(tipo: String, k: int, tt: float, pico: float) -> void:
	var e = _envelope(tt, pico)
	var ep = max(e, 0.0)
	var s = _lado_s(k)
	_rapidez = max(_rapidez, 34.0)
	var ombro: Vector3 = _R[_lado_n(k) + "Arm"] + Vector3(_bacia.x, _bacia.y - _h0, _bacia.z)
	var alcance = (_l_braco + _l_ante) * 0.97
	match tipo:
		"jab", "direto":
			var mira = Vector3(-0.03 * s, 1.47, 1.2) + Vector3(_centro.x, 0.0, _centro.y)
			var d = (mira - ombro).normalized()
			var fim = _do_mundo(ombro + d * alcance)
			a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(fim, ep)
			a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(d, ep).normalized()
			a_polegar[k] = (a_polegar[k] as Vector3).linear_interpolate(Vector3(-s, 0.25, 0.0).normalized(), ep).normalized()
			a_cotovelo[k] = (a_cotovelo[k] as Vector3).linear_interpolate(Vector3(0.8 * s, -0.5, 0.0).normalized(), ep).normalized()
			a_ombro[k] += Vector2(0.10, 0.18) * ep
			if tipo == "direto":
				# O direto vem do chão: gira bacia e tronco, o calcanhar de
				# trás sobe e gira.
				a_bacia_rot.y += 0.55 * e
				a_tronco.y += 0.35 * e
				a_calcanhar[1] = max(a_calcanhar[1], ep)
				a_bacia.z += 0.04 * ep
			else:
				a_tronco.y += -0.14 * e
				a_bacia.z += 0.02 * ep
			a_cabeca.z += 0.06 * s * ep
		"gancho":
			var mira2 = _do_mundo(ombro + Vector3(-0.28 * s, 0.02, 0.36))
			a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(mira2, ep)
			a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(Vector3(-s, 0.1, 0.35).normalized(), ep).normalized()
			a_polegar[k] = (a_polegar[k] as Vector3).linear_interpolate(Vector3.UP, ep).normalized()
			a_cotovelo[k] = (a_cotovelo[k] as Vector3).linear_interpolate(Vector3(s, 0.35, -0.2).normalized(), ep).normalized()
			a_tronco.y += (-0.55 if k == 0 else 0.55) * e
			a_bacia_rot.y += (-0.30 if k == 0 else 0.30) * e
			a_calcanhar[k] = max(a_calcanhar[k], ep * 0.8)
		"upper":
			var baixo = ombro + Vector3(-0.05 * s, -0.30, 0.22)
			var alto = ombro + Vector3(-0.10 * s, 0.14, 0.36)
			var alvo = _do_mundo(baixo.linear_interpolate(alto, clamp(e, 0.0, 1.0)))
			a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(alvo, clamp(abs(e) * 1.5, 0.0, 1.0))
			a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(Vector3(0.0, 1.0, 0.25).normalized(), ep).normalized()
			a_polegar[k] = (a_polegar[k] as Vector3).linear_interpolate(Vector3(0, 0.2, -1).normalized(), ep).normalized()
			a_cotovelo[k] = (a_cotovelo[k] as Vector3).linear_interpolate(Vector3(0.2 * s, -1.0, 0.1).normalized(), ep).normalized()
			a_bacia.y -= 0.05 * sin(clamp(tt / pico, 0.0, 1.0) * PI * 0.5) * (1.0 - ep) + 0.02 * ep
			a_tronco.y += (0.40 if k == 1 else -0.40) * e
			a_tronco.x += -0.10 * ep
	a_expr["grito"] = max(float(a_expr.get("grito", 0.0)), ep * 0.35)


# ------------------------------------------------------- o que ele faz
## NAS CORDAS. 0–0,45 s: vai de costas até elas. 0,45–1,05 s: encosta,
## tronco para trás, braços abertos por cima da corda, as cordas cedem.
## Depois: as cordas o devolvem — um passo para a frente e a guarda volta.
const CORDAS_Z = 1.22
var _cordas_devolveu = false

func _nas_cordas(tp: float) -> void:
	var vai = clamp(tp / 0.45, 0.0, 1.0)
	var apoio = clamp((tp - 0.30) / 0.25, 0.0, 1.0) * (1.0 - clamp((tp - 1.05) / 0.35, 0.0, 1.0))
	if tp < 1.05:
		_cordas_devolveu = false
		_centro_alvo = Vector2(_centro.x * 0.6, lerp(_centro.y, -CORDAS_Z, ease(vai, 0.5)))
		_vagar_em = 2.0
	elif not _cordas_devolveu:
		# o estilingue das cordas
		_cordas_devolveu = true
		_centro_vel += Vector2(0.0, 2.1)
		_centro_alvo = Vector2(_rng.randf_range(-0.08, 0.08), 0.02)
	a_tronco.x -= 0.34 * apoio
	a_cabeca.x -= 0.22 * apoio
	a_bacia.y -= 0.03 * apoio
	for k in 2:
		var sl = _lado_s(k)
		var na_corda = Vector3(0.46 * sl, -0.04, -0.20)
		a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(na_corda, apoio)
		a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(Vector3(sl, -0.2, -0.3).normalized(), apoio).normalized()
		a_cotovelo[k] = (a_cotovelo[k] as Vector3).linear_interpolate(Vector3(sl, -0.5, -0.3).normalized(), apoio).normalized()
	a_expr["dor"] = 1.0 if tp < 1.2 else 0.5
	_rapidez = 10.0


## Quanto o corpo está empurrando as cordas (0–1), para a arena vergá-las.
func pressao_nas_cordas() -> float:
	if _papel != "cordas":
		return 0.0
	var fundo = clamp((-_centro.y - (CORDAS_Z - 0.18)) / 0.18, 0.0, 1.0)
	return fundo


func _nem_sentiu(tp: float) -> void:
	# Nem sentiu. Balança a cabeça, sorri de lado e chama com a luva.
	a_expr["deboche"] = clamp(tp * 3.0, 0.0, 1.0)
	if tp > 0.25 and tp < 1.1:
		var u = (tp - 0.25) / 0.85
		a_cabeca.y += sin(u * TAU * 2.0) * 0.28 * sin(u * PI)
	if tp > 1.0:
		var u2 = fmod(tp - 1.0, 0.65) / 0.65
		var chama = sin(u2 * PI)
		# a luva da frente sai e volta, "vem"
		a_mao[0] += Vector3(0.04, 0.02, 0.14) * chama
		a_mao_dir[0] = Vector3(0.0, 0.3 + 0.7 * chama, 0.9 - 0.6 * chama).normalized()
		a_cabeca.x -= 0.10
		a_cabeca.z += 0.12


func _celebrar(tp: float) -> void:
	# Aguentou: braços para o alto, pula com a torcida.
	var entra = clamp(tp * 3.0, 0.0, 1.0)
	var pulo = abs(sin(_relogio * TAU * 1.1))
	a_bacia.y += pulo * 0.035 * entra
	for k in 2:
		var s = _lado_s(k)
		var alto = Vector3(0.28 * s, 0.42 + 0.05 * sin(_relogio * 6.0 + k), 0.06)
		a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(alto, entra)
		a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(Vector3(0.1 * s, 1, 0.1).normalized(), entra).normalized()
		a_cotovelo[k] = (a_cotovelo[k] as Vector3).linear_interpolate(Vector3(s, 0.1, -0.2).normalized(), entra).normalized()
		a_calcanhar[k] = max(a_calcanhar[k], pulo * entra)
	a_cabeca.x -= 0.25 * entra
	a_expr["grito"] = entra * (0.6 + 0.4 * sin(_relogio * 3.0))


func _debochar(tp: float) -> void:
	# A FESTA LONGA DE QUEM GANHOU DO JOGADOR. Oito segundos em cinco
	# atos, em laço: vitória, "Ali shuffle", aponta para a câmera e ri,
	# bate no queixo ("bate aqui"), mostra os bíceps.
	var ato = fmod(tp, 8.0)
	var entra = clamp(tp * 3.0, 0.0, 1.0)
	a_bacia_rot.y *= 0.4
	if ato < 1.5:
		_celebrar(ato + 0.4)
		return
	if ato < 3.4:
		# Ali shuffle: pés trocando rápido, luvas baixas balançando.
		var u = ato - 1.5
		var troca = sin(u * TAU * 3.2)
		_centro_alvo = Vector2(troca * 0.03, 0.0)
		for k in 2:
			var s = _lado_s(k)
			a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(Vector3(0.20 * s, -0.12 + 0.05 * troca * s, 0.16), entra)
			a_calcanhar[k] = 0.6
		a_bacia.y += abs(troca) * 0.02
		a_cabeca.y += sin(u * 5.0) * 0.18
		a_expr["deboche"] = 1.0
		return
	if ato < 5.0:
		# Aponta para quem jogou e ri.
		var u2 = clamp((ato - 3.4) * 4.0, 0.0, 1.0)
		var ombro: Vector3 = _R["LeftArm"] + Vector3(_bacia.x, _bacia.y - _h0, _bacia.z)
		var d = (Vector3(_centro.x, 1.5, 2.0) - ombro).normalized()
		a_mao[0] = (a_mao[0] as Vector3).linear_interpolate(_do_mundo(ombro + d * (_l_braco + _l_ante) * 0.95), u2)
		a_mao_dir[0] = (a_mao_dir[0] as Vector3).linear_interpolate(d, u2).normalized()
		a_cotovelo[0] = Vector3(0.7, -0.6, 0.0).normalized()
		var ri = 0.5 + 0.5 * sin(_relogio * 18.0)
		a_tronco.x += -0.12 - 0.04 * ri
		a_cabeca.x += -0.28 - 0.05 * ri
		a_mao[1] = (a_mao[1] as Vector3).linear_interpolate(Vector3(-0.05, -0.12, 0.14), u2)
		a_expr["grito"] = 0.5 + 0.35 * ri
		a_expr["deboche"] = 0.6
		return
	if ato < 6.5:
		# "Bate aqui": a luva bate duas vezes no próprio queixo.
		var u3 = ato - 5.0
		var bate = abs(sin(u3 * TAU * 1.4))
		a_mao[0] = (a_mao[0] as Vector3).linear_interpolate(Vector3(0.02, 0.10 + 0.03 * bate, 0.12 + 0.05 * bate), 0.9)
		a_mao_dir[0] = Vector3(-0.3, 0.9, 0.2).normalized()
		a_cabeca.x -= 0.18
		a_cabeca.z += 0.10
		a_expr["deboche"] = 1.0
		return
	# Mostra os bíceps, gritando.
	var u4 = clamp((ato - 6.5) * 4.0, 0.0, 1.0)
	for k in 2:
		var s = _lado_s(k)
		a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(Vector3(0.36 * s, 0.24, 0.04), u4)
		a_mao_dir[k] = (a_mao_dir[k] as Vector3).linear_interpolate(Vector3(-0.6 * s, 0.8, 0.0).normalized(), u4).normalized()
		a_cotovelo[k] = Vector3(s, -0.15, -0.2).normalized()
	a_tronco.x += 0.12 * u4
	a_expr["grito"] = u4


func _zonzo(tp: float) -> void:
	# Levou bonito e ficou de pé: zonzo, balança a cabeça, respeita.
	_tonto = max(_tonto, 0.8)
	var u = clamp(tp * 2.0, 0.0, 1.0)
	a_expr["dor"] = 0.7
	for k in 2:
		a_mao[k] = (a_mao[k] as Vector3).linear_interpolate(_guarda_local(k, 0.35), u)
	if tp > 2.0:
		# balança a cabeça: "que soco!"
		a_cabeca.y += sin(tp * 7.0) * 0.12
		a_cabeca.x += 0.12


func _socar_a_tela(tp: float) -> void:
	# QUEM DEMORA LEVA. Avança, arma, e solta o direto na câmera.
	if tp < 0.75:
		_centro_alvo = Vector2(0.02, 0.95)
		a_expr["deboche"] = 0.6
	elif tp < 1.55:
		_centro_alvo = Vector2(0.02, 0.95)
	else:
		_centro_alvo = Vector2(0.0, 0.0)
	var arma = clamp((tp - 0.72) / 0.28, 0.0, 1.0) * (1.0 - clamp((tp - 1.0) / 0.06, 0.0, 1.0))
	var solta = clamp((tp - 1.0) / 0.10, 0.0, 1.0)
	var volta = clamp((tp - 1.25) / 0.45, 0.0, 1.0)
	var e = solta * (1.0 - volta * volta * (3.0 - 2.0 * volta))
	# arma: recolhe o direito e gira o corpo para trás
	a_tronco.y += -0.35 * arma + 0.55 * e
	a_bacia_rot.y += -0.2 * arma + 0.6 * e
	a_calcanhar[1] = max(a_calcanhar[1], e)
	a_mao[1] = (a_mao[1] as Vector3) + Vector3(-0.04, 0.0, -0.06) * arma
	if e > 0.0:
		_rapidez = 40.0
		var cam = _camera_no_esqueleto()
		var ombro: Vector3 = _R["RightArm"] + Vector3(_bacia.x, _bacia.y - _h0, _bacia.z)
		var d = (cam - ombro).normalized()
		a_mao[1] = (a_mao[1] as Vector3).linear_interpolate(_do_mundo(ombro + d * (_l_braco + _l_ante)), e)
		a_mao_dir[1] = (a_mao_dir[1] as Vector3).linear_interpolate(d, e).normalized()
		a_polegar[1] = (a_polegar[1] as Vector3).linear_interpolate(Vector3(1, 0.3, 0).normalized(), e).normalized()
		a_cotovelo[1] = Vector3(-0.8, -0.5, 0.0).normalized()
		a_ombro[1] += Vector2(0.12, 0.28) * e
		a_bacia.z += 0.06 * e
	if _tela_ok and tp >= 1.09:
		_tela_ok = false
		_tela_bateu = true
	a_expr["grito"] = max(solta * (1.0 - volta), float(a_expr.get("grito", 0.0)))
	if tp > 1.6:
		a_expr["deboche"] = 1.0
	# a câmera vem ao encontro do soco e depois volta
	var alvo_dolly = 0.0
	if tp > 0.4 and tp < 1.7:
		alvo_dolly = 0.72 * clamp((tp - 0.4) / 0.6, 0.0, 1.0)
	_dolly = lerp(_dolly, alvo_dolly, 1.0 - exp(-_dt * 6.0))


func _camera_no_esqueleto() -> Vector3:
	if _sk == null or not _sk.is_inside_tree():
		return Vector3(0.0, 1.5, 2.6)
	return _sk.global_transform.affine_inverse() * ponto_da_camera


# ===================================================================
# SUAVIZAÇÃO, PASSOS E IK
# ===================================================================
func _suavizar(dt: float) -> void:
	var a = 1.0 - exp(-dt * _rapidez)
	var lento = 1.0 - exp(-dt * 10.0)
	_bacia = _bacia.linear_interpolate(a_bacia, a)
	_bacia_rot = _bacia_rot.linear_interpolate(a_bacia_rot, lento)
	_tronco = _tronco.linear_interpolate(a_tronco, a)
	_cabeca = _cabeca.linear_interpolate(a_cabeca, lento)
	for k in 2:
		# As luvas da guarda são guardadas relativas ao centro do corpo.
		var alvo: Vector3 = _no_tronco(a_mao[k])
		_mao[k] = (_mao[k] as Vector3).linear_interpolate(alvo, a)
		_mao_dir[k] = Compat.slerp3(_mao_dir[k] as Vector3, (a_mao_dir[k] as Vector3).normalized(), a).normalized()
		_polegar[k] = Compat.slerp3(_polegar[k] as Vector3, (a_polegar[k] as Vector3).normalized(), a).normalized()
		_cotovelo[k] = (_cotovelo[k] as Vector3).linear_interpolate(a_cotovelo[k], a).normalized()
		_ombro[k] = (_ombro[k] as Vector2).linear_interpolate(a_ombro[k], a)
		_calcanhar[k] = lerp(_calcanhar[k], a_calcanhar[k], a)


## Um ponto da guarda (medido a partir do peito) levado para o mundo,
## girando com o tronco: a guarda acompanha o corpo.
func _no_tronco(p: Vector3) -> Vector3:
	return _peito_base() + _peito_giro() * p


## O caminho inverso: um ponto do mundo (a câmera, o alvo de um golpe)
## no espaço da guarda.
func _do_mundo(p: Vector3) -> Vector3:
	return _peito_giro().inverse() * (p - _peito_base())


func _peito_giro() -> Basis:
	return Basis(Vector3(_bacia_rot.x + _tronco.x * 0.7, _bacia_rot.y + _tronco.y, _bacia_rot.z + _tronco.z))


func _peito_base() -> Vector3:
	var peito: Vector3 = _R["Spine2"]
	return Vector3(_bacia.x, peito.y + (_bacia.y - _h0), _bacia.z)


func _andar(dt: float) -> void:
	var livre = _caindo or queda > 0.01
	if livre:
		return
	# Um pé de cada vez: o que está mais longe de onde devia estar.
	var pior = -1
	var maior = LIMIAR_DO_PASSO
	for k in 2:
		if _passo_t[k] >= 0.0:
			continue
		var b = _base_do_pe(k)
		var d = Vector2(_pe[k].x, _pe[k].z).distance_to(b)
		var giro_err = abs(_pe_giro[k] - _giro_do_pe(k))
		if d > maior or giro_err > 0.5:
			maior = d
			pior = k
	var algum_andando: bool = _passo_t[0] >= 0.0 or _passo_t[1] >= 0.0
	if pior >= 0 and not algum_andando:
		var alvo = _base_do_pe(pior)
		# passo um pouco além, para o corpo ter para onde ir
		var sobra = (alvo - Vector2(_pe[pior].x, _pe[pior].z)) * 0.15
		_passo_t[pior] = 0.0
		_passo_de[pior] = _pe[pior]
		_passo_para[pior] = Vector3(alvo.x + sobra.x, _tornozelo, alvo.y + sobra.y)
		_passo_giro_de[pior] = _pe_giro[pior]
		_passo_giro_para[pior] = _giro_do_pe(pior)
	var pressa = 1.0 + clamp(_centro_vel.length() * 1.2, 0.0, 1.2)
	for k in 2:
		if _passo_t[k] < 0.0:
			continue
		_passo_t[k] += dt * pressa / TEMPO_DO_PASSO
		var u = clamp(_passo_t[k], 0.0, 1.0)
		var liso = u * u * (3.0 - 2.0 * u)
		var p: Vector3 = (_passo_de[k] as Vector3).linear_interpolate(_passo_para[k], liso)
		p.y = _tornozelo + sin(u * PI) * ALTURA_DO_PASSO
		_pe[k] = p
		_pe_giro[k] = lerp(_passo_giro_de[k], _passo_giro_para[k], liso)
		if _passo_t[k] >= 1.0:
			_passo_t[k] = -1.0
			_pe[k].y = _tornozelo


## A POSE: da coreografia até cada osso.
##
## Roda UMA vez por quadro, depois de todos os subpassos da física (ver
## `atualizar`). Os subpassos só integram molas, alvos e passos — que são
## contas pequenas; montar o esqueleto inteiro a cada subpasso custava
## três ou quatro poses por quadro justamente na TV Box que já estava
## atrasada, e é assim que um quadro lento vira uma sequência de quadros
## lentos.
func _resolver() -> void:
	var G = _G
	var O = _O
	var rot_bacia = Basis(_bacia_rot)
	var bacia = _bacia
	var deita = 0.0
	var levantando = _papel == "get_up" and _lev_ok
	for k in 2:
		_r_pe[k] = _pe_com_calcanhar(k)
		_r_tomba[k] = 0.0
		_r_mao[k] = _mao[k]
		_r_cot[k] = _cotovelo[k]
	if levantando:
		deita = _pose_levantando()
		bacia = _r_bacia
		rot_bacia = _r_rot
	elif _queda_vis > 0.001:
		# A QUEDA É O CORPO TODO GIRANDO PARA TRÁS EM VOLTA DOS PÉS — mas o
		# giro vai nos ALVOS (bacia, luvas, cotovelos), e não no nó do corpo.
		# Girar o nó levava os pés junto: eles saíam do chão, e no levantar
		# o lutador subia sentado no ar. Assim os pés ficam onde estão e as
		# pernas é que seguem o corpo.
		var q = _queda_vis
		var cai = ease(q, 2.2)
		var quique = sin(clamp((q - 0.86) / 0.14, 0.0, 1.0) * PI) * 0.06
		var ang = -QUEDA_ANGULO * cai + quique
		var piv = Vector3((_pe[0].x + _pe[1].x) * 0.5, _tornozelo, (_pe[0].z + _pe[1].z) * 0.5)
		var giro = Basis(Vector3.RIGHT, ang)
		bacia = piv + giro * (bacia - piv)
		rot_bacia = giro * rot_bacia
		for k in 2:
			_r_mao[k] = piv + giro * ((_mao[k] as Vector3) - piv)
			_r_cot[k] = giro * (_cotovelo[k] as Vector3)
			_r_tomba[k] = ang
		deita = clamp(q * 2.5, 0.0, 1.0)
		_deitado_bacia = bacia
		_deitado_ang = ang
	else:
		# ---- bacia: desce se alguma perna não alcança o chão.
		var falta = 0.0
		for k in 2:
			var quadril: Vector3 = bacia + rot_bacia * (_R[L_UPLEG[k]] - _R["Hips"])
			var pe: Vector3 = _r_pe[k]
			var h = Vector2(quadril.x - pe.x, quadril.z - pe.z).length()
			var alcance = (_l_coxa + _l_canela) * 0.985
			var alto = pe.y + sqrt(max(alcance * alcance - h * h, 0.0))
			falta = max(falta, quadril.y - alto)
		bacia.y -= falta
	G["Hips"] = rot_bacia
	O["Hips"] = bacia
	# ---- coluna
	var pai = "Hips"
	for i in 3:
		var n: String = COLUNA[i]
		var q = Basis((_tronco + _mola_tronco) * float(COLUNA_PESO[i]))
		G[n] = (G[pai] as Basis) * q
		O[n] = (O[pai] as Vector3) + (G[pai] as Basis) * (_R[n] - _R[pai])
		pai = n
	var cab = _cabeca + _mola_cab
	G["Neck"] = (G["Spine2"] as Basis) * Basis(cab * 0.4)
	O["Neck"] = (O["Spine2"] as Vector3) + (G["Spine2"] as Basis) * (_R["Neck"] - _R["Spine2"])
	G["Head"] = (G["Neck"] as Basis) * Basis(cab * 0.6)
	O["Head"] = (O["Neck"] as Vector3) + (G["Neck"] as Basis) * (_R["Head"] - _R["Neck"])
	# ---- braços
	for k in 2:
		var sg = _lado_s(k)
		var ombro: String = L_SHOULDER[k]
		var braco: String = L_ARM[k]
		var cl = (G["Spine2"] as Basis) * Basis(Vector3(0.0, -_ombro[k].y * sg * 0.6, _ombro[k].x * sg))
		G[ombro] = cl
		O[ombro] = (O["Spine2"] as Vector3) + (G["Spine2"] as Basis) * (_R[ombro] - _R["Spine2"])
		var raiz: Vector3 = (O[ombro] as Vector3) + cl * (_R[braco] - _R[ombro])
		var mao: Vector3 = _r_mao[k]
		var polo: Vector3 = _r_cot[k]
		if levantando:
			mao = _mao_levantando(k, O, G)
			polo = _r_cot[k]
		elif deita > 0.0:
			mao = mao.linear_interpolate(_mao_deitado(k, O, G), deita)
		# A luva nunca entra na lona (apoio no chão, braço largado).
		mao.y = max(mao.y, RAIO_DA_LUVA)
		var ik = _ik(raiz, mao, _l_braco, _l_ante, polo)
		var cot: Vector3 = ik[0]
		var pulso: Vector3 = ik[1]
		var dobra: Vector3 = ik[2]
		G[braco] = _girar(braco, cot - raiz, dobra)
		O[braco] = raiz
		var pol: Vector3 = _polegar[k]
		G[L_FOREARM[k]] = _girar(L_FOREARM[k], pulso - cot, pol)
		O[L_FOREARM[k]] = cot
		# PUNHO RETO, como de boxeador: a luva segue o antebraço (é ele
		# que o punho da luva abraça). Só uma pitada da direção pedida,
		# para o gesto não ficar duro.
		var ante = (pulso - cot).normalized()
		var dir_mao: Vector3 = Compat.slerp3(ante, (_mao_dir[k] as Vector3).normalized(), 0.12).normalized()
		G[L_HAND[k]] = _girar(L_HAND[k], dir_mao, pol)
		O[L_HAND[k]] = pulso
	# ---- pernas
	for k in 2:
		var coxa: String = L_UPLEG[k]
		var raiz: Vector3 = bacia + rot_bacia * (_R[coxa] - _R["Hips"])
		var pe: Vector3 = _r_pe[k]
		var frente_pe = Vector3(sin(_pe_giro[k]), 0.0, cos(_pe_giro[k]))
		var cima_pe = Vector3.UP
		var tomba: float = _r_tomba[k]
		if abs(tomba) > 0.0001:
			# deitado, o pé acompanha a perna: dedos para cima
			var gp = Basis(Vector3.RIGHT, tomba)
			frente_pe = gp * frente_pe
			cima_pe = gp * cima_pe
		var polo = (frente_pe + Vector3(0.40 * _lado_s(k), 0.0, 0.0)).normalized()
		var ik = _ik(raiz, pe, _l_coxa, _l_canela, polo)
		var joelho: Vector3 = ik[0]
		var tornozelo: Vector3 = ik[1]
		var dobra: Vector3 = ik[2]
		G[coxa] = _girar(coxa, joelho - raiz, dobra)
		O[coxa] = raiz
		G[L_LEG[k]] = _girar(L_LEG[k], tornozelo - joelho, dobra)
		O[L_LEG[k]] = joelho
		# O CALCANHAR SOBE GIRANDO NA PLANTA DO PÉ. O osso do pé desce o
		# ângulo pedido e a planta (`_pe_com_calcanhar` já levantou o
		# tornozelo na medida certa) fica no chão.
		var inc = _inc_do_calcanhar(k) * (1.0 - deita)
		var frente = frente_pe * cos(inc) - cima_pe * sin(inc)
		var cima = cima_pe * cos(inc) + frente_pe * sin(inc)
		var dir_pe = frente * cos(_desce_pe) - cima * sin(_desce_pe)
		G[L_FOOT[k]] = _girar(L_FOOT[k], dir_pe, cima)
		O[L_FOOT[k]] = tornozelo
		# E OS DEDOS FICAM DEITADOS NA LONA. Eles giravam junto com o pé
		# (60% do giro) em volta do tornozelo: com o calcanhar no alto, a
		# biqueira da bota afundava 6 cm na lona — e a lona, desenhada na
		# frente, "cortava" o pé. Era o pé incompleto que sumia e voltava a
		# cada quique da guarda.
		var dir_dedo = frente_pe * cos(_desce_dedo) - cima_pe * sin(_desce_dedo)
		G[L_TOE[k]] = _girar(L_TOE[k], dir_dedo, cima_pe)
		O[L_TOE[k]] = tornozelo + (G[L_FOOT[k]] as Basis) * (_R[L_TOE[k]] - _R[L_FOOT[k]])
	# ---- NADA ATRAVESSA A LONA. Mede os pontos que encostam no chão (sola,
	# calcanhar, bacia, costas, cabeça) e, se algum passou, sobe o corpo
	# inteiro essa diferença. É a garantia que vale para qualquer pose —
	# guarda, golpe, queda, deitado e levantando.
	var fundo = INF
	for k in 2:
		var pe_b: Basis = G[L_FOOT[k]]
		var dedo_b: Basis = G[L_TOE[k]]
		var ponta: Vector3 = (O[L_TOE[k]] as Vector3) + dedo_b * (_R[L_TOE_END[k]] - _R[L_TOE[k]])
		fundo = min(fundo, ponta.y - _sola_ponta)
		fundo = min(fundo, (O[L_TOE[k]] as Vector3).y - _sola_planta)
		var calc: Vector3 = (O[L_FOOT[k]] as Vector3) + pe_b * _calcanhar_ofs
		fundo = min(fundo, calc.y)
	if deita > 0.0 or levantando:
		fundo = min(fundo, bacia.y - RAIO_DA_BACIA)
		fundo = min(fundo, (O["Spine2"] as Vector3).y - RAIO_DAS_COSTAS)
		var topo: Vector3 = (O["Head"] as Vector3) + (G["Head"] as Basis) * ((_R["HeadTop_End"] - _R["Head"]) * 0.5)
		fundo = min(fundo, topo.y - RAIO_DA_CABECA)
	if fundo < 0.0:
		bacia.y -= fundo
	# ---- grava no esqueleto
	for k in _nomes.size():
		var n = _nomes[k]
		var p = _pais[k]
		if not _comandado[k]:
			# osso sem comando (dedos, pontas): segue o pai. A rotação local
			# dele é a identidade — gravada uma vez só, e não a cada quadro.
			G[n] = G.get(_nomes[p], Basis.IDENTITY) if p >= 0 else Basis.IDENTITY
			if not _gravou_fixos:
				_gravar_osso(k, Basis.IDENTITY, _repouso_origem[k])
			continue
		var g: Basis = G[n]
		var local = g
		if p >= 0:
			local = (G.get(_nomes[p], Basis.IDENTITY) as Basis).inverse() * g
		_gravar_osso(k, Basis(local.get_rotation_quat()), bacia if k == _i["Hips"] else _repouso_origem[k])
	_gravou_fixos = true


## A pose LOCAL do osso (rotação e posição, como no Godot 4), convertida
## para o Godot 3, onde a pose vai por cima do repouso.
func _gravar_osso(k: int, rotacao: Basis, posicao: Vector3) -> void:
	_sk.set_bone_pose(k, _repouso_inv[k] * Transform(rotacao, posicao))


## Quanto o calcanhar do pé `k` está levantado, em radianos.
func _inc_do_calcanhar(k: int) -> float:
	return CALCANHAR_MAX * clamp(_calcanhar[k], 0.0, 1.0)


## Onde o TORNOZELO fica com o calcanhar levantado: o pé gira em volta da
## planta (o osso dos dedos), que continua no chão — e não em volta do
## próprio tornozelo, que era o que afundava a ponta da bota na lona.
func _pe_com_calcanhar(k: int) -> Vector3:
	var p: Vector3 = _pe[k]
	var inc = _inc_do_calcanhar(k)
	if inc <= 0.0001:
		return p
	var frente = Vector3(sin(_pe_giro[k]), 0.0, cos(_pe_giro[k]))
	var planta = p + frente * (_pe_l * cos(_desce_pe)) - Vector3(0.0, _pe_l * sin(_desce_pe), 0.0)
	return planta - frente * (_pe_l * cos(_desce_pe + inc)) + Vector3(0.0, _pe_l * sin(_desce_pe + inc), 0.0)


func _mao_deitado(k: int, O: Dictionary, G: Dictionary) -> Vector3:
	var s = _lado_s(k)
	var peito: Vector3 = O["Spine2"]
	var g: Basis = G["Spine2"]
	return peito + g * Vector3(0.50 * s, 0.10, -0.12)


# ------------------------------------------------------------- levantar
## O LEVANTAR EM QUATRO TEMPOS, com os pés no chão:
##
##   deitado → senta (o tronco sobe, as mãos apoiam atrás) → encolhe as
##   pernas (os pés vêm para baixo do corpo) → agacha com as luvas nos
##   joelhos → fica de pé e volta à guarda.
##
## Cada tempo é uma pose-chave e o caminho entre elas é suave (sai e
## chega devagar). O último tempo termina EXATAMENTE na pose de guarda
## que a coreografia está pedindo, então a volta ao combate não dá tranco.
const LEVANTAR_TEMPOS = [0.0, 0.24, 0.50, 0.76, 1.0]
const LEVANTAR_TOMBO = [0.0, -0.30, 0.22, 0.52, 0.0]

## Em que trecho do levantar estamos: [índice do trecho, fração suave].
static func _trecho(g: float) -> Vector2:
	for i in range(1, LEVANTAR_TEMPOS.size()):
		var t1: float = LEVANTAR_TEMPOS[i]
		if g <= t1 or i == LEVANTAR_TEMPOS.size() - 1:
			var t0: float = LEVANTAR_TEMPOS[i - 1]
			var u = clamp((g - t0) / max(t1 - t0, 0.001), 0.0, 1.0)
			return Vector2(float(i - 1), u * u * (3.0 - 2.0 * u))
	return Vector2(3.0, 1.0)


func _levantar_g() -> float:
	return clamp(_tempo_no_papel / TEMPO_LEVANTAR, 0.0, 1.0)


## Fotografa a pose de deitado e escolhe onde ele vai ficar de pé.
func _comecar_a_levantar() -> void:
	_lev_ok = true
	_lev_bacia = _deitado_bacia
	_lev_ang = _deitado_ang
	for k in 2:
		_lev_pe[k] = _pe[k]
	# De pé ele fica um passo atrás de onde estavam os pés (o corpo
	# levanta por cima deles, e não por cima da cabeça).
	var meio = Vector2((_pe[0].x + _pe[1].x) * 0.5, (_pe[0].z + _pe[1].z) * 0.5)
	_centro = Vector2(meio.x, meio.y - 0.40) - (PE_FRENTE + PE_TRAS) * 0.5
	_centro_alvo = _centro
	_centro_vel = Vector2.ZERO


## A pose do levantar: escreve bacia, giro e pés em `_r_*`. Devolve quanto
## os braços ainda estão "deitados" (para a luva largada na lona).
func _pose_levantando() -> float:
	var g = _levantar_g()
	var tr = _trecho(g)
	var i = int(tr.x)
	var u = tr.y
	var c = _centro
	var em_pe = _bacia
	var sentado = _lev_bacia + Vector3(0.0, 0.02, 0.0)
	var encolhido = Vector3(c.x, 0.16, c.y - 0.34)
	var agachado = Vector3(c.x, 0.47, c.y - 0.04)
	var chaves = [_lev_bacia, sentado, encolhido, agachado, em_pe]
	_r_bacia = (chaves[i] as Vector3).linear_interpolate(chaves[i + 1], u)
	var tombos = LEVANTAR_TOMBO.duplicate()
	tombos[0] = _lev_ang
	var tombo = lerp(tombos[i], tombos[i + 1], u)
	_r_rot = Basis(Vector3.RIGHT, tombo) * Basis(Vector3(_bacia_rot.x * (1.0 if i >= 3 else 0.0) * u, _bacia_rot.y, _bacia_rot.z))
	# Os pés: até sentar ficam onde caíram (dedos para cima); depois vêm
	# por baixo do corpo, num arco rasteiro, e plantam na base da guarda.
	for k in 2:
		var base = _base_do_pe(k)
		var plantado = Vector3(base.x, _tornozelo, base.y)
		if i <= 0:
			_r_pe[k] = _lev_pe[k]
			_r_tomba[k] = _lev_ang
		elif i == 1:
			var p: Vector3 = (_lev_pe[k] as Vector3).linear_interpolate(plantado, u)
			p.y += sin(u * PI) * 0.05
			_r_pe[k] = p
			_r_tomba[k] = lerp(_lev_ang, 0.0, u)
		else:
			_r_pe[k] = plantado
			_pe[k] = plantado
			_pe_giro[k] = _giro_do_pe(k)
			_passo_t[k] = -1.0
	return 1.0 - clamp(g / LEVANTAR_TEMPOS[1], 0.0, 1.0)


## As luvas no levantar: largadas → apoiadas atrás → nos joelhos → guarda.
func _mao_levantando(k: int, O: Dictionary, G: Dictionary) -> Vector3:
	var tr = _trecho(_levantar_g())
	var i = int(tr.x)
	var u = tr.y
	var s = _lado_s(k)
	var b: Vector3 = O["Hips"]
	var giro = Basis(Vector3.UP, _bacia_rot.y)
	var chaves = [
		_mao_deitado(k, O, G),
		Vector3(b.x, RAIO_DA_LUVA, b.z) + giro * Vector3(0.26 * s, 0.0, -0.20),
		b + giro * Vector3(0.17 * s, 0.26, 0.30),
		b + giro * Vector3(0.15 * s, 0.02, 0.24),
		_mao[k],
	]
	var cotovelos = [
		_cotovelo[k],
		Vector3(0.6 * s, -0.2, -0.7).normalized(),
		Vector3(0.7 * s, -0.5, -0.2).normalized(),
		Vector3(0.7 * s, -0.4, -0.3).normalized(),
		_cotovelo[k],
	]
	_r_cot[k] = (cotovelos[i] as Vector3).linear_interpolate(cotovelos[i + 1], u).normalized()
	return (chaves[i] as Vector3).linear_interpolate(chaves[i + 1], u)


## Base global de um osso: leva a direção de repouso (até o filho) para
## `dir` e o eixo secundário de repouso para `sec`.
func _girar(osso: String, dir: Vector3, sec: Vector3) -> Basis:
	var repouso: Basis = _repouso_t.get(osso, Basis.IDENTITY)
	return _ortonormal(dir, sec) * repouso


static func _ortonormal(d: Vector3, s: Vector3) -> Basis:
	var x = d.normalized()
	var y = s - x * s.dot(x)
	if y.length() < 0.0001:
		y = x.cross(Vector3.RIGHT if abs(x.x) < 0.9 else Vector3.UP)
	y = y.normalized()
	return Basis(x, y, x.cross(y))


static func _filho(osso: String) -> String:
	if osso.ends_with("ForeArm"):
		return osso.replace("ForeArm", "Hand")
	if osso.ends_with("Arm"):
		return osso.replace("Arm", "ForeArm")
	if osso.ends_with("Hand"):
		return osso + "Middle1"
	if osso.ends_with("UpLeg"):
		return osso.replace("UpLeg", "Leg")
	if osso.ends_with("Leg"):
		return osso.replace("Leg", "Foot")
	if osso.ends_with("Foot"):
		return osso.replace("Foot", "ToeBase")
	if osso.ends_with("ToeBase"):
		return osso.replace("ToeBase", "Toe_End")
	return osso


## IK de dois ossos. Devolve [junta, ponta, direção da dobra].
static func _ik(raiz: Vector3, alvo: Vector3, l1: float, l2: float, polo: Vector3) -> Array:
	var v = alvo - raiz
	var d = clamp(v.length(), abs(l1 - l2) + 0.001, (l1 + l2) * 0.9995)
	var dir = v.normalized() if v.length() > 0.0001 else Vector3.DOWN
	var ponta = raiz + dir * d
	var a = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h = sqrt(max(l1 * l1 - a * a, 0.0))
	var dobra = polo - dir * polo.dot(dir)
	if dobra.length() < 0.0001:
		dobra = dir.cross(Vector3.RIGHT)
	dobra = dobra.normalized()
	return [raiz + dir * a + dobra * h, ponta, dobra]


# ===================================================================
# ROSTO, QUEDA E TINTA
# ===================================================================
func _rosto(dt: float) -> void:
	if _pele == null:
		return
	var a = 1.0 - exp(-dt * MESCLA_EXPR)
	for nome in _expr:
		var alvo = clamp(float(a_expr.get(nome, 0.0)), 0.0, 1.0)
		var antes = float(_expr_valor[nome])
		var v = lerp(antes, alvo, a)
		if v < 0.002 and alvo <= 0.0:
			v = 0.0
		# Só mexe no rosto quando mudou: cada troca de peso refaz a malha
		# deformada na GPU, e o rosto parado não precisa disso.
		if abs(v - antes) > 0.0005 or (v == 0.0 and antes != 0.0):
			_expr_valor[nome] = v
			_pele.set("blend_shapes/" + nome, v)


func _raiz() -> void:
	# A QUEDA: quanto do tombo já aconteceu. O giro em si é aplicado nos
	# alvos da pose (ver `_resolver`), com os pés no chão; o nó do corpo
	# fica parado.
	var alvo = clamp(queda, 0.0, 1.0)
	if alvo > _queda_vis:
		_queda_vis = min(alvo, _queda_vis + _dt * 2.4)
	else:
		_queda_vis = alvo
	if _papel == "get_up" and not _lev_ok and _caindo:
		_comecar_a_levantar()
	elif _papel != "get_up" and _lev_ok:
		_lev_ok = false
	if _corpo.transform != Transform.IDENTITY:
		_corpo.transform = Transform.IDENTITY


func _pintar() -> void:
	if not _pronto or not _montar_pose:
		return
	# O clarão do golpe é um calor na pele, não um lençol branco: com 0,5
	# o corpo inteiro "estourava" e perdia forma no quadro do impacto.
	var brilho = clamp(_clarao, 0.0, 1.0) * 0.28
	if not _mats_leves.empty():
		if abs(brilho - _clarao_pintado) > 0.004:
			_clarao_pintado = brilho
			for m in _mats_leves:
				m.set_shader_param("clarao", brilho)
		var dl = clamp(dano, 0.0, 1.0)
		if _mat_leve_pele != null and abs(dl - _dano_pintado) > 0.01:
			_dano_pintado = dl
			_mat_leve_pele.set_shader_param("dano", dl)
		return
	_mat_clarao.albedo_color = Color(1.0, 0.62, 0.45) * brilho
	var ligado = brilho > 0.01
	for mi in _malhas:
		if (mi.material_overlay != null) != ligado:
			mi.material_overlay = _mat_clarao if ligado else null
	if _mat_pele != null:
		# O estrago aparece: a pele fica mais vermelha com o dano.
		var d = clamp(dano, 0.0, 1.0)
		_mat_pele.albedo_color = Color(1.0, 1.0 - 0.10 * d, 1.0 - 0.14 * d)
		if _shader_pele != null and abs(d - _dano_pintado) > 0.01:
			_dano_pintado = d
			_shader_pele.set_shader_param("dano", d)
