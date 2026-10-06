class_name SacoMotor
extends Reference

## O MOTOR QUE BAIXA E LEVANTA O SACO — o lado do jogo.
##
## O QUE ELE FAZ, EM UMA LINHA: fora da partida o saco fica ENROLADO em
## cima; no START o jogo confere que ele está em cima (sobe se não
## estiver), tira a foto, e só então o saco DESCE para o soco; acabou a
## rodada, ele sobe de novo.
##
## POR QUE ISTO É UMA CLASSE E NÃO DUAS LINHAS DENTRO DO `main.gd`.
## Porque um motor não é um LED. Um LED aceso por engano é um LED aceso;
## um motor ligado por engano é uma correia arrebentada, um saco no chão
## ou um fim de curso destruído — e acontece longe de quem programou,
## numa festa, às onze da noite. Tudo o que decide ligar o motor está
## nesta página, e ela é curta de propósito para caber inteira na cabeça
## de quem for mexer.
##
## AS QUATRO REGRAS, e nenhuma delas é opcional:
##
##   1. INTENÇÃO, E NÃO COMANDO. O jogo diz onde o saco DEVE estar
##      ("em baixo", "em cima"); nunca diz "liga o motor". Um comando
##      repetido é uma intenção repetida, e intenção repetida não faz
##      nada — é isso que impede o jogo de manter o motor ligado à força
##      de mandar a mesma coisa sessenta vezes por segundo.
##
##   2. NADA DE ESPERAR. Nenhuma função aqui bloqueia. O jogo manda a
##      intenção e segue desenhando; a confirmação chega depois, pela
##      serial, como qualquer outra mensagem da placa. Esperar o motor
##      seria congelar a tela por três segundos e meio no momento exato
##      em que o jogador aperta START.
##
##   3. O TEMPO É O TETO, E ELE É DO FIRMWARE. Quem desliga o motor é a
##      placa, sempre, mesmo que o jogo trave, feche ou o cabo caia. Este
##      lado só pede; a garantia mora do outro lado do cabo. Ver
##      `motorAtualizar` no firmware.
##
##   4. SEM MOTOR, O JOGO É O MESMO. Um gabinete sem motor ligado (ou
##      com ele desligado na Central) joga exatamente igual. Esta é a
##      diferença entre um recurso e uma dependência.

## Onde o saco deve estar. É isto que o jogo escreve.
enum Onde { EM_CIMA, EM_BAIXO }

## QUANTO TEMPO ESPERAR ANTES DE DESISTIR de uma intenção.
##
## Se a placa não confirmar dentro do curso inteiro mais uma folga, o
## jogo para de insistir e diz que não sabe onde o saco está. Insistir
## para sempre é o laço infinito com outro nome.
const FOLGA_DA_CONFIRMACAO_MS = 2500

## O intervalo mínimo entre dois pedidos IGUAIS. Existe para o caso de a
## placa reiniciar no meio do curso e perder o comando: o jogo repete uma
## vez por segundo, e não sessenta.
const REPETIR_A_CADA_MS = 1000

## LIGADO DE FÁBRICA. Desligado de fábrica, uma máquina recém-montada
## não mexia o motor de jeito nenhum até alguém achar a chave na Central
## — e o saco ficava parado onde estava, parecendo defeito da placa.
var ligado = true
## OS DOIS TEMPOS DO CURSO INTEIRO (firmware V10, SEM SENSOR): descer de
## cima até embaixo e subir de embaixo até em cima — um o inverso do
## outro. A placa conta onde o saco está pelo tempo.
var curso_ms = 3000
var curso_sobe_ms = 3000
## Onde a placa diz que o saco está, em milésimos (0 = em cima).
var permil = -1
var pausa_ms = 350
## Não há mais sensor de fim de curso (build 110 / firmware V10).
var fim_de_curso = false
## VELOCIDADE do motor em % (firmware V6: PWM na ponte H). A subida leva o
## peso do saco; a descida tem a gravidade a favor e começa mais devagar.
var vel_sobe = 80
var vel_desce = 60

