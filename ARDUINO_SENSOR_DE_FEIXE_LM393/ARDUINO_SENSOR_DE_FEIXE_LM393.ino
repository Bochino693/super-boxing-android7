/*
  PUNCH CHALLENGE - FIRMWARE COMPLETO SENSOR DE FEIXE MH/LM393 V9
  Arduino Uno/Nano ATmega328P - serial 115200

  Sensor: VCC->5V, GND->GND, D0->D4, A0->A0
  Botoes: START->D2/GND, CREDIT->D3/GND, CONFIG->D12/GND
  Fitas: dados esquerda D5, dados direita D6, fonte externa e GND comum
  Motor (ponte H BTS7960 "BT_2"/IBT-2): D9 -> RPWM (DESCE com velocidade),
         D10 -> LPWM (SOBE com velocidade), R_EN e L_EN e VCC -> 5V,
         GND -> GND. PWM de 20 kHz (sem chiado), rampa suave na partida.
  Fim de curso: SO O DE CIMA, em D11: SENSOR INFRAVERMELHO de obstaculo
         (modulo FC-51/LM393, 3 pinos VCC/GND/OUT): OUT->D11 e um resistor
         de 100k do D11 ao GND. A descida termina pelo tempo de curso.

  O QUE MUDOU NA V9 (motor que "nao responde"):
    - SERVE PARA AS DUAS LIGACOES DA PONTE H. Ate a V5 o motor era no
      D7 (RPWM/DESCE) e no D8 (LPWM/SOBE); da V6 em diante e no D9/D10
      com velocidade. Quem montou pela tabela antiga e gravou o firmware
      novo ficava com o motor MORTO. Agora a placa liga OS DOIS PARES ao
      mesmo tempo: D9/D10 com velocidade e D7/D8 em velocidade cheia.
    - AUTOTESTE SEM JOGO: segure o botao START e ligue o Arduino (ou
      aperte o RESET) e continue segurando 2 s. O motor DESCE 1,5 s, para
      e SOBE ate 1,5 s (para antes se o sensor de cima ver o saco). Nao
      depende do jogo, da TV Box nem da comunicacao: se o motor nao mexer
      no autoteste, o problema e de ligacao ou de fonte.
    - Comando MOTOR,TESTE (botao TESTE na Central, aba SACO): o mesmo
      teste pela serial. Linhas TESTE,DESCE / TESTE,PAUSA / TESTE,SOBE /
      TESTE,FIM.

  O QUE MUDOU NA V8 (o motor anda SEMPRE, com ou sem o sensor de cima):
    - O SENSOR DE CIMA E VIGIADO PELA PROPRIA PLACA. Se ele mente, a placa
      percebe sozinha e passa a SUBIR PELO TEMPO DE CURSO:
        * PRESO EM "CHEGOU": o saco desceu o curso inteiro e o sensor nunca
          ficou livre (fio OUT solto do D11, sensor sem 5V, ou vendo outra
          coisa). Antes a placa recusava toda subida = motor "morto".
        * NUNCA VE: a subida durou o teto todo e ele nao viu o saco.
      Linha SENSOR_CIMA,<0 ok|1 preso em chegou|2 nunca ve> a cada 250 ms.
      Voltou a funcionar (ficou livre / viu o saco subindo): volta ao normal.
    - A PLACA LEMBRA (EEPROM) onde o saco ficou e o estado do sensor. Ao
      ligar, se o saco nao estava em cima, ela o recolhe sozinha - mesmo
      com o sensor com defeito (pelo tempo).
    - SEM SENSOR CONFIAVEL, a subida pelo tempo usa o TEMPO DE CURSO da
      Central (aba SACO): acerte-o com o TESTE_PONTE_H (comando t).

  O QUE MUDOU NA V7 (motor "morto"):
    - A SUBIDA NAO TRAVA MAIS PARA SEMPRE. Na V6, se o saco subisse o
      tempo de curso inteiro sem o sensor de cima ver (curso curto demais,
      fonte do motor desligada, sensor desalinhado), a placa travava a
      subida ate alguem apertar PARAR na Central - e o motor ficava
      "morto". Agora ela para, avisa ERROR,FIM_CIMA e tenta de novo no
      proximo pedido.
    - QUEM DIZ SE O SACO ESTA EM CIMA E O SENSOR, e nao a memoria da
      placa: SOBE com o sensor livre sempre liga o motor, mesmo que a
      placa "lembre" que o saco estava em cima (alguem baixou na mao).
    - A SUBIDA TEM TETO PROPRIO: curso + 50% (no minimo +1,5 s), porque
      ela para pelo sensor; a descida continua sendo o tempo de curso.
    - Pedido repetido no mesmo sentido responde a linha MOTOR (antes
      ficava calado e o jogo nao sabia se a placa ouviu).

  O QUE MUDOU NA V6:
    - VELOCIDADE: subida e descida com velocidade propria (padrao 80% e
      60%), ajustada na Central (aba SACO) ou por MOTOR,VEL,<sobe>,<desce>.
      A partida e em rampa (RAMPA_MS) para nao dar tranco na caixa.
    - Pinos novos: RPWM no D9 e LPWM no D10 (os unicos pinos livres com
      PWM). O botao CONFIG foi para o D12. O fim de curso de baixo saiu.
    - AO LIGAR A PLACA RECOLHE O SACO SOZINHA (1,5 s depois), mesmo sem o
      jogo: fora da partida o saco fica enrolado em cima. O sensor de cima
      para a subida; o tempo de curso e o teto.

  O QUE MUDOU NA V5:
    - Fim de curso de CIMA = sensor infravermelho de obstaculo. A saida
      dele vai a LOW (0 V) quando "ve" o alvo branco preso no saco: e o
      "chegou em cima". O resistor de 100k do D11 ao GND faz um fio OUT
      partido, ou o sensor sem o 5V, tambem ler LOW: o firmware entende
      "ja chegou" e NAO liga a subida (falha segura, como a chave NF).
      O D11 fica SEM o pull-up interno (INPUT), senao o fio solto leria
      HIGH.
    - Quem ainda usa a micro chave NF: FIM_CIMA_INFRAVERMELHO 0 (abaixo).

  O QUE MUDOU NA V4 (sensor que "nao funcionava" e saco subindo demais):
    - O FEIXE FICA SURDO ENQUANTO O MOTOR ANDA, e mais ASSENTAR_MS depois.
      O saco desce na contagem e o jogo arma o sensor logo em seguida: a
      palheta passando pela fenda empurrada pelo MOTOR gastava o soco
      (ou virava "soco fraco") antes de o jogador bater.
    - O REPOUSO DO FEIXE E APRENDIDO SOZINHO (polaridade AUTO): o nivel
      que fica parado por REPOUSO_MS e o "livre". Antes ele era medido uma
      vez so, no arranque; se a palheta estivesse na fenda naquela hora, a
      placa passava a medir ao contrario e nenhum soco valia.
    - FIM DE CURSO DE CIMA OBRIGATORIO, contato NF (normalmente fechado):
      o saco sobe ate abrir a chave, e quem corta o motor e a INTERRUPCAO
      do pino, no mesmo instante, sem esperar o loop. Fio partido ou chave
      solta = chave aberta = o motor NAO sobe (falha segura).
    - Se o tempo de curso acabar subindo sem a chave abrir, o motor TRAVA
      a subida (ERROR,FIM_CIMA) ate o tecnico apertar PARAR na Central.
      Assim o mecanismo nunca fica forcando o fim do curso rodada apos
      rodada.
    - Linha FIM,<cima>,<baixo>,<trava> na telemetria para a Central.

  Recursos mantidos:
    - descoberta/reconexao pelo protocolo PUNCH_OPTICAL;
    - START e CREDIT com antirrepique;
    - duas fitas WS2812B (Adafruit NeoPixel opcional);
    - telemetria D0/A0 e diagnosticos de recusa;
    - captura D4 por interrupcao PCINT20;
    - um comando ARM independente para cada um dos dois socos;
    - velocidade real calculada pela largura da palheta e duracao do pulso.

  A palheta precisa ENTRAR E SAIR da fenda. O jogo envia ARM ao iniciar
  cada tentativa. Depois de um HIT o firmware fecha aquela janela, e so
  outro ARM libera o soco seguinte; assim o retorno nao vira pontuacao.
*/
#include <Arduino.h>
#include <stdlib.h>
#include <avr/eeprom.h>
#if defined(__has_include)
  #if __has_include(<Adafruit_NeoPixel.h>)
    #include <Adafruit_NeoPixel.h>
    #define TEM_FITAS 1
  #endif
