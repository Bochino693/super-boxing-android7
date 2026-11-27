package com.lazersport.punch.quadros;

import android.app.Activity;
import android.opengl.EGL14;
import android.opengl.EGLDisplay;
import android.opengl.EGLExt;
import android.opengl.EGLSurface;
import android.view.Choreographer;

/**
 * 30 QUADROS TRAVADOS NA BATIDA DA TV (build 130, o mesmo metodo do Strike
 * Kids GLES2, que roda liso na Mali-450).
 *
 * O jogo ja mirava 30 quadros por segundo, mas pelo relogio do Godot
 * (Engine.target_fps): ele dorme ate completar 33 ms e entrega o quadro -
 * so que a TV troca a imagem na batida DELA (60 Hz), e o quadro que chega
 * um pouco depois de uma batida espera a seguinte. Resultado: quadros que
 * ficam 1, 2 ou 3 batidas na tela, um atras do outro - a media da 30, mas
 * o movimento "agarra" (o lutador anda aos trancos, a camera trepida).
 *
 * Aqui cada quadro diz QUANDO deve aparecer (EGL_ANDROID_presentation_time),
 * sempre na grade das batidas da TV (Choreographer): exatamente 2 batidas
 * por quadro, como o "vSyncCount = 2" do Unity e a biblioteca de ritmo de
 * quadros do Android (Swappy). No Android o eglSwapInterval(2) nao vale (o
 * sistema trava em 1). O proprio sistema segura o jogo no ritmo (a fila de
 * imagens da tela enche e o desenho espera): o Godot mede quadros de 1/30 s
 * certinhos, e o jogo deixa o relogio dele livre (target_fps = 0).
 */
final class QuadrosDaTv {

    private static volatile int intervalo = 1;        // batidas da TV por quadro: 1 = 60, 2 = 30
    private static volatile long periodo = 16666667L; // uma batida da TV (ns)
    private static volatile long ultimaBatida = 0;    // a ultima batida (ns, relogio do System.nanoTime)
    private static volatile float hzDaTv = 0f;
    private static volatile boolean recursoFalhou = false;
    private static boolean ouvindo = false;           // (linha da interface)
    private static long ultimoAlvo = 0;               // (linha do desenho) a batida do quadro anterior
    private static volatile long quadros = 0;
    private static volatile long atrasados = 0;

    private QuadrosDaTv() {
    }

    private static final Choreographer.FrameCallback BATIDA = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long t) {
            ultimaBatida = t;
            if (intervalo > 1) {
                Choreographer.getInstance().postFrameCallback(this);
            } else {
                ouvindo = false;
                ultimaBatida = 0;
            }
        }
    };

    static int intervalo() {
        return intervalo;
    }

    /** 1 = cada quadro numa batida (60 numa TV de 60 Hz), 2 = 30 travados. */
    static void definir(final Activity a, int n) {
        intervalo = Math.max(1, Math.min(3, n));
        if (intervalo <= 1 || a == null) {
            return;
        }
        a.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    float hz = a.getWindowManager().getDefaultDisplay().getRefreshRate();
                    hzDaTv = hz;
                    if (hz > 20f && hz < 250f) {
                        periodo = Math.round(1e9 / hz);
                    }
                } catch (Throwable t) {
                    // fica nos 60 Hz
                }
                if (!ouvindo) {
                    ouvindo = true;
                    Choreographer.getInstance().postFrameCallback(BATIDA);
                }
            }
        });
    }

    /** Para a Central: o que esta valendo de verdade. */
    static String descrever() {
        if (recursoFalhou) {
            return "sem presentation_time nesta TV Box (relogio do Godot)";
        }
        if (intervalo <= 1) {
            return "uma batida por quadro";
        }
        long q = quadros;
        long at = atrasados;
        String pct = q > 0 ? String.format(java.util.Locale.US, "%.1f%%", 100.0 * at / q) : "-";
        return String.format(java.util.Locale.US, "%d batidas por quadro (TV %.0f Hz) - atrasados %s",
                intervalo, hzDaTv, pct);
    }

    /**
     * Na linha do desenho, depois do quadro desenhado e antes de ir para a
     * tela (GodotPlugin.onGLDrawFrame): marca a batida em que ele aparece.
     */
    static void antesDeTrocar() {
        int n = intervalo;
        long base = ultimaBatida;
        if (n <= 1 || base <= 0 || recursoFalhou) {
            ultimoAlvo = 0;
            return;
        }
        long p = periodo;
        long agora = System.nanoTime();
        // a primeira batida que este quadro ainda alcanca (uma batida inteira
        // para a placa terminar e a tela pegar), na grade das batidas
        long minimo = base + ((agora + p - base) / p + 1) * p;
        long alvo = minimo;
        if (ultimoAlvo > 0) {
            // `n` batidas depois do anterior (o sistema segura o jogo ate la);
            // atrasou, vai na primeira que da
            long desejado = base + Math.round((double) (ultimoAlvo + n * p - base) / p) * p;
            if (desejado >= minimo && desejado - agora < 4 * n * p) {
                alvo = desejado;
            } else {
                atrasados++;
            }
        }
        quadros++;
        ultimoAlvo = alvo;
        try {
            EGLDisplay d = EGL14.eglGetCurrentDisplay();
            EGLSurface s = EGL14.eglGetCurrentSurface(EGL14.EGL_DRAW);
            if (d != EGL14.EGL_NO_DISPLAY && s != EGL14.EGL_NO_SURFACE) {
                // um quarto de batida antes: a tela pega este, nunca o seguinte
                if (!EGLExt.eglPresentationTimeANDROID(d, s, alvo - p / 4)) {
                    // a extensao nao existe nesta TV Box: o jogo volta ao
                    // relogio do Godot (ver `falhou`)
                    recursoFalhou = true;
                    intervalo = 1;
                }
            }
        } catch (Throwable ignored) {
            // aparelho sem o recurso: o jogo volta ao relogio do Godot
            recursoFalhou = true;
            intervalo = 1;
        }
    }

    /** O jogo precisa voltar a segurar o proprio ritmo (sem o recurso). */
    static boolean falhou() {
        return recursoFalhou;
    }
}
