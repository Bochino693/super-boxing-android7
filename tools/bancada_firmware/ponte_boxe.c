// PONTE: firmware V9 de verdade (simavr, ATmega328P 16 MHz) <-> jogo (TCP).
// Roda em TEMPO REAL. Modelo fisico do saco: posicao 0 = enrolado em cima,
// 1 = embaixo. O sensor IR de cima (D11/PB3) ve o saco (nivel 0) quando a
// posicao esta no topo. Linhas "@@..." do jogo sao comandos da bancada
// (apertar START, socar), nao vao para o Nano.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <simavr/sim_avr.h>
#include <simavr/sim_elf.h>
#include <simavr/avr_uart.h>
#include <simavr/avr_ioport.h>

static avr_t *avr;
static int cli = -1;
static char fila[65536]; static int fi = 0, ff = 0;
static avr_irq_t *uart_in;
static char linha_nano[512]; static int nl = 0;
static double t0;
static double agora(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static double tsim(void) { return avr->cycle / 16e6; }

static void uart_out(struct avr_irq_t *irq, uint32_t v, void *p) {
    char c = (char)v;
    if (cli >= 0) { if (send(cli, &c, 1, MSG_NOSIGNAL) < 0) {} }
    if (c == '\n') { linha_nano[nl] = 0; if (strncmp(linha_nano, "MOTOR,", 6) && strncmp(linha_nano, "FIM,", 4)) printf("[%7.2f] NANO> %s\n", tsim(), linha_nano); nl = 0; }
    else if (c != '\r' && nl < 500) linha_nano[nl++] = c;
}
static avr_cycle_count_t enviar(avr_t *a, avr_cycle_count_t q, void *p) {
    if (fi < ff) avr_raise_irq(uart_in, (uint8_t)fila[fi++]);
    if (fi == ff) fi = ff = 0;
    return q + 1389;
}
static avr_irq_t *pin(char porta, int bit) { return avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ(porta), bit); }
static uint8_t ext_mask[3], ext_val[3];
static void segura(char porta, int bit, int v) {
    int i = porta - 'B';
    ext_mask[i] |= 1 << bit;
    if (v) ext_val[i] |= 1 << bit; else ext_val[i] &= ~(1 << bit);
    avr_ioport_external_t e = { .name = porta, .mask = ext_mask[i], .value = ext_val[i] };
    avr_ioctl(avr, AVR_IOCTL_IOPORT_SET_EXTERNAL(porta), &e);
    avr_raise_irq(pin(porta, bit), v);
}
static int pb(int b) { return (avr->data[0x25] >> b) & 1; }
static int pd(int b) { return (avr->data[0x2B] >> b) & 1; }
static int desce_on(void) { return ((avr->data[0x80] >> 7) & 1) || pd(7); }   // D9 PWM ou D7
static int sobe_on(void) { return ((avr->data[0x80] >> 5) & 1) || pb(0); }    // D10 PWM ou D8

// eventos agendados (tempo simulado)
typedef struct { double t; int tipo; int arg; } Ev;   // tipo 1 START, 2 soco(arg ms), 3 credito
static Ev evs[256]; static int nev = 0;
static void agenda(double t, int tipo, int arg) { if (nev < 256) evs[nev++] = (Ev){t, tipo, arg}; }

