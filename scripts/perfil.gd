class_name Perfil
extends RefCounted

## O PERFIL DESTA VERSÃO: GODOT 4.6 — TV BOX COM OPENGL ES 3.
##
## A versão S905L (Android 7.1, 1 GB, Mali-450) roda no Godot 3.6 e corta
## tudo o que a placa não aguenta. Esta é a versão completa: TV Box com
## placa de vídeo OpenGL ES 3.0 ou mais nova (Mali-T720 / G31 / G52 e
## acima, 2 GB de RAM ou mais). Tudo o que muda entre as duas mora aqui.

const NOME := "4.6 PRO · OpenGL ES 3"

## 60 quadros por segundo: a luta, o tremor e a câmera ficam lisos.
const FPS := 60

## O vigia de desempenho (`Desempenho`) mede contra esta meta: corta efeito
## só quando o pior quadro passa de ~20 ms e devolve abaixo de ~17.
const FPS_MINIMO := 50.0
const FPS_FOLGADO := 58.0
## Um quadro acima disto é tranco de verdade (a 60 fps o normal é 16,7 ms).
const QUADRO_CRITICO_MS := 34.0

## A arena 3D na resolução cheia do quadro (1080x1540), COM antisserrilhado
## MSAA 4x.
##
## Sem ele (builds 201 a 203) a borda do lutador, os cadarços da bota e as
## cordas saíam em escadinha na TV. A conta de 40% que tirou o MSAA foi
## medida no PC, no desenho por processador (llvmpipe). Na placa da TV Box
## (Mali, Adreno, PowerVR) o Godot 4.6 usa a extensão
## EXT_multisampled_render_to_texture: as amostras ficam na memória
## interna da placa e são resolvidas lá mesmo, sem a cópia da imagem
## inteira — o 4x da Mali sai praticamente de graça.
const ARENA_ESCALA := 1.0
const ARENA_MSAA := Viewport.MSAA_4X
## As luzes coloridas de recorte (rosa e azul) desenham o contorno do
## lutador de verdade, com sombra.
const LUZES_DE_RECORTE := true
## A pele com shader próprio: luz que atravessa a pele, suor, poros,
## relevo, vermelhidão dos golpes.
const PELE_DETALHADA := true
## O desenho caprichado. (Na versão S905L, `false` voltava ao desenho da
## build 97.)
const VISUAL_NOVO := true
## O "lutador de uma passada" era o atalho da Mali-450: aqui o lutador usa
## os materiais completos, com sombra e luzes reais.
const LUTADOR_LEVE := false
## SOMBRA DE VERDADE: o lutador projeta a sombra na lona e no próprio
## corpo (braços no peito, cabeça no pescoço).
const SOMBRAS := true
## O mapa da sombra cobre só até aqui (metros a partir da câmera, que fica
## a ~3,6 m do lutador). Antes eram 9 m num mapa de 4096: quase todo ele
## gasto com o vazio atrás do ringue. Mais curto, um mapa de 2048 dá MAIS
## detalhe no corpo do lutador do que o de 4096 dava, e custa um quarto.
const SOMBRA_DISTANCIA := 6.0
## Partículas 3D do golpe, do suor e da poeira da lona: todas.
const PARTICULAS_3D := 1.0

## Onde o vigia de desempenho começa (0..1) e o teto de efeitos inicial.
const QUALIDADE_INICIAL := 1.0
const TETO_INICIAL := "ALTO"

## Webcam: intervalo entre quadros na contagem da foto (ms).
const CAMERA_CONTAGEM_MS := 66

## Carregar, na abertura, as imagens e sons da pasta `assets`: com 2 GB
## ou mais isso evita a primeira leitura do disco no meio do jogo.
const PRECARREGAR_TUDO := true

## A CAIXA-PRETA NA TELA (como terminou a sessão anterior). Escondida: a
## gravação continua no arquivo, e a Central mostra quando for preciso.
const DIAGNOSTICO_NA_TELA := false