#endif
#ifndef TEM_FITAS
  #define TEM_FITAS 0
#endif

#define PIN_START 2
#define PIN_CREDIT 3
#define PIN_CONFIG 12
#define PIN_D0 4
#define PIN_A0 A0
#define LED_STATUS 13
#define PIN_FITA_ESQ 5
#define PIN_FITA_DIR 6
#define LEDS_POR_FITA 30

/* ------------------------------------------------------------------
   MOTOR DO SACO - desce no START e sobe no fim da rodada.

   LIGACAO. Duas saidas com PWM comandam a ponte H BTS7960 (placa "BT_2",
   a IBT-2): cada uma liga UM sentido, e a largura do pulso e a
   velocidade. NUNCA as duas ao mesmo tempo - ver `saidaLigar`.

     D9  -> RPWM  = DESCE, com velocidade
     D10 -> LPWM  = SOBE, com velocidade
     5V  -> R_EN, L_EN e VCC da ponte (habilitam a ponte; sem eles ela
            nao anda)       GND -> GND da ponte. R_IS e L_IS: nao ligar.
     D11 -> fim de curso DE CIMA   (OUT do sensor infravermelho + 100k ao
            GND; obrigatorio com "FINS DE CURSO: SIM" na Central)

   O DE CIMA FALHA PARA O LADO SEGURO. Com o sensor infravermelho, o
   pino le HIGH enquanto o sensor nao ve nada e LOW quando ve o alvo (o
   saco chegou). O fio OUT partido ou o sensor sem 5V tambem leem LOW por
   causa do resistor de 100k ao GND: o firmware entende "ja chegou" e NAO
   liga a subida. O defeito vira saco parado, e nunca motor forcando o
   mecanismo. (Com a micro chave NF a ideia e a mesma, com HIGH.)

   POR QUE O CURSO E POR TEMPO. Um motor de saco de pancada nao tem
   encoder e nao precisa de um: o curso e sempre o mesmo, e cronometrar
   e a maneira mais simples de garantir que ele PARA. Os fins de curso,
   quando existem, param antes; o tempo e o teto que vale mesmo se um
   deles falhar, se o cabo soltar ou se a correia patinar.

   E NAO HA LACO NENHUM AQUI. Nada de while esperando chegar: o estado
   avanca em `motorAtualizar`, chamada uma vez por volta do `loop`. Um
   firmware que fica preso esperando um motor e um firmware que para de
   ler o sensor e de responder ao jogo - e ai ninguem consegue nem
   mandar parar.
   ------------------------------------------------------------------ */
#define PIN_MOTOR_DESCE 9    /* RPWM - OC1A (PB1) */
#define PIN_MOTOR_SOBE 10    /* LPWM - OC1B (PB2) */
#define PIN_FIM_CIMA 11
/* V9: as MESMAS ordens tambem no D7 (DESCE) e no D8 (SOBE), a ligacao da
   V5 e anteriores, em velocidade cheia (liga/desliga, sem pulso). */
#define PIN_ESPELHO_DESCE 7   /* PD7 */
#define PIN_ESPELHO_SOBE 8    /* PB0 */

/* QUAL E O FIM DE CURSO DE CIMA.
   1 = SENSOR INFRAVERMELHO de obstaculo (FC-51 / LM393, VCC-GND-OUT):
       OUT -> D11, VCC -> 5V, GND -> GND, e um resistor de 100k (47k a
       100k) do D11 ao GND. LOW = viu o alvo = chegou em cima.
       Fio OUT partido ou sensor sem 5V: o resistor puxa para LOW = "chegou"
       = a subida NAO liga. Sensor sem o GND: le "livre"; ai quem protege e
       o TEMPO DE CURSO (corta e trava a subida com ERROR,FIM_CIMA).
   0 = micro chave com contato NF (C no GND, NF no D11): HIGH = chegou. */
#define FIM_CIMA_INFRAVERMELHO 1
#if FIM_CIMA_INFRAVERMELHO
  #define FIM_CIMA_NIVEL_CHEGOU LOW
  #define FIM_CIMA_MODO INPUT          /* sem pull-up: o 100k puxa para o GND */
#else
  #define FIM_CIMA_NIVEL_CHEGOU HIGH
  #define FIM_CIMA_MODO INPUT_PULLUP
