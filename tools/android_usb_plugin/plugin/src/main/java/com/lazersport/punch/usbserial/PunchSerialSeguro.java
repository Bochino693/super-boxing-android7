package com.lazersport.punch.usbserial;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.os.Build;
import android.os.SystemClock;

import com.hoho.android.usbserial.driver.UsbSerialDriver;
import com.hoho.android.usbserial.driver.UsbSerialPort;
import com.hoho.android.usbserial.driver.UsbSerialProber;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.nio.charset.Charset;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * ARDUINO DO SACO E DO SENSOR - USB SERIAL SEM O CRASH NATIVO.
 *
 * O plugin PunchUsbSerial (Kotlin) lia a porta com o SerialInputOutputManager
 * da biblioteca, que espera os dados com UsbDeviceConnection.requestWait()
 * SEM tempo limite, numa thread propria. Ao fechar a porta (o jogo fecha e
 * reabre quando o Arduino some - e o tranco do motor reinicia a USB do Nano)
 * a conexao era fechada com essa thread ainda presa dentro do requestWait.
 * No Android 7 isso derruba o processo inteiro:
 *     Fatal signal 11 (SIGSEGV) ... libusbhost.so (usb_request_wait)
 * - era o "o jogo parou" do Super Boxing. O mesmo erro foi corrigido no
 * Dragon Bowling (build 5), com esta mesma forma de ler.
 *
 * AQUI:
 *  - a leitura usa read() com tempo limite (LEITURA_MS = bulkTransfer): a
 *    thread nunca fica presa mais que isso;
 *  - fechar PRIMEIRO para a leitura e ESPERA a thread sair; so depois fecha
 *    a conexao. Se a thread demorar, ela mesma fecha ao sair - nunca as duas
 *    ao mesmo tempo;
 *  - escrita e fechamento passam pela mesma trava;
 *  - nenhuma excecao escapa de uma thread.
 *
 * E um segundo plugin do mesmo .aar ("PunchSerialSeguro"); a camera continua
 * no PunchUsbSerial. As funcoes tem os mesmos nomes que o jogo ja usa.
 */
public class PunchSerialSeguro extends GodotPlugin {

    private static final int LEITURA_MS = 200;
    private static final int ESPERA_LEITURA_MS = 1500;
    private static final int ESCRITA_MS = 250;
    private static final int MAX_LINHAS = 128;
    private static final int FLAG_MUTABLE = 0x02000000;      // PendingIntent.FLAG_MUTABLE (API 31)
    private static final int RECEIVER_NOT_EXPORTED = 4;      // Context.RECEIVER_NOT_EXPORTED (API 33)
    private static final String ACAO_PERMISSAO = "com.lazersport.punch.SERIAL_PERMISSION";
    private static final Charset ASCII = Charset.forName("US-ASCII");

    private final Object linhasLock = new Object();
    private final ArrayDeque<String> linhas = new ArrayDeque<String>();
    private final StringBuilder parcial = new StringBuilder();
    /** Escrita e fechamento nunca ao mesmo tempo. */
    private final Object ioLock = new Object();
    private final ExecutorService escritor = Executors.newSingleThreadExecutor();
    private final ExecutorService varredor = Executors.newSingleThreadExecutor();
    private final AtomicBoolean varrendo = new AtomicBoolean(false);
    private final Set<Integer> permissaoPedida = Collections.synchronizedSet(new HashSet<Integer>());

    private volatile UsbSerialPort porta;
    private volatile Leitor leitor;
    private volatile String erro = "";
    private volatile List<UsbSerialDriver> driversEmCache = new ArrayList<UsbSerialDriver>();
    private volatile String portasEmCache = "";
    private volatile long varridoEm = 0L;
    private volatile long janelaAbertaDesde = 0L;
    private boolean receptorLigado = false;
    private UsbManager usbManager;

