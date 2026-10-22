extends Node

## OS GABINETES DO SUPER BOXING EM 3D (so no PC, fica fora do APK).
##
## Monta os gabinetes com as medidas de tools/marketing/medidas.py (exportadas
## em medidas.json) e as artes dos adesivos (marketing/adesivos/*/texturas) e
## grava as fotos. Precisa do renderizador GLES3 (brilho e reflexo no piso):
##   godot3 --video-driver GLES3 --path . res://tools/marketing/gabinete3d/gabinete3d.tscn --
##          --saida=/pasta --modelos=torre,compacto --vistas=heroi,heroi_d,frente,lado
##          [--tamanho=2000x2600] [--tela=/x/tela.png] [--giro=150] [--fila]
## --giro=N grava N quadros dando uma volta (para o video); --fila poe os
## dois modelos lado a lado na mesma foto.

const COR_FUNDO = Color(0.030, 0.012, 0.060)

var dados = {}
var marketing = ""
var saida = ""
var modelos = ["torre"]
var vistas = ["heroi"]
var tamanho = Vector2(2000, 2600)
var tela_png = ""
var giro = 0
var fila = false
var recorte = false
var _cenario = []

var vp: Viewport
var mundo: Spatial
var camera: Camera
var _gabinetes = {}
var _pivos = {}
var _quadro = 0
var _fila_de_fotos = []


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--saida="):
			saida = a.substr(8)
		elif a.begins_with("--modelos="):
			modelos = a.substr(10).split(",")
		elif a.begins_with("--vistas="):
			vistas = a.substr(9).split(",")
		elif a.begins_with("--tamanho="):
			var p = a.substr(10).split("x")
			tamanho = Vector2(int(p[0]), int(p[1]))
		elif a.begins_with("--tela="):
			tela_png = a.substr(7)
		elif a.begins_with("--giro="):
			giro = int(a.substr(7))
		elif a == "--fila":
			fila = true
		elif a == "--recorte":
			recorte = true
	marketing = ProjectSettings.globalize_path("res://").plus_file("marketing")
	var f = File.new()
	f.open("res://tools/marketing/gabinete3d/medidas.json", File.READ)
	dados = parse_json(f.get_as_text())
	f.close()
	Directory.new().make_dir_recursive(saida)

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
	var x = 0.0
	for i in modelos.size():
		var m = modelos[i]
		var g = _gabinete(m)
		if giro > 0:
			# NO GIRO O GABINETE RODA (mesa giratoria), e nao a camera: ela
			# daria a volta por tras da parede do cenario. O eixo fica no
			# meio da profundidade.
			var meio_z = 0.0
			for p in dados[m]["perfil"]:
				meio_z = max(meio_z, float(p[0]) / 200.0)
			var pivo = Spatial.new()
			pivo.translation = Vector3(0, 0, meio_z)
			mundo.remove_child(g)
			pivo.add_child(g)
			g.translation = Vector3(0, 0, -meio_z)
			mundo.add_child(pivo)
			_pivos[m] = pivo
		if fila:
			g.translation.x = x
			x += float(dados[m]["W"]) / 100.0 + 0.55
		_gabinetes[m] = g
	if fila and modelos.size() > 1:
		var meio = (x - 0.55) / 2.0 - float(dados[modelos[0]]["W"]) / 200.0
		for m in _gabinetes:
			_gabinetes[m].translation.x -= meio
	camera = Camera.new()
	camera.fov = 26.0
	camera.near = 0.05
	camera.far = 60.0
	mundo.add_child(camera)
	camera.current = true
	_montar_fila()


# ---------------------------------------------------------------- fotos
func _montar_fila() -> void:
	if giro > 0:
		for i in giro:
			_fila_de_fotos.append(["giro", float(i) / giro])
		return
	if fila:
		for v in vistas:
			_fila_de_fotos.append(["fila", v])
		return
	for m in modelos:
		for v in vistas:
			_fila_de_fotos.append([m, v])


