// O LUTADOR INTEIRO NUMA PASSADA SÓ — feito para a Mali-450 da S905L.
//
// Com o material padrão do Godot 3 a TV Box desenhava um lutador chapado:
// sem as duas luzes coloridas de recorte (cortadas para caber na placa),
// a pele virava uma cor só, e o "rim" do material acendia pontinhos
// brancos na borda do cabelo e dos ombros — na imagem pequena da arena,
// um chuvisco em volta do corpo. Aqui a luz é calculada à mão, uma vez
// por pixel e sem passada extra por luz:
//   • LUZ PRINCIPAL embrulhada (a sombra não corta seco) e, na pele, a
//     passagem para a sombra puxando para o vermelho;
//   • RELEVO DOS MÚSCULOS pelo mapa de relevo da pele;
//   • BRILHO macio do suor/couro/cetim, pela aspereza de cada peça;
//   • RECORTE ROSA à esquerda e AZUL à direita — as duas luzes de palco
//     do jogo original, agora sem custo de luz nenhuma;
//   • o CLARÃO do golpe e o DANO na pele, sem outra passada por cima.
// Toda conta é de meia precisão segura: nada de relógio, nada de número
// grande (a placa calcula o pixel em 16 bits).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D pintura : hint_albedo;
uniform float tem_pintura = 0.0;
uniform sampler2D relevo : hint_normal;
uniform float tem_relevo = 0.0;
uniform float relevo_forca = 1.0;
uniform vec4 tom : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float aspereza = 0.5;
uniform float metal = 0.0;
uniform float pele = 0.0;
uniform float dano = 0.0;
uniform float clarao = 0.0;
// A luz principal, já no espaço da câmera (calculada fora, por quadro).
uniform vec3 luz_dir = vec3(0.35, 0.65, 0.65);
uniform vec4 luz_cor : hint_color = vec4(1.0, 0.945, 0.847, 1.0);
uniform float luz_forca = 1.0;
uniform vec4 ambiente : hint_color = vec4(0.16, 0.18, 0.28, 1.0);
uniform vec4 rim_rosa : hint_color = vec4(1.0, 0.16, 0.63, 1.0);
uniform vec4 rim_azul : hint_color = vec4(0.20, 0.84, 1.0, 1.0);
uniform float rim_forca = 0.50;

void fragment() {
	vec3 cor = COLOR.rgb * tom.rgb;
	if (tem_pintura > 0.5) {
		cor *= texture(pintura, UV).rgb;
	}
	// Cabelo e sobrancelhas (o escuro da pintura da pele) não brilham.
	float lum = dot(cor, vec3(0.30, 0.55, 0.15));
	float brilha = mix(1.0, smoothstep(0.08, 0.22, lum), pele);
	cor = mix(cor, cor * vec3(1.08, 0.80, 0.76), clamp(dano, 0.0, 1.0) * 0.55 * pele);

	vec3 n = NORMAL;
	// RELEVO>
	// (Só a pele usa este trecho: o lutador que tira a variante sem ele.
	// Material que lê TANGENT obriga a malha a ter tangentes, e na Mali-450
	// — corpo deformado pelo processador — peça sem tangente SOME.)
	if (tem_relevo > 0.5) {
		vec2 m = (texture(relevo, UV).rg * 2.0 - 1.0) * relevo_forca;
		float mz = sqrt(max(0.0, 1.0 - dot(m, m)));
		n = normalize(TANGENT * m.x + BINORMAL * m.y + NORMAL * mz);
	}
	// <RELEVO
	vec3 v = normalize(VIEW);
	vec3 l = normalize(luz_dir);
	vec3 luz = luz_cor.rgb * luz_forca;

	float ndl = dot(n, l);
	float embrulho = 0.22 + 0.18 * pele;
	float dif = clamp((ndl + embrulho) / (1.0 + embrulho), 0.0, 1.0);
	vec3 col = cor * (ambiente.rgb + luz * dif);
	// A pele: a faixa entre luz e sombra fica quente (luz que atravessa).
	float faixa = clamp(1.0 - abs(ndl) * 2.2, 0.0, 1.0) * step(-0.45, ndl) * pele;
	col += cor * vec3(0.85, 0.22, 0.12) * faixa * 0.30 * luz;

	// Brilho: expoente e força pela aspereza da peça.
	vec3 h = normalize(l + v);
	float ndh = max(dot(n, h), 0.0);
	float liso = 1.0 - aspereza;
	float e = 10.0 + liso * liso * 54.0;
	float brilho = pow(ndh, e) * (0.08 + 0.55 * liso * liso) * clamp(ndl * 2.0, 0.0, 1.0) * brilha;
	col += mix(vec3(1.0), cor * 1.6, metal) * brilho * luz;

	// Recorte colorido na silhueta: largo e macio (sem chuvisco).
	// Só nas bordas DE LADO (as luzes de palco ficam atrás, à esquerda e
	// à direita): o que está de frente ou virado para cima não se tinge.
	float borda = 1.0 - max(dot(n, v), 0.0);
	borda = borda * borda;
	borda = borda * borda;
	float lado = smoothstep(-0.25, 0.25, n.x);
	float de_lado = smoothstep(0.15, 0.75, abs(n.x));
	col += mix(rim_rosa.rgb, rim_azul.rgb, lado) * borda * de_lado * rim_forca * (0.30 + 0.70 * brilha);

	// O clarão do golpe: um calor sobre a forma, não um lençol branco.
	col += cor * vec3(1.0, 0.62, 0.45) * clarao;
	ALBEDO = col;
}
