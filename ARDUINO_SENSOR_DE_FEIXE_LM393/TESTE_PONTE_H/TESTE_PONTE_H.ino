/*
  TESTE DA PONTE H, DA VELOCIDADE E DO FIM DE CURSO - SEM O JOGO (V6)
  Arduino Uno/Nano - Monitor Serial a 115200, "Nova linha"

  Serve para montar a maquina: sobe e desce o saco pelo Monitor Serial,
  acha a velocidade boa e mostra o sensor de cima. Usa os MESMOS pinos e
  as MESMAS protecoes do firmware do jogo (ARDUINO_SENSOR_DE_FEIXE_LM393.ino):

    D9  -> RPWM da ponte H  (DESCE, com velocidade)
    D10 -> LPWM da ponte H  (SOBE, com velocidade)
    5V  -> R_EN, L_EN e VCC da ponte H        GND -> GND da ponte H
    D11 <- OUT do sensor infravermelho de CIMA (+ resistor de 100k do D11 ao GND)

  COMANDOS (digite e aperte Enter):
    s      sobe ate o sensor de cima ver o saco (ou o tempo acabar)
    d      desce pelo tempo de curso
    p      para na hora
    t      mostra quanto tempo o ultimo curso levou
    v80    velocidade da SUBIDA em % (20 a 100)
    w60    velocidade da DESCIDA em % (20 a 100)
    2500   (um numero) muda o tempo maximo do curso em ms (padrao 4000)

  Achou a velocidade boa? Ponha os MESMOS numeros na Central do jogo
  (aba SACO, VELOCIDADE). DEPOIS DO TESTE grave de novo o
  ARDUINO_SENSOR_DE_FEIXE_LM393.ino.

  As duas saidas NUNCA tem pulso juntas e ha uma pausa ao inverter o
  sentido: e o que protege a ponte H e a caixa de reducao. A partida e
  em rampa (sem tranco).
*/

#define PIN_DESCE 9    /* RPWM - OC1A */
#define PIN_SOBE 10    /* LPWM - OC1B */
#define PIN_FIM_CIMA 11
/* 1 = sensor infravermelho (LOW = viu o saco); 0 = micro chave NF (HIGH).
   IGUAL ao ARDUINO_SENSOR_DE_FEIXE_LM393.ino. */
#define FIM_CIMA_INFRAVERMELHO 1
#if FIM_CIMA_INFRAVERMELHO
  #define FIM_CIMA_NIVEL_CHEGOU LOW
  #define FIM_CIMA_MODO INPUT
#else
  #define FIM_CIMA_NIVEL_CHEGOU HIGH
  #define FIM_CIMA_MODO INPUT_PULLUP
#endif
#define PWM_TOPO 800              /* 16 MHz / 800 = 20 kHz */

const unsigned long PAUSA_MS = 350;
const unsigned long RAMPA_MS = 300;
const uint8_t RAMPA_INICIO = 25;
unsigned long cursoMaxMs = 4000;
uint8_t velSobe = 80, velDesce = 60;

uint8_t sentido = 0;            /* 0 parado, 1 descendo, 2 subindo */
unsigned long inicio = 0, ultimoCurso = 0, paradoEm = 0, ultimaLinha = 0;
char linha[16];
uint8_t uso = 0;

bool cimaChegou() { return digitalRead(PIN_FIM_CIMA) == FIM_CIMA_NIVEL_CHEGOU; }

void saidasDesligar() {
  TCCR1A &= ~(_BV(COM1A1) | _BV(COM1B1));
  OCR1A = 0; OCR1B = 0;
  digitalWrite(PIN_DESCE, LOW); digitalWrite(PIN_SOBE, LOW);
}

/* Liga/atualiza o pulso do sentido atual, com a rampa de partida. */
void saidaAtualizar() {
  uint8_t alvo = sentido == 2 ? velSobe : velDesce;
  unsigned long dt = millis() - inicio;
  uint8_t pct = alvo;
  if (dt < RAMPA_MS && alvo > RAMPA_INICIO) pct = RAMPA_INICIO + (uint8_t)((unsigned long)(alvo - RAMPA_INICIO) * dt / RAMPA_MS);
  uint16_t carga = (uint16_t)((unsigned long)pct * PWM_TOPO / 100);
  if (sentido == 2) {
    TCCR1A &= ~_BV(COM1A1); digitalWrite(PIN_DESCE, LOW); OCR1A = 0;
    OCR1B = carga; TCCR1A |= _BV(COM1B1);
  } else if (sentido == 1) {
    TCCR1A &= ~_BV(COM1B1); digitalWrite(PIN_SOBE, LOW); OCR1B = 0;
    OCR1A = carga; TCCR1A |= _BV(COM1A1);
  }
}