var estado = ArduinoProtocol.MOTOR_PARADO
var posicao = ArduinoProtocol.POS_DESCONHECIDA
var resta_ms = 0

## AS CHAVES DE FIM DE CURSO, como a placa lê agora (firmware V4).
## -1 = a placa ainda não disse (firmware antigo, ou sem placa).
var fim_cima = -1
var fim_baixo = -1
## A placa travou a subida: subiu o tempo inteiro e a chave de cima não
## abriu. Só o PARAR da Central destrava (lá e aqui).
var trava_cima = false

## FORA DA PARTIDA O SACO FICA ENROLADO (em cima). É a intenção com que
## o jogo nasce: assim que a placa responde, ele pede para recolher.
var _querido: int = Onde.EM_CIMA
var _pedido_em_ms = 0
var _ultimo_envio_ms = 0
var _desistiu = false
## UMA INTENÇÃO NOVA SAI NA HORA, e esta bandeira é o que garante isso.
##
## Antes o "já mandei há pouco?" era uma subtração de relógios com
## `_ultimo_envio_ms` começando em zero — e zero não quer dizer "nunca
## mandei", quer dizer "no instante em que o programa subiu". Nos
## primeiros mil milissegundos de vida do processo, portanto, o primeiro
## comando do motor era engolido pelo próprio intervalo de repetição.
## Uma bandeira diz o que a conta não sabia dizer.
var _mandar_ja = true
## O relógio da desistência só começa quando o pedido SAI de verdade.
## Antes ele começava no `quero` (ou no zero do programa): com a placa
## demorando a conectar, o jogo "desistia" antes de mandar o primeiro
## comando — e o saco nunca era recolhido ao ligar a máquina.
var _enviado = false
## A placa já respondeu a algum comando de motor nesta conexão? Sem isso,
## o jogo não espera o saco descer (firmware sem motor, placa antiga).
var placa_tem_motor = false
## Quantos relatos MOTOR chegaram desde o último `exigir` — para saber se
## a resposta é DESTE pedido ou um eco velho.
var relatos_desde_o_pedido = 0
## A ÚLTIMA SUBIDA ACABOU PELO TEMPO sem o sensor de cima ver o saco
## (ERROR,FIM_CIMA). Desde o firmware V7 isto é aviso, não trava: a
## próxima subida é tentada de novo.
var subida_sem_sensor = false
## O SENSOR DE CIMA DIZ "CHEGOU" COM O SACO EMBAIXO: fio OUT solto,
## resistor de 100k sem o sensor, ou o sensor vendo outra coisa. Com isso
## a placa recusa toda subida — é o "motor morto" mais comum.
var sensor_cima_suspeito = false
## O QUE A PLACA ACHA DO SENSOR DE CIMA (firmware V8, linha SENSOR_CIMA):
## -1 = não disse (firmware antigo), 0 = funcionando, 1 = preso em
## "chegou", 2 = nunca vê o saco. Com 1 ou 2 a placa sobe PELO TEMPO.
var sensor_estado = -1

## O que o jogo chama. Não manda nada por si: só registra a intenção.
func quero(onde: int) -> void:
	if _querido == onde and not _desistiu:
		return
	_querido = onde
	_desistiu = false
	_mandar_ja = true
	_enviado = false
	_pedido_em_ms = Time.get_ticks_msec()
	_ultimo_envio_ms = Time.get_ticks_msec()

## O PEDIDO QUE SEMPRE SAI, mesmo que o jogo ache que o saco já está lá.
##
## `quero` ignora a intenção repetida — é o que impede o laço infinito.
## Mas o START, a foto, o fim da rodada e os botões da Central PRECISAM
## que o comando saia: se o jogo "achava" que o saco estava em cima e ele
## não estava (desceu na mão, a placa religou, a fonte do motor estava
## desligada), o botão SUBIR não fazia nada — o motor parecia morto.
## Aqui a posição antiga é esquecida e a placa responde com a verdade.
func exigir(onde: int) -> void:
	_querido = onde
	_desistiu = false
	_mandar_ja = true
	_enviado = false
	posicao = ArduinoProtocol.POS_DESCONHECIDA
	estado = ArduinoProtocol.MOTOR_PARADO
	relatos_desde_o_pedido = 0
	if onde == Onde.EM_CIMA:
		subida_sem_sensor = false
	_pedido_em_ms = Time.get_ticks_msec()
	_ultimo_envio_ms = Time.get_ticks_msec()

