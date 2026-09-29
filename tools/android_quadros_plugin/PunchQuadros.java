package com.lazersport.punch.quadros;

import java.lang.reflect.Method;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.GodotPluginRegistry;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * A PONTE DOS QUADROS DA WEBCAM PARA O GODOT 3.
 *
 * O plugin PunchUsbSerial entrega cada quadro como byte[] (pollUvcFrame).
 * No Godot 4 isso chega ao jogo; no Godot 3.6 NAO: o retorno byte[] de um
 * plugin nao tem conversao no JNISingleton e chega vazio - a camera
 * transmitia (a Central mostrava "QUADROS: aceitos 964") e o jogo ficava
 * em "SEM IMAGEM". Dentro de um Dictionary o byte[] e convertido (vira
 * PoolByteArray). Este plugin so pega o quadro do PunchUsbSerial e o
 * devolve assim, junto com a largura e a altura do MESMO quadro.
 */
public class PunchQuadros extends GodotPlugin {
    private Object ponte;
    private Method poll;
    private Method largura;
    private Method altura;

    public PunchQuadros(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PunchQuadros";
    }

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
            ponte = p;
            return true;
        } catch (Throwable t) {
            poll = null;
            return false;
        }
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
            d.put("dados", b);
            d.put("largura", Integer.valueOf(w));
            d.put("altura", Integer.valueOf(h));
        } catch (Throwable t) {
            d.put("erro", String.valueOf(t));
        }
        return d;
    }
}
