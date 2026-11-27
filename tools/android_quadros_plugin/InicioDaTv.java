package com.lazersport.punch.quadros;

import java.lang.reflect.Method;
import java.util.List;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import org.godotengine.godot.utils.ProcessPhoenix;

/**
 * O JOGO ABRE SOZINHO AO LIGAR A TV - o padrao do Strike Kids 8.8 (build 133).
 *
 * 1. NAO E MAIS TELA INICIAL. Ate a build 132 o jogo se oferecia como a
 *    tela inicial do Android (PunchInicioAtivo com HOME): havia TV Box que
 *    esquecia o "SEMPRE" e perguntava "app padrao" a cada vez que ligava.
 *    Agora a TV Box usa a propria tela inicial e nunca pergunta nada.
 * 2. QUEM ABRE O JOGO AO LIGAR: o aviso de "ligou" do Android (PunchLigou,
 *    abrirAoLigar) - na hora e de novo aos 2,5 / 6 / 12 / 25 s, se a tela
 *    da TV Box cobrir o jogo (TV Box lenta ainda monta o lancador dela
 *    quando o aviso chega). Um app de AUTO START (Launch on Boot) pode
 *    abrir junto: o jogo ja na frente nao e aberto de novo (naFrente).
 *    Android ate o 9: sempre pode. Android 10+: so com "sobrepor a outros
 *    apps" (pedirSobrepor, pela Central).
 * 3. VOLTA DA ESPERA: desligada pelo CONTROLE, a TV nao desliga de verdade
 *    (fica em espera) e nada "liga" de novo. Com o processo do jogo vivo,
 *    ouvirTela() percebe a tela apagar e acender: depois de 10 s ou mais
 *    apagada, o jogo solta a webcam e o Arduino e reinicia do zero.
 * 4. SAIDA DO OPERADOR: sairParaTv() abre a tela inicial da propria TV (a
 *    Central). O HOME do controle tambem leva a ela, agora direto.
 *
 * O ARDUINO PERGUNTA UMA VEZ SO: isso e do plugin USB (UsbAttachActivity
 * directBootAware) - ver o manifesto dele.
 */
final class InicioDaTv {

    private static final String TAG = "PunchQuadros";
    static final int PEDIDO_PAPEL = 7501;
    /** RoleManager.ROLE_HOME (Android 10+). */
    private static final String PAPEL_HOME = "android.app.role.HOME";
    private static final String PREFS = "punch_inicio";
    private static final int VEZES_PARA_SAIR = 5;
    private static final long JANELA_SAIR_MS = 10000;
    private static final long APAGADA_PARA_REINICIAR_MS = 10000;
    private static final long ESPERA_AO_ACENDER_MS = 1500;

    /** Na hora e de novo, se a tela da TV Box cobrir o jogo (o do Strike Kids). */
    private static final long[] TENTATIVAS_MS = {0, 2500, 6000, 12000, 25000};
    /** O jogo esta na frente (PunchQuadros: onMainResume / onMainPause). */
    static volatile boolean naFrente = false;

    private static long pedidoEm = 0;
    private static boolean pedidoSozinho = false;
    private static long apagouEm = 0;
    private static BroadcastReceiver tela;

    private InicioDaTv() {
    }

    private static Intent home() {
        return new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
    }

    /** Abre uma tela de outro app; false se a TV nao tem essa tela. */
    private static boolean abrir(Context c, Intent i) {
        try {
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
            return true;
        } catch (ActivityNotFoundException e) {
            return false;
        } catch (Throwable t) {
            Log.i(TAG, "inicio: " + t);
            return false;
        }
    }

    /** O jogo, como o lancador o abre (so traz para a frente se ja esta aberto). */
    static void abrirJogo(Context c) {
        Intent jogo = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
        if (jogo != null) {
            jogo.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            c.startActivity(jogo);
        }
    }

    // ------------------------------------------------------------ ligou

    /** O Android deixa o aviso de "ligou" abrir uma tela? (ate o 9 sempre; 10+ so com "sobrepor") */
    static boolean podeAbrirDeFundo(Context c) {
        if (Build.VERSION.SDK_INT < 29) {
            return true;
        }
        try {
            return Settings.canDrawOverlays(c);
        } catch (Throwable t) {
            return false;
        }
    }

    /** A TV ligou (ou o jogo foi atualizado): abre o jogo, tentando de novo se nao veio. */
    static void abrirAoLigar(final Context c, final BroadcastReceiver.PendingResult fim) {
        final Handler h = new Handler(Looper.getMainLooper());
        for (int k = 0; k < TENTATIVAS_MS.length; k++) {
            final boolean ultima = k == TENTATIVAS_MS.length - 1;
            h.postDelayed(new Runnable() {
                @Override
                public void run() {
                    try {
                        if (!naFrente) {
                            Log.i(TAG, "inicio: ligou: abrindo o jogo");
                            abrirJogo(c);
                        }
                        if (ultima && !naFrente && !podeAbrirDeFundo(c)) {
                            Log.i(TAG, "inicio: Android 10+ sem 'sobrepor a outros apps': o jogo nao pode abrir sozinho");
                        }
                    } catch (Throwable t) {
                        Log.i(TAG, "inicio: ligou: " + t);
                    } finally {
                        if (ultima && fim != null) {
                            fim.finish();
                        }
                    }
                }
            }, TENTATIVAS_MS[k]);
        }
    }

