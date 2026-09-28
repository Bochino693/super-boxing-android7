shader_type canvas_item;
// O ESCUDO SUPER BOXING com vida: uma faixa de brilho varre o logo de
// tempos em tempos (só onde há logo, pelo alfa) e o miolo pulsa de leve.
// Os relógios chegam prontos (meia precisão na Mali-450; ver `main.gd`):
// x = posição da varredura (0..1), y = fase do pulso (0..2π).
uniform float brilho = 1.0;
uniform vec2 fases = vec2(0.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float x = UV.x + UV.y * 0.45;
	float pos = fases.x * 2.6 - 0.7;
	float faixa = smoothstep(0.10, 0.0, abs(x - pos));
	float fio = smoothstep(0.018, 0.0, abs(x - pos - 0.05));
	float luz = (faixa * 0.55 + fio * 0.6) * brilho;
	c.rgb += vec3(1.0, 0.96, 0.86) * luz * c.a;
	c.rgb *= 1.0 + 0.06 * sin(fases.y);
	COLOR = c * COLOR;
}
