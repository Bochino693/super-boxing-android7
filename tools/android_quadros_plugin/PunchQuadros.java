package com.lazersport.punch.quadros;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.InputStreamReader;
import java.lang.reflect.Method;
import java.util.ArrayList;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.ComponentCallbacks2;
import android.content.Context;
import android.content.res.Configuration;
import android.os.SystemClock;
import android.view.View;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.GodotPluginRegistry;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * A PONTE DOS QUADROS DA WEBCAM PARA O GODOT 3 — E A CAIXA-PRETA DA PLACA.
 *
 * 1. QUADROS. O plugin PunchUsbSerial entrega cada quadro como byte[]
 *    (pollUvcFrame). No Godot 3.6 esse retorno chega vazio (o JNISingleton
 *    nao converte byte[]); dentro de um Dictionary ele vira PoolByteArray.
 *    Fora da hora da foto o quadro vai em MEIA resolucao (320x240): 4x
 *    menos memoria copiada, menos conversao e menos textura na Mali-450.
 *
 * 2. MEMORIA. Numa TV Box de 1 GB, quando a memoria livre cai, o Android
 *    derruba primeiro o que esta em segundo plano — o launcher ("LongLauncher
 *    parou"). O jogo pergunta aqui quanta memoria o Android tem livre e
 *    quantas vezes ele avisou que estava apertado (onTrimMemory).
 *
 * 3. ERROS DA ABERTURA ANTERIOR. Na abertura, le o logcat do proprio jogo
 *    (o Android deixa cada app ler o seu) e guarda os erros da sessao
 *    anterior: o jogo mostra na tela, e basta uma foto — sem cabo, sem ADB.
 */
public class PunchQuadros extends GodotPlugin {
    private Object ponte;
    private Method poll;
    private Method largura;
    private Method altura;
    private Method meiaResolucao;

    /** Resolucao cheia so na janela da foto (o jogo liga e desliga). */
    private volatile boolean fotoCheia = false;
    private byte[] meio;

    private Context contexto;
    private volatile int avisoNivel = 0;
    private volatile long avisoEm = 0L;
    private volatile int avisosApertado = 0;
    private volatile int piorAviso = 0;
    private volatile String errosAnteriores = "";
    private volatile boolean errosProntos = false;

    public PunchQuadros(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PunchQuadros";
    }

    @Override
    public View onMainCreate(Activity activity) {
        try {
            contexto = activity.getApplicationContext();
            contexto.registerComponentCallbacks(new ComponentCallbacks2() {
                @Override
                public void onTrimMemory(int nivel) {
                    anotarAviso(nivel);
                }

                @Override
                public void onLowMemory() {
                    anotarAviso(ComponentCallbacks2.TRIM_MEMORY_COMPLETE);
                }

                @Override
                public void onConfigurationChanged(Configuration c) {
                }
            });
        } catch (Throwable t) {
            // sem avisos: o resto funciona igual
        }
        Thread leitor = new Thread(new Runnable() {
            @Override
            public void run() {
                lerErrosAnteriores();
            }
        }, "punch-logcat");
        leitor.setDaemon(true);
        leitor.start();
        return null;
    }

    private void anotarAviso(int nivel) {
        // TRIM_MEMORY_UI_HIDDEN (20) so diz que a tela saiu de cima; nao e aperto.
        if (nivel == ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN) {
            return;
        }
        avisoNivel = nivel;
        avisoEm = SystemClock.elapsedRealtime();
        if (nivel >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW) {
            avisosApertado++;
        }
        if (nivel > piorAviso) {
            piorAviso = nivel;
        }
    }

    // ------------------------------------------------------------------
    // 1. QUADROS
    // ------------------------------------------------------------------

    private boolean ligar() {
        if (poll != null) {
            return true;
        }
        try {
            GodotPlugin p = GodotPluginRegistry.getPluginRegistry().getPlugin("PunchUsbSerial");
            if (p == null) {
                return false;
            }
            Class<?> c = p.getClass();
            poll = c.getMethod("pollUvcFrame");
            largura = c.getMethod("getUvcFrameWidth");
            altura = c.getMethod("getUvcFrameHeight");
            try {
                meiaResolucao = c.getMethod("setUvcHalfResolution", boolean.class);
            } catch (Throwable semMeia) {
                meiaResolucao = null;
            }
            ponte = p;
            return true;
        } catch (Throwable t) {
            poll = null;
            return false;
        }
    }

    /** true na janela da foto (quadro cheio); false no resto (meia resolucao). */
    @UsedByGodot
    public void definirFotoCheia(boolean cheia) {
        fotoCheia = cheia;
    }

    /** O quadro mais novo: {"dados": bytes RGBA, "largura", "altura"} (vazio sem quadro novo). */
    @UsedByGodot
    public Dictionary pollQuadro() {
        Dictionary d = new Dictionary();
        if (!ligar()) {
            d.put("erro", "PunchUsbSerial ausente");
            return d;
        }
        try {
            byte[] b = (byte[]) poll.invoke(ponte);
            // O pollUvcFrame escolhe a resolucao da PROXIMA conversao pelo
            // ritmo das leituras; aqui ela fica presa: meia fora da foto.
            if (meiaResolucao != null) {
                meiaResolucao.invoke(ponte, Boolean.valueOf(!fotoCheia));
            }
            int w = ((Number) largura.invoke(ponte)).intValue();
            int h = ((Number) altura.invoke(ponte)).intValue();
            if (b == null || b.length == 0 || w <= 0 || h <= 0) {
                return d;
            }
            // A resolucao pode trocar entre um quadro e outro (meia/inteira):
            // acerta pelo tamanho do proprio quadro.
            if (b.length != w * h * 4) {
                if (b.length == (w / 2) * (h / 2) * 4) {
                    w /= 2;
                    h /= 2;
                } else if (b.length == (w * 2) * (h * 2) * 4) {
                    w *= 2;
                    h *= 2;
                } else {
                    return d;
                }
            }
            // Chegou cheio fora da foto (a troca vale do proximo quadro em
            // diante): reduz aqui mesmo, e o jogo recebe sempre o leve.
            if (!fotoCheia && w > 400) {
                b = reduzirPelaMetade(b, w, h);
                w /= 2;
                h /= 2;
            }
            d.put("dados", b);
            d.put("largura", Integer.valueOf(w));
            d.put("altura", Integer.valueOf(h));
        } catch (Throwable t) {
            d.put("erro", String.valueOf(t));
        }
        return d;
    }

    /** Media de 2x2 pixels RGBA. O vetor e reaproveitado (o Godot copia na volta). */
    private byte[] reduzirPelaMetade(byte[] src, int w, int h) {
        int w2 = w / 2;
        int h2 = h / 2;
        int precisa = w2 * h2 * 4;
        if (meio == null || meio.length != precisa) {
            meio = new byte[precisa];
        }
        byte[] out = meio;
        int o = 0;
        int linha = w * 4;
        for (int y = 0; y < h2; y++) {
            int a = (y * 2) * linha;
            int b = a + linha;
            for (int x = 0; x < w2; x++) {
                int i = a + x * 8;
                int j = b + x * 8;
                for (int c = 0; c < 4; c++) {
                    int s = (src[i + c] & 0xff) + (src[i + 4 + c] & 0xff)
                            + (src[j + c] & 0xff) + (src[j + 4 + c] & 0xff);
                    out[o++] = (byte) (s >> 2);
                }
            }
        }
        return out;
    }

    // ------------------------------------------------------------------
    // 2. MEMORIA
    // ------------------------------------------------------------------

    /**
     * {"livre": MB livres no Android, "total": MB da placa, "limite": MB em
     * que o Android comeca a fechar apps de fundo, "pouca": abaixo do limite,
     * "jogo": MB do proprio jogo (RSS), "aviso": ultimo aviso de memoria
     * (onTrimMemory, 0 = nenhum), "aviso_ha_s": segundos desde ele (-1 =
     * nunca), "apertos": quantos avisos de aperto, "pior": o pior aviso}.
     */
    @UsedByGodot
    public Dictionary memoria() {
        Dictionary d = new Dictionary();
        try {
            Context c = contexto != null ? contexto : getActivity();
            ActivityManager am = (ActivityManager) c.getSystemService(Context.ACTIVITY_SERVICE);
            ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
            am.getMemoryInfo(mi);
            d.put("livre", Integer.valueOf((int) (mi.availMem / 1048576L)));
            d.put("total", Integer.valueOf((int) (mi.totalMem / 1048576L)));
            d.put("limite", Integer.valueOf((int) (mi.threshold / 1048576L)));
            d.put("pouca", Boolean.valueOf(mi.lowMemory));
        } catch (Throwable t) {
            d.put("erro", String.valueOf(t));
        }
        d.put("jogo", Integer.valueOf(rssDoJogo()));
        d.put("aviso", Integer.valueOf(avisoNivel));
        long ha = avisoEm == 0L ? -1L : (SystemClock.elapsedRealtime() - avisoEm) / 1000L;
        d.put("aviso_ha_s", Integer.valueOf((int) ha));
        d.put("apertos", Integer.valueOf(avisosApertado));
        d.put("pior", Integer.valueOf(piorAviso));
        return d;
    }

    private static int rssDoJogo() {
        BufferedReader r = null;
        try {
            r = new BufferedReader(new FileReader("/proc/self/status"));
            String l;
            while ((l = r.readLine()) != null) {
                if (l.startsWith("VmRSS:")) {
                    String n = l.substring(6).trim().split("\\s+")[0];
                    return (int) (Long.parseLong(n) / 1024L);
                }
            }
        } catch (Throwable t) {
            // sem /proc: fica 0
        } finally {
            try {
                if (r != null) r.close();
            } catch (Throwable t) {
                // nada
            }
        }
        return 0;
    }

    // ------------------------------------------------------------------
    // 3. ERROS DA ABERTURA ANTERIOR
    // ------------------------------------------------------------------

    /** "" enquanto le; depois as ultimas linhas de erro da sessao anterior (ou "NENHUM"). */
    @UsedByGodot
    public String errosDaAberturaAnterior() {
        return errosProntos ? errosAnteriores : "";
    }

    private static boolean interessa(String l) {
        if (l.contains(" F/") || l.contains(" E/")) {
            return !l.contains("PunchCamera");
        }
        String m = l.toLowerCase();
        return m.contains("fatal") || m.contains("signal ") || m.contains("outofmemory")
                || m.contains("out of memory") || m.contains("lowmemory") || m.contains("abort")
                || m.contains("superboxing");
    }

    /** O PID de uma linha "-v time": "09-29 13:01:11.770 E/tag( 1234): msg". */
    private static int pidDaLinha(String l) {
        int b = l.indexOf("): ");
        int a = b < 0 ? -1 : l.lastIndexOf('(', b);
        if (a < 0) return -1;
        try {
            return Integer.parseInt(l.substring(a + 1, b).trim());
        } catch (Throwable t) {
            return -1;
        }
    }

    private void lerErrosAnteriores() {
        ArrayList<String> achadas = new ArrayList<String>();
        int eu = android.os.Process.myPid();
        int ultimoPid = -1;
        // Com o buffer "crash" (queda de Java) e, se o logcat recusar, sem ele.
        String[][] comandos = {
            {"logcat", "-d", "-v", "time", "-b", "main", "-b", "system", "-b", "crash"},
            {"logcat", "-d", "-v", "time"},
        };
        for (String[] comando : comandos) {
            int lidas = 0;
            Process p = null;
            try {
                p = Runtime.getRuntime().exec(comando);
                BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
                String l;
                while ((l = r.readLine()) != null) {
                    lidas++;
                    int pid = pidDaLinha(l);
                    if (pid <= 0 || pid == eu || !interessa(l)) continue;
                    // So a ultima sessao antes desta: um PID novo recomeca a lista.
                    if (pid != ultimoPid) {
                        achadas.clear();
                        ultimoPid = pid;
                    }
                    achadas.add(l.length() > 200 ? l.substring(0, 200) : l);
                    if (achadas.size() > 400) achadas.remove(0);
                }
                r.close();
            } catch (Throwable t) {
                achadas.clear();
                achadas.add("LOGCAT INDISPONIVEL: " + t);
            } finally {
                try {
                    if (p != null) p.destroy();
                } catch (Throwable t) {
                    // nada
                }
            }
            if (lidas > 3) break;
        }
        StringBuilder tudo = new StringBuilder();
        for (String s : achadas) tudo.append(s).append('\n');
        // Guarda inteiro (para quem um dia tiver cabo) e devolve o miolo.
        try {
            Context c = contexto;
            if (c != null) {
                FileWriter w = new FileWriter(new File(c.getFilesDir(), "erros_abertura_anterior.txt"));
                w.write(tudo.toString());
                w.close();
            }
        } catch (Throwable t) {
            // sem arquivo: a tela ainda mostra
        }
        // Na tela: os ERROS (E/F) mais recentes; sem eles, os ultimos passos.
        ArrayList<String> tela = new ArrayList<String>();
        for (String s : achadas) {
            if (s.contains(" F/") || s.contains(" E/")) tela.add(s);
        }
        if (tela.isEmpty()) tela = achadas;
        StringBuilder resumo = new StringBuilder();
        for (int i = Math.max(0, tela.size() - 6); i < tela.size(); i++) {
            String s = tela.get(i);
            // Tira data e hora: sobra "E/tag( pid): mensagem", que cabe na tela.
            int corte = s.indexOf(' ', s.indexOf(' ') + 1);
            s = corte > 0 ? s.substring(corte + 1) : s;
            resumo.append(s).append('\n');
        }
        errosAnteriores = achadas.isEmpty() ? "NENHUM" : resumo.toString().trim();
        errosProntos = true;
    }
}
