/*
  TESTE DO SENSOR DE FEIXE - SEM O JOGO
  Arduino Uno/Nano - Monitor Serial a 115200

  Responde em dois minutos: o feixe esta vendo a palheta, e a que
  velocidade? Mesmos pinos do firmware do jogo:

    DO do sensor -> D4      AO do sensor -> A0      VCC 5V, GND

  O QUE APARECE
    A cada segundo:  feixe LIVRE/CORTADO, nivel do DO e o A0 (0 a 1023).
    A cada passagem: "BLOQUEIO de X ms -> Y m/s" (palheta de 20 mm).

  COMO LER
    - Passe um cartao na fenda: tem de mudar de LIVRE para CORTADO e
      voltar. Se nao muda: gire o trimpot do modulo ate o LED dele mudar
      com o cartao, ou confira o fio do DO (tem de ir no D4, nao no D2).
    - Soco forte de verdade: bloqueio de 3 a 10 ms (2 a 7 m/s).
      Se der 20 ms ou mais num soco forte, o sensor e lento demais
      (LDR com laser): troque por sensor de fenda/infravermelho.
    - O nivel que fica parado com a fenda livre e o "livre"; o firmware
      do jogo aprende isso sozinho.

  DEPOIS DO TESTE grave de novo o ARDUINO_SENSOR_DE_FEIXE_LM393.ino.
*/

#define PIN_DO 4
#define PIN_AO A0
const float PALHETA_M = 0.020;

uint8_t livre;               /* nivel do DO com a fenda livre (medido ao ligar) */
uint8_t anterior;
unsigned long inicioUs = 0, ultimaLinha = 0;

void setup() {
  pinMode(PIN_DO, INPUT_PULLUP);
  Serial.begin(115200);
  delay(300);
  livre = digitalRead(PIN_DO);
  anterior = livre;
  Serial.print(F("TESTE DO FEIXE - nivel LIVRE (fenda vazia ao ligar) = "));
  Serial.println(livre);
}

void loop() {
  uint8_t n = digitalRead(PIN_DO);
  if (n != anterior) {
    unsigned long agora = micros();
    if (n != livre) {
      inicioUs = agora;                     /* comecou a cortar */
    } else {
      unsigned long d = agora - inicioUs;   /* voltou a ficar livre */
      float ms = d / 1000.0;
      Serial.print(F("BLOQUEIO de ")); Serial.print(ms, 2); Serial.print(F(" ms -> "));
      Serial.print(PALHETA_M * 1000000.0 / d, 2); Serial.println(F(" m/s"));
    }
    anterior = n;
  }
  if (millis() - ultimaLinha >= 1000) {
    ultimaLinha = millis();
    Serial.print(F("feixe ")); Serial.print(n == livre ? F("LIVRE  ") : F("CORTADO"));
    Serial.print(F("   DO=")); Serial.print(n);
    Serial.print(F("   AO=")); Serial.println(analogRead(PIN_AO));
  }
}
