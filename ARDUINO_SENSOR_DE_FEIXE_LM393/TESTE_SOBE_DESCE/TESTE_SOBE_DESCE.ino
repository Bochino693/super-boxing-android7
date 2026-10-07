/*
  TESTE SOBE / DESCE - SEM JOGO, SEM SERIAL, SEM SENSOR.
  Grave, ligue a fonte do motor e OLHE O SACO. Em laco, para sempre:
    DESCE 2 s  ->  para 1 s  ->  SOBE 2 s  ->  para 3 s
  O LED "L" do Nano fica ACESO enquanto o motor deve andar.

  O QUE O RESULTADO DIZ:
  - Desce E sobe: ponte H e fios OK. Grave de novo o firmware
    ARDUINO_SENSOR_DE_FEIXE_LM393.ino (V10) e jogue.
  - So UM sentido anda (e trocando M+/M- o sentido que anda inverte):
    um dos dois fios de comando NAO chega na ponte H. Confira na BTS7960:
      RPWM -> D9      LPWM -> D10
      R_EN -> 5V      L_EN -> 5V      VCC -> 5V      GND -> GND do Nano
    (quem montou pela ligacao antiga: RPWM -> D7 e LPWM -> D8 tambem vale -
    este teste liga os dois pares ao mesmo tempo, igual ao firmware).
    Fio certo e mesmo assim so um sentido: a metade da ponte H queimou.
  - Nao mexe nada: fonte do motor (B+/B-), R_EN/L_EN sem 5V ou GND solto.
*/
const int DESCE_PWM = 9, SOBE_PWM = 10;     // ligacao atual (RPWM / LPWM)
const int DESCE_ANT = 7, SOBE_ANT = 8;      // ligacao antiga (RPWM / LPWM)
const unsigned long TEMPO = 2000;

void tudoParado() {
  digitalWrite(DESCE_PWM, LOW); digitalWrite(SOBE_PWM, LOW);
  digitalWrite(DESCE_ANT, LOW); digitalWrite(SOBE_ANT, LOW);
  digitalWrite(LED_BUILTIN, LOW);
}

void setup() {
  int pinos[] = {DESCE_PWM, SOBE_PWM, DESCE_ANT, SOBE_ANT, LED_BUILTIN};
  for (int i = 0; i < 5; i++) { digitalWrite(pinos[i], LOW); pinMode(pinos[i], OUTPUT); }
  tudoParado();
  delay(1500);
}

void loop() {
  // DESCE: so o lado da descida em HIGH, o outro em LOW
  digitalWrite(SOBE_PWM, LOW); digitalWrite(SOBE_ANT, LOW);
  digitalWrite(DESCE_PWM, HIGH); digitalWrite(DESCE_ANT, HIGH); digitalWrite(LED_BUILTIN, HIGH);
  delay(TEMPO);
  tudoParado(); delay(1000);
  // SOBE
  digitalWrite(DESCE_PWM, LOW); digitalWrite(DESCE_ANT, LOW);
  digitalWrite(SOBE_PWM, HIGH); digitalWrite(SOBE_ANT, HIGH); digitalWrite(LED_BUILTIN, HIGH);
  delay(TEMPO);
  tudoParado(); delay(3000);
}