#endif

/* Estados do motor. PARADO e o unico em que as duas saidas estao baixas. */
#define MOTOR_PARADO 0
#define MOTOR_DESCENDO 1
#define MOTOR_SUBINDO 2

/* Onde o saco esta. DESCONHECIDA ate a primeira subida completa: no
   arranque o firmware nao tem como saber, e fingir que sabe seria pior
   que admitir. */
#define POS_DESCONHECIDA 0
#define POS_EM_CIMA 1
#define POS_EM_BAIXO 2

volatile uint8_t motorEstado = MOTOR_PARADO;  /* lido tambem na interrupcao */
uint8_t motorPosicao = POS_DESCONHECIDA;
unsigned long motorAte = 0;        /* quando o curso atual expira */
unsigned long motorLiberaEm = 0;   /* pausa obrigatoria antes de inverter */
uint8_t motorProximo = MOTOR_PARADO; /* o que fazer quando a pausa acabar */

/* Curso em milissegundos, ajustavel pelo jogo, com teto absoluto. O teto
   existe porque um valor errado vindo do outro lado do cabo nao pode
   virar um motor ligado para sempre. */
unsigned long motorCursoMs = 3500;
const unsigned long MOTOR_CURSO_MAX_MS = 15000;
/* Tempo morto ao inverter o sentido: protege a ponte H de conducao
   cruzada e a caixa de reducao do tranco. */
unsigned long motorPausaMs = 350;
/* VELOCIDADE em % (20 a 100). A subida carrega o peso do saco; a descida
   tem a gravidade a favor, por isso comeca mais devagar. */
uint8_t motorVelSobe = 80;
uint8_t motorVelDesce = 60;
/* Rampa de partida: sai de RAMPA_INICIO % ate a velocidade em RAMPA_MS. */
const unsigned long RAMPA_MS = 300;
const uint8_t RAMPA_INICIO = 25;
unsigned long motorInicio = 0;
/* PWM do Timer1 a 20 kHz (Fast PWM, TOPO no ICR1): 16 MHz / 800. */
#define PWM_TOPO 800
volatile bool motorUsaFimDeCurso = true;
/* A interrupcao do fim de curso cortou o motor; o loop confirma. */
volatile bool motorCorteFim = false;
/* V7: a subida NAO trava mais (ver o cabecalho). Fica sempre false; o
   campo continua na linha FIM para jogos antigos. */
bool motorTravaCima = false;
/* AO LIGAR, O SACO E RECOLHIDO SOZINHO (fora da partida ele fica
   enrolado em cima). Espera RECOLHER_APOS_MS depois de ligar; qualquer
   comando MOTOR do jogo antes disso cancela (o jogo manda o que quer). So
   com fim de curso ligado: e o sensor de cima que para a subida. */
#define RECOLHER_AO_LIGAR 1
const unsigned long RECOLHER_APOS_MS = 1500;
bool recolherPendente = RECOLHER_AO_LIGAR;

/* O SENSOR DE CIMA E VIGIADO (V8). Ver o cabecalho. */
#define SENSOR_OK 0
#define SENSOR_PRESO 1      /* diz "chegou" sempre */
#define SENSOR_NUNCA_VE 2   /* nunca ve o saco */
volatile uint8_t sensorCima = SENSOR_OK;
bool descidaViuLivre = false;      /* o sensor ficou livre durante a descida? */
unsigned long sensorLivreDesde = 0; /* para sair do PRESO: livre firme */
/* EEPROM: 0 = marca, 1 = estado do sensor, 2 = onde o saco ficou. */
#define EE_MARCA 0
#define EE_SENSOR 1
#define EE_POSICAO 2
#define EE_CURSO 3          /* 2 bytes: o tempo de curso da Central */
#define EE_VALOR_MARCA 0xB8

/* O feixe nao mede enquanto o motor anda nem logo depois: o saco ainda
   balanca do tranco do motor. */
const unsigned long ASSENTAR_MS = 900;
unsigned long feixeLiberaEm = 0;
volatile bool feixeMudo = false;

/* Repouso do feixe aprendido (polaridade AUTO): o nivel que fica parado
   esse tempo todo e o livre. Um soco bloqueia por milissegundos. */
const unsigned long REPOUSO_MS = 1500;