## ------------------------------------------------------------------
## A PLACA DE VÍDEO DESTA TV BOX, DESCOBERTA AO LIGAR.
##
## A versão PRO roda em TV Box muito diferentes. A Proeletronic SmartPro
## (PROSB-3000) é Allwinner H313: quatro Cortex-A53 e uma Mali-G31 MP2 —
## a placa de vídeo OpenGL ES 3 mais fraca que existe, com memória de
## banda estreita. Os "gigas" da caixa não ajudam: quem desenha é a placa
## de vídeo, e o que a afoga é passar imagens grandes pela memória.
##
## Numa placa assim (`leve`):
##   • 30 quadros por segundo FIRMES, e não 60 oscilando entre 20 e 45 —
##     o olho lê 30 constantes como liso e lê 45/20 como travado;
##   • sem o BRILHO PÓS-PROCESSADO (glow). No Godot 4.6 ele obriga o 3D a
##     ser desenhado numa imagem intermediária de alta precisão e passar
##     por várias cópias borradas a cada quadro — é o maior consumidor de
##     banda da arena;
##   • sem a sombra real (ver `sombra_real`): fica a sombra de contato. O
##     resto (lutador, materiais, luzes de recorte, torcida, fachos) fica
##     igual;
##   • menos partículas 3D.
## Placas melhores (Mali-G52/G57/G610, Adreno, PowerVR série 9...) ficam
## com tudo.
static var leve := false
static var placa := ""
## A JANELA QUE O ANDROID DEU AO JOGO (só para o diagnóstico da Central).
## O jogo é SEMPRE desenhado em 1080p (1080x1920 de pé, arena 3D com
## 1080 de largura), seja qual for a janela: na build 203 uma janela de
## 720 linhas baixava o desenho inteiro para 720x1280 e os cartões, as
## letras e o lutador saíam serrilhados na TV.
static var janela := Vector2i.ZERO
## A ARENA 3D NA RESOLUÇÃO DA SAÍDA (build 207). O 2D (letras, cartões,
## logos) é sempre desenhado em 1080x1920 — reduzido para a TV, ele sai
## mais liso do que desenhado pequeno. O 3D, não: com o Android da TV Box
## em 720 linhas, desenhar a arena em 1080 era 2,25 vezes os pixels para
## a TV mostrar os mesmos 720 — e o antisserrilhado (MSAA) já deixa a
## borda do lutador lisa no tamanho certo. 1080p ou mais: 1,0.
static var fator_3d := 1.0

## Nomes de placa que entram no perfil leve.
const PLACAS_LEVES := ["Mali-G31", "Mali-T7", "Mali-T8", "Mali-4", "PowerVR Rogue GE8", "Adreno (TM) 3", "Adreno (TM) 4", "llvmpipe"]

static func descobrir_placa() -> void:
	janela = DisplayServer.window_get_size()
	var linhas := mini(janela.x, janela.y)
	fator_3d = clampf(float(linhas) / 1080.0, 0.5, 1.0) if linhas > 0 else 1.0
	if fator_3d > 0.97:
		fator_3d = 1.0
	placa = RenderingServer.get_video_adapter_name()
	leve = false
	for nome in PLACAS_LEVES:
		if placa.findn(nome) >= 0:
			leve = true
	if OS.has_environment("PUNCH_PLACA_LEVE"):
		leve = OS.get_environment("PUNCH_PLACA_LEVE") == "1"

static func fps() -> int:
	return 30 if leve else FPS

static func brilho() -> bool:
	return not leve

static func particulas_3d() -> float:
	return 0.6 if leve else PARTICULAS_3D

## O vigia de desempenho mede contra a meta de quadros DESTA placa.
static func fps_minimo() -> float:
	return 26.0 if leve else FPS_MINIMO

static func fps_folgado() -> float:
	return 29.0 if leve else FPS_FOLGADO

## O DEGRAU DO GRÁFICO com que uma instalação nova começa (ver
## `Arena3D.DEGRAUS`): o completo. Dali o jogo desce sozinho se a luta
## ficar abaixo da meta de quadros.
static func degrau_inicial() -> int:
	return 0

## A SOMBRA REAL (o mapa de sombra da luz principal). Escolhida UMA VEZ,
## aqui, e nunca trocada com o jogo rodando — trocar recompila os shaders
## de luz de tudo o que ela ilumina (ver `Arena3D.DEGRAUS`). Na placa leve
## fica de fora: no renderizador de compatibilidade do Godot 4.6 a luz
## principal com sombra desenha de novo, numa segunda passada, a lona
## inteira e o lutador, além do próprio mapa. Fica a sombra de contato
## embaixo do lutador.
static func sombra_real() -> bool:
	return SOMBRAS and not leve

static func quadro_critico_ms() -> float:
	return 60.0 if leve else QUADRO_CRITICO_MS

static func nome_do_perfil() -> String:
	return ("PLACA LEVE (30 qps, sem brilho)" if leve else "PLACA COMPLETA (60 qps)") + " • " + placa \
		+ " • janela %dx%d • 3D %d%%" % [janela.x, janela.y, int(round(fator_3d * 100.0))]