int main(int argc, char **argv) {
    elf_firmware_t fw;
    if (argc < 3 || elf_read_firmware(argv[1], &fw) != 0) { printf("uso: ponte v9.elf PORTA\n"); return 1; }
    int porta_tcp = atoi(argv[2]);
    double curso_desce = getenv("CURSO_DESCE") ? atof(getenv("CURSO_DESCE")) : 2.6;  // s para descer tudo
    double curso_sobe = getenv("CURSO_SOBE") ? atof(getenv("CURSO_SOBE")) : 2.2;
    double pos = getenv("POS_INICIAL") ? atof(getenv("POS_INICIAL")) : 1.0;          // comeca EMBAIXO
    setvbuf(stdout, NULL, _IOLBF, 0);
    avr = avr_make_mcu_by_name("atmega328p"); avr_init(avr); avr->frequency = 16000000;
    avr_load_firmware(avr, &fw);
    uint32_t f = 0; avr_ioctl(avr, AVR_IOCTL_UART_GET_FLAGS('0'), &f); f &= ~AVR_UART_FLAG_STDIO; avr_ioctl(avr, AVR_IOCTL_UART_SET_FLAGS('0'), &f);
    avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_OUTPUT), uart_out, NULL);
    uart_in = avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_INPUT);
    avr_cycle_timer_register(avr, 1389, enviar, NULL);
    segura('D', 2, 1); segura('D', 3, 1); segura('B', 4, 1);   // botoes soltos
    segura('D', 4, 0);                                          // feixe livre
    segura('B', 3, pos <= 0.02 ? 0 : 1);                        // sensor de cima

    int srv = socket(AF_INET, SOCK_STREAM, 0); int um = 1; setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &um, sizeof um);
    struct sockaddr_in ad = { .sin_family = AF_INET, .sin_port = htons(porta_tcp) }; ad.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(srv, (void *)&ad, sizeof ad) || listen(srv, 1)) { perror("tcp"); return 1; }
    fcntl(srv, F_SETFL, O_NONBLOCK);
    printf("PONTE pronta na porta %d (saco comeca %s)\n", porta_tcp, pos > 0.5 ? "EMBAIXO" : "EM CIMA");

    t0 = agora();
    char rx[512]; int nrx = 0;
    const char *est_ant = ""; double pos_log = -1; int sensor = pos <= 0.02 ? 0 : 1;
    double t_ultimo = 0;
    double fim_soco = -1; int segurando_start = 0; double solta_start = 0;
    while (1) {
        double alvo = agora() - t0;
        if (alvo > 3600) break;
        // anda o Nano ate o relogio de verdade, em passos de 1 ms (modelo fisico a cada passo)
        while (tsim() < alvo) {
            avr_cycle_count_t meta = avr->cycle + 16000;
            while (avr->cycle < meta) { int st = avr_run(avr); if (st == cpu_Done || st == cpu_Crashed) { printf("CPU PAROU\n"); return 2; } }
            double dt = 0.001;
            int d = desce_on(), s = sobe_on();
            if (d && !s) pos += dt / curso_desce;
            if (s && !d) pos -= dt / curso_sobe;
            if (pos < 0) pos = 0; if (pos > 1) pos = 1;
            int sens = pos <= 0.02 ? 0 : 1;
            if (sens != sensor) { sensor = sens; segura('B', 3, sens); printf("[%7.2f] SENSOR DE CIMA: %s\n", tsim(), sens ? "livre" : "VE O SACO"); }
            const char *est = (d && s) ? "CURTO!" : d ? "DESCENDO" : s ? "SUBINDO" : "parado";
            if (strcmp(est, est_ant)) { printf("[%7.2f] MOTOR %-8s posicao %3.0f%% %s\n", tsim(), est, pos * 100, pos <= 0.02 ? "(EM CIMA, enrolado)" : pos >= 0.98 ? "(EMBAIXO)" : "(no meio)"); est_ant = est; pos_log = pos; }
            // eventos
            double t = tsim();
            for (int i = 0; i < nev; i++) if (evs[i].t >= 0 && t >= evs[i].t) {
                if (evs[i].tipo == 1) { segura('D', 2, 0); segurando_start = 1; solta_start = t + 0.12; printf("[%7.2f] BANCADA: aperta START\n", t); }
                if (evs[i].tipo == 3) { segura('D', 3, 0); printf("[%7.2f] BANCADA: ficha\n", t); evs[i].tipo = 4; evs[i].t = t + 0.12; continue; }
                if (evs[i].tipo == 4) { segura('D', 3, 1); }
                if (evs[i].tipo == 2) { segura('D', 4, 1); fim_soco = t + evs[i].arg / 1000.0; printf("[%7.2f] BANCADA: soco (feixe %d ms) - saco em %.0f%%\n", t, evs[i].arg, pos * 100); }
                evs[i].t = -1;
            }
            if (segurando_start && t >= solta_start) { segura('D', 2, 1); segurando_start = 0; }
            if (fim_soco > 0 && t >= fim_soco) { segura('D', 4, 0); fim_soco = -1; }
        }
        // rede
        if (cli < 0) {
            int c = accept(srv, NULL, NULL);
            if (c >= 0) { cli = c; fcntl(cli, F_SETFL, O_NONBLOCK); printf("[%7.2f] JOGO CONECTOU\n", tsim()); }
        } else {
            char b[256]; int n = recv(cli, b, sizeof b, 0);
            if (n == 0) { printf("[%7.2f] JOGO DESCONECTOU\n", tsim()); close(cli); cli = -1; }
            for (int i = 0; i < n; i++) {
                if (b[i] == '\n') {
                    rx[nrx] = 0;
                    if (!strncmp(rx, "@@", 2)) {
                        double t = tsim();
                        if (!strcmp(rx, "@@START")) agenda(t, 1, 0);
                        else if (!strcmp(rx, "@@FICHA")) agenda(t, 3, 0);
                        else if (!strncmp(rx, "@@SOCO", 6)) agenda(t, 2, atoi(rx + 7) > 0 ? atoi(rx + 7) : 6);
                        else if (!strcmp(rx, "@@FIM")) { printf("[%7.2f] FIM DA BANCADA. saco em %.0f%%\n", t, pos * 100); return 0; }
                    } else {
                        printf("[%7.2f] JOGO> %s\n", tsim(), rx);
                        int k = strlen(rx); if (ff + k + 1 < (int)sizeof fila) { memcpy(fila + ff, rx, k); ff += k; fila[ff++] = '\n'; }
                    }
                    nrx = 0;
                } else if (b[i] != '\r' && nrx < 500) rx[nrx++] = b[i];
            }
        }
        usleep(500);
    }
    return 0;
}
