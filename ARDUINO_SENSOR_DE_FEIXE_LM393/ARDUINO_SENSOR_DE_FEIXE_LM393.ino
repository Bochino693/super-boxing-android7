/*
  PUNCH CHALLENGE - FIRMWARE COMPLETO SENSOR DE FEIXE MH/LM393 V5
  Arduino Uno/Nano ATmega328P - serial 115200

  Sensor: VCC->5V, GND->GND, D0->D4, A0->A0
  Botoes: START->D2/GND, CREDIT->D3/GND, CONFIG->D9/GND
  Fitas: dados esquerda D5, dados direita D6, fonte externa e GND comum
  Motor: D7 desce, D8 sobe (ponte H). Fim de curso de CIMA em D11:
         SENSOR INFRAVERMELHO de obstaculo (modulo FC-51/LM393, 3 pinos
         VCC/GND/OUT): OUT->D11 e um resistor de 100k do D11 ao GND.
         De BAIXO em D10 (micro chave NA ou outro sensor igual, opcional).

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
#define PIN_CONFIG 9
#define PIN_D0 4
#define PIN_A0 A0
#define LED_STATUS 13
#define PIN_FITA_ESQ 5
#define PIN_FITA_DIR 6
#define LEDS_POR_FITA 30

/* ------------------------------------------------------------------
   MOTOR DO SACO - desce no START e sobe no fim da rodada.

   LIGACAO. Duas saidas digitais comandam uma ponte H (L298N: IN1/IN2;
   BTS7960: D7->RPWM, D8->LPWM, R_EN e L_EN->5V) ou um par de reles com intertravamento
   mecanico. NUNCA as duas ao mesmo tempo - ver `motorParar`.

     D7  -> DESCE   (IN1 ou RPWM)
     D8  -> SOBE    (IN2 ou LPWM)
     D10 -> fim de curso DE BAIXO  (C e NA da chave: C no GND; opcional)
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
#define PIN_MOTOR_DESCE 7
#define PIN_MOTOR_SOBE 8
#define PIN_FIM_BAIXO 10
#define PIN_FIM_CIMA 11

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
volatile bool motorUsaFimDeCurso = true;
/* A interrupcao do fim de curso cortou o motor; o loop confirma. */
volatile bool motorCorteFim = false;
/* Subida sem o sensor de cima ver o saco dentro do tempo: subida travada ate
   um MOTOR,PARA (botao PARAR da Central). */
bool motorTravaCima = false;

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
   escrevendo na serial). D8 = PB0 (sobe), D7 = PD7 (desce),
   D11 = PB3 (cima: FIM_CIMA_NIVEL_CHEGOU), D10 = PB2 (baixo: LOW = chegou). */
ISR(PCINT0_vect) {
  if (!motorUsaFimDeCurso) return;
  uint8_t cima = (PINB & _BV(PB3)) ? HIGH : LOW;
  if (motorEstado == MOTOR_SUBINDO && cima == FIM_CIMA_NIVEL_CHEGOU) { PORTB &= ~_BV(PB0); motorCorteFim = true; }
  if (motorEstado == MOTOR_DESCENDO && !(PINB & _BV(PB2))) { PORTD &= ~_BV(PD7); motorCorteFim = true; }
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
  digitalWrite(PIN_MOTOR_DESCE, LOW);
  digitalWrite(PIN_MOTOR_SOBE, LOW);
  bool mudou = motorEstado != MOTOR_PARADO;
  motorEstado = MOTOR_PARADO;
  motorProximo = MOTOR_PARADO;
  motorCorteFim = false;
  if (mudou) feixeLiberaEm = millis() + ASSENTAR_MS;
  if (avisar && mudou) motorRelatar();
}

