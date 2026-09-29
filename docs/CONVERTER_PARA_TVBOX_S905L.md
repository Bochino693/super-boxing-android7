# Como converter um jogo para a TV Box S905L (Android 7.1)

Guia tirado da conversão do Super Boxing (builds 93 a 103). Tudo aqui
aconteceu de verdade nesta placa; siga na ordem.

## 1. A placa

| O quê | Como é | O que isso obriga |
|---|---|---|
| Processador | Amlogic S905L, 4× Cortex-A53 | 30 quadros fixos (`Engine.target_fps = 30`) |
| Vídeo | **Mali-450, só OpenGL ES 2.0** | Godot 4 **não abre** (exige ES 3.0): usar **Godot 3.6.2 / GLES2** |
| Vídeo | Mali-450 sem textura no vértice | o Godot 3 deforma personagem 3D **no processador** (ver §4) |
| Vídeo | conta do pixel em **16 bits** | nada de relógio grande dentro de shader (ver §4) |
| Memória | **1 GB** para tudo | orçamento apertado (ver §3) |
| Sistema | Android 7.1, launcher de fábrica (LongLauncher) | máquina dedicada: o jogo vira a tela inicial (ver §5) |

## 2. Godot 4 → Godot 3.6.2

- Projeto em `GLES2`, `fallback_to_gles2=true`, `force_vertex_shading.mobile=false`.
- Uma camada de compatibilidade (`scripts/compat.gd`) concentra as trocas de
  API: textos/fontes, `draw_set_transform`, arquivos, imagens, enquadramento.
- `static var` do Godot 4 → `const` com dicionário (é único e alterável).
- **Nomes que existem nos dois mas mudaram de dono** passam no teste de
  sintaxe e quebram rodando. O pior deles: `Image.empty()` (Godot 4) é
  `Image.is_empty()` no Godot 3 — com o nome errado, **cada quadro da câmera
  e cada foto davam erro** e a câmera "nunca pegava". Depois de converter,
  rode uma varredura dos métodos chamados contra a API do Godot 3.
- `CameraServer` **não existe no Android no Godot 3** (só no 4.4+): câmera
  só pelo plugin Android.
- Plugin Android no formato v1 (`.gdap` + `.aar`, `org.godotengine.plugin.v1`).
- **Plugin que devolve `byte[]` não funciona no Godot 3.6**: o `JNISingleton`
  não converte esse retorno e o GDScript recebe vazio (a câmera
  "transmitia" e o jogo ficava sem imagem). Devolva um
  `org.godotengine.godot.Dictionary` com o `byte[]` dentro — isso o Godot 3
  converte para `PoolByteArray`. Tipos de retorno que funcionam: `void`,
  `boolean`, `int`, `float`, `String`, `int[]`, `float[]`, `String[]`,
  `Dictionary`. Ver `tools/android_quadros_plugin`.

## 3. Memória (1 GB)

Quando falta memória o Android derruba primeiro o que está em segundo
plano — o **launcher** — e aparece "LongLauncher parou" por cima do jogo,
ou o próprio jogo cai na tela de carregamento. Orçamento que rodou:
**~52 MB de imagens, ~61 MB fixos, ~25 MB dinâmicos**.

- **Não pré-carregar** a pasta `assets` inteira; só o que a cena usa.
- `ResourceLoader.load_interactive` no Godot 3 duplica recursos: usar `load`.
- **Fontes**: poucos tamanhos padrão (cada tamanho é um atlas de até 2 MB).
- Imagem 2D **sem mipmaps**: no GLES2, imagem de tamanho qualquer com
  mipmaps é esticada para potência de 2 e dobra de memória.
- Imagem **sem transparência** (JPG, fundos): compressão de placa (ETC1).
  Imagem **com transparência**: o ETC1 não tem alfa e o Godot 3 rebaixa
  para 16 tons por canal — decidir caso a caso.
- Texturas 3D em no máximo 1024.
- `Viewport` que só desenha 2D: `usage = USAGE_2D`, `disable_3d = true`
  (senão reserva um buffer de profundidade do tamanho da tela).
- **Nada em paralelo na abertura.** Fotos, imagens e sons abertos um por
  vez (uma fila, uma linha de processamento). Vinte fotos abertas juntas
  derrubaram o jogo.
- **Câmera**: não fechar e reabrir a webcam em sequência (driver USB
  nativo + memória do sistema). Reabrir raramente (≥ 30 s, no máximo 3
  vezes) e só na tela de espera; acordar a câmera depois da abertura.
- Medir no PC: `VisualServer.texture_debug_usage()`,
  `OS.get_static_memory_usage()`, `OS.get_dynamic_memory_usage()`.

