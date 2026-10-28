class_name InicioDaTv
extends Reference

## O JOGO ABRE SOZINHO AO LIGAR A TV (build 129) — o método do boliche.
##
## Quem faz o trabalho é o plugin PunchQuadros (Java, tools/
## android_quadros_plugin): uma TELA INICIAL invisível do Android que só
## abre o jogo (PunchInicioAtivo), o aviso de "ligou" da tomada
## (PunchLigou) e a volta da espera (tela apagada 10 s ou mais e acesa de
## novo: a webcam e o Arduino são soltos e o jogo reinicia do zero). Aqui
## o jogo só pergunta e pede:
##
##   estado()       "jogo" (a TV já abre o jogo sozinha), "escolher" (o
##                  Android ainda pergunta), "outra|Nome" ou "" (fora da
##                  TV Box).
##   escolher()     abre a escolha do Android (Central Técnica): o que
##                  abriu — "ja", "papel", "ajustes", "escolha", "app",
##                  "config" ou "" (nada).
##   pedir()        o mesmo, pedido pelo jogo na tela de espera: só as
##                  janelas de escolha, nunca os ajustes gerais.
##   sair_para_tv() abre a tela inicial da própria TV (ajustes, outros
##                  apps). Um HOME volta ao jogo.

static func _ponte() -> Object:
	if OS.get_name() != "Android" or not Engine.has_singleton("PunchQuadros"):
		return null
	return Engine.get_singleton("PunchQuadros")

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