    private final BroadcastReceiver receptor = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent != null && ACAO_PERMISSAO.equals(intent.getAction())) {
                janelaAbertaDesde = 0L;
                varridoEm = 0L;
            }
        }
    };

    public PunchSerialSeguro(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PunchSerialSeguro";
    }

    // ------------------------------------------------------------ leitura

    /** Uma thread por porta aberta. Le com tempo limite e sai sozinha. */
    private final class Leitor extends Thread {
        final UsbSerialPort alvo;
        volatile boolean rodando = true;
        volatile boolean caiu = false;
        /** O fechamento desistiu de esperar: quem fecha a porta e o leitor. */
        volatile boolean fecharAoSair = false;

        Leitor(UsbSerialPort alvo) {
            super("PunchSerialLeitura");
            this.alvo = alvo;
            setDaemon(true);
        }

        @Override
        public void run() {
            byte[] buf = new byte[256];
            try {
                while (rodando) {
                    int n = alvo.read(buf, LEITURA_MS);
                    if (n > 0) receber(buf, n);
                }
            } catch (Throwable t) {
                if (rodando) {
                    erro = "USB desconectada: " + mensagem(t);
                    caiu = true;
                }
            } finally {
                if (fecharAoSair) fecharConexao(alvo);
            }
        }
    }

    private void receber(byte[] dados, int n) {
        synchronized (linhasLock) {
            for (int i = 0; i < n; i++) {
                char c = (char) (dados[i] & 0xff);
                if (c == '\n') {
                    String linha = parcial.toString();
                    if (linha.endsWith("\r")) linha = linha.substring(0, linha.length() - 1);
                    parcial.setLength(0);
                    if (linha.length() > 0) {
                        if (linhas.size() >= MAX_LINHAS) linhas.removeFirst();
                        linhas.addLast(linha);
                    }
                } else if (parcial.length() < 200) {
                    parcial.append(c);
                } else {
                    parcial.setLength(0);
                }
            }
        }
    }

    // ------------------------------------------------------------ portas

    private UsbManager usb() {
        if (usbManager == null) {
            Activity a = getActivity();
            if (a != null) usbManager = (UsbManager) a.getSystemService(Context.USB_SERVICE);
        }
        return usbManager;
    }

    private static String chave(UsbSerialDriver d) {
        UsbDevice dev = d.getDevice();
        return String.format(Locale.US, "usb:%04X:%04X:%d", dev.getVendorId(), dev.getProductId(), dev.getDeviceId());
    }

    private List<UsbSerialDriver> varrer() {
        UsbManager m = usb();
        if (m == null) return new ArrayList<UsbSerialDriver>();
        List<UsbSerialDriver> lista = UsbSerialProber.getDefaultProber().findAllDrivers(m);
        StringBuilder sb = new StringBuilder();
        for (UsbSerialDriver d : lista) {
            if (sb.length() > 0) sb.append('\n');
            sb.append(chave(d));
        }
        driversEmCache = lista;
        portasEmCache = sb.toString();
        varridoEm = SystemClock.elapsedRealtime();
        return lista;
    }

    /** Renova a lista numa thread propria: o quadro do jogo nunca espera a USB. */
    private void renovarLista(boolean forcar) {
        if (!forcar && SystemClock.elapsedRealtime() - varridoEm < 1200L) return;
        if (!varrendo.compareAndSet(false, true)) return;
        try {
            varredor.execute(new Runnable() {
                @Override
                public void run() {
                    try {
                        varrer();
                    } catch (Throwable t) {
                        erro = "Falha ao listar USB: " + mensagem(t);
                    } finally {
                        varrendo.set(false);
                    }
                }
            });
        } catch (Throwable t) {
            varrendo.set(false);
        }
    }

    @UsedByGodot
    public int getApiVersion() {
        return 3;
    }

    @UsedByGodot
    public String listPorts() {
        renovarLista(false);
        return portasEmCache;
    }

    @UsedByGodot
    public void allowPermissionRetry() {
        permissaoPedida.clear();
        janelaAbertaDesde = 0L;
    }

    /** Verdadeiro enquanto a janela de permissao USB esta aberta (ate 60 s). */
    @UsedByGodot
    public boolean usbPermissionPending() {
        long desde = janelaAbertaDesde;
        return desde != 0L && SystemClock.elapsedRealtime() - desde < 60000L;
    }

    private void ligarReceptor(Activity host) {
        if (receptorLigado) return;
        try {
            IntentFilter filtro = new IntentFilter(ACAO_PERMISSAO);
            Context ctx = host.getApplicationContext();
            if (Build.VERSION.SDK_INT >= 33) {
                Context.class.getMethod("registerReceiver", BroadcastReceiver.class, IntentFilter.class, int.class)
                        .invoke(ctx, receptor, filtro, RECEIVER_NOT_EXPORTED);
            } else {
                ctx.registerReceiver(receptor, filtro);
            }
            receptorLigado = true;
        } catch (Throwable ignorado) {
        }
    }

    @UsedByGodot
    public boolean openPort(String chavePorta, int baud) {
        fecharPorta();
        UsbDeviceConnection conexao = null;
        UsbSerialPort candidata = null;
        try {
            UsbSerialDriver driver = null;
            for (UsbSerialDriver d : driversEmCache) {
                if (chave(d).equals(chavePorta)) { driver = d; break; }
            }
            if (driver == null) {
                for (UsbSerialDriver d : varrer()) {
                    if (chave(d).equals(chavePorta)) { driver = d; break; }
                }
            }
            if (driver == null) return falhar("dispositivo USB nao esta mais conectado");
            final UsbDevice dev = driver.getDevice();
            final UsbManager m = usb();
            if (m == null) return falhar("tela Android ainda nao esta disponivel");
            if (!m.hasPermission(dev)) {
                // UMA janela por aparelho e por execucao, nunca com outra aberta.
                if (!usbPermissionPending() && permissaoPedida.add(dev.getDeviceId())) {
                    final Activity host = getActivity();
                    if (host == null) return falhar("tela Android ainda nao esta disponivel");
                    ligarReceptor(host);
                    janelaAbertaDesde = SystemClock.elapsedRealtime();
                    host.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                Intent intent = new Intent(ACAO_PERMISSAO).setPackage(host.getPackageName());
                                int flags = PendingIntent.FLAG_UPDATE_CURRENT | FLAG_MUTABLE;
                                m.requestPermission(dev, PendingIntent.getBroadcast(host, dev.getDeviceId(), intent, flags));
                            } catch (Throwable t) {
                                janelaAbertaDesde = 0L;
                            }
                        }
                    });
                }
                return falhar("autorize o Arduino: marque a caixa da janela e toque OK (so na 1a vez)");
            }
            permissaoPedida.remove(dev.getDeviceId());
            List<UsbSerialPort> portas = driver.getPorts();
            if (portas == null || portas.isEmpty()) return falhar("adaptador USB serial nao possui porta");
            conexao = m.openDevice(dev);
            if (conexao == null) return falhar("Android recusou a abertura do dispositivo USB");
            candidata = portas.get(0);
            candidata.open(conexao);
            candidata.setParameters(baud, UsbSerialPort.DATABITS_8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE);
            try { candidata.setDTR(true); } catch (Throwable ignorado) { }
            try { candidata.setRTS(true); } catch (Throwable ignorado) { }
            Leitor novo = new Leitor(candidata);
            porta = candidata;
            leitor = novo;
            novo.start();
            erro = "";
            return true;
        } catch (Throwable t) {
            // Nenhuma leitura comecou nesta porta: fechar aqui e seguro.
            porta = null;
            leitor = null;
            if (candidata != null) fecharConexao(candidata);
            else if (conexao != null) try { conexao.close(); } catch (Throwable ignorado) { }
            renovarLista(true);
            return falhar("falha ao abrir USB serial: " + mensagem(t));
        }
    }

    private boolean falhar(String msg) {
        erro = msg;
        return false;
    }

    @UsedByGodot
    public void closePort() {
        fecharPorta();
    }

    /** Para a leitura, espera a thread sair e so entao fecha a conexao. */
    private void fecharPorta() {
        UsbSerialPort p = porta;
        Leitor l = leitor;
        porta = null;
        leitor = null;
        if (l != null) {
            l.rodando = false;
            if (l != Thread.currentThread()) {
                try {
                    l.join(ESPERA_LEITURA_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            if (l.isAlive()) {
                // Ainda dentro de uma leitura: ela fecha a porta ao sair.
                l.fecharAoSair = true;
                if (!l.isAlive()) fecharConexao(l.alvo);
                p = null;
            }
        }
        if (p != null) fecharConexao(p);
        synchronized (linhasLock) {
            linhas.clear();
            parcial.setLength(0);
        }
    }

    private void fecharConexao(UsbSerialPort p) {
        synchronized (ioLock) {
            try {
                if (p.isOpen()) p.close();
            } catch (Throwable ignorado) { }
        }
    }

    /** Aberta e lendo. A leitura caiu (Arduino reiniciou/saiu): fechada. */
    @UsedByGodot
    public boolean isOpen() {
        Leitor l = leitor;
        return porta != null && l != null && !l.caiu && l.isAlive();
    }

    @UsedByGodot
    public boolean writeLine(String linha) {
        final UsbSerialPort alvo = porta;
        if (alvo == null) return falhar("USB serial fechada");
        if (linha == null || linha.length() > 120) return falhar("comando serial longo");
        String limpa = linha;
        while (limpa.length() > 0 && Character.isWhitespace(limpa.charAt(limpa.length() - 1))) {
            limpa = limpa.substring(0, limpa.length() - 1);
        }
        final byte[] dados = (limpa + "\n").getBytes(ASCII);
        try {
            escritor.execute(new Runnable() {
                @Override
                public void run() {
                    synchronized (ioLock) {
                        if (porta != alvo) return;   // fechada/trocada enquanto esperava
                        try {
                            alvo.write(dados, ESCRITA_MS);
                        } catch (Throwable t) {
                            erro = "falha ao escrever na USB: " + mensagem(t);
                        }
                    }
                }
            });
        } catch (Throwable t) {
            return falhar("fila de escrita indisponivel");
        }
        return true;
    }

    @UsedByGodot
    public String pollLines() {
        synchronized (linhasLock) {
            if (linhas.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            while (!linhas.isEmpty()) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(linhas.removeFirst());
            }
            return sb.toString();
        }
    }

    @UsedByGodot
    public String getLastError() {
        return erro;
    }

    /** SAIR SEM TRAVAR: a porta e solta em segundo plano. */
    @UsedByGodot
    public void shutdown() {
        try {
            varredor.execute(new Runnable() {
                @Override
                public void run() {
                    fecharPorta();
                }
            });
        } catch (Throwable ignorado) { }
    }

    @Override
    public void onMainDestroy() {
        fecharPorta();
        if (receptorLigado) {
            try {
                Activity a = getActivity();
                if (a != null) a.getApplicationContext().unregisterReceiver(receptor);
            } catch (Throwable ignorado) { }
            receptorLigado = false;
        }
        super.onMainDestroy();
    }

    private static String mensagem(Throwable t) {
        String m = t.getMessage();
        return m != null ? m : t.getClass().getSimpleName();
    }
}