## 4. Desenho na Mali-450 (o que derrubou builds)

- **Personagem 3D deformado no processador** (software skinning). No PC é
  na placa de vídeo, então **teste no PC com**
  `rendering/quality/skinning/force_software_skinning=true` — é o único
  jeito de ver o que a TV Box vê. Nesse modo:
  - material que lê `TANGENT` em malha **sem tangentes** → a peça **some**;
  - **blend shapes (expressões) não funcionam** — não mexa nelas (cada
    tentativa vira erro no logcat, todo quadro);
  - **nunca refaça a malha em tempo de jogo** (`ArrayMesh` novo a partir
    de `surface_get_arrays`): corrompe a memória e o jogo cai. Para peça
    com faces do avesso, use `CULL_FRONT` no material.
- **Shader com relógio**: o pixel é calculado em 16 bits; `sin(tempo * 9)`
  com o relógio correndo anda aos saltos. Mande do GDScript só frações
  (`fposmod(tempo * f, 1.0)`) e use `sin(6.2831 * fração)`.
- **Shader novo = risco.** O Super Boxing caiu em 99% do carregamento com
  um shader novo que no PC era perfeito. Mantenha um caminho "de sempre"
  e ligue o novo por uma chave (`Perfil.VISUAL_NOVO`).
- Arena 3D numa janela menor (`ARENA_ESCALA = 0.55`) ampliada com filtro.

## 5. Som: alto-falante de TV

Alto-falante de TV quase não toca abaixo de ~150-200 Hz. Som que é quase só
grave (trilha eletrônica, "boom" de START, soco) **some na TV** — no fone
parece perfeito. Meça a fração de energia acima de 250 Hz de cada WAV; abaixo
de ~40%, trate com `tools/ajustar_som_tv.py` (o grave vira harmônicos que a TV
toca). Torcida e voz já são médios e aparecem.

## 6. Android: tela, permissões, máquina dedicada

- **Tela cheia de verdade** (sem borda preta): a `GodotApp.java` escrita
  pelo `GERAR_APK_COMPLETO.ps1` usa `FLAG_LAYOUT_IN_OVERSCAN`,
  `FLAG_LAYOUT_NO_LIMITS`, modo imersivo e zera a margem das barras; o tema
  vira `Theme.Black.NoTitleBar.Fullscreen` com `windowOverscan`. Sobrou
  borda? `TELA_CHEIA_TVBOX.bat` e "Posição da tela = 100%" na TV Box.
- **Permissões uma vez só**:
  - CAMERA: o Android guarda sozinho; só pedir se faltar.
  - USB (Arduino, webcam): atividade com `USB_DEVICE_ATTACHED` + filtro de
    aparelhos, e o operador marca **"Usar por padrão"** na primeira janela.
  - Guardar o que foi autorizado (`scripts/lembranca_usb.gd`) e, na
    abertura seguinte, **esperar o Android devolver a permissão** antes de
    chamar qualquer coisa que abra janela.
  - Nunca pedir a janela USB da webcam quando ela é câmera do sistema.
- **Instalação sempre por pendrive** (sem ADB): o jogo tem de rodar do
  jeito que é instalado, com o launcher de fábrica ligado. Nada de
  depender de comando no aparelho.

## 7. Gerar o APK

`GERAR_APK_AGORA.bat` → `tools/gerar_apk/GERAR_APK_COMPLETO.ps1`: baixa o
Godot 3.6.2 e os modelos, confere a pasta contra `arquivos_build.txt`
(guarda sobras de versões antigas), escreve a Activity de tela cheia, exporta
e confere o APK. Toda build nova: subir o carimbo em `versao.gd`,
`export_presets.cfg`, `$Build` do `.ps1` e `SUPERBOXING_BUILD` dos `.bat`, e
regenerar `arquivos_build.txt` (`git ls-files`).

## 8. Testar antes de mandar para a placa

1. Sintaxe de todos os scripts (Godot 3.6.2 sem janela).
2. Abertura inteira pelo carregador (até "PRONTO") e uma partida inteira.
3. **As mesmas duas com `force_software_skinning=true`** (várias vezes).
4. Memória (§3) comparada com a última build que rodou na placa.
5. Imagem da tela na orientação da TV (1920×1080 girado).
6. Na placa: se cair, a abertura seguinte mostra a faixa "A ÚLTIMA
   ABERTURA PAROU EM: ..." (o `Diario` grava cada etapa até 90 s depois
   da abertura). Uma foto dela diz onde parou. Com ADB,
   `ABERTURA_TVBOX.bat` traz o erro exato do Android.
