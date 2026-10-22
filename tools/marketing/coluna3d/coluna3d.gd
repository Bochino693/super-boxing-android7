extends Node

## O GABINETE COLUNA DO SUPER BOXING EM 3D, PARA O COMERCIAL (so no PC).
##
## Monta a coluna com as medidas de tools/marketing/adesivos_coluna.py
## (medidas.json) e os adesivos de marketing/adesivos/coluna/texturas, poe o
## JOGO DE VERDADE na tela (os quadros da captura) e grava cenas animadas,
## quadro a quadro (30 por segundo). Precisa do renderizador GLES3:
##   godot3 --video-driver GLES3 --path . res://tools/marketing/coluna3d/coluna3d.tscn --
##          --saida=/pasta --cena=revelar|soco|orbita|final|heroi|giro [--tamanho=1080x1920]
##          [--captura=/pasta/da/captura] [--recorte]
## Cenas: revelar (as luzes acendem e a camera recua), soco (a bola leva o
## soco e balanca), orbita (meia volta em torno da maquina), final (a
## maquina de frente, a camera chegando), heroi (uma foto), giro (volta
## inteira, 150 quadros). --recorte grava com fundo transparente.

const FPS = 30.0
const COR_FUNDO = Color(0.020, 0.010, 0.045)
const LED_COR = Color(0.30, 0.42, 1.0)
## A vista heroica (tres quartos pela direita, a maquina inteira no quadro em pe)
const HEROI = Vector3(2.15, 1.5, 4.7)

var M = {}
var marketing = ""
var saida = ""
var cena = "heroi"
var tamanho = Vector2(1080, 1920)
var pasta_captura = ""
var recorte = false
## --passo=N grava so um quadro a cada N (para conferir a cena depressa)
var passo = 1

var vp: Viewport
var mundo: Spatial
var camera: Camera
var maquina: Spatial
var _pivo_bola: Spatial
var _mola: MeshInstance
var _tela_tex: ImageTexture
var _tela_mat: SpatialMaterial
var _leds = []
var _luz_soco: OmniLight
var _luzes_cena = []
var _cenario = []
var _quadro = 0
var _i = 0
var _total = 1
var _quadro_da_tela = -1


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--cena="):
			cena = a.substr(7)
		elif a.begins_with("--tamanho="):
			var p = a.substr(10).split("x")
			tamanho = Vector2(int(p[0]), int(p[1]))
		elif a.begins_with("--captura="):
			pasta_captura = a.substr(10)
		elif a == "--recorte":
			recorte = true
		elif a.begins_with("--passo="):
			passo = max(1, int(a.substr(8)))
	marketing = ProjectSettings.globalize_path("res://").plus_file("marketing")
	var f = File.new()
	f.open("res://tools/marketing/coluna3d/medidas.json", File.READ)
	M = parse_json(f.get_as_text())
	f.close()
	Directory.new().make_dir_recursive(saida)
	_total = {"revelar": 105, "soco": 120, "orbita": 150, "final": 96, "heroi": 1, "giro": 150}.get(cena, 1)

	vp = Viewport.new()
	vp.size = tamanho
	vp.own_world = true
	vp.hdr = not recorte
	vp.msaa = Viewport.MSAA_4X
	vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	vp.render_target_v_flip = true
	vp.shadow_atlas_size = 4096
	vp.transparent_bg = recorte
	add_child(vp)
	mundo = Spatial.new()
	vp.add_child(mundo)
	_ambiente()
	maquina = _maquina()
	camera = Camera.new()
	camera.near = 0.05
	camera.far = 60.0
	mundo.add_child(camera)
	camera.current = true


func _process(_d: float) -> void:
	_quadro += 1
	# os primeiros quadros compilam os shaders
	if _quadro < 6:
		_pose(0.0)
		return
	if _i >= _total:
		get_tree().quit()
		return
	# dois quadros do motor por quadro gravado: um para posar, outro para gravar
	if _quadro % 2 == 0:
		_pose(_i / FPS)
		return
	yield(VisualServer, "frame_post_draw")
	var img = vp.get_texture().get_data()
	var nome = "%s_%04d.png" % [cena, _i]
	if cena == "heroi":
		nome = "coluna_heroi%s.png" % ("_recorte" if recorte else "")
	img.save_png(saida.plus_file(nome))
	print("QUADRO ", nome)
	_i += passo


