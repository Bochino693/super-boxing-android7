class_name Perfil
extends Reference

## O PERFIL DESTA VERSÃO: TV Box Amlogic S905L.
##
## Quatro núcleos Cortex-A53, 1 GB de RAM, 8 GB de armazenamento, Android
## 7.1 e uma placa de vídeo de celular de entrada. Tudo o que esta versão
## faz diferente da versão das TV Box maiores mora aqui, num lugar só —
## para ajustar depois de ver o jogo rodando na placa, é este arquivo.
##
## A regra é a mesma do resto do jogo: nada muda de aparência de propósito;
## o que cai é o que a pessoa na frente da máquina não percebe (luzes que
## só recortavam o contorno, antisserrilhado de uma imagem que vai ser
## ampliada, partículas demais, resolução interna da janela 3D).

const NOME = "S905L · Android 7.1"

## 30 quadros por segundo, FIXOS. Num processador desses, mirar 60 dá um
## jogo que oscila entre 35 e 55 — e oscilar é o que o olho chama de
## "travando". 30 constantes, com o relógio do jogo encaixado no da tela
## (ver `Ritmo`), é liso.
const FPS = 30

## O vigia de desempenho (`Desempenho`) mede contra esta meta: só corta
## efeito quando o pior quadro passa de ~37 ms, e só devolve abaixo de ~34.
const FPS_MINIMO = 27.0
const FPS_FOLGADO = 29.5
## Um quadro acima disto é tranco de verdade (a 30 fps o normal é 33 ms).
const QUADRO_CRITICO_MS = 48.0

## A janela 3D (a arena) é desenhada nesta fração da resolução lógica e
## ampliada no quadro: 1008 × 1422 → 554 × 782. É o que mais pesa na placa
## de vídeo, e ampliada ela continua nítida a 2 metros da tela.
const ARENA_ESCALA = 0.55
## Antisserrilhado da arena: desligado (a ampliação já suaviza as bordas).
const ARENA_MSAA = false
## As duas luzes coloridas de recorte (rosa e azul) redesenham o lutador
## uma vez cada. O contorno colorido vem do "rim" do material, com a luz
## principal — uma passada só.
const LUZES_DE_RECORTE = false
## A pele com shader próprio (luz que atravessa, suor, poros) calcula a luz
## pixel a pixel. Aqui o lutador usa o material padrão, com a mesma pintura.
const PELE_DETALHADA = false
## Fração das partículas 3D do golpe e da poeira da lona.
const PARTICULAS_3D = 0.5

## Onde o vigia de desempenho começa (0..1) e o teto de efeitos inicial.
const QUALIDADE_INICIAL = 0.65
const TETO_INICIAL = "MEDIO"

## Webcam: intervalo entre quadros na contagem da foto (ms). A 8 quadros por
## segundo a prévia continua viva e a conversão de imagem sai da frente do
## jogo.
const CAMERA_CONTAGEM_MS = 125

## Carregar, na abertura, TODAS as imagens e sons da pasta `assets` (no PC
## evita a primeira leitura do disco no meio do jogo). Na S905L, com 1 GB,
## isso punha na memória ao mesmo tempo coisas que o jogo nunca mostra e o
## Android derrubava o launcher: só a cena do jogo é carregada.
const PRECARREGAR_TUDO = false
