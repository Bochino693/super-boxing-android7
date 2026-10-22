# SUPER BOXING — kit de divulgação, adesivos e gabinetes

Tudo aqui sai do próprio jogo: o logo e as letras são os do jogo (fonte
Bungee, `tools/gerar_tema.py`), o lutador é o mesmo modelo 3D da arena e o
vídeo é o jogo rodando, com o som dele. Esta pasta tem um `.gdignore`: o Godot
não importa nada daqui e nada daqui vai para o APK.

## O que tem em cada pasta

| Pasta | O que é |
| --- | --- |
| `video/` | O **comercial da máquina COLUNA** (`super_boxing_comercial_coluna_*`) e o vídeo promocional dos gabinetes torre e compacto, cada um vertical (1080×1920: Reels, TikTok, Shorts, Status) e horizontal (1920×1080: YouTube, TV da loja, site), com som |
| `posts/` | Pôster vertical, post quadrado, banner horizontal e a página de catálogo com os dois gabinetes |
| `adesivos/coluna/` | **O gabinete COLUNA** (o da foto de referência: capô com a bola, TV em pé, base de chapa xadrez): todos os adesivos em PDF tamanho real com sangria, prévias e o `montagem.jpg` (frente e lado já vestidos) |
| `adesivos/torre/` e `adesivos/compacto/` | Os adesivos de cada gabinete em PDF, **tamanho real com sangria**, prontos para a gráfica |
| `adesivos/comuns/` | Peças iguais para os dois modelos: como jogar (A3), aviso de segurança, adesivo de piso, logos recortados |
| `adesivos/*/previas/` | Prévia de cada peça com a linha de corte, a área segura, os furos e as medidas (para conferir e mandar junto) |
| `gabinetes/` | Desenho técnico dos dois gabinetes (frente e lado, com medidas e lista de peças) e os renders 3D |
| `renders/` | O lutador recortado (fundo transparente) em alta: guarda, soco, campeão, nocaute, caído |
| `TEXTOS_DIVULGACAO.md` | Legendas, frases e ficha técnica para postar e para propostas |

## O gabinete COLUNA (o da foto de referência)

| Peça | Medida (cm) |
| --- | --- |
| Coluna (L × P × A) | 62 × 48 × 175, TV 32" em pé na frente |
| Capô (L × P × A) | 72 × 115 × 38, avança 67 cm sobre o jogador; a bola pendura embaixo, a 30 cm da frente |
| Base (L × P × A) | 85 × 130 × 12; a coluna fica no fundo, o resto é o piso de chapa xadrez |
| Altura total | 225 |

Os adesivos (`adesivos/coluna/`): capô (frente, laterais e embaixo, com o
furo do suporte da bola), frente da coluna em duas peças (o nome + a
moldura amarela e preta da TV com a janela recortada; o painel de baixo com
START, crédito, logo, lutador e FIGHT!), laterais, traseira (opcional) e o
piso da base. O `montagem.jpg` mostra a máquina vestida, de frente e de
lado. As medidas são uma proposta: confira o gabinete e a TV e ajuste em
`MEDIDAS`, no começo de `tools/marketing/adesivos_coluna.py`. Os adesivos, a
montagem e o modelo 3D do comercial (`tools/marketing/coluna3d`) saem de lá.

## Os dois gabinetes

| | TORRE | COMPACTO |
| --- | --- | --- |
| Medidas (L × P × A) | 78 × 116 × 224 cm | 66 × 102 × 196 cm |
| TV | 40" em pé, no meio | 32" em pé, no meio |
| Centro do saco | 1,38 m do chão | 1,30 m do chão |
| Público | adultos e adolescentes | família, buffet, adolescentes |

**O desenho:** a TV grande em pé no meio do gabinete e o saco vindo de
cima, pendurado bem na frente da tela. O braço do saco gira no eixo do
**capô** (a cobertura de cima, que avança sobre o jogador e leva o motor, o
sensor de feixe e o letreiro luminoso). Para jogar, o motor desce o braço e
o saco fica na frente do lutador da tela; para guardar, sobe o braço até a
horizontal. No soco o saco balança para trás até o batente, sem chegar na
tela: entre o saco e a TV há folga e um acrílico de proteção
(`docs/MONTAGEM_3_MECANICA.png`).