#if TEM_FITAS
Adafruit_NeoPixel fitaEsq(LEDS_POR_FITA, PIN_FITA_ESQ, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel fitaDir(LEDS_POR_FITA, PIN_FITA_DIR, NEO_GRB + NEO_KHZ800);
#endif

char polaridade = 'A';
float larguraM = 0.020f;
float velocidadeMin = 1.33f;   // 20 mm em 15 ms: bloqueio mais lento nao e soco
float velocidadeMax = 8.00f;
unsigned long pulsoMinUs = 700;
const unsigned long PULSO_MAX_US = 300000;
const unsigned long TEMPO_MORTO_MS = 1200;

volatile bool pronto = false;
volatile uint8_t nivelAtivo = LOW;
volatile uint8_t ultimoNivel = LOW;
volatile unsigned long inicioUs = 0;
volatile unsigned long duracaoUs = 0;
volatile unsigned long ultimaBordaUs = 0;
volatile bool pulsoAberto = false;
volatile bool pulsoPendente = false;
volatile bool capturaArmada = false;

unsigned long ultimoHitMs = 0;
unsigned long ultimaTelemetriaMs = 0;
float ultimoA0 = 0.0f;
float ultimaVelocidade = 0.0f;
char entrada[80];
uint8_t entradaUso = 0;

void observar(uint8_t nivel, unsigned long agora) {
  if (!pronto || !capturaArmada || feixeMudo || nivel == ultimoNivel) return;
  if ((unsigned long)(agora - ultimaBordaUs) < 80) return;
  ultimaBordaUs = agora;
  ultimoNivel = nivel;
  if (nivel == nivelAtivo) {
    inicioUs = agora;
    pulsoAberto = true;
    digitalWrite(LED_STATUS, HIGH);
  } else if (pulsoAberto) {
    unsigned long d = agora - inicioUs;
    pulsoAberto = false;
    digitalWrite(LED_STATUS, LOW);
    if (!pulsoPendente) {
      duracaoUs = d;
      pulsoPendente = true;
    }
  }
}

void armarCaptura() {
  noInterrupts();
  pulsoAberto = false;
  pulsoPendente = false;
  duracaoUs = 0;
  ultimoNivel = digitalRead(PIN_D0);
  ultimaBordaUs = micros();
  capturaArmada = true;
  interrupts();
  ultimoHitMs = millis() - TEMPO_MORTO_MS;
  digitalWrite(LED_STATUS, LOW);
  Serial.println(F("OK,ARM"));
}

#if defined(__AVR_ATmega328P__)
ISR(PCINT2_vect) { observar((PIND & _BV(PD4)) ? HIGH : LOW, micros()); }

/* FIM DE CURSO POR INTERRUPCAO: corta a saida do sentido no mesmo
   microssegundo em que a chave muda, sem esperar o loop (que pode estar
   escrevendo na serial). D10 = PB2/OC1B (sobe), D11 = PB3 (cima:
   FIM_CIMA_NIVEL_CHEGOU). Cortar = desligar o PWM do pino e po-lo em LOW. */
ISR(PCINT0_vect) {
  if (!motorUsaFimDeCurso || sensorCima == SENSOR_PRESO) return;
  uint8_t cima = (PINB & _BV(PB3)) ? HIGH : LOW;
  if (motorEstado == MOTOR_SUBINDO && cima == FIM_CIMA_NIVEL_CHEGOU) {
    TCCR1A &= ~_BV(COM1B1); PORTB &= ~(_BV(PB2) | _BV(PB0)); motorCorteFim = true;
  }
}
#endif

/* Solta o feixe depois do motor: comeca do nivel de agora, sem pulso
   meio-aberto herdado do movimento. */
void feixeAtualizarMudo() {
  bool mudo = motorEstado != MOTOR_PARADO || (long)(millis() - feixeLiberaEm) < 0;
  if (mudo == feixeMudo) return;
  if (!mudo) {
    noInterrupts();
    ultimoNivel = digitalRead(PIN_D0);
    pulsoAberto = false;
    pulsoPendente = false;
    ultimaBordaUs = micros();
    interrupts();
    digitalWrite(LED_STATUS, LOW);
  }
  feixeMudo = mudo;
}

/* POLARIDADE AUTO SEMPRE ATUAL. O nivel que fica parado REPOUSO_MS e o
   do feixe livre; o ativo e o outro. So muda fora de um pulso. */
void feixeAcompanharRepouso() {
  static uint8_t visto = HIGH;
  static unsigned long desde = 0;
  if (polaridade != 'A' || !pronto) return;
  uint8_t n = digitalRead(PIN_D0);
  if (n != visto) { visto = n; desde = millis(); return; }
  if (millis() - desde < REPOUSO_MS || pulsoAberto) return;
  uint8_t ativo = (n == HIGH) ? LOW : HIGH;
  if (ativo == nivelAtivo) return;
  noInterrupts();
  nivelAtivo = ativo;
  ultimoNivel = n;
  pulsoAberto = false;
  pulsoPendente = false;
  interrupts();
  Serial.print(F("OK,REPOUSO,")); Serial.println((int)n);
}

void botoes() {
  static bool sAnt = HIGH, cAnt = HIGH, cfgAnt = HIGH;
  static unsigned long ts = 0, tc = 0, tcfg = 0;
  bool s = digitalRead(PIN_START), c = digitalRead(PIN_CREDIT), cfg = digitalRead(PIN_CONFIG);
  unsigned long agora = millis();
  if (sAnt && !s && agora - ts > 250) { ts = agora; Serial.println(F("BUTTON,START")); }
  if (cAnt && !c && agora - tc > 250) { tc = agora; Serial.println(F("BUTTON,CREDIT")); }
  if (cfgAnt && !cfg && agora - tcfg > 350) { tcfg = agora; Serial.println(F("BUTTON,CONFIG")); }
  sAnt = s; cAnt = c; cfgAnt = cfg;
}

void calibrar() {
  pronto = false; capturaArmada = false; pulsoAberto = false; pulsoPendente = false;
  uint16_t altos = 0; unsigned long soma = 0;
  int minimo = 1023, maximo = 0;
  for (uint16_t i = 0; i < 250; i++) {
    if (digitalRead(PIN_D0) == HIGH) altos++;
    int a = analogRead(PIN_A0); soma += a;
    if (a < minimo) minimo = a;
    if (a > maximo) maximo = a;
    if (i % 25 == 0) { Serial.print(F("CALIBRATING,")); Serial.println(i * 100 / 250); }
    botoes(); delay(2);
  }
  uint8_t repouso = altos >= 125 ? HIGH : LOW;
  nivelAtivo = polaridade == 'H' ? HIGH : (polaridade == 'L' ? LOW : !repouso);
  ultimoNivel = digitalRead(PIN_D0);
  ultimaBordaUs = micros();
  ultimoHitMs = millis() - TEMPO_MORTO_MS;
  pronto = true;
  Serial.print(F("NOISE,")); Serial.print((float)(maximo-minimo)/1023.0f, 3);
  Serial.print(','); Serial.println((float)soma/250.0f/1023.0f, 3);
  Serial.print(F("CALIBRATED,")); Serial.print((int)repouso);
  Serial.print(','); Serial.print((float)soma/250.0f/1023.0f, 3); Serial.println(F(",0.000"));
  Serial.println(F("OK,OPTICAL"));
}

void medir() {
#if !defined(__AVR_ATmega328P__)
  observar(digitalRead(PIN_D0), micros());
#endif
  noInterrupts();
  bool tem = pulsoPendente; unsigned long d = duracaoUs;
  if (tem) pulsoPendente = false;
  bool aberto = pulsoAberto; unsigned long inicio = inicioUs;
  interrupts();
  if (aberto && micros() - inicio > PULSO_MAX_US) {
    noInterrupts(); pulsoAberto = false; interrupts();
    Serial.println(F("REJECT,SUSTENTADO,0.00,300,0.0,0.00"));
  }
  if (!tem) return;
  float ms = d / 1000.0f;
  if (d < pulsoMinUs) { Serial.print(F("REJECT,CURTO,0.00,")); Serial.print(ms,2); Serial.println(F(",0.0,0.00")); return; }
  if (d > PULSO_MAX_US || millis() - ultimoHitMs < TEMPO_MORTO_MS) return;
  float v = larguraM * 1000000.0f / d;
  if (v < velocidadeMin) { Serial.print(F("REJECT,FRACO,0.00,")); Serial.print(ms,2); Serial.print(F(",0.0,")); Serial.println(v,2); return; }
  if (v > max(8.0f, velocidadeMax * 2.2f)) { Serial.print(F("REJECT,CURTO,0.00,")); Serial.print(ms,2); Serial.print(F(",0.0,")); Serial.println(v,2); return; }
  ultimoHitMs = millis(); ultimaVelocidade = v;
  capturaArmada = false; // exatamente um HIT; o jogo envia ARM no proximo soco
  Serial.print(F("HIT,")); Serial.print(v,3); Serial.print(','); Serial.print(ultimoA0,3);
  Serial.print(','); Serial.print(ms,3); Serial.println(F(",O"));
}

void configurar(char *cmd) {
  char *p = strtok(cmd, ","); p = strtok(NULL, ","); if (!p) return;
  char pol = toupper(p[0]); polaridade = (pol == 'H' || pol == 'L') ? pol : 'A';
  p = strtok(NULL, ","); if (!p) return; larguraM = constrain(atof(p), .005f, .100f);
  p = strtok(NULL, ","); if (!p) return; velocidadeMin = constrain(atof(p), .10f, 20.0f);
  p = strtok(NULL, ","); if (!p) return; pulsoMinUs = constrain(atof(p), .15f, 20.0f) * 1000UL;
  p = strtok(NULL, ","); if (p) velocidadeMax = constrain(atof(p), velocidadeMin + .5f, 40.0f);
  calibrar(); Serial.println(F("OK,CONFIG"));
}

void leds(long permil) {
#if TEM_FITAS
  permil = constrain(permil, 0, 1000);
  int acesos = permil * LEDS_POR_FITA / 1000;
  for (int i=0; i<LEDS_POR_FITA; i++) {
    uint32_t cor = i < acesos ? fitaEsq.Color(i > 25 ? 255 : 0, i > 18 ? 90 : 180, i <= 18 ? 210 : 0) : 0;
    fitaEsq.setPixelColor(i, cor); fitaDir.setPixelColor(i, cor);
  }
  fitaEsq.show(); fitaDir.show();
#else
  (void)permil;
#endif
}

/* ---------------------------------------------------------- o motor */

/* AS DUAS SAIDAS DA PONTE H. So uma tem PWM de cada vez; a outra fica em
   LOW. Com as duas em LOW (e R_EN/L_EN no 5V) a ponte FREIA o motor: o
   saco fica onde parou. */
void saidasDesligar() {
  TCCR1A &= ~(_BV(COM1A1) | _BV(COM1B1));
  OCR1A = 0; OCR1B = 0;
  PORTB &= ~(_BV(PB1) | _BV(PB2) | _BV(PB0));
  PORTD &= ~_BV(PD7);
}

uint16_t motorCarga(uint8_t sentido) {
  uint8_t alvo = (sentido == MOTOR_SUBINDO) ? motorVelSobe : motorVelDesce;
  unsigned long dt = millis() - motorInicio;
  uint8_t pct = alvo;
  if (dt < RAMPA_MS && alvo > RAMPA_INICIO)
    pct = RAMPA_INICIO + (uint8_t)((unsigned long)(alvo - RAMPA_INICIO) * dt / RAMPA_MS);
  return (uint16_t)((unsigned long)pct * PWM_TOPO / 100);   /* 100% = TOPO+1: sempre alto */
}

/* Liga (ou atualiza) o PWM do sentido. A saida do outro sentido fica em
   LOW antes de qualquer coisa. */
void saidaLigar(uint8_t sentido) {
  uint16_t carga = motorCarga(sentido);
  if (sentido == MOTOR_SUBINDO) {
    TCCR1A &= ~_BV(COM1A1); PORTB &= ~_BV(PB1); OCR1A = 0; PORTD &= ~_BV(PD7);
    OCR1B = carga; TCCR1A |= _BV(COM1B1); PORTB |= _BV(PB0);
  } else {
    TCCR1A &= ~_BV(COM1B1); PORTB &= ~_BV(PB2); OCR1B = 0; PORTB &= ~_BV(PB0);
    OCR1A = carga; TCCR1A |= _BV(COM1A1); PORTD |= _BV(PD7);
  }
}

void motorRelatar() {
  Serial.print(F("MOTOR,"));
  Serial.print(motorEstado); Serial.print(',');
  Serial.print(motorPosicao); Serial.print(',');
  unsigned long resta = 0;
  if (motorEstado != MOTOR_PARADO && motorAte > millis()) resta = motorAte - millis();
  Serial.println(resta);
}

/* Desliga as duas saidas. E o unico lugar que escreve LOW nas duas, e
   toda mudanca de estado passa por aqui antes de ligar o outro sentido. */
void motorParar(bool avisar) {
  saidasDesligar();
  bool mudou = motorEstado != MOTOR_PARADO;
  motorEstado = MOTOR_PARADO;
  motorProximo = MOTOR_PARADO;
  motorCorteFim = false;
  if (mudou) feixeLiberaEm = millis() + ASSENTAR_MS;
  if (avisar && mudou) motorRelatar();
}

bool cimaLido() { return digitalRead(PIN_FIM_CIMA) == FIM_CIMA_NIVEL_CHEGOU; }

/* O sensor de cima vale para parar/recusar a subida? Preso em "chegou" nao
   vale (a subida e pelo tempo). "Nunca ve" ainda vale: se ele ver, para. */
bool sensorValeParaParar() { return motorUsaFimDeCurso && sensorCima != SENSOR_PRESO; }
/* O sensor e quem diz se o saco esta em cima (e nao a memoria)? */
bool sensorManda() { return motorUsaFimDeCurso && sensorCima == SENSOR_OK; }

/* A posicao so vai para a EEPROM com o sensor ruim: com ele bom, quem diz
   onde o saco esta ao ligar e o proprio sensor (e a EEPROM nao gasta). */
void guardarPosicao() {
  if (sensorCima != SENSOR_OK) eeprom_update_byte((uint8_t *)EE_POSICAO, motorPosicao);
}
void guardarSensor(uint8_t novo) {
  if (sensorCima == novo) return;
  sensorCima = novo;
  eeprom_update_byte((uint8_t *)EE_SENSOR, novo);
  eeprom_update_byte((uint8_t *)EE_POSICAO, motorPosicao);
}

bool motorFimAtingido(uint8_t sentido) {
  if (!sensorValeParaParar()) return false;
  /* So ha fim de curso EM CIMA: a descida termina pelo tempo. */
  if (sentido == MOTOR_SUBINDO) return cimaLido();
  return false;
}

/* A chave mudou de verdade, ou foi um pico no fio? Quatro leituras em
   2 ms. O motor ja esta cortado enquanto isso. */
bool motorFimFirme(uint8_t sentido) {
  for (uint8_t i = 0; i < 4; i++) {
    if (!motorFimAtingido(sentido)) return false;
    delayMicroseconds(500);
  }
  return true;
}

/* O teto de tempo do curso. A descida e o proprio curso (ela para pelo
   tempo). A subida para pelo sensor; o tempo e so a protecao, entao ela
   ganha folga: um curso medido um pouco curto nao vira subida pela metade. */
unsigned long motorTeto(uint8_t sentido) {
  if (sentido == MOTOR_SUBINDO && sensorManda()) {
    unsigned long folga = motorCursoMs / 2;
    if (folga < 1500) folga = 1500;
    unsigned long t = motorCursoMs + folga;
    return t > 20000UL ? 20000UL : t;
  }
  return motorCursoMs;
}

/* Comeca um curso. IDEMPOTENTE de proposito: mandar DESCE enquanto ja
   desce nao reinicia o cronometro, e mandar DESCE com o saco ja embaixo
   nao faz nada. E o que impede o jogo de manter o motor ligado para
   sempre a forca de repetir o comando. */
void motorIr(uint8_t sentido) {
  if (sentido != MOTOR_DESCENDO && sentido != MOTOR_SUBINDO) { motorParar(true); return; }
  if (motorEstado == sentido) { motorRelatar(); return; }
  uint8_t destino = (sentido == MOTOR_DESCENDO) ? POS_EM_BAIXO : POS_EM_CIMA;
  /* EM CIMA QUEM DIZ E O SENSOR. Viu o saco: ja chegou. Nao viu: sobe,
     mesmo que a placa "lembre" que estava em cima. */
  if (motorFimAtingido(sentido)) { motorPosicao = destino; motorRelatar(); return; }
  bool peloSensor = (sentido == MOTOR_SUBINDO) && sensorManda();
  if (!peloSensor && motorPosicao == destino) { motorRelatar(); return; }
  /* Inverter exige parar e esperar o tempo morto. */
  if (motorEstado != MOTOR_PARADO) {
    motorPosicao = POS_DESCONHECIDA;
    motorParar(false);
    motorProximo = sentido;
    motorLiberaEm = millis() + motorPausaMs;
    motorRelatar();
    return;
  }
  if (millis() < motorLiberaEm) { motorProximo = sentido; return; }
  /* Saiu do lugar: ate chegar, a posicao e desconhecida. Sem isto, um
     DESCE no meio de uma subida que saiu de baixo era ignorado ("ja esta
     embaixo") e a subida seguia. */
  motorPosicao = POS_DESCONHECIDA;
  guardarPosicao();
  motorEstado = sentido;
  descidaViuLivre = false;
  motorAte = millis() + motorTeto(sentido);
  motorInicio = millis();
  saidaLigar(sentido);
  motorRelatar();
}

/* Uma passada por volta do loop. Sem espera, sem bloqueio. */
void motorAtualizar() {
  if (motorEstado == MOTOR_PARADO) {
    if (motorProximo != MOTOR_PARADO && millis() >= motorLiberaEm) {
      uint8_t alvo = motorProximo; motorProximo = MOTOR_PARADO; motorIr(alvo);
    }
    return;
  }
  if (motorCorteFim || motorFimAtingido(motorEstado)) {
    uint8_t sentido = motorEstado;
    if (motorFimFirme(sentido)) {
      motorPosicao = (sentido == MOTOR_DESCENDO) ? POS_EM_BAIXO : POS_EM_CIMA;
      guardarPosicao();
      if (sentido == MOTOR_SUBINDO) guardarSensor(SENSOR_OK);   /* viu o saco subindo: funciona */
      motorParar(false);
      motorLiberaEm = millis() + motorPausaMs;
      motorRelatar();
      return;
    }
    /* Pico no fio: a chave nao ficou aberta. Religa o mesmo sentido; o
       cronometro do curso continua o mesmo, entao o teto nao muda. */
    motorCorteFim = false;
    saidaLigar(sentido);
  }
  if (motorEstado == MOTOR_DESCENDO && !cimaLido()) descidaViuLivre = true;
  /* Rampa: a carga sobe ate a velocidade escolhida. */
  if (!motorCorteFim && millis() - motorInicio <= RAMPA_MS + 20) saidaLigar(motorEstado);
  if ((long)(millis() - motorAte) >= 0) {
    uint8_t sentido = motorEstado;
    motorParar(false);
    motorLiberaEm = millis() + motorPausaMs;
    if (sentido == MOTOR_SUBINDO && sensorManda()) {
      /* SUBIU O TETO TODO (curso + 50%) E O SENSOR DE CIMA NAO VIU O SACO.
         O saco esta em cima (andou mais que o curso), o sensor e que nao
         ve: daqui em diante a subida e pelo tempo, ate ele voltar a ver. */
      guardarSensor(SENSOR_NUNCA_VE);
      Serial.println(F("ERROR,FIM_CIMA"));
      motorPosicao = POS_EM_CIMA;
    } else {
      /* Descendo (ou subida pelo tempo): o tempo e o curso. */
      motorPosicao = (sentido == MOTOR_DESCENDO) ? POS_EM_BAIXO : POS_EM_CIMA;
      /* DESCEU O CURSO INTEIRO E O SENSOR DE CIMA NUNCA FICOU LIVRE: ele
         esta preso em "chegou". Sem isto a placa recusaria toda subida. */
      if (sentido == MOTOR_DESCENDO && motorUsaFimDeCurso && !descidaViuLivre && cimaLido()) {
        guardarSensor(SENSOR_PRESO);
        Serial.println(F("ERROR,SENSOR_CIMA_PRESO"));
      }
    }
    guardarPosicao();
    motorRelatar();
  }
}

/* ---------------------------------------------------------- o teste
   DESCE 1,5 s, pausa, SOBE ate 1,5 s (para antes se o sensor de cima ver
   o saco). Velocidade cheia nos dois pares de pinos. Nao passa pela
   logica de posicao: e o teste da LIGACAO. */
const unsigned long TESTE_MS = 1500, TESTE_PAUSA_MS = 600;
uint8_t testeFase = 0;           /* 0 nada, 1 descendo, 2 pausa, 3 subindo */
unsigned long testeAte = 0, testePisca = 0;

void testeSaida(uint8_t sentido) {
  saidasDesligar();
  if (sentido == MOTOR_SUBINDO) { OCR1B = PWM_TOPO; TCCR1A |= _BV(COM1B1); PORTB |= _BV(PB0); }
  else { OCR1A = PWM_TOPO; TCCR1A |= _BV(COM1A1); PORTD |= _BV(PD7); }
}

void testeComecar() {
  recolherPendente = false;
  motorParar(false);
  motorPosicao = POS_DESCONHECIDA;
  testeFase = 1; testeAte = millis() + TESTE_MS;
  testeSaida(MOTOR_DESCENDO);
  Serial.println(F("TESTE,DESCE"));
}

void testeParar() {
  if (!testeFase) return;
  testeFase = 0; saidasDesligar(); digitalWrite(LED_STATUS, LOW);
  motorLiberaEm = millis() + motorPausaMs;
  Serial.println(F("TESTE,FIM"));
}

void testeAtualizar() {
  if (!testeFase) return;
  if (millis() - testePisca > 100) { testePisca = millis(); digitalWrite(LED_STATUS, !digitalRead(LED_STATUS)); }
  if (testeFase == 3 && sensorCima != SENSOR_PRESO && cimaLido()) {   /* chegou em cima */
    motorPosicao = POS_EM_CIMA; testeParar(); return;
  }
  if ((long)(millis() - testeAte) < 0) return;
  if (testeFase == 1) { saidasDesligar(); testeFase = 2; testeAte = millis() + TESTE_PAUSA_MS; Serial.println(F("TESTE,PAUSA")); }
  else if (testeFase == 2) { testeFase = 3; testeAte = millis() + TESTE_MS; testeSaida(MOTOR_SUBINDO); Serial.println(F("TESTE,SOBE")); }
  else testeParar();
}

void motorConfigurar(char *cmd) {
  char *p = strtok(cmd, ","); p = strtok(NULL, ","); /* MOTOR */ p = strtok(NULL, ",");
  if (p) {
    motorCursoMs = constrain(atol(p), 200L, (long)MOTOR_CURSO_MAX_MS);
    /* Guardado: ao ligar, a subida pelo tempo (sensor ruim) usa este. */
    eeprom_update_word((uint16_t *)EE_CURSO, (uint16_t)motorCursoMs);
  }
  p = strtok(NULL, ","); if (p) motorPausaMs = constrain(atol(p), 50L, 2000L);
  p = strtok(NULL, ","); if (p) motorUsaFimDeCurso = atoi(p) != 0;
  /* Opcionais (Central da build 106 em diante): velocidade de subida e
     de descida em %. Um jogo antigo manda so os tres primeiros. */
  p = strtok(NULL, ","); if (p) motorVelSobe = constrain(atoi(p), 20, 100);
  p = strtok(NULL, ","); if (p) motorVelDesce = constrain(atoi(p), 20, 100);
  Serial.println(F("OK,MOTOR"));
  motorRelatar();
}

void motorComando(char *cmd) {
  recolherPendente = false;   /* o jogo assumiu o motor */
  if (!strcasecmp(cmd + 6, "TESTE")) { testeComecar(); return; }
  /* Durante o teste so CONFIG, VEL e ESTADO passam; qualquer ordem de
     movimento (ou PARA) encerra o teste antes. */
  if (testeFase && strncasecmp(cmd + 6, "CONFIG", 6) && strncasecmp(cmd + 6, "VEL", 3) && strcasecmp(cmd + 6, "ESTADO"))
    testeParar();
  if (!strncasecmp(cmd + 6, "CONFIG", 6)) { motorConfigurar(cmd); return; }
  if (!strncasecmp(cmd + 6, "VEL,", 4)) {
    char *p = cmd + 10;
    motorVelSobe = constrain(atoi(p), 20, 100);
    p = strchr(p, ','); if (p) motorVelDesce = constrain(atoi(p + 1), 20, 100);
    Serial.print(F("OK,VEL,")); Serial.print(motorVelSobe); Serial.print(','); Serial.println(motorVelDesce);
    return;
  }
  if (!strcasecmp(cmd + 6, "DESCE")) motorIr(MOTOR_DESCENDO);
  else if (!strcasecmp(cmd + 6, "SOBE")) motorIr(MOTOR_SUBINDO);
  else if (!strcasecmp(cmd + 6, "PARA")) { motorTravaCima = false; motorParar(true); }
  else if (!strcasecmp(cmd + 6, "ESTADO")) motorRelatar();
  else Serial.println(F("ERROR,MOTOR"));
}

void comando(char *cmd) {
  if (!strcasecmp(cmd,"PING")) { Serial.println(F("READY,PUNCH_OPTICAL,V9-MH-LM393")); Serial.println(F("PONG")); }
  else if (!strcasecmp(cmd,"ARM")) armarCaptura();
  else if (!strcasecmp(cmd,"RESET")) { noInterrupts(); capturaArmada=false; pulsoAberto=false; pulsoPendente=false; interrupts(); motorParar(false); Serial.println(F("OK,RESET")); }
  else if (!strcasecmp(cmd,"CALIBRATE")) { calibrar(); Serial.println(F("OK,CALIBRATE")); }
  else if (!strcasecmp(cmd,"TEST")) { Serial.println(F("HIT,2.600,0.500,7.692,O")); }
  else if (!strncasecmp(cmd,"CONFIG,",7)) configurar(cmd);
  else if (!strncasecmp(cmd,"LEDS,",5)) leds(atol(cmd+5));
  else if (!strncasecmp(cmd,"MOTOR,",6)) motorComando(cmd);
  else Serial.println(F("ERROR,COMANDO"));
}

void serialReceber() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') {
      if (entradaUso) { entrada[entradaUso]=0; comando(entrada); entradaUso=0; }
    } else if (entradaUso < sizeof(entrada)-1) entrada[entradaUso++] = c;
  }
}