func _process(_d: float) -> void:
	_quadro += 1
	# os primeiros quadros compilam os shaders e assentam o brilho
	if _quadro < 6:
		return
	if _fila_de_fotos.empty():
		get_tree().quit()
		return
	var item = _fila_de_fotos[0]
	_posicionar(item)
	if _quadro % 3 != 0:
		return
	_fila_de_fotos.pop_front()
	yield(VisualServer, "frame_post_draw")
	var img = vp.get_texture().get_data()
	var nome = ""
	if item[0] == "giro":
		nome = "giro_%04d.png" % int(round(item[1] * giro))
	elif item[0] == "fila":
		nome = ("linha_%s_recorte.png" if recorte else "linha_%s.png") % item[1]
	else:
		nome = "%s_%s.png" % [item[0], item[1]]
	img.save_png(saida.plus_file(nome))
	print("FOTO ", nome)


func _posicionar(item: Array) -> void:
	var m = modelos[0] if item[0] in ["giro", "fila"] else item[0]
	var H = float(dados[m]["H"]) / 100.0
	if item[0] == "fila":
		H = 0.0
		for k in modelos:
			H = max(H, float(dados[k]["H"]) / 100.0)
	for k in _gabinetes:
		_gabinetes[k].visible = item[0] in ["giro", "fila"] or k == m
	var alvo = Vector3(0.0, H * 0.48, 0.55)
	var ang = 0.0
	var dist = H * 3.0
	var alto = H * 0.60
	var vista = item[1] if item[0] != "giro" else "giro"
	match vista:
		"heroi":
			ang = deg2rad(-34.0)
		"heroi_d":
			ang = deg2rad(34.0)
		"frente":
			ang = 0.0
			alto = H * 0.5
		"lado":
			ang = deg2rad(-90.0)
			alto = H * 0.5
			alvo.z = 0.58
		"giro":
			ang = deg2rad(-30.0)
			for k in _pivos:
				_pivos[k].rotation.y = item[1] * TAU
	if item[0] == "fila":
		dist = H * 2.6
		alvo.y = H * 0.50
		alto = H * 0.56
	camera.fov = 26.0
	var pos = alvo + Vector3(sin(ang) * dist, 0.0, cos(ang) * dist)
	pos.y = alto
	camera.look_at_from_position(pos, alvo, Vector3.UP)


# ------------------------------------------------------------- ambiente
func _ambiente() -> void:
	var we = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COR_FUNDO
	env.ambient_light_color = Color(0.30, 0.22, 0.45)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
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
	env.fog_color = Color(0.10, 0.03, 0.18)
	env.fog_depth_begin = 9.0
	env.fog_depth_end = 40.0
	if recorte:
		env.glow_enabled = false
		env.fog_enabled = false
		env.ss_reflections_enabled = false
		env.background_mode = Environment.BG_CLEAR_COLOR
	we.environment = env
	mundo.add_child(we)

	# piso escuro e brilhante (reflete o gabinete e as luzes)
	var piso = MeshInstance.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	piso.mesh = pm
	var mp = SpatialMaterial.new()
	mp.albedo_color = Color(0.035, 0.025, 0.05)
	mp.roughness = 0.18
	mp.metallic = 0.0
	mp.metallic_specular = 0.6
	piso.material_override = mp
	mundo.add_child(piso)
	_cenario.append(piso)

	# parede do fundo com faixas de neon (a casa de jogos)
	var parede = MeshInstance.new()
	var cm = CubeMesh.new()
	cm.size = Vector3(30, 8, 0.2)
	parede.mesh = cm
	var mw = SpatialMaterial.new()
	mw.albedo_color = Color(0.05, 0.02, 0.09)
	mw.roughness = 0.9
	parede.material_override = mw
	parede.translation = Vector3(0, 4, -3.2)
	mundo.add_child(parede)
	_cenario.append(parede)
	for i in 7:
		var tubo = MeshInstance.new()
		var tm = CubeMesh.new()
		tm.size = Vector3(0.04, 3.2, 0.04)
		tubo.mesh = tm
		var mt = SpatialMaterial.new()
		mt.flags_unshaded = true
		mt.albedo_color = [Color(1.0, 0.15, 0.66), Color(0.3, 0.86, 1.0), Color(0.5, 0.2, 1.0)][i % 3] * 1.6
		tubo.material_override = mt
		tubo.translation = Vector3(-4.2 + i * 1.4, 2.3, -3.05)
		tubo.rotation_degrees = Vector3(0, 0, 32)
		mundo.add_child(tubo)
		_cenario.append(tubo)

	if recorte:
		for c in _cenario:
			c.visible = false
	_luz_spot(Vector3(-2.6, 3.6, 3.6), Vector3(0, 1.1, 0.3), Color(1.0, 0.95, 0.88), 2.9, 32.0, true)
	_luz_spot(Vector3(2.8, 2.4, 3.2), Vector3(0, 1.3, 0.3), Color(0.75, 0.80, 1.0), 0.9, 40.0, false)
	_luz_omni(Vector3(-1.8, 2.6, -1.2), Color(1.0, 0.18, 0.66), 1.4, 4.0)
	_luz_omni(Vector3(1.8, 2.4, -1.2), Color(0.25, 0.85, 1.0), 1.4, 4.0)
	_luz_omni(Vector3(0.0, 0.4, 2.2), Color(0.55, 0.3, 1.0), 0.4, 3.0)


