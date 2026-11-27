package com.lazersport.punch.quadros;

import android.app.Activity;
import android.os.Bundle;

/**
 * ABRE O JOGO E FECHA (build 133).
 *
 * Ate a build 132 esta era a TELA INICIAL do Android (HOME): escolhida com
 * "SEMPRE", o Android a abria ao ligar e a cada HOME. Havia TV Box que
 * esquecia o "SEMPRE" e perguntava "app padrao" a cada vez que ligava - o
 * padrao do Strike Kids 8.8 tirou isso: o jogo nao e mais candidato a tela
 * inicial (o manifesto nao a declara como HOME e ela nao e exportada) e
 * quem abre o jogo ao ligar e o aviso de "ligou" (PunchLigou) ou o AUTO
 * START. Ela fica so como um atalho interno que abre o jogo.
 */
public class PunchInicioAtivo extends Activity {
    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        try {
            InicioDaTv.abrirJogo(this);
        } catch (Throwable ignorado) {
            // nada: nunca pode cair
        }
        finish();
    }
}