**O estilo (o das máquinas chinesas):** corpo **preto brilhante**, uma
única lâmina de cor (ciano em cima, roxo, rosa embaixo — as cores do jogo)
acompanhando a frente, o logo e o lutador nas laterais, e mais nada: sem
frases, selos ou faixas no móvel. Quem chama a atenção são os **LEDs de
verdade** — o contorno das laterais (perfil de alumínio com difusor e fita
RGB), as duas fitas do jogo ao lado da TV, os anéis dos alto-falantes, o
rodapé e o letreiro — e a própria tela.

As medidas são uma proposta: **confira a TV e as peças compradas antes de
cortar** e ajuste em `tools/marketing/medidas.py` (os adesivos, o desenho e
os renders saem de lá). Fixe o gabinete na parede ou no piso (2
cantoneiras) e ponha o lastro no pedestal: o capô avança sobre o jogador e
o soco empurra o saco para trás.

## Para a gráfica (adesivos)

- Arquivos em **PDF RGB**, no **tamanho real** (1:1), com **sangria** (1 cm
  nas peças grandes, 3 a 5 mm nas pequenas). A resolução já está certa para
  cada peça: 100 dpi nas laterais e na frente (vistas de longe), 120 a 200
  dpi nas médias, 300 dpi no aviso.
- As cores neon (rosa, ciano, roxo) passam do CMYK comum: peça para a gráfica
  imprimir com o perfil de **cores vivas** e aprove uma prova. O preto é um
  preto rico (não só K): fica profundo debaixo do verniz.
- **Laterais, frente e moldura**: vinil **brilho** + laminação brilho (é o
  acabamento "piano" das máquinas chinesas). Laterais com recorte
  eletrônico no contorno (a linha magenta da prévia); a esquerda tem a
  frente do gabinete à direita da folha; a direita, à esquerda.
- **Frente do pedestal**: recortar os furos dos alto-falantes e cortar o
  adesivo na emenda da porta do cofre (tracejado da prévia).
- **Painel de comando**: furo do botão START (60 mm) e do moedeiro/noteiro
  (o do arquivo é uma sugestão: recorte conforme a sua peça). Laminação
  **fosca** e resistente (é onde as mãos batem).
- **Letreiro**: vinil **translúcido** (backlight) sobre acrílico leitoso com
  LED atrás.
- **Moldura da TV**: a janela recortada é a área visível da TV; as faixas
  tracejadas ao lado são as canaletas das fitas de LED.
- **Piso**: vinil de chão antiderrapante.

## Refazer as peças (depois de mudar medidas, textos ou o logo)

Precisa de Python 3 com `numpy`, `scipy` e `pillow` (e o `ffmpeg` para o vídeo):

```
python tools/marketing/adesivos_coluna.py       # adesivos do gabinete COLUNA + montagem
python tools/marketing/gerar_adesivos.py        # adesivos (torre, compacto, comuns)
python tools/marketing/gerar_gabinetes.py       # desenho técnico + textura do saco
python tools/marketing/gerar_posts.py           # pôsteres e catálogo
python tools/marketing/medidas.py --json        # medidas para o 3D
```

Os renders 3D dos gabinetes saem do Godot 3.6 no PC (renderizador GLES3):

```
godot3 --video-driver GLES3 --path . res://tools/marketing/gabinete3d/gabinete3d.tscn -- \
    --saida=marketing/gabinetes/renders --modelos=torre,compacto \
    --vistas=heroi,heroi_d,frente,lado --tamanho=1800x2340 --tela=QUADRO_DO_JOGO.jpg
```

O comercial da COLUNA junta a captura do jogo com as cenas da máquina em 3D,
com o jogo de verdade passando na tela dela (`coluna3d.tscn --cena=revelar`,
`soco` e `orbita`, mais a `heroi --recorte` do cartão final), montadas por
`tools/marketing/comercial_coluna.py`.

O vídeo usa uma captura do jogo quadro a quadro, feita numa cópia preparada
por `tools/marketing/captura/preparar_copia.py` (as instruções estão no
começo do arquivo), e é montado por `tools/marketing/montar_video.py`.
