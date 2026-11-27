class_name InicioDaTv
extends Reference

## O JOGO ABRE SOZINHO AO LIGAR A TV — o padrão do Strike Kids 8.8 (build 133).
##
## Quem faz o trabalho é o plugin PunchQuadros (Java, tools/
## android_quadros_plugin). Até a build 132 o jogo se oferecia como a TELA
## INICIAL do Android (e pedia essa escolha na tela de espera): havia TV
## Box que esquecia o "SEMPRE" e perguntava "app padrão" a cada vez que
## ligava. Agora a TV Box usa a tela inicial dela e quem abre o jogo ao
## ligar é o aviso de "ligou" do Android (com novas tentativas até 25 s) —
## ou o AUTO START (Launch on Boot), que pode ficar ligado junto. A volta
## da espera (tela apagada 10 s ou mais e acesa de novo) continua
## reiniciando o jogo do zero. Aqui o jogo só pergunta e pede:
##
##   abrir_ao_ligar() "sim" (o aviso de "ligou" abre o jogo), "sobrepor"
##                    (Android 10+ sem "sobrepor a outros apps") ou "" (fora
##                    da TV Box).
##   pedir_sobrepor() abre a página "sobrepor a outros apps" do jogo
##                    (Android 10+): "ajustes" ou "".
##   sair_para_tv()   abre a tela inicial da própria TV (ajustes, outros
##                    apps). O HOME do controle também leva a ela.
##   estado()         qual é a tela inicial da TV ("outra|Nome"...), só
##                    informativo.

static func _ponte() -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("PunchQuadros"):
		return null
	return Engine.get_singleton("PunchQuadros")

static func abrir_ao_ligar() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("abrir_ao_ligar"))

static func pedir_sobrepor() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("pedir_sobrepor"))

static func estado() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("tela_inicial"))

static func escolher() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("escolher_tela_inicial"))

static func pedir() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("pedir_tela_inicial"))

static func sair_para_tv() -> String:
	var p = _ponte()
	return "" if p == null else str(p.call("sair_para_tv"))

## O nome da tela inicial de hoje, de um estado "outra|Nome" ("" se não).
static func nome_da_outra(estado_atual: String) -> String:
	return estado_atual.substr(6) if estado_atual.begins_with("outra|") else ""
