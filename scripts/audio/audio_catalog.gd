extends Reference
## Catálogo único dos arquivos sonoros. AudioBank cuida da reprodução.
## Os sons básicos (crédito, START, contagem, golpe, veredito). Todos os
## arquivos moram em `assets/audio/arcade/` (até a build 115 havia uma
## segunda cópia de cada um em `assets/audio/`, carregada no arranque e
## trocada em seguida: memória e tempo de abertura gastos à toa na TV Box).
const CUES = [
	"credit", "start", "count", "go", "hit", "tick", "charge", "win",
	"medium", "lose", "error", "menu", "record", "legendary",
]
## Os outros sons. Os oito níveis entram aqui: eles nasceram já na mesa
## nova e nunca tiveram versão antiga.
const EXTRA = [
	"music", "shutter", "ranking", "score_loop",
	"ranking_neutral_1", "ranking_neutral_2", "ranking_neutral_3",
	"ranking_burst", "disconnect_alert",
	"nivel_leve", "nivel_bom", "nivel_forte", "nivel_explosivo",
	"nivel_nocaute", "nivel_peso", "nivel_lendario", "nivel_perfeito",
	"start_negado", "couro", "subgrave",
	# A ARENA TROUXE SONS PRÓPRIOS. O soco já tinha o couro e o
	# subgrave — o que faltava era o CORPO: o baque de quem leva, a
	# queda na lona e a plateia reagindo. Sem eles o lutador aparecia
	# na tela mas o ouvido continuava batendo num saco de areia.
	"arena_corpo", "arena_queda", "arena_publico",
	# As vinhetas de entrada no ranking: fanfarras de fliperama (build 116,
	# `tools/gerar_sons_arcade.py`), sem gravação de torcida.
	"torcida_recorde", "torcida_podio", "torcida_top10", "torcida_top20",
	# A torcida longa do fim de rodada: vaia (o jogador perdeu e o
	# lutador tira onda) e festa (o jogador ganhou, o ginásio pega fogo).
	"torcida_vaia", "torcida_festa",
	# E a torcida do MEIO da luta: empurra quem está batendo, nunca vaia.
	"torcida_incentivo",
	# Vozes especiais da rodada de dois golpes.
	"not_supress", "good_player",
	# O GINÁSIO, em laço, por baixo da luta inteira: ronco grave e
	# murmúrio. Até a build 115 era uma gravação de torcida com gritos
	# agudos; agora é sintetizado, só vozes graves (ver
	# `tools/gerar_sons_arcade.py`).
	"arena_ambiente",
	# O sino do round: até a build 120 montado amostra por amostra em
	# GDScript na abertura (26 mil voltas de laço no processador da TV Box);
	# agora é um arquivo como os outros (`tools/gerar_sons_arcade.py`).
	"round_bell",
]
const LOOPS = ["music", "charge", "score_loop", "arena_ambiente"]
const ROOT = "res://assets/audio/arcade/"

## O arquivo de alguns sons tem outro nome: o do erro chama-se `aviso.wav`,
## para a palavra "error" não aparecer na lista da importação quando o APK
## é gerado (quem lê a janela acha que é um erro de verdade).
const ARQUIVO = {"error": "aviso"}

static func path_for(cue: String) -> String:
	return ROOT + str(ARQUIVO.get(cue, cue)) + ".wav"

## A QUE MESA CADA SOM VAI.
##
## Quatro barramentos, e não um só, porque eles precisam de volumes
## independentes E de um abaixar a voz para o outro aparecer:
##
##   Music   a trilha, que toca o dia inteiro e tem de sumir de baixo do
##           veredito sem parar;
##   Impact  o soco e os oito níveis — o que precisa doer;
##   UI      crédito, START, contagem, obturador: informação, e informação
##           não pode ser abafada pela festa;
##   SFX     o resto.
##
## Um som que não aparecer aqui vai para SFX.
const BARRAMENTOS = {
	"music": "Music",
	"hit": "Impact", "subgrave": "Impact", "couro": "Impact",
	"nivel_leve": "Impact", "nivel_bom": "Impact", "nivel_forte": "Impact",
	"nivel_explosivo": "Impact", "nivel_nocaute": "Impact", "nivel_peso": "Impact",
	"nivel_lendario": "Impact", "nivel_perfeito": "Impact",
	"arena_corpo": "Impact", "arena_queda": "Impact", "arena_publico": "SFX",
	"not_supress": "Impact", "good_player": "SFX",
	"credit": "UI", "start": "UI", "start_negado": "UI", "menu": "UI",
	"error": "UI", "disconnect_alert": "UI",
	"count": "UI", "go": "UI", "tick": "UI",
	"shutter": "UI", "round_bell": "UI",
}
const BARRAMENTO_PADRAO = "SFX"

static func bus_for(cue: String) -> String:
	return str(BARRAMENTOS.get(cue, BARRAMENTO_PADRAO))
