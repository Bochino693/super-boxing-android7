// Banco do V10 SEM SENSOR: so tempo. Modelo: corda para fora em fracao do
// curso (0 topo, 1 embaixo), SEM limites (passar de 1 ou de 0 = erro).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <simavr/sim_avr.h>
#include <simavr/sim_elf.h>
#include <simavr/avr_uart.h>
#include <simavr/avr_ioport.h>
#include <simavr/avr_eeprom.h>
static avr_t *avr; static elf_firmware_t fw;
static char saida[65536]; static int ns = 0;
static char fila[4096]; static int fi = 0, ff = 0;
static avr_irq_t *uart_in;
static double pos = 0, pmin = 0, pmax = 0;
static double T_DESCE = 3.0, T_SOBE = 2.5;    // a maquina "de verdade"
static int falhas = 0;
static uint8_t ee[1024];
static void uo(struct avr_irq_t *i, uint32_t v, void *p) { if (ns < 65000) saida[ns++] = v; saida[ns] = 0; }
static avr_cycle_count_t env(avr_t *a, avr_cycle_count_t q, void *p) { if (fi < ff) avr_raise_irq(uart_in, fila[fi++]); if (fi == ff) fi = ff = 0; return q + 1389; }
static avr_irq_t *pin(char po, int b) { return avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ(po), b); }
static int pb(int b) { return (avr->data[0x25] >> b) & 1; } static int pd(int b) { return (avr->data[0x2B] >> b) & 1; }
static int desce(void) { return ((avr->data[0x80] >> 7) & 1) || pd(7); } static int sobe(void) { return ((avr->data[0x80] >> 5) & 1) || pb(0); }
static void rodar(double ms) {
  for (double t = 0; t < ms; t += 1) {
    avr_cycle_count_t meta = avr->cycle + 16000;
    while (avr->cycle < meta) { int st = avr_run(avr); if (st == cpu_Done || st == cpu_Crashed) { printf("CPU PAROU\n"); exit(2); } }
    int d = desce(), s = sobe();
    if (d && s) { printf("CURTO: as duas saidas ligadas!\n"); falhas++; }
    if (d && !s) pos += 0.001 / T_DESCE;
    if (s && !d) pos -= 0.001 / T_SOBE;
    if (pos < pmin) pmin = pos; if (pos > pmax) pmax = pos;
  }
}
static void manda(const char *s) { int n = strlen(s); memcpy(fila + ff, s, n); ff += n; }
static void ok(int c, const char *m) { printf("%s  %s  [saco %.1f%%, min %.1f%%, max %.1f%%]\n", c ? "OK   " : "FALHA", m, pos * 100, pmin * 100, pmax * 100); if (!c) falhas++; }
static int tem(const char *s) { return strstr(saida, s) != NULL; }
static void limpa(void) { ns = 0; saida[0] = 0; }
static int parado(void) { return !desce() && !sobe(); }
static int ultimo_saco(void) { char *p = saida, *u = NULL; while ((p = strstr(p, "SACO,"))) { u = p; p += 5; } return u ? atoi(u + 5) : -1; }
static void ligar(int com_eeprom) {
  fi = ff = 0; limpa();
  avr = avr_make_mcu_by_name("atmega328p"); avr_init(avr); avr->frequency = 16000000; avr_load_firmware(avr, &fw);
  if (com_eeprom) { avr_eeprom_desc_t d = { .ee = ee, .offset = 0, .size = 1024 }; avr_ioctl(avr, AVR_IOCTL_EEPROM_SET, &d); }
  uint32_t f = 0; avr_ioctl(avr, AVR_IOCTL_UART_GET_FLAGS('0'), &f); f &= ~AVR_UART_FLAG_STDIO; avr_ioctl(avr, AVR_IOCTL_UART_SET_FLAGS('0'), &f);
  avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_OUTPUT), uo, NULL);
  uart_in = avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_INPUT); avr_cycle_timer_register(avr, 1389, env, NULL);
  avr_raise_irq(pin('D', 2), 1); avr_raise_irq(pin('D', 3), 1); avr_raise_irq(pin('B', 4), 1);
}
static void desligar(void) { avr_eeprom_desc_t d = { .ee = ee, .offset = 0, .size = 1024 }; avr_ioctl(avr, AVR_IOCTL_EEPROM_GET, &d); memcpy(ee, d.ee, 1024); }
int main(int argc, char **argv) {
  if (elf_read_firmware(argv[1], &fw)) return 1;
  setvbuf(stdout, NULL, _IOLBF, 0);
  printf("== 1. primeira vez com o V10 (saco enrolado em cima)\n");
  ligar(0); rodar(4000);
  ok(tem("READY,PUNCH_OPTICAL,V10") && parado() && pos == 0, "READY V10, conta o saco em cima e nao mexe");
  ok(!tem("FIM,") && !tem("SENSOR_CIMA"), "sem linhas de sensor (FIM / SENSOR_CIMA)");
  manda("MOTOR,CONFIG,3000,350,2500,80,60\n"); rodar(200);
  ok(tem("OK,MOTOR"), "CONFIG com descida 3,0 s e subida 2,5 s");
  printf("== 2. partida: desce, sobe\n");
  limpa(); manda("MOTOR,DESCE\n"); rodar(3300);
  ok(parado() && fabs(pos - 1) < 0.01 && tem("MOTOR,0,2") && ultimo_saco() == 1000, "desceu o curso inteiro em 3,0 s e parou EMBAIXO (SACO,1000)");
  limpa(); manda("MOTOR,SOBE\n"); rodar(2900);
  ok(parado() && fabs(pos) < 0.01 && tem("MOTOR,0,1") && ultimo_saco() == 0, "subiu o INVERSO (2,5 s) e voltou EM CIMA (SACO,0)");
  printf("== 3. inverter no meio\n");
  limpa(); manda("MOTOR,DESCE\n"); rodar(1200); manda("MOTOR,SOBE\n"); rodar(3000);
  ok(parado() && fabs(pos) < 0.01, "desceu 1,2 s, subiu so o que desceu: em cima de novo");
  limpa(); manda("MOTOR,DESCE\n"); rodar(3300); manda("MOTOR,SOBE\n"); rodar(1000); manda("MOTOR,DESCE\n"); rodar(3000);
  ok(parado() && fabs(pos - 1) < 0.01 && pmax < 1.01, "embaixo, subiu 1 s, desceu de novo: so o que faltava (nao desenrola demais)");
  manda("MOTOR,SOBE\n"); rodar(3000);
  printf("== 4. 20 partidas seguidas com interrupcoes\n");
  srand(7); pmin = pmax = pos;
  for (int k = 0; k < 20; k++) {
    manda("MOTOR,DESCE\n"); rodar(200 + rand() % 3500);
    if (rand() % 3 == 0) { manda("MOTOR,PARA\n"); rodar(300); }
    manda("MOTOR,SOBE\n"); rodar(3200);
  }
  ok(parado() && fabs(pos) < 0.01 && pmin > -0.01 && pmax < 1.01, "20 ciclos: sempre volta ao topo, nunca passa dos limites");
  printf("== 5b. faltou luz no meio da SUBIDA (o pior caso: nao pode forcar o topo)\n");
  manda("MOTOR,DESCE\n"); rodar(3300); limpa(); manda("MOTOR,SOBE\n"); rodar(1900); desligar();
  printf("      (saco em %.0f%% quando a luz caiu)\n", pos * 100);
  ligar(1); pmin = pmax = pos; rodar(5000);
  ok(parado() && pmin > -0.001 && pos < 0.05, "religou e subiu o resto SEM passar do topo");
  pos = 0; manda("MOTOR,ZERA\n"); rodar(100);
  printf("== 5. faltou luz no meio da descida\n");
  limpa(); manda("MOTOR,DESCE\n"); rodar(1700); double antes = pos; desligar();
  printf("      (saco em %.0f%% quando a luz caiu)\n", antes * 100);
  ligar(1); pmin = pmax = pos; rodar(1300);
  ok(parado() && !tem("MOTOR,2"), "liga de novo e espera 1,5 s");
  rodar(3500);
  ok(parado() && pos < 0.05 && pmin > -0.001, "sobe sozinho o que a EEPROM lembrava: volta ao topo sem passar dele (erro max. 0,1 s)");
  printf("== 6. ZERA e AJUSTE (alinhar a mao)\n");
  pos = 0.15; limpa(); manda("MOTOR,AJUSTE,SOBE\n"); rodar(600);
  ok(parado() && pos < 0.08 && pos > 0.06 && tem("OK,AJUSTE") && !tem("SACO,-") && !tem("MOTOR,2"), "AJUSTE,SOBE: um toque de 0,2 s (8%) sem mexer na contagem");
  pos = 0.0; limpa(); manda("MOTOR,ZERA\n"); rodar(100);
  ok(tem("OK,ZERA") && ultimo_saco() == 0, "ZERA: a contagem volta a zero (em cima)");
  printf("== 7. jogo antigo (CONFIG com 3 campos)\n");
  limpa(); manda("MOTOR,CONFIG,3000,350,1\n"); rodar(100); manda("MOTOR,DESCE\n"); rodar(3300); T_SOBE = 3.0; manda("MOTOR,SOBE\n"); rodar(3300);
  ok(parado() && fabs(pos) < 0.01, "subida = descida quando o jogo nao manda o tempo de subida");
  T_SOBE = 2.5; manda("MOTOR,CONFIG,3000,350,2500,80,60\n"); rodar(100);
  printf("== 8. TESTE da ligacao\n");
  limpa(); double p0 = pos; manda("MOTOR,TESTE\n"); rodar(4500);
  ok(parado() && tem("TESTE,FIM") && fabs(pos - p0) < 0.01, "desce 1,5 s e sobe o inverso: o saco volta onde estava");
  printf("== 9. feixe surdo com o motor andando\n");
  limpa(); manda("ARM\n"); rodar(50); manda("MOTOR,DESCE\n"); rodar(500);
  avr_raise_irq(pin('D', 4), 1); rodar(6); avr_raise_irq(pin('D', 4), 0); rodar(100);
  ok(!tem("HIT,"), "palheta com o motor descendo: ignorada");
  rodar(3000); manda("MOTOR,SOBE\n"); rodar(3000);
  printf("\n%s: %d falha(s)\n", falhas ? "REPROVADO" : "APROVADO", falhas);
  return falhas != 0;
}
