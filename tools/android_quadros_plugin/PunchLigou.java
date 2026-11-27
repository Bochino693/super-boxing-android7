package com.lazersport.punch.quadros;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * A TV LIGOU (na tomada) - ou o jogo acabou de ser atualizado: abre o jogo,
 * como o "Launch on Boot" fazia, sem precisar de outro app (o padrao do
 * Strike Kids 8.8, build 133). Tenta na hora e de novo aos 2,5 / 6 / 12 /
 * 25 s, se a tela da TV Box cobrir o jogo (InicioDaTv.abrirAoLigar). Com um
 * app de AUTO START abrindo junto, o jogo ja na frente nao e aberto de novo.
 * QUICKBOOT_POWERON: o "ligou" das TVs e TV Boxes com inicializacao rapida.
 */
public class PunchLigou extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        try {
            Log.i("PunchQuadros", "inicio: " + i.getAction() + ": abrindo o jogo");
            InicioDaTv.abrirAoLigar(c.getApplicationContext(), goAsync());
        } catch (Throwable t) {
            Log.i("PunchQuadros", "inicio: ligou: " + t);
        }
    }
}
