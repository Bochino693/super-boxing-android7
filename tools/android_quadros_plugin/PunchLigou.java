package com.lazersport.punch.quadros;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * A TV LIGOU (na tomada): abre o jogo, como o "Launch on Boot" fazia - sem
 * precisar de outro app. Com o jogo escolhido como tela inicial
 * (PunchInicioAtivo) o Android ja o abre sozinho; isto e a segunda
 * garantia (no Android 10+ o sistema pode barrar uma tela aberta daqui).
 * QUICKBOOT_POWERON: o "ligou" das TVs e TV Boxes com inicializacao rapida.
 */
public class PunchLigou extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        try {
            Log.i("PunchQuadros", "inicio: a TV ligou (" + i.getAction() + "): abrindo o jogo");
            InicioDaTv.abrirJogo(c);
        } catch (Throwable t) {
            Log.i("PunchQuadros", "inicio: ligou: " + t);
        }
    }
}