# ------------------------------------------------------------- animacao
func _suave(t: float) -> float:
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _olhar(pos: Vector3, alvo: Vector3, fov: float, tremor := 0.0) -> void:
	camera.fov = fov
	var s = Vector3(sin(_i * 2.7), cos(_i * 3.1), 0.0) * tremor
	camera.look_at_from_position(pos + s, alvo + s * 0.5, Vector3.UP)


## A bola depois do soco: balanca para tras (para a coluna) e volta,
## amortecida. `dt` = segundos desde o soco.
func _balanco(dt: float) -> float:
	if dt < 0.0:
		return 0.0
	var w = TAU * 1.5
	return 0.62 * exp(-1.6 * dt) * sin(w * dt)


func _pose(t: float) -> void:
	var led = 1.0
	var angulo = 0.0
	var flash = 0.0
	var tela = 160 + int(t * FPS)
	var cx = 0.0
	var cz = 0.55
	match cena:
		"revelar":
			# escuro; as fitas acendem piscando e a camera recua para a vista heroica
			var k = _suave(t / 3.2)
			led = clamp((t - 0.25) / 0.9, 0.0, 1.0)
			if t > 0.25 and t < 1.0 and int(t * 23.0) % 3 == 0:
				led *= 0.25
			for l in _luzes_cena:
				l[0].light_energy = l[1] * clamp((t - 0.6) / 1.0, 0.0, 1.0)
			_olhar(Vector3(0.25, 0.55, 2.3).linear_interpolate(HEROI, k),
				Vector3(0.0, 1.75, 0.65).linear_interpolate(Vector3(0.0, 1.15, 0.55), k), 40.0)
			tela = 158 + int(t * FPS)
		"soco":
			# de perto, a bola leva o soco no segundo 1 e a tela mostra o golpe
			var dt = t - 1.0
			angulo = _balanco(dt)
			if dt >= 0.0:
				flash = exp(-dt * 5.0)
				led = 1.0 + 2.2 * exp(-dt * 4.0)
			var k = _suave(t / 4.0)
			_olhar(Vector3(1.05, 1.42, 2.25).linear_interpolate(Vector3(0.85, 1.38, 1.95), k),
				Vector3(0.0, 1.38, 0.75), 42.0, 0.012 * flash)
			tela = 482 - 30 + int(t * FPS)
		"orbita":
			var a = lerp(deg2rad(42.0), deg2rad(-42.0), _suave(t / 5.0))
			var r = 4.6
			led = 1.0 + 0.25 * sin(t * 5.0)
			_olhar(Vector3(sin(a) * r + cx, 1.45 + 0.15 * sin(t * 0.8), cos(a) * r + cz), Vector3(cx, 1.15, cz), 40.0)
			tela = 254 + int(t * FPS)
		"final":
			var k = _suave(t / 3.2)
			# tres quartos pela direita: de frente a bola cobre a tela
			_olhar(Vector3(1.6, 1.32, 4.9).linear_interpolate(Vector3(1.35, 1.26, 4.4), k), Vector3(0.0, 1.14, 0.6), 38.0)
			tela = 700 + int(t * FPS * 0.5)
		"giro":
			var a = t / (150.0 / FPS) * TAU + deg2rad(35.0)
			_olhar(Vector3(sin(a) * 4.7, 1.45, cos(a) * 4.7 + cz), Vector3(0.0, 1.15, cz), 40.0)
			tela = 254 + int(t * FPS)
		_:
			_olhar(HEROI, Vector3(0.0, 1.15, 0.55), 40.0)
			tela = 420
	_pivo_bola.rotation.x = angulo
	_mola.scale = Vector3(1.0, 1.0 + 0.25 * flash, 1.0)
	_luz_soco.light_energy = 3.5 * flash
	for l in _leds:
		l.set_shader_param("energia", 2.4 * led)
	_mostrar_quadro(tela)


func _mostrar_quadro(n: int) -> void:
	if pasta_captura == "" or n == _quadro_da_tela:
		return
	var caminho = pasta_captura.plus_file("q%05d.jpg" % n)
	if not File.new().file_exists(caminho):
		return
	var img = Image.new()
	if img.load(caminho) != OK:
		return
	_quadro_da_tela = n
	if _tela_tex == null:
		_tela_tex = ImageTexture.new()
		_tela_tex.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS)
		_tela_mat.albedo_texture = _tela_tex
	else:
		_tela_tex.set_data(img)


