# Testar o sensor de feixe e o motor do saco, sem o jogo

Todo o código do Arduino desta máquina fica em **uma pasta só**:
`ARDUINO_SENSOR_DE_FEIXE_LM393`.

| Arquivo | Para que serve |
| --- | --- |
| `ARDUINO_SENSOR_DE_FEIXE_LM393.ino` | **O firmware do jogo**: sensor de feixe, botões, fitas de LED, ponte H do motor do saco e fins de curso. É este que fica gravado na máquina. |
| `TESTE_FEIXE/TESTE_FEIXE.ino` | Teste do sensor de feixe sem o jogo. |
| `TESTE_PONTE_H/TESTE_PONTE_H.ino` | Teste da ponte H (sobe/desce o saco, com velocidade) e do sensor IR de cima, sem o jogo. |

Os testes ficam em subpastas de propósito: a IDE do Arduino só junta ao
firmware os `.ino` que estão na pasta dele, nunca os das subpastas.

## Teste do feixe

1. Na IDE do Arduino, abra `TESTE_FEIXE/TESTE_FEIXE.ino` e grave
   (Placa: Arduino Uno ou Nano). Ligue com a fenda livre.
2. Abra o **Monitor Serial** em **115200**.
3. Passe um cartão na fenda: a linha tem de mudar de `LIVRE` para
   `CORTADO` e voltar. Se não muda, gire o trimpot do módulo até o LED
   dele mudar com o cartão, e confira o fio **DO no D4**.
4. Dê um soco: aparece `BLOQUEIO de X ms -> Y m/s`. Soco forte de
   verdade dá de 3 a 10 ms. Se der 20 ms ou mais, o sensor é lento demais
   (LDR com laser): use sensor de fenda ou infravermelho.

## Teste da ponte H, da velocidade e do fim de curso

1. Abra `TESTE_PONTE_H/TESTE_PONTE_H.ino` e grave.
2. Abra o **Monitor Serial** em **115200**, com **Nova linha**.
3. A cada segundo aparece o estado do sensor de cima e as velocidades. Ponha a mão (ou o
   alvo branco) na frente do sensor de cima: tem de mudar para `ACIONADO`
   e o LED OBS do sensor acende. Se não mudar, gire o trimpot do sensor e
   confira o OUT no D11 e o resistor de 100k do D11 ao GND
   (`docs/MONTAGEM_5_SENSOR_FIM_DE_CURSO_IR.png`).
4. Com o saco no meio, digite `s` e Enter: o saco **sobe** e para quando
   o sensor de cima vê o alvo. Se ele descer, inverta M+ e M− na ponte H (não
   mexa no D9/D10).
5. `d` desce, `p` para na hora, `t` mostra quanto tempo o último curso
   levou: no jogo, use esse tempo **+ 10%** em TEMPO DE CURSO (aba SACO).
6. **Velocidade:** `v80` muda a subida para 80%, `w60` a descida para 60%
   (de 20 a 100). Ache o valor que sobe firme sem dar tranco no topo e
   ponha os mesmos números na Central, aba SACO, **VELOCIDADE DO MOTOR**.

## Depois do teste

Grave de novo o `ARDUINO_SENSOR_DE_FEIXE_LM393.ino`. Os testes não
falam com o jogo.