    /** O jogo veio para a frente. */
    static void jogoNaFrente(Context c) {
        naFrente = true;
    }

    /** Para a Central: "sim" (abre sozinho ao ligar) ou "sobrepor" (Android 10+ sem a permissao). */
    static String abreAoLigar(Context c) {
        return podeAbrirDeFundo(c) ? "sim" : "sobrepor";
    }

    private static Intent telaDeSobrepor(Context c) {
        if (Build.VERSION.SDK_INT < 23) {
            return null;
        }
        Intent i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + c.getPackageName()));
        if (i.resolveActivity(c.getPackageManager()) != null) {
            return i;
        }
        i = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
        return i.resolveActivity(c.getPackageManager()) != null ? i : null;
    }

    /** Abre a pagina "sobrepor a outros apps" do jogo: "ajustes" ou "" (a TV nao tem). */
    static String pedirSobrepor(Activity a) {
        Intent i = telaDeSobrepor(a);
        return i != null && abrir(a, i) ? "ajustes" : "";
    }

    // ------------------------------------------------------------ tela inicial
    // (Ate a build 132 o jogo era candidato a tela inicial. Continua aqui
    // so o que diz qual e a tela inicial da TV e como sair para ela.)

    /** A tela inicial que o Android abre hoje (null, ou a janela de escolha). */
    private static ResolveInfo padrao(Context c) {
        return c.getPackageManager().resolveActivity(home(), PackageManager.MATCH_DEFAULT_ONLY);
    }

    private static boolean ehCandidata(Context c, ResolveInfo ri) {
        List<ResolveInfo> todas = c.getPackageManager().queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY);
        for (ResolveInfo r : todas) {
            if (r.activityInfo.packageName.equals(ri.activityInfo.packageName) && r.activityInfo.name.equals(ri.activityInfo.name)) {
                return true;
            }
        }
        return false;
    }

    /** "jogo" (a TV ja abre o jogo), "escolher" (o Android ainda pergunta) ou "outra|Nome". */
    static String estado(Context c) {
        ResolveInfo ri = padrao(c);
        if (ri == null || ri.activityInfo == null) {
            return "escolher";
        }
        if (ri.activityInfo.packageName.equals(c.getPackageName())) {
            return "jogo";
        }
        // sem uma escolhida, o Android devolve a propria janela de escolha
        if (!ehCandidata(c, ri)) {
            return "escolher";
        }
        return "outra|" + ri.loadLabel(c.getPackageManager());
    }

    /**
     * Abre a escolha da tela inicial: "ja" (ja e o jogo), "papel" (a janela do
     * Android 10+), "ajustes", "escolha" (a janela "Sempre / So uma vez"),
     * "app" (a pagina da tela inicial da TV: "Limpar padroes"), "config" ou ""
     * (nada abriu). sozinho (o jogo pedindo na tela de espera): so as janelas
     * de escolha, nunca a pagina do app nem os ajustes gerais.
     */
    static String escolher(Activity a, boolean sozinho) {
        String agora = estado(a);
        if (agora.equals("jogo")) {
            return "ja";
        }
        pedidoSozinho = sozinho;
        if (Build.VERSION.SDK_INT >= 29 && pedirPapel(a)) {
            return "papel";
        }
        return semPapel(a, agora, sozinho);
    }

    private static boolean pedirPapel(Activity a) {
        try {
            Class<?> classe = Class.forName("android.app.role.RoleManager");
            Object rm = a.getSystemService(classe);
            if (rm == null) {
                return false;
            }
            Method disponivel = classe.getMethod("isRoleAvailable", String.class);
            Method tem = classe.getMethod("isRoleHeld", String.class);
            Method pedido = classe.getMethod("createRequestRoleIntent", String.class);
            if (!((Boolean) disponivel.invoke(rm, PAPEL_HOME)) || ((Boolean) tem.invoke(rm, PAPEL_HOME))) {
                return false;
            }
            pedidoEm = SystemClock.elapsedRealtime();
            a.startActivityForResult((Intent) pedido.invoke(rm, PAPEL_HOME), PEDIDO_PAPEL);
            return true;
        } catch (Throwable t) {
            Log.i(TAG, "inicio: papel: " + t);
            return false;
        }
    }

    /** A janela do papel voltou: se ela nem apareceu (TV sem essa janela), segue pelos ajustes. */
    static void depoisDoPapel(Activity a, int resultado) {
        if (resultado == Activity.RESULT_OK || SystemClock.elapsedRealtime() - pedidoEm > 1500) {
            return;
        }
        String agora = estado(a);
        if (!agora.equals("jogo")) {
            semPapel(a, agora, pedidoSozinho);
        }
    }

    private static String semPapel(Activity a, String agora, boolean sozinho) {
        if (abrir(a, new Intent(Settings.ACTION_HOME_SETTINGS))) {
            return "ajustes";
        }
        if (agora.equals("escolher") && abrir(a, home())) {
            return "escolha";
        }
        if (sozinho) {
            return "";
        }
        ResolveInfo ri = padrao(a);
        if (ri != null && ri.activityInfo != null && !ri.activityInfo.packageName.equals(a.getPackageName())
                && abrir(a, new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ri.activityInfo.packageName)))) {
            return "app";
        }
        if (abrir(a, new Intent(Settings.ACTION_SETTINGS))) {
            return "config";
        }
        return "";
    }

    // ------------------------------------------------------------ saida

    /** A tela inicial da propria TV (a de maior prioridade que nao e o jogo), ou null. */
    private static ResolveInfo outraTela(Context c) {
        PackageManager pm = c.getPackageManager();
        ResolveInfo melhor = null;
        for (ResolveInfo r : pm.queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY)) {
            if (r.activityInfo == null || r.activityInfo.packageName.equals(c.getPackageName())) {
                continue;
            }
            // a "FallbackHome" dos Ajustes (so a do comeco do boot) tem prioridade -1000
            if (melhor == null || r.priority > melhor.priority
                    || (r.priority == melhor.priority && sistema(r) && !sistema(melhor))) {
                melhor = r;
            }
        }
        return melhor;
    }

    private static boolean sistema(ResolveInfo r) {
        return (r.activityInfo.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;
    }

    /** Abre a tela inicial da propria TV (ou os ajustes): o nome dela, "config" ou "". */
    static String sairParaTv(Context c) {
        ResolveInfo outra = outraTela(c);
        if (outra != null) {
            Intent i = home().setClassName(outra.activityInfo.packageName, outra.activityInfo.name)
                    .addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
            if (abrir(c, i)) {
                return outra.loadLabel(c.getPackageManager()).toString();
            }
        }
        return abrir(c, new Intent(Settings.ACTION_SETTINGS)) ? "config" : "";
    }

    /** HOME 5 vezes em 10 s (ou o jogo caindo sem parar): true = sair para a tela da TV. */
    static boolean pediuParaSair(Context c) {
        SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        long agora = SystemClock.elapsedRealtime();
        long desde = p.getLong("desde", 0);
        int vezes = p.getInt("vezes", 0);
        if (agora < desde || agora - desde > JANELA_SAIR_MS) {
            desde = agora;
            vezes = 0;
        }
        vezes++;
        boolean sair = vezes >= VEZES_PARA_SAIR;
        p.edit().putLong("desde", sair ? 0 : desde).putInt("vezes", sair ? 0 : vezes).commit();
        return sair;
    }

    // ------------------------------------------------------------ volta da espera

    /**
     * Tela apagada 10 s ou mais e acesa de novo = o jogo reinicia do zero.
     * Fica ouvindo enquanto o processo do jogo viver (mesmo com o jogo
     * fechado ou atras de outro app). `antes` solta a webcam e o Arduino
     * (fora da thread da interface: a espera da webcam passa por ela).
     */
    static void ouvirTela(Activity atividade, final Runnable antes) {
        if (tela != null) {
            return;
        }
        final Context app = atividade.getApplicationContext();
        tela = new BroadcastReceiver() {
            @Override
            public void onReceive(Context c, Intent i) {
                if (Intent.ACTION_SCREEN_OFF.equals(i.getAction())) {
                    apagouEm = SystemClock.elapsedRealtime();
                    return;
                }
                long apagada = apagouEm > 0 ? SystemClock.elapsedRealtime() - apagouEm : 0;
                apagouEm = 0;
                if (apagada < APAGADA_PARA_REINICIAR_MS) {
                    return;
                }
                Log.i(TAG, "inicio: a TV voltou da espera (" + apagada / 1000 + " s): o jogo reinicia");
                new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        Thread reinicio = new Thread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    if (antes != null) antes.run();
                                } catch (Throwable t) {
                                    Log.i(TAG, "inicio: soltar: " + t);
                                }
                                try {
                                    ProcessPhoenix.triggerRebirth(app);
                                } catch (Throwable t) {
                                    Log.i(TAG, "inicio: reiniciar: " + t);
                                }
                            }
                        }, "punch-reinicio");
                        reinicio.start();
                    }
                }, ESPERA_AO_ACENDER_MS);
            }
        };
        IntentFilter f = new IntentFilter(Intent.ACTION_SCREEN_OFF);
        f.addAction(Intent.ACTION_SCREEN_ON);
        try {
            app.registerReceiver(tela, f);
        } catch (Throwable t) {
            tela = null;
            Log.i(TAG, "inicio: tela: " + t);
        }
    }
}