## O SACO ESTÁ ENROLADO EM CIMA? Com o sensor de cima ligado, quem diz é
## ele (a linha FIM chega 4 vezes por segundo). Sem sensor, vale o que a
## placa disse depois do último pedido.
func esta_em_cima() -> bool:
	return relatos_desde_o_pedido > 0 and posicao == ArduinoProtocol.POS_EM_CIMA \
		and estado == ArduinoProtocol.MOTOR_PARADO

## O SENSOR DE CIMA É CONFIÁVEL AGORA? Ligado na Central, a placa já disse
## o que ele lê (linha FIM), não está preso nem cego (SENSOR_CIMA) e não
## acusou o saco com ele embaixo.
func sensor_confiavel() -> bool:
	return false   # build 110: o saco anda só por tempo

## TOPO CONFIRMADO (build 110) — a condição para a foto e para descer.
## Com o sensor bom, quem diz é ele (o saco está ali, agora). Sem ele, só
## vale a placa dizendo, DEPOIS do último pedido, que parou em cima.
func topo_confirmado() -> bool:
	if sensor_confiavel():
		return fim_cima == 1
	return relatos_desde_o_pedido > 0 and posicao == ArduinoProtocol.POS_EM_CIMA \
		and estado == ArduinoProtocol.MOTOR_PARADO

## EMBAIXO CONFIRMADO (build 110) — a condição para liberar o soco: a
## placa disse, depois do último pedido, que terminou a descida e parou.
func baixo_confirmado() -> bool:
	return relatos_desde_o_pedido > 0 and posicao == ArduinoProtocol.POS_EM_BAIXO \
		and estado == ArduinoProtocol.MOTOR_PARADO

## O sensor de cima está vendo o saco agora (sem pedir nada à placa)?
func sensor_ve_em_cima() -> bool:
	return false   # build 110: sem sensor

## FORA DA PARTIDA, O SACO ESTÁ ENROLADO? Com o sensor bom, pergunta a
## ele (pega o saco baixado à mão); sem ele, vale o que a placa confirmou.
func recolhido() -> bool:
	return posicao == ArduinoProtocol.POS_EM_CIMA and estado == ArduinoProtocol.MOTOR_PARADO

## A linha SENSOR_CIMA da placa V8.
func receber_sensor(estado_do_sensor: int) -> void:
	sensor_estado = estado_do_sensor
	if estado_do_sensor != 0:
		sensor_cima_suspeito = false   # a placa já sabe e sobe pelo tempo

## A PLACA (RE)APARECEU: o cabo voltou, a placa religou, o jogo abriu.
## Ela não sabe o que o jogo quer, e o jogo não sabe onde o saco está:
## pede de novo, na hora, a intenção de agora (fora da partida = em cima).
func reafirmar() -> void:
	_desistiu = false
	_mandar_ja = true
	_enviado = false
	placa_tem_motor = false
	estado = ArduinoProtocol.MOTOR_PARADO
	posicao = ArduinoProtocol.POS_DESCONHECIDA
	_pedido_em_ms = Time.get_ticks_msec()
	_ultimo_envio_ms = Time.get_ticks_msec()

## O saco está embaixo e parado (pronto para o soco)?
func em_baixo_parado() -> bool:
	return posicao == ArduinoProtocol.POS_EM_BAIXO and estado == ArduinoProtocol.MOTOR_PARADO

