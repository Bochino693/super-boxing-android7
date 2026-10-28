package com.lazersport.punch.quadros;

import android.app.Activity;
import android.os.Bundle;

/**
 * O JOGO ABRE SOZINHO AO LIGAR A TV (build 129, igual ao boliche).
 *
 * Esta atividade invisivel e uma TELA INICIAL do Android (filtro HOME no
 * manifesto). Escolhida como a tela inicial da TV ("Sempre"), e ela que o
 * Android abre ao ligar a TV, ao voltar do modo de espera para o inicio e a
 * cada HOME do controle: so traz o jogo para a frente (ou abre) e fecha na
 * hora. Se o jogo fechar ou cair, o Android volta para a tela inicial - e o
 * jogo abre de novo. Ao contrario de um aviso de "ligou" (BOOT_COMPLETED), o
 * Android nunca bloqueia a tela inicial de abrir uma tela, em nenhuma versao.
 *
 * HOME apertado 5 vezes seguidas (ou o jogo caindo sem parar) abre a tela
 * inicial da propria TV (InicioDaTv.pediuParaSair): a saida do operador sem
 * a Central. Um HOME de novo volta ao jogo.
 */
public class PunchInicioAtivo extends Activity {
    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        try {
            if (InicioDaTv.pediuParaSair(this)) {
                InicioDaTv.sairParaTv(this);
            } else {
                InicioDaTv.abrirJogo(this);
            }
        } catch (Throwable ignorado) {
            // nada: a tela inicial nunca pode cair
        }
        finish();
    }
}