void telemetria() {
  ultimoA0 = analogRead(PIN_A0) / 1023.0f;
  Serial.print(F("TELEMETRY,")); Serial.print(digitalRead(PIN_D0)==nivelAtivo?1:0);
  Serial.print(','); Serial.print(ultimoA0,3); Serial.print(F(",0,0,0,0,"));
  Serial.print(ultimaVelocidade,3); Serial.println(F(",0"));
  Serial.print(F("PINS,")); Serial.print(digitalRead(PIN_START)==LOW?1:0); Serial.print(',');
  Serial.print(digitalRead(PIN_CREDIT)==LOW?1:0); Serial.print(','); Serial.println(digitalRead(PIN_CONFIG)==LOW?1:0);
  Serial.print(F("STATUS,")); Serial.print(pulsoAberto?1:0); Serial.print(','); Serial.print(ultimoA0,3); Serial.print(','); Serial.println(pulsoMinUs/1000.0f,2);
  /* FIM,<cima chegou>,<baixo chegou>,<subida travada> - cru, para a
     Central: ponha a mao (ou o alvo branco) na frente do sensor de cima
     e veja o numero mudar. */
  Serial.print(F("FIM,")); Serial.print(digitalRead(PIN_FIM_CIMA)==FIM_CIMA_NIVEL_CHEGOU?1:0); Serial.print(',');
  Serial.print(0); Serial.print(','); Serial.println(motorTravaCima?1:0);   /* sem fim de curso de baixo */
  Serial.print(F("SENSOR_CIMA,")); Serial.println(sensorCima);
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_START,INPUT_PULLUP); pinMode(PIN_CREDIT,INPUT_PULLUP); pinMode(PIN_CONFIG,INPUT_PULLUP);
  pinMode(PIN_D0,INPUT_PULLUP); pinMode(PIN_A0,INPUT); pinMode(LED_STATUS,OUTPUT);
  /* O MOTOR NASCE DESLIGADO, e as saidas viram saidas DEPOIS de ja
     estarem em LOW. Configurar o pino como saida antes de escrever nele
     deixa um pulso de nivel indefinido na ponte H - curto, mas suficiente
     para o saco dar um tranco toda vez que a maquina liga. */
  digitalWrite(PIN_MOTOR_DESCE,LOW); digitalWrite(PIN_MOTOR_SOBE,LOW);
  digitalWrite(PIN_ESPELHO_DESCE,LOW); digitalWrite(PIN_ESPELHO_SOBE,LOW);
  pinMode(PIN_MOTOR_DESCE,OUTPUT); pinMode(PIN_MOTOR_SOBE,OUTPUT);
  pinMode(PIN_ESPELHO_DESCE,OUTPUT); pinMode(PIN_ESPELHO_SOBE,OUTPUT);
  digitalWrite(PIN_MOTOR_DESCE,LOW); digitalWrite(PIN_MOTOR_SOBE,LOW);
  /* Timer1 so para a ponte H: Fast PWM (modo 14), TOPO no ICR1, sem
     divisor -> 20 kHz, acima do que o ouvido escuta. As saidas so ligam
     em saidaLigar. */
  TCCR1A = _BV(WGM11); TCCR1B = 0; TCNT1 = 0;
  ICR1 = PWM_TOPO - 1; OCR1A = 0; OCR1B = 0;
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS10);
  pinMode(PIN_FIM_CIMA,FIM_CIMA_MODO);
  /* O QUE A PLACA LEMBRA da ultima vez que ficou ligada. */
  if (eeprom_read_byte((uint8_t *)EE_MARCA) == EE_VALOR_MARCA) {
    uint8_t sv = eeprom_read_byte((uint8_t *)EE_SENSOR);
    uint8_t pv = eeprom_read_byte((uint8_t *)EE_POSICAO);
    sensorCima = sv <= SENSOR_NUNCA_VE ? sv : SENSOR_OK;
    /* Com o sensor confiavel quem diz e ele; sem, vale a memoria. */
    if (sensorCima != SENSOR_OK && pv <= POS_EM_BAIXO) motorPosicao = pv;
    uint16_t cv = eeprom_read_word((uint16_t *)EE_CURSO);
    if (cv >= 200 && cv <= MOTOR_CURSO_MAX_MS) motorCursoMs = cv;
  } else {
    eeprom_update_byte((uint8_t *)EE_MARCA, EE_VALOR_MARCA);
    eeprom_update_byte((uint8_t *)EE_SENSOR, SENSOR_OK);
    eeprom_update_byte((uint8_t *)EE_POSICAO, POS_DESCONHECIDA);
    eeprom_update_word((uint16_t *)EE_CURSO, (uint16_t)motorCursoMs);
  }