## Vale a pena esperar o saco? Só com o motor ligado, a placa falando de
## motor e sem desistência — senão o jogo segue como se não houvesse motor.
func vale_esperar() -> bool:
	return ligado and placa_tem_motor and not _desistiu

## Chamada a cada quadro. Devolve a linha a enviar, ou "" quando não há
## nada a dizer — que é o caso na esmagadora maioria dos quadros.
func passo() -> String:
	if not ligado or _desistiu:
		return ""
	var alvo = (
		ArduinoProtocol.POS_EM_BAIXO if _querido == Onde.EM_BAIXO
		else ArduinoProtocol.POS_EM_CIMA
	)
	if posicao == alvo and estado == ArduinoProtocol.MOTOR_PARADO:
		return ""
	var agora = Time.get_ticks_msec()
	# JÁ ESTÁ INDO PARA LÁ: a placa confirmou o sentido certo e está
	# andando. Repetir o pedido a cada segundo só enchia a serial.
	var indo = ArduinoProtocol.MOTOR_DESCENDO if _querido == Onde.EM_BAIXO else ArduinoProtocol.MOTOR_SUBINDO
	if _enviado and estado == indo:
		return ""
	# DESISTIR É PARTE DO PROJETO. Passado o curso inteiro mais a folga
	# sem a placa confirmar, o jogo para de pedir e passa a dizer que não
	# sabe onde o saco está — que é a verdade. Continuar mandando seria
	# um laço infinito distribuído entre dois aparelhos.
	if _enviado and agora - _pedido_em_ms > curso_ms + FOLGA_DA_CONFIRMACAO_MS:
		_desistiu = true
		posicao = ArduinoProtocol.POS_DESCONHECIDA
		return ""
	if not _mandar_ja and agora - _ultimo_envio_ms < REPETIR_A_CADA_MS:
		return ""
	if not _enviado:
		_enviado = true
		_pedido_em_ms = agora
	_mandar_ja = false
	_ultimo_envio_ms = agora
	return ArduinoProtocol.build_motor(
		"DESCE" if _querido == Onde.EM_BAIXO else "SOBE"
	)

## A placa respondeu. Aqui o jogo aprende onde o saco está de verdade.
func receber(msg: Dictionary) -> void:
	estado = int(msg.get("estado", ArduinoProtocol.MOTOR_PARADO))
	posicao = int(msg.get("posicao", ArduinoProtocol.POS_DESCONHECIDA))
	resta_ms = int(msg.get("resta_ms", 0))
	placa_tem_motor = true
	relatos_desde_o_pedido += 1
	if posicao == ArduinoProtocol.POS_EM_CIMA and estado == ArduinoProtocol.MOTOR_PARADO:
		subida_sem_sensor = false
	if estado != ArduinoProtocol.MOTOR_PARADO:
		# Enquanto anda, o relógio da desistência anda junto: um curso
		# longo configurado pelo operador não pode virar desistência só
		# porque demora o que ele mesmo mandou demorar.
		_pedido_em_ms = Time.get_ticks_msec()
		_desistiu = false

## A linha FIM da telemetria.
func receber_fim(msg: Dictionary) -> void:
	fim_cima = 1 if bool(msg.get("cima", false)) else 0
	fim_baixo = 1 if bool(msg.get("baixo", false)) else 0
	trava_cima = bool(msg.get("trava", false))
	# Saco embaixo e parado, e o sensor de cima jura que ele chegou em
	# cima: o sensor (ou o fio dele) está mentindo.
	if fim_cima == 0:
		sensor_cima_suspeito = false
	elif fim_de_curso and sensor_estado <= 0 and posicao == ArduinoProtocol.POS_EM_BAIXO \
			and estado == ArduinoProtocol.MOTOR_PARADO:
		sensor_cima_suspeito = true

## ERROR,FIM_CIMA: a placa cortou a subida sem a chave de cima abrir.
## O jogo para de pedir — a placa recusaria de qualquer jeito, e repetir
## o pedido uma vez por segundo seria barulho na serial e na tela.
func travou() -> void:
	# Firmware V8: a placa para, avisa e logo em seguida diz onde o saco
	# ficou — não há o que desistir. (O V6 travava a subida; grave o V8.)
	subida_sem_sensor = true

