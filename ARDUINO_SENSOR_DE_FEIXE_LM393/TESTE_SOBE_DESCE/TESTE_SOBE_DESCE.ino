/*
  TESTE SOBE / DESCE - SEM JOGO, SEM SERIAL, SEM SENSOR (mesmos pinos do V11).
  Grave, ligue a fonte do motor e OLHE O SACO. Em laco, para sempre:
    DESCE 2 s (D9 em 5V)  ->  para 1 s  ->  SOBE 2 s (D10 em 5V)  ->  para 3 s
  O LED "L" do Nano fica ACESO enquanto o motor deve andar.

  LIGACAO (docs\MONTAGEM_DEFINITIVA_V11.png):
    D9  -> RPWM (pino 1 do IBT-2)  = DESCER
    D10 -> LPWM (pino 2 do IBT-2)  = SUBIR
    5V  -> R_EN (3), L_EN (4) e VCC (7)      GND -> GND (8)
    R_IS (5) e L_IS (6): sem ligacao.

  O QUE O RESULTADO DIZ:
  - Desce E sobe: tudo certo. Grave o ARDUINO_SENSOR_DE_FEIXE_LM393.ino (V11).
  - Desce quando devia subir (e vice-versa): troque M+ com M- no borne verde.
  - So UM sentido anda: o fio do outro sentido (D9->RPWM ou D10->LPWM) nao
    chega, ou R_EN/L_EN nao estao no 5V. Fio certo e ainda so um sentido: a
    ponte H esta com defeito (troque a placa).
  - Nao mexe nada: fonte do motor (B+/B-), VCC/R_EN/L_EN sem 5V, GND solto.
*/
const int DESCER = 9;    // RPWM
const int SUBIR = 10;    // LPWM
const unsigned long TEMPO = 2000;

void parado() {
  digitalWrite(DESCER, LOW); digitalWrite(SUBIR, LOW); digitalWrite(LED_BUILTIN, LOW);
}

void setup() {
  digitalWrite(DESCER, LOW); digitalWrite(SUBIR, LOW);
  pinMode(DESCER, OUTPUT); pinMode(SUBIR, OUTPUT); pinMode(LED_BUILTIN, OUTPUT);
  parado();
  delay(1500);
}

void loop() {
  digitalWrite(SUBIR, LOW); digitalWrite(DESCER, HIGH); digitalWrite(LED_BUILTIN, HIGH);
  delay(TEMPO);
  parado(); delay(1000);
  digitalWrite(DESCER, LOW); digitalWrite(SUBIR, HIGH); digitalWrite(LED_BUILTIN, HIGH);
  delay(TEMPO);
  parado(); delay(3000);
}