# ------------------------------------------------------------- ambiente
func _ambiente() -> void:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
	env.ambient_light_color = Color(0.28, 0.22, 0.48)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_strength = 0.95
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set("glow_levels/1", true)
	env.set("glow_levels/2", true)
	env.set("glow_levels/3", true)
	env.set("glow_levels/5", true)
	env.ss_reflections_enabled = true
	env.ss_reflections_max_steps = 96
	env.ss_reflections_roughness = true
	env.ssao_enabled = true
	env.ssao_radius = 0.25
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_color = Color(0.09, 0.03, 0.18)
	env.fog_depth_begin = 7.0
	env.fog_depth_end = 30.0
	if recorte:
		env.glow_enabled = false
		env.fog_enabled = false
		env.ss_reflections_enabled = false
		env.background_mode = Environment.BG_CLEAR_COLOR
	we.environment = env
	mundo.add_child(we)

	# piso escuro e brilhante
	var piso = MeshInstance.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	piso.mesh = pm
	var mp = SpatialMaterial.new()
	mp.albedo_color = Color(0.03, 0.022, 0.045)
	mp.roughness = 0.16
	mp.metallic_specular = 0.65
	piso.material_override = mp
	mundo.add_child(piso)
	_cenario.append(piso)
	# parede do fundo com tubos de neon (a casa de jogos)
	var parede = MeshInstance.new()
	var cm = CubeMesh.new()
	cm.size = Vector3(30, 8, 0.2)
	parede.mesh = cm
	var mw = SpatialMaterial.new()
	mw.albedo_color = Color(0.045, 0.02, 0.085)
	mw.roughness = 0.9
	parede.material_override = mw
	parede.translation = Vector3(0, 4, -3.0)
	mundo.add_child(parede)
	_cenario.append(parede)
	for i in 9:
		var tubo = MeshInstance.new()
		var tm = CubeMesh.new()
		tm.size = Vector3(0.04, 3.4, 0.04)
		tubo.mesh = tm
		var mt = SpatialMaterial.new()
		mt.flags_unshaded = true
		mt.albedo_color = [Color(1.0, 0.15, 0.66), Color(0.3, 0.6, 1.0), Color(0.5, 0.2, 1.0)][i % 3] * 1.7
		tubo.material_override = mt
		tubo.translation = Vector3(-5.6 + i * 1.4, 2.4, -2.85)
		tubo.rotation_degrees = Vector3(0, 0, 30 if i % 2 == 0 else -30)
		mundo.add_child(tubo)
		_cenario.append(tubo)
	if recorte:
		for c in _cenario:
			c.visible = false
	_luzes_cena.append([_luz_spot(Vector3(-2.4, 3.8, 3.6), Vector3(0, 1.2, 0.5), Color(1.0, 0.95, 0.9), 2.8, 34.0, true), 2.8])
	_luzes_cena.append([_luz_spot(Vector3(2.9, 2.6, 3.0), Vector3(0, 1.3, 0.5), Color(0.72, 0.8, 1.0), 1.0, 40.0, false), 1.0])
	_luzes_cena.append([_luz_omni(Vector3(-1.9, 2.6, -1.0), Color(1.0, 0.18, 0.66), 1.5, 4.5), 1.5])
	_luzes_cena.append([_luz_omni(Vector3(1.9, 2.4, -1.0), Color(0.25, 0.55, 1.0), 1.5, 4.5), 1.5])
	_luz_soco = _luz_omni(Vector3(0.0, 1.45, 1.2), Color(1.0, 0.85, 0.6), 0.0, 3.0)


func _luz_spot(pos: Vector3, alvo: Vector3, cor: Color, energia: float, angulo: float, sombra: bool) -> SpotLight:
	var l = SpotLight.new()
	l.light_color = cor
	l.light_energy = energia
	l.spot_range = 12.0
	l.spot_angle = angulo
	l.spot_attenuation = 0.6
	l.shadow_enabled = sombra
	mundo.add_child(l)
	l.look_at_from_position(pos, alvo, Vector3.UP)
	return l