## A parada de emergência. Ela é diferente de `quero`: não é uma
## intenção, é uma ordem — e ela apaga a intenção junto, senão o passo
## seguinte religaria o motor que o operador acabou de mandar parar.
func parar() -> String:
	trava_cima = false     # o PARAR também destrava a subida na placa
	_querido = Onde.EM_CIMA if posicao == ArduinoProtocol.POS_EM_CIMA else Onde.EM_BAIXO
	_desistiu = true
	return ArduinoProtocol.build_motor("PARA")

## Tira o freio de mão depois de um PARA ou de uma desistência.
func destravar() -> void:
	_desistiu = false
	_mandar_ja = true
	_enviado = false
	_pedido_em_ms = Time.get_ticks_msec()
	_ultimo_envio_ms = Time.get_ticks_msec()

func andando() -> bool:
	return estado != ArduinoProtocol.MOTOR_PARADO

func desistiu() -> bool:
	return _desistiu

## Quanto do curso já andou, de 0 a 1 — para a Central desenhar uma barra
## que anda de verdade.
func progresso() -> float:
	if estado == ArduinoProtocol.MOTOR_PARADO or curso_ms <= 0:
		return 1.0
	# Firmware V10: a posição de verdade (SACO,<milésimos>).
	if permil >= 0:
		var p = clamp(permil / 1000.0, 0.0, 1.0)
		return p if estado == ArduinoProtocol.MOTOR_DESCENDO else 1.0 - p
	return clamp(1.0 - float(resta_ms) / float(curso_ms), 0.0, 1.0)

## Uma frase pronta para a tela, e ela nunca mente: quando o jogo não
## sabe onde o saco está, ela diz isso.
func ficha() -> String:
	if not ligado:
		return "MOTOR DESLIGADO NA CENTRAL"
	if _desistiu:
		return "MOTOR NÃO RESPONDEU — CONFIRA A LIGAÇÃO"
	if estado == ArduinoProtocol.MOTOR_DESCENDO:
		return "BAIXANDO O SACO… %d%%" % int(progresso() * 100.0)
	if estado == ArduinoProtocol.MOTOR_SUBINDO:
		return "SUBINDO O SACO… %d%%" % int(progresso() * 100.0)
	return ArduinoProtocol.nome_da_posicao(posicao)

func para_salvar() -> Dictionary:
	return {
		"ligado": ligado, "curso_ms": curso_ms, "curso_sobe_ms": curso_sobe_ms,
		"pausa_ms": pausa_ms, "fim_de_curso": fim_de_curso,
		"vel_sobe": vel_sobe, "vel_desce": vel_desce,
		"versao": 3,
	}

func carregar(dados: Dictionary) -> void:
	ligado = bool(dados.get("ligado", true))
	# Configuração gravada antes da build 107 tinha o motor DESLIGADO de
	# fábrica: liga de novo uma vez. Depois disso vale o que o operador
	# escolher na Central.
	if int(dados.get("versao", 1)) < 2:
		ligado = true
	curso_ms = int(clamp(int(dados.get("curso_ms", 3500)), 200, 15000))
	curso_sobe_ms = int(clamp(int(dados.get("curso_sobe_ms", curso_ms)), 200, 15000))
	# Build 110: 3 s para descer e 3 s para subir (padrão pedido). Ajuste
	# gravado antes disso (3,5 s, com sensor) volta para 3 s / 3 s uma vez.
	if int(dados.get("versao", 1)) < 3:
		curso_ms = 3000
		curso_sobe_ms = 3000
	pausa_ms = int(clamp(int(dados.get("pausa_ms", 350)), 50, 2000))
	fim_de_curso = false
	vel_sobe = int(clamp(int(dados.get("vel_sobe", 80)), 20, 100))
	vel_desce = int(clamp(int(dados.get("vel_desce", 60)), 20, 100))