bool motorFimAtingido(uint8_t sentido) {
  if (!motorUsaFimDeCurso) return false;
  if (sentido == MOTOR_DESCENDO) return digitalRead(PIN_FIM_BAIXO) == LOW;   /* NA */
  if (sentido == MOTOR_SUBINDO) return digitalRead(PIN_FIM_CIMA) == FIM_CIMA_NIVEL_CHEGOU;
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

/* Comeca um curso. IDEMPOTENTE de proposito: mandar DESCE enquanto ja
   desce nao reinicia o cronometro, e mandar DESCE com o saco ja embaixo
   nao faz nada. E o que impede o jogo de manter o motor ligado para
   sempre a forca de repetir o comando. */
void motorIr(uint8_t sentido) {
  if (sentido != MOTOR_DESCENDO && sentido != MOTOR_SUBINDO) { motorParar(true); return; }
  if (motorEstado == sentido) return;
  if (sentido == MOTOR_SUBINDO && motorTravaCima) { Serial.println(F("ERROR,FIM_CIMA")); motorRelatar(); return; }
  uint8_t destino = (sentido == MOTOR_DESCENDO) ? POS_EM_BAIXO : POS_EM_CIMA;
  if (motorPosicao == destino) { motorRelatar(); return; }
  if (motorFimAtingido(sentido)) { motorPosicao = destino; motorRelatar(); return; }
  /* Inverter exige parar e esperar o tempo morto. */
  if (motorEstado != MOTOR_PARADO) {
    motorParar(false);
    motorProximo = sentido;
    motorLiberaEm = millis() + motorPausaMs;
    motorRelatar();
    return;
  }
  if (millis() < motorLiberaEm) { motorProximo = sentido; return; }
  motorEstado = sentido;
  motorAte = millis() + motorCursoMs;
  digitalWrite(PIN_MOTOR_DESCE, sentido == MOTOR_DESCENDO ? HIGH : LOW);
  digitalWrite(PIN_MOTOR_SOBE, sentido == MOTOR_SUBINDO ? HIGH : LOW);
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
      motorParar(false);
      motorLiberaEm = millis() + motorPausaMs;
      motorRelatar();
      return;
    }
    /* Pico no fio: a chave nao ficou aberta. Religa o mesmo sentido; o
       cronometro do curso continua o mesmo, entao o teto nao muda. */
    motorCorteFim = false;
    digitalWrite(sentido == MOTOR_DESCENDO ? PIN_MOTOR_DESCE : PIN_MOTOR_SOBE, HIGH);
  }
  if ((long)(millis() - motorAte) >= 0) {
    uint8_t sentido = motorEstado;
    motorParar(false);
    motorLiberaEm = millis() + motorPausaMs;
    if (sentido == MOTOR_SUBINDO && motorUsaFimDeCurso) {
      /* SUBIU O TEMPO TODO E O SENSOR DE CIMA NAO VIU O SACO. Ou o sensor
         esta fora do lugar/desregulado, ou sem o GND: o saco pode estar
         forcando o topo.
         Nao finge que chegou e trava a subida ate o tecnico ver. */
      motorPosicao = POS_DESCONHECIDA;
      motorTravaCima = true;
      Serial.println(F("ERROR,FIM_CIMA"));
    } else {
      /* Sem fins de curso (ou descendo sem a chave de baixo): o tempo e
         o curso. */
      motorPosicao = (sentido == MOTOR_DESCENDO) ? POS_EM_BAIXO : POS_EM_CIMA;
    }
    motorRelatar();
  }
}

void motorConfigurar(char *cmd) {
  char *p = strtok(cmd, ","); p = strtok(NULL, ","); /* MOTOR */ p = strtok(NULL, ",");
  if (p) motorCursoMs = constrain(atol(p), 200L, (long)MOTOR_CURSO_MAX_MS);
  p = strtok(NULL, ","); if (p) motorPausaMs = constrain(atol(p), 50L, 2000L);
  p = strtok(NULL, ","); if (p) motorUsaFimDeCurso = atoi(p) != 0;
  Serial.println(F("OK,MOTOR"));
  motorRelatar();
}

void motorComando(char *cmd) {
  if (!strncasecmp(cmd + 6, "CONFIG", 6)) { motorConfigurar(cmd); return; }
  if (!strcasecmp(cmd + 6, "DESCE")) motorIr(MOTOR_DESCENDO);
  else if (!strcasecmp(cmd + 6, "SOBE")) motorIr(MOTOR_SUBINDO);
  else if (!strcasecmp(cmd + 6, "PARA")) { motorTravaCima = false; motorParar(true); }
  else if (!strcasecmp(cmd + 6, "ESTADO")) motorRelatar();
  else Serial.println(F("ERROR,MOTOR"));
}

void comando(char *cmd) {
  if (!strcasecmp(cmd,"PING")) { Serial.println(F("READY,PUNCH_OPTICAL,V5-MH-LM393")); Serial.println(F("PONG")); }
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
  Serial.print(digitalRead(PIN_FIM_BAIXO)==LOW?1:0); Serial.print(','); Serial.println(motorTravaCima?1:0);
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
  pinMode(PIN_MOTOR_DESCE,OUTPUT); pinMode(PIN_MOTOR_SOBE,OUTPUT);
  digitalWrite(PIN_MOTOR_DESCE,LOW); digitalWrite(PIN_MOTOR_SOBE,LOW);
  pinMode(PIN_FIM_BAIXO,INPUT_PULLUP); pinMode(PIN_FIM_CIMA,FIM_CIMA_MODO);
#if TEM_FITAS
  fitaEsq.begin(); fitaDir.begin(); fitaEsq.setBrightness(140); fitaDir.setBrightness(140);
  fitaEsq.show(); fitaDir.show();
#endif
  Serial.println(F("READY,PUNCH_OPTICAL,V5-MH-LM393")); calibrar();
#if defined(__AVR_ATmega328P__)
  PCICR |= _BV(PCIE2); PCMSK2 |= _BV(PCINT20);
  PCICR |= _BV(PCIE0); PCMSK0 |= _BV(PCINT2) | _BV(PCINT3);   /* D10, D11 */
#endif
}

void loop() {
  serialReceber(); botoes(); motorAtualizar(); feixeAtualizarMudo(); feixeAcompanharRepouso(); medir();
  if (millis()-ultimaTelemetriaMs >= 250) { ultimaTelemetriaMs=millis(); telemetria(); }
}
