/*
  TESTE DA PONTE H E DOS FINS DE CURSO - SEM O JOGO
  Arduino Uno/Nano - Monitor Serial a 115200, "Nova linha"

  Serve para montar a maquina: sobe e desce o saco pelo Monitor Serial e
  mostra as chaves de fim de curso. Usa os MESMOS pinos e as MESMAS
  protecoes do firmware do jogo (ARDUINO_SENSOR_DE_FEIXE_LM393.ino):

    D7  -> RPWM da ponte H (DESCE)      D11 <- fim de curso de CIMA (NF)
    D8  -> LPWM da ponte H (SOBE)       D10 <- fim de curso de BAIXO (NA, opcional)
    R_EN e L_EN da ponte -> 5V          GND da ponte = GND do Arduino

  COMANDOS (digite e aperte Enter):
    s  sobe ate a chave de cima abrir (ou o tempo acabar)
    d  desce ate a chave de baixo (ou o tempo acabar)
    p  para na hora
    t  mostra quanto tempo o ultimo curso levou
    2500  (um numero) muda o tempo maximo do curso em ms (padrao 4000)

  DEPOIS DO TESTE grave de novo o ARDUINO_SENSOR_DE_FEIXE_LM393.ino.

  As duas saidas NUNCA ficam altas juntas e ha uma pausa ao inverter o
  sentido: e o que protege a ponte H e a caixa de reducao.
*/

#define PIN_DESCE 7
#define PIN_SOBE 8
#define PIN_FIM_BAIXO 10   /* NA: LOW = chegou embaixo */
#define PIN_FIM_CIMA 11    /* NF: HIGH = chegou em cima (ou fio solto) */

const unsigned long PAUSA_MS = 350;
unsigned long cursoMaxMs = 4000;

uint8_t sentido = 0;            /* 0 parado, 1 descendo, 2 subindo */
unsigned long inicio = 0, ultimoCurso = 0, paradoEm = 0, ultimaLinha = 0;
char linha[16];
uint8_t uso = 0;

bool cimaChegou() { return digitalRead(PIN_FIM_CIMA) == HIGH; }
bool baixoChegou() { return digitalRead(PIN_FIM_BAIXO) == LOW; }

void parar(const __FlashStringHelper *motivo) {
  digitalWrite(PIN_DESCE, LOW);
  digitalWrite(PIN_SOBE, LOW);
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
  if (novo == 2 && cimaChegou()) { Serial.println(F("JA ESTA EM CIMA (ou a chave de cima esta solta: confira o NF no D11)")); return; }
  if (novo == 1 && baixoChegou()) { Serial.println(F("JA ESTA EMBAIXO")); return; }
  while (millis() - paradoEm < PAUSA_MS) { }   /* pausa ao inverter */
  sentido = novo;
  inicio = millis();
  digitalWrite(novo == 1 ? PIN_DESCE : PIN_SOBE, HIGH);
  Serial.println(novo == 1 ? F("DESCENDO...") : F("SUBINDO..."));
}

void comando(char *c) {
  if (c[0] == 's' || c[0] == 'S') ir(2);
  else if (c[0] == 'd' || c[0] == 'D') ir(1);
  else if (c[0] == 'p' || c[0] == 'P') parar(F("comando p"));
  else if (c[0] == 't' || c[0] == 'T') { Serial.print(F("ULTIMO CURSO: ")); Serial.print(ultimoCurso); Serial.println(F(" ms  -> no jogo use este valor + 10%")); }
  else if (c[0] >= '0' && c[0] <= '9') {
    cursoMaxMs = constrain(atol(c), 200L, 15000L);
    Serial.print(F("TEMPO MAXIMO DO CURSO: ")); Serial.print(cursoMaxMs); Serial.println(F(" ms"));
  }
}

void setup() {
  digitalWrite(PIN_DESCE, LOW); digitalWrite(PIN_SOBE, LOW);
  pinMode(PIN_DESCE, OUTPUT); pinMode(PIN_SOBE, OUTPUT);
  digitalWrite(PIN_DESCE, LOW); digitalWrite(PIN_SOBE, LOW);
  pinMode(PIN_FIM_CIMA, INPUT_PULLUP); pinMode(PIN_FIM_BAIXO, INPUT_PULLUP);
  Serial.begin(115200);
  Serial.println(F("TESTE DA PONTE H - comandos: s (sobe), d (desce), p (para), t (tempo), numero (tempo maximo ms)"));
}

void loop() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n' || c == '\r') { if (uso) { linha[uso] = 0; comando(linha); uso = 0; } }
    else if (uso < sizeof(linha) - 1) linha[uso++] = c;
  }
  if (sentido == 2 && cimaChegou()) parar(F("chave de CIMA abriu"));
  if (sentido == 1 && baixoChegou()) parar(F("chave de BAIXO"));
  if (sentido != 0 && millis() - inicio >= cursoMaxMs)
    parar(sentido == 2 ? F("TEMPO ACABOU SUBINDO SEM A CHAVE DE CIMA ABRIR - ajuste a chave!") : F("tempo do curso"));
  if (millis() - ultimaLinha >= 1000) {
    ultimaLinha = millis();
    Serial.print(F("chave CIMA: ")); Serial.print(cimaChegou() ? F("ACIONADA") : F("livre"));
    Serial.print(F("   chave BAIXO: ")); Serial.print(baixoChegou() ? F("ACIONADA") : F("livre"));
    Serial.print(F("   motor: ")); Serial.println(sentido == 0 ? F("parado") : (sentido == 1 ? F("descendo") : F("subindo")));
  }
}