void parar(const __FlashStringHelper *motivo) {
  saidasDesligar();
  if (sentido != 0) {
    ultimoCurso = millis() - inicio;
    paradoEm = millis();
    Serial.print(F("PAROU: ")); Serial.print(motivo);
    Serial.print(F("  (curso de ")); Serial.print(ultimoCurso); Serial.println(F(" ms)"));
  }
  sentido = 0;
}

void ir(uint8_t novo) {
  if (sentido == novo) return;
  if (sentido != 0) parar(F("inversao"));
  if (novo == 2 && cimaChegou()) { Serial.println(F("JA ESTA EM CIMA (ou o fio OUT do sensor de cima esta solto: confira o D11)")); return; }
  while (millis() - paradoEm < PAUSA_MS) { }   /* pausa ao inverter */
  sentido = novo;
  inicio = millis();
  saidaAtualizar();
  Serial.print(novo == 1 ? F("DESCENDO a ") : F("SUBINDO a "));
  Serial.print(novo == 1 ? velDesce : velSobe); Serial.println(F("%..."));
}

void comando(char *c) {
  if (c[0] == 's' || c[0] == 'S') ir(2);
  else if (c[0] == 'd' || c[0] == 'D') ir(1);
  else if (c[0] == 'p' || c[0] == 'P') parar(F("comando p"));
  else if (c[0] == 't' || c[0] == 'T') { Serial.print(F("ULTIMO CURSO: ")); Serial.print(ultimoCurso); Serial.println(F(" ms  -> no jogo use este valor + 10%")); }
  else if (c[0] == 'v' || c[0] == 'V') { velSobe = constrain(atoi(c + 1), 20, 100); Serial.print(F("VELOCIDADE DA SUBIDA: ")); Serial.print(velSobe); Serial.println('%'); }
  else if (c[0] == 'w' || c[0] == 'W') { velDesce = constrain(atoi(c + 1), 20, 100); Serial.print(F("VELOCIDADE DA DESCIDA: ")); Serial.print(velDesce); Serial.println('%'); }
  else if (c[0] >= '0' && c[0] <= '9') {
    cursoMaxMs = constrain(atol(c), 200L, 15000L);
    Serial.print(F("TEMPO MAXIMO DO CURSO: ")); Serial.print(cursoMaxMs); Serial.println(F(" ms"));
  }
}

void setup() {
  digitalWrite(PIN_DESCE, LOW); digitalWrite(PIN_SOBE, LOW);
  pinMode(PIN_DESCE, OUTPUT); pinMode(PIN_SOBE, OUTPUT);
  digitalWrite(PIN_DESCE, LOW); digitalWrite(PIN_SOBE, LOW);
  /* Timer1: Fast PWM (modo 14), TOPO no ICR1, sem divisor -> 20 kHz. */
  TCCR1A = _BV(WGM11); TCCR1B = 0; TCNT1 = 0;
  ICR1 = PWM_TOPO - 1; OCR1A = 0; OCR1B = 0;
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS10);
  pinMode(PIN_FIM_CIMA, FIM_CIMA_MODO);
  Serial.begin(115200);
  Serial.println(F("TESTE DA PONTE H V6 - comandos: s (sobe), d (desce), p (para), t (tempo), v80 (vel. subida %), w60 (vel. descida %), numero (tempo maximo ms)"));
}

void loop() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') { if (uso) { linha[uso] = 0; comando(linha); uso = 0; } }
    else if (uso < sizeof(linha) - 1) linha[uso++] = c;
  }
  if (sentido == 2 && cimaChegou()) parar(F("sensor de CIMA viu o saco"));
  if (sentido != 0 && millis() - inicio <= RAMPA_MS + 20) saidaAtualizar();
  if (sentido != 0 && millis() - inicio >= cursoMaxMs)
    parar(sentido == 2 ? F("TEMPO ACABOU SUBINDO SEM O SENSOR DE CIMA VER O SACO - ajuste o sensor/trimpot!") : F("tempo do curso (descida)"));
  if (millis() - ultimaLinha >= 1000) {
    ultimaLinha = millis();
    Serial.print(F("sensor CIMA: ")); Serial.print(cimaChegou() ? F("ACIONADO") : F("livre"));
    Serial.print(F("   motor: ")); Serial.print(sentido == 0 ? F("parado") : (sentido == 1 ? F("descendo") : F("subindo")));
    Serial.print(F("   vel. subida ")); Serial.print(velSobe); Serial.print(F("% / descida ")); Serial.print(velDesce); Serial.println('%');
  }
}