func _luz_spot(pos: Vector3, alvo: Vector3, cor: Color, energia: float, angulo: float, sombra: bool) -> void:
	var l = SpotLight.new()
	l.light_color = cor
	l.light_energy = energia
	l.spot_range = 12.0
	l.spot_angle = angulo
	l.spot_attenuation = 0.6
	l.shadow_enabled = sombra
	mundo.add_child(l)
	l.look_at_from_position(pos, alvo, Vector3.UP)


func _luz_omni(pos: Vector3, cor: Color, energia: float, alcance: float) -> void:
	var l = OmniLight.new()
	l.light_color = cor
	l.light_energy = energia
	l.omni_range = alcance
	l.translation = pos
	mundo.add_child(l)


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


func _mat_adesivo(modelo: String, peca: String, brilho := 0.0) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	var caminho = marketing.plus_file("adesivos/%s/texturas/%s.jpg" % [modelo, peca])
	if modelo == "comuns":
		caminho = marketing.plus_file("adesivos/comuns/texturas/%s.jpg" % peca)
	m.albedo_texture = _textura(caminho)
	# vinil brilho com laminacao: o verniz reflete as luzes da casa
	m.roughness = 0.2
	m.metallic_specular = 0.55
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	m.clearcoat_gloss = 0.9
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy = brilho
	return m