func _luz_omni(pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight:
	var l = OmniLight.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.translation = pos
	mundo.add_child(l)
	return l


# ------------------------------------------------------------- materiais
var _texturas = {}

func _textura(caminho: String) -> Texture:
	if _texturas.has(caminho):
		return _texturas[caminho]
	var img = Image.new()
	if img.load(caminho) != OK:
		push_warning("sem textura: " + caminho)
		return null
	var t = ImageTexture.new()
	t.create_from_image(img, Texture.FLAG_FILTER | Texture.FLAG_MIPMAPS | Texture.FLAG_ANISOTROPIC_FILTER)
	_texturas[caminho] = t
	return t


func _mat_adesivo(peca: String) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	m.albedo_texture = _textura(marketing.plus_file("adesivos/coluna/texturas/%s.jpg" % peca))
	m.roughness = 0.22
	m.metallic_specular = 0.55
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	m.clearcoat_gloss = 0.9
	return m


func _mat(cor: Color, rug := 0.5, metal := 0.0) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	m.albedo_color = cor
	m.roughness = rug
	m.metallic = metal
	return m


const SHADER_LED = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 cor : hint_color = vec4(0.3, 0.42, 1.0, 1.0);
uniform float energia = 2.4;
void fragment() {
	ALBEDO = cor.rgb * energia;
}
"""

func _mat_led() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SHADER_LED
	m.shader = sh
	m.set_shader_param("cor", LED_COR)
	_leds.append(m)
	return m


const SHADER_BOLA = """
shader_type spatial;
uniform vec4 vermelho : hint_color = vec4(0.78, 0.04, 0.06, 1.0);
uniform vec4 preto : hint_color = vec4(0.03, 0.03, 0.035, 1.0);
void fragment() {
	// gomos vermelhos com duas faixas pretas e o topo preto (a bola de soco)
	float u = fract(UV.x * 2.0);
	float faixa = step(0.40, u) * step(u, 0.60);
	vec3 c = mix(vermelho.rgb, preto.rgb, faixa);
	c = mix(c, preto.rgb, step(UV.y, 0.12));
	ALBEDO = c;
	ROUGHNESS = 0.3;
	SPECULAR = 0.7;
}
"""


# ------------------------------------------------------------- geometria
func _caixa(centro: Vector3, tam: Vector3, mat: Material, pai: Node) -> MeshInstance:
	var mi = MeshInstance.new()
	var c = CubeMesh.new()
	c.size = tam
	mi.mesh = c
	mi.material_override = mat
	mi.translation = centro
	pai.add_child(mi)
	return mi


## Um retangulo com a textura inteira; `giro` em graus (ordem YXZ do Godot).
## Sem giro ele olha para +Z (a frente), com a borda de cima da textura em +Y.
func _quadro(centro: Vector3, w: float, h: float, mat: Material, pai: Node, giro := Vector3.ZERO) -> MeshInstance:
	var mi = MeshInstance.new()
	var q = QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.material_override = mat
	mi.translation = centro
	mi.rotation_degrees = giro
	pai.add_child(mi)
	return mi


func _bola(raio: float, altura: float) -> MeshInstance:
	var perfil = [[0.0, 0.10], [0.03, 0.40], [0.09, 0.68], [0.18, 0.88], [0.30, 0.98], [0.44, 1.0], [0.58, 0.97],
		[0.70, 0.89], [0.81, 0.75], [0.90, 0.56], [0.96, 0.34], [0.99, 0.14], [1.0, 0.0]]
	var lados = 48
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in perfil.size() - 1:
		var t0 = perfil[i][0]
		var r0 = perfil[i][1] * raio
		var t1 = perfil[i + 1][0]
		var r1 = perfil[i + 1][1] * raio
		for j in lados:
			var a0 = float(j) / lados * TAU
			var a1 = float(j + 1) / lados * TAU
			var p = [Vector3(cos(a0) * r0, -t0 * altura, sin(a0) * r0), Vector3(cos(a1) * r0, -t0 * altura, sin(a1) * r0),
				Vector3(cos(a1) * r1, -t1 * altura, sin(a1) * r1), Vector3(cos(a0) * r1, -t1 * altura, sin(a0) * r1)]
			var uv = [Vector2(float(j) / lados, t0), Vector2(float(j + 1) / lados, t0),
				Vector2(float(j + 1) / lados, t1), Vector2(float(j) / lados, t1)]
			var ang = [a0, a1, a1, a0]
			for k in [0, 2, 1, 0, 3, 2]:
				st.add_normal(Vector3(cos(ang[k]), 0.2 * (1.0 - 2.0 * uv[k].y), sin(ang[k])).normalized())
				st.add_uv(uv[k])
				st.add_vertex(p[k])
	var mi = MeshInstance.new()
	mi.mesh = st.commit()
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SHADER_BOLA
	m.shader = sh
	mi.material_override = m
	return mi


## A mola (helice) que segura a bola, de cima (y=0) para baixo.
func _helice(raio: float, fio: float, comprimento: float, voltas: int) -> MeshInstance:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = voltas * 16
	var lados = 6
	var pts = []
	for i in n + 1:
		var a = float(i) / 16.0 * TAU
		pts.append(Vector3(cos(a) * raio, -comprimento * float(i) / n, sin(a) * raio))
	for i in n:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var tang = (p1 - p0).normalized()
		var n0 = Vector3(p0.x, 0, p0.z).normalized()
		var b0 = tang.cross(n0).normalized()
		for j in lados:
			var a0 = float(j) / lados * TAU
			var a1 = float(j + 1) / lados * TAU
			var o0 = (n0 * cos(a0) + b0 * sin(a0)) * fio
			var o1 = (n0 * cos(a1) + b0 * sin(a1)) * fio
			var v = [p0 + o0, p0 + o1, p1 + o1, p1 + o0]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_normal((v[k] - (p0 if k in [0, 1] else p1)).normalized())
				st.add_vertex(v[k])
	var mi = MeshInstance.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.05, 0.05, 0.06), 0.35, 0.8)
	return mi


# ------------------------------------------------------------- a maquina
func _maquina() -> Spatial:
	var cm = 0.01
	var co = M["coluna"]
	var ca = M["capo"]
	var b = M["base"]
	var tv = M["tv"]
	var raiz = Spatial.new()
	raiz.name = "coluna"
	mundo.add_child(raiz)
	var preto = _mat(Color(0.02, 0.016, 0.03), 0.15)
	preto.metallic_specular = 0.7
	preto.clearcoat_enabled = true
	preto.clearcoat = 0.7
	preto.clearcoat_gloss = 0.95
	var led = _mat_led()

	var bl = float(b["largura"]) * cm
	var bp = float(b["profundidade"]) * cm
	var bh = float(b["altura"]) * cm
	var cl = float(co["largura"]) * cm
	var cp = float(co["profundidade"]) * cm
	var ch = float(co["altura"]) * cm
	var kl = float(ca["largura"]) * cm
	var kp = float(ca["profundidade"]) * cm
	var kh = float(ca["altura"]) * cm
	var y0 = bh                 # pe da coluna
	var y1 = bh + ch            # topo da coluna = base do capo
	var y2 = y1 + kh            # topo do capo

	# A BASE: caixa preta, piso de chapa xadrez e a fita de LED embaixo
	_caixa(Vector3(0, bh / 2.0, bp / 2.0), Vector3(bl, bh, bp), preto, raiz)
	_quadro(Vector3(0, bh + 0.001, (cp + bp) / 2.0), bl, bp - cp, _mat_adesivo("base_piso"), raiz, Vector3(-90, 0, 0))
	_caixa(Vector3(0, 0.018, bp + 0.004), Vector3(bl, 0.012, 0.006), led, raiz)
	for s in [-1, 1]:
		_caixa(Vector3(s * (bl / 2.0 + 0.004), 0.018, bp / 2.0), Vector3(0.006, 0.012, bp), led, raiz)
	_caixa(Vector3(0, bh - 0.004, bp + 0.004), Vector3(bl, 0.006, 0.006), led, raiz)

	# A COLUNA: corpo e os adesivos (frente em duas pecas, lados e traseira)
	_caixa(Vector3(0, (y0 + y1) / 2.0, cp / 2.0), Vector3(cl - 0.004, ch, cp - 0.004), preto, raiz)
	var alto = (float(M["faixa_topo"]) + float(M["moldura"])) * cm
	var baixo = ch - alto
	_quadro(Vector3(0, y1 - alto / 2.0, cp + 0.001), cl, alto, _mat_adesivo("coluna_frente_alto"), raiz)
	_quadro(Vector3(0, y0 + baixo / 2.0, cp + 0.001), cl, baixo, _mat_adesivo("coluna_frente_baixo"), raiz)
	_quadro(Vector3(-cl / 2.0 - 0.001, (y0 + y1) / 2.0, cp / 2.0), cp, ch, _mat_adesivo("coluna_lateral_esquerda"), raiz, Vector3(0, -90, 0))
	_quadro(Vector3(cl / 2.0 + 0.001, (y0 + y1) / 2.0, cp / 2.0), cp, ch, _mat_adesivo("coluna_lateral_direita"), raiz, Vector3(0, 90, 0))
	_quadro(Vector3(0, (y0 + y1) / 2.0, -0.001), cl, ch, _mat_adesivo("coluna_traseira"), raiz, Vector3(0, 180, 0))
	# as quinas da frente com fita de LED
	for s in [-1, 1]:
		_caixa(Vector3(s * (cl / 2.0 + 0.002), (y0 + y1) / 2.0, cp + 0.002), Vector3(0.008, ch, 0.008), led, raiz)

	# A TELA (o jogo) na janela da moldura, com acrilico na frente
	_tela_mat = SpatialMaterial.new()
	_tela_mat.flags_unshaded = true
	_tela_mat.albedo_color = Color(1.0, 1.0, 1.0) * 1.05
	var jy = y1 - (float(M["faixa_topo"]) + float(M["moldura"]) / 2.0) * cm
	_quadro(Vector3(0, jy, cp + 0.0025), float(tv["vis_w"]) * cm, float(tv["vis_h"]) * cm, _tela_mat, raiz)
	var acr = SpatialMaterial.new()
	acr.flags_transparent = true
	acr.albedo_color = Color(0.85, 0.9, 1.0, 0.05)
	acr.roughness = 0.03
	acr.metallic_specular = 1.0
	_quadro(Vector3(0, jy, cp + 0.008), cl, float(M["moldura"]) * cm, acr, raiz)

	# START e moedeiro no alto do painel de baixo
	var yb = y0 + baixo - float(M["comando"]) * 0.42 * cm
	var botao = MeshInstance.new()
	var cb = CylinderMesh.new()
	cb.top_radius = float(M["start"]["diam"]) * cm / 2.0 * 0.92
	cb.bottom_radius = float(M["start"]["diam"]) * cm / 2.0
	cb.height = 0.022
	botao.mesh = cb
	var mb = _mat(Color(1.0, 0.8, 0.1), 0.25)
	mb.emission_enabled = true
	mb.emission = Color(1.0, 0.75, 0.1)
	mb.emission_energy = 1.4
	botao.material_override = mb
	botao.rotation.x = PI / 2
	botao.translation = Vector3(-cl / 2.0 + cl * 0.32, yb, cp + 0.011)
	raiz.add_child(botao)
	var moed = _caixa(Vector3(-cl / 2.0 + cl * 0.70, yb, cp + 0.004), Vector3(0.06, 0.11, 0.008), _mat(Color(0.75, 0.75, 0.8), 0.25, 1.0), raiz)
	_caixa(Vector3(0, 0, 0.005), Vector3(0.006, 0.07, 0.002), preto, moed)

	# O CAPO: caixa preta com os adesivos, LED nas bordas
	_caixa(Vector3(0, (y1 + y2) / 2.0, kp / 2.0), Vector3(kl - 0.004, kh, kp - 0.004), preto, raiz)
	_quadro(Vector3(0, (y1 + y2) / 2.0, kp + 0.001), kl, kh, _mat_adesivo("capo_frente"), raiz)
	_quadro(Vector3(-kl / 2.0 - 0.001, (y1 + y2) / 2.0, kp / 2.0), kp, kh, _mat_adesivo("capo_lateral_esquerda"), raiz, Vector3(0, -90, 0))
	_quadro(Vector3(kl / 2.0 + 0.001, (y1 + y2) / 2.0, kp / 2.0), kp, kh, _mat_adesivo("capo_lateral_direita"), raiz, Vector3(0, 90, 0))
	_quadro(Vector3(0, y1 - 0.001, kp / 2.0), kl, kp, _mat_adesivo("capo_baixo"), raiz, Vector3(90, 180, 0))
	for yy in [y1 - 0.003, y2 + 0.003]:
		_caixa(Vector3(0, yy, kp + 0.003), Vector3(kl + 0.008, 0.008, 0.008), led, raiz)
		for s in [-1, 1]:
			_caixa(Vector3(s * (kl / 2.0 + 0.003), yy, kp / 2.0), Vector3(0.008, 0.008, kp), led, raiz)

	# A BOLA: suporte, mola e a bola, num pivo que balanca no soco
	var sb = M["suporte_bola"]
	var bz = kp - float(sb["da_frente"]) * cm
	_caixa(Vector3(0, y1 - 0.012, bz), Vector3(0.10, 0.02, 0.10), _mat(Color(0.7, 0.7, 0.75), 0.25, 1.0), raiz)
	_pivo_bola = Spatial.new()
	_pivo_bola.translation = Vector3(0, y1 - 0.022, bz)
	raiz.add_child(_pivo_bola)
	_mola = _helice(0.022, 0.0035, 0.20, 16)
	_pivo_bola.add_child(_mola)
	var bola = _bola(0.13, 0.34)
	bola.translation = Vector3(0, -0.20, 0)
	_pivo_bola.add_child(bola)
	return raiz