#if TEM_FITAS
  fitaEsq.begin(); fitaDir.begin(); fitaEsq.setBrightness(140); fitaDir.setBrightness(140);
  fitaEsq.show(); fitaDir.show();
#endif
  Serial.println(F("READY,PUNCH_OPTICAL,V9-MH-LM393")); calibrar();
#if defined(__AVR_ATmega328P__)
  PCICR |= _BV(PCIE2); PCMSK2 |= _BV(PCINT20);
  PCICR |= _BV(PCIE0); PCMSK0 |= _BV(PCINT3);   /* D11: fim de curso de cima */
#endif
  /* AUTOTESTE: START segurado ao ligar (2 s firmes) = teste do motor. */
  unsigned long t0 = millis(); bool segurou = true;
  while (millis() - t0 < 2000) {
    if (digitalRead(PIN_START) != LOW) { segurou = false; break; }
  }
  if (segurou) { Serial.println(F("AUTOTESTE,START SEGURADO")); testeComecar(); }
}

void loop() {
  /* PRESO EM "CHEGOU" QUE FICOU LIVRE (meio segundo firme): o sensor
     voltou a funcionar (fio arrumado). */
  if (sensorCima == SENSOR_PRESO) {
    if (cimaLido()) sensorLivreDesde = 0;
    else if (!sensorLivreDesde) sensorLivreDesde = millis() | 1;
    else if (millis() - sensorLivreDesde > 500) { guardarSensor(SENSOR_OK); sensorLivreDesde = 0; }
  }
  /* AO LIGAR: recolhe o saco. Com sensor bom, sobe ate ele ver (se ja ve,
     nao mexe). Com sensor ruim, sobe pelo tempo se a placa nao lembra do
     saco em cima. */
  if (recolherPendente && millis() >= RECOLHER_APOS_MS) {
    recolherPendente = false;
    if (motorEstado == MOTOR_PARADO) motorIr(MOTOR_SUBINDO);
  }
  serialReceber(); botoes();
  if (testeFase) testeAtualizar(); else motorAtualizar(); feixeAtualizarMudo(); feixeAcompanharRepouso(); medir();
  if (millis()-ultimaTelemetriaMs >= 250) { ultimaTelemetriaMs=millis(); telemetria(); }
}