## A FITA DE LED em degrade pela altura (rosa embaixo, roxo, ciano em cima):
## as mesmas cores da lamina dos adesivos.
const SHADER_LED = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float altura = 2.2;
uniform float energia = 2.6;
varying float h;
void vertex() {
	h = (WORLD_MATRIX * vec4(VERTEX, 1.0)).y / altura;
}
void fragment() {
	vec3 rosa = vec3(1.0, 0.15, 0.66);
	vec3 roxo = vec3(0.48, 0.18, 1.0);
	vec3 ciano = vec3(0.27, 0.86, 1.0);
	float t = clamp(h, 0.0, 1.0);
	vec3 c = t < 0.55 ? mix(rosa, roxo, t / 0.55) : mix(roxo, ciano, (t - 0.55) / 0.45);
	ALBEDO = c * energia;
}
"""

func _mat_led(altura: float, energia := 2.6) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = SHADER_LED
	m.shader = sh
	m.set_shader_param("altura", altura)
	m.set_shader_param("energia", energia)
	return m


func _mat(cor: Color, rug := 0.5, metal := 0.0, luz := 0.0) -> SpatialMaterial:
	var m = SpatialMaterial.new()
	m.albedo_color = cor
	m.roughness = rug
	m.metallic = metal
	m.params_cull_mode = SpatialMaterial.CULL_DISABLED
	if luz > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy = luz
	return m


# ------------------------------------------------------------- geometria
func _malha_extrudada(pts: Array, x0: float, x1: float, mat_x0: Material, mat_x1: Material, mat_borda: Material,
		uv_x0: Array, uv_x1: Array) -> MeshInstance:
	## Poligono no plano ZY (metros), extrudado em X de x0 a x1.
	var poly = PoolVector2Array()
	for p in pts:
		poly.append(p)
	var tri = Geometry.triangulate_polygon(poly)
	var am = ArrayMesh.new()
	for lado in [0, 1]:
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var x = x0 if lado == 0 else x1
		var uvs = uv_x0 if lado == 0 else uv_x1
		var n = Vector3(-1, 0, 0) if lado == 0 else Vector3(1, 0, 0)
		var ordem = [0, 1, 2] if lado == 1 else [0, 2, 1]
		var i = 0
		while i + 2 < tri.size():
			for k in ordem:
				var idx = tri[i + k]
				st.add_normal(n)
				st.add_uv(uvs[idx])
				st.add_vertex(Vector3(x, pts[idx].y, pts[idx].x))
			i += 3
		st.commit(am)
	# a borda (espessura da chapa)
	var sb = SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var area = 0.0
	for i in pts.size():
		var a = pts[i]
		var b = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	for i in pts.size():
		var a = pts[i]
		var b = pts[(i + 1) % pts.size()]
		var d = (b - a).normalized()
		var n2 = Vector2(d.y, -d.x) if area > 0 else Vector2(-d.y, d.x)
		var n = Vector3(0, n2.y, n2.x)
		var v = [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)]
		var tris = [0, 1, 2, 0, 2, 3] if area > 0 else [0, 2, 1, 0, 3, 2]
		for k in tris:
			sb.add_normal(n)
			sb.add_uv(Vector2(0, 0))
			sb.add_vertex(v[k])
	sb.commit(am)
	am.surface_set_material(0, mat_x0)
	am.surface_set_material(1, mat_x1)
	am.surface_set_material(2, mat_borda)
	var mi = MeshInstance.new()
	mi.mesh = am
	return mi


func _caixa(centro: Vector3, tam: Vector3, mat: Material, pai: Node) -> MeshInstance:
	var mi = MeshInstance.new()
	var c = CubeMesh.new()
	c.size = tam
	mi.mesh = c
	mi.material_override = mat
	mi.translation = centro
	pai.add_child(mi)
	return mi


func _quadro_texturizado(centro: Vector3, w: float, h: float, mat: Material, pai: Node, giro_x := 0.0) -> MeshInstance:
	## Retangulo voltado para +Z (a frente), com a textura inteira.
	var mi = MeshInstance.new()
	var q = QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	mi.material_override = mat
	mi.translation = centro
	mi.rotation.x = giro_x
	pai.add_child(mi)
	return mi


func _saco(raio: float, altura: float, mat: Material) -> MeshInstance:
	var perfil = [[0.0, 0.16], [0.03, 0.42], [0.08, 0.66], [0.16, 0.84], [0.27, 0.95], [0.40, 1.0], [0.53, 0.99],
		[0.66, 0.93], [0.78, 0.81], [0.88, 0.62], [0.95, 0.38], [0.99, 0.15], [1.0, 0.0]]
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
			var uv = [Vector2(1.0 - float(j) / lados, t0), Vector2(1.0 - float(j + 1) / lados, t0),
				Vector2(1.0 - float(j + 1) / lados, t1), Vector2(1.0 - float(j) / lados, t1)]
			var ang = [a0, a1, a1, a0]
			for k in [0, 2, 1, 0, 3, 2]:
				st.add_normal(Vector3(cos(ang[k]), 0.15 * (1.0 - 2.0 * uv[k].y), sin(ang[k])).normalized())
				st.add_uv(uv[k])
				st.add_vertex(p[k])
	var mi = MeshInstance.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


# -------------------------------------------------------------- gabinete
func _gabinete(nome: String) -> Spatial:
	var d = dados[nome]
	var cm = 0.01
	var W = float(d["W"]) * cm
	var H = float(d["H"]) * cm
	var ch = float(d["chapa"]) * cm
	var wi = W - 2.0 * ch
	var raiz = Spatial.new()
	raiz.name = nome
	mundo.add_child(raiz)
	# PRETO BRILHANTE (pintura automotiva com verniz), como nas maquinas
	# chinesas; o fosco fica so onde nao aparece
	var preto = _mat(Color(0.022, 0.018, 0.03), 0.14)
	preto.metallic_specular = 0.7
	preto.clearcoat_enabled = true
	preto.clearcoat = 0.7
	preto.clearcoat_gloss = 0.95
	var preto_fosco = _mat(Color(0.02, 0.015, 0.03), 0.8)
	var led = _mat_led(H)

	# AS LATERAIS: o perfil, com a arte na face de fora e o fio de LED na borda
	var perfil = d["perfil"]
	var pts = []
	var xmax = 0.0
	for p in perfil:
		xmax = max(xmax, float(p[0]))
	for p in perfil:
		pts.append(Vector2(float(p[0]) * cm, float(p[1]) * cm))
	var uv_esq = []
	var uv_dir = []
	for p in perfil:
		var u = float(p[0]) / xmax
		var v = 1.0 - float(p[1]) / float(d["H"])
		uv_esq.append(Vector2(u, v))
		uv_dir.append(Vector2(1.0 - u, v))
	# a borda das laterais e a FITA DE LED (em degrade pela altura)
	var lat_e = _malha_extrudada(pts, -W / 2.0, -W / 2.0 + ch, _mat_adesivo(nome, "lateral_esquerda"), preto, led, uv_esq, uv_esq)
	raiz.add_child(lat_e)
	var lat_d = _malha_extrudada(pts, W / 2.0 - ch, W / 2.0, preto, _mat_adesivo(nome, "lateral_direita"), led, uv_dir, uv_dir)
	raiz.add_child(lat_d)

	# PEDESTAL: frente com a arte, alto-falantes e a porta do cofre
	var pe = d["pedestal"]
	var py1 = float(pe["y1"]) * cm
	var pz = float(pe["x1"]) * cm
	_caixa(Vector3(0, py1 / 2.0, pz / 2.0), Vector3(wi, py1, pz), preto_fosco, raiz)
	_quadro_texturizado(Vector3(0, py1 / 2.0, pz + 0.001), wi, py1, _mat_adesivo(nome, "frontal"), raiz)
	var so = d["som"]
	# a fita de LED do rodape (luz no chao, na frente)
	_caixa(Vector3(0, 0.012, pz + 0.006), Vector3(wi, 0.008, 0.006), led, raiz)
	for s in [-1, 1]:
		# o anel de LED em volta do alto-falante (um disco aceso atras dele)
		var anel = MeshInstance.new()
		var ca_ = CylinderMesh.new()
		ca_.top_radius = float(so["diam"]) * cm / 2.0 + 0.007
		ca_.bottom_radius = ca_.top_radius
		ca_.height = 0.006
		ca_.radial_segments = 48
		anel.mesh = ca_
		anel.material_override = led
		anel.rotation.x = PI / 2
		anel.translation = Vector3(s * float(so["dx"]) * cm, float(so["y"]) * cm, pz + 0.002)
		raiz.add_child(anel)
		var alto_falante = MeshInstance.new()
		var cil = CylinderMesh.new()
		cil.top_radius = float(so["diam"]) * cm / 2.0
		cil.bottom_radius = cil.top_radius
		cil.height = 0.012
		alto_falante.mesh = cil
		alto_falante.material_override = _mat(Color(0.05, 0.04, 0.06), 0.6, 0.3)
		alto_falante.rotation.x = PI / 2
		alto_falante.translation = Vector3(s * float(so["dx"]) * cm, float(so["y"]) * cm, pz + 0.004)
		raiz.add_child(alto_falante)

	# PAINEL DE COMANDO inclinado, com START aceso e o moedeiro
	var co = d["comando"]
	var a = Vector2(float(co["x_frente"]) * cm, float(co["y_frente"]) * cm)
	var b = Vector2(float(co["x_tras"]) * cm, float(co["y_tras"]) * cm)
	var meio = (a + b) / 2.0
	var comp = a.distance_to(b)
	var incl = atan2(b.y - a.y, a.x - b.x)
	var painel = Spatial.new()
	painel.translation = Vector3(0, meio.y, meio.x)
	painel.rotation.x = -(PI / 2 - incl)
	raiz.add_child(painel)
	_caixa(Vector3(0, 0, -0.01), Vector3(wi, comp, 0.02), preto, painel)
	_quadro_texturizado(Vector3(0, 0, 0.0015), wi, comp, _mat_adesivo(nome, "painel_comando"), painel)
	var st_ = d["start"]
	var botao = MeshInstance.new()
	var cb = CylinderMesh.new()
	cb.top_radius = float(st_["diam"]) * cm / 2.0 * 0.92
	cb.bottom_radius = float(st_["diam"]) * cm / 2.0
	cb.height = 0.022
	botao.mesh = cb
	botao.material_override = _mat(Color(1.0, 0.78, 0.08), 0.25, 0.0, 1.2)
	botao.rotation.x = PI / 2
	# o botao fica a 45% do comprimento a partir da borda de tras (topo da folha)
	botao.translation = Vector3(float(st_["dx"]) * cm, comp / 2.0 - comp * 0.45, 0.012)
	painel.add_child(botao)
	var mo = d["moedeiro"]
	var moed = _caixa(Vector3(float(mo["dx"]) * cm, comp / 2.0 - comp * 0.45, 0.004),
		Vector3(float(mo["w"]) * cm + 0.02, float(mo["h"]) * cm + 0.02, 0.008), _mat(Color(0.75, 0.75, 0.8), 0.25, 1.0), painel)
	_caixa(Vector3(0, 0, 0.004), Vector3(0.006, float(mo["h"]) * cm * 0.7, 0.002), preto, moed)

	# A TV NO MEIO: corpo, moldura com a janela, a tela do jogo e o acrilico
	var tv = d["tv"]
	var ca = d["capo"]
	var tz = float(tv["x"]) * cm
	var ty0 = b.y
	var ty1 = float(ca["y0"]) * cm
	_caixa(Vector3(0, (ty0 + ty1) / 2.0, tz / 2.0), Vector3(wi, ty1 - ty0, tz - 0.01), preto_fosco, raiz)
	_quadro_texturizado(Vector3(0, (ty0 + ty1) / 2.0, tz + 0.001), wi, ty1 - ty0, _mat_adesivo(nome, "moldura_da_tela"), raiz)
	var tela = SpatialMaterial.new()
	tela.flags_unshaded = true
	if tela_png != "":
		tela.albedo_texture = _textura(tela_png)
	else:
		tela.albedo_color = Color(0.1, 0.05, 0.2)
	var tvy = (float(tv["y0"]) + float(tv["ext_h"]) / 2.0) * cm
	_quadro_texturizado(Vector3(0, tvy, tz + 0.0025), float(tv["vis_w"]) * cm, float(tv["vis_h"]) * cm, tela, raiz)
	# as duas fitas de LED do jogo (WS2812B), uma de cada lado da tela
	for s in [-1, 1]:
		var xf = s * (float(tv["vis_w"]) / 2.0 + 1.4 + 3.0) * cm
		_caixa(Vector3(xf, tvy, tz + 0.004), Vector3(0.012, (float(tv["vis_h"]) - 4.0) * cm, 0.004), led, raiz)
	var acr = SpatialMaterial.new()
	acr.flags_transparent = true
	acr.albedo_color = Color(0.85, 0.9, 1.0, 0.06)
	acr.roughness = 0.03
	acr.metallic_specular = 1.0
	acr.params_cull_mode = SpatialMaterial.CULL_DISABLED
	_quadro_texturizado(Vector3(0, (ty0 + ty1) / 2.0, tz + 0.01), wi, ty1 - ty0, acr, raiz)

	# O CAPO em cima: caixa preta, letreiro aceso na frente e a camera embaixo
	var cz1 = float(ca["x1"]) * cm
	var cy0 = float(ca["y0"]) * cm
	var cy1 = float(ca["y1"]) * cm
	_caixa(Vector3(0, (cy0 + cy1) / 2.0, cz1 / 2.0), Vector3(wi, cy1 - cy0, cz1), preto, raiz)
	_caixa(Vector3(0, (cy1 + H) / 2.0, cz1 / 2.0), Vector3(W, max(0.005, H - cy1), cz1 + 0.01), preto, raiz)
	var le = d["letreiro"]
	var ly0 = float(le["y0"]) * cm
	var ly1 = float(le["y1"]) * cm
	_quadro_texturizado(Vector3(0, (ly0 + ly1) / 2.0, cz1 + 0.002), wi, ly1 - ly0, _mat_adesivo(nome, "letreiro", 1.2), raiz)
	# a fita de LED embaixo do capo, iluminando o saco de cima
	_caixa(Vector3(0, cy0 + 0.004, cz1 - 0.02), Vector3(wi * 0.92, 0.008, 0.01), led, raiz)
	var cam_c = _caixa(Vector3(0, float(d["camera"]["y"]) * cm, cz1 - 0.03), Vector3(0.09, 0.035, 0.04), preto, raiz)
	_caixa(Vector3(0, 0, 0.021), Vector3(0.014, 0.014, 0.004), _mat(Color(0.3, 0.6, 1.0), 0.1, 0.0, 1.5), cam_c)

	# O SACO pendurado no braco que desce do eixo do capo
	var ei = d["eixo"]
	var sc = d["saco"]
	var ex = float(ei["x"]) * cm
	var ey = float(ei["y"]) * cm
	var topo = float(sc["topo"]) * cm
	var aco = _mat(Color(0.7, 0.7, 0.75), 0.25, 1.0)
	_caixa(Vector3(0, cy0 - 0.02, ex), Vector3(0.08, 0.04, 0.06), aco, raiz)
	var braco = _caixa(Vector3(0, (cy0 - 0.02 + topo) / 2.0, ex), Vector3(0.028, cy0 - 0.02 - topo, 0.028), aco, raiz)
	braco.name = "braco"
	var msaco = SpatialMaterial.new()
	msaco.albedo_texture = _textura(marketing.plus_file("gabinetes/texturas/saco.jpg"))
	msaco.roughness = 0.35
	msaco.metallic_specular = 0.7
	msaco.params_cull_mode = SpatialMaterial.CULL_DISABLED
	var saco = _saco(float(sc["diametro"]) * cm / 2.0, float(sc["altura"]) * cm, msaco)
	saco.translation = Vector3(0, topo, ex)
	raiz.add_child(saco)
	_caixa(Vector3(0, topo + 0.012, ex), Vector3(0.05, 0.035, 0.05), _mat(Color(0.08, 0.06, 0.08), 0.5), raiz)
	# o adesivo de piso, na posicao do jogador
	if not recorte:
		var piso_m = _mat_adesivo("comuns", "piso_posicao")
		piso_m.roughness = 0.4
		var zp = ex + float(sc["diametro"]) * cm / 2.0 + 0.45 + 0.30
		_quadro_texturizado(Vector3(0, 0.002, zp), 0.6, 0.6, piso_m, raiz, -PI / 2)
	return raiz
