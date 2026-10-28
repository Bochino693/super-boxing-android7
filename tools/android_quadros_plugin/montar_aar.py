"""Monta android/plugins/PunchQuadros-release.aar (plugin v1 do Godot 3.6).

    python tools/android_quadros_plugin/montar_aar.py GODOT_LIB_AAR ANDROID_JAR

GODOT_LIB_AAR: godot-lib.release.aar do android_source.zip do Godot 3.6.2
ANDROID_JAR:   android.jar (SDK) ou android-all 7.1 (robolectric)

O plugin sao as classes Java ao lado (PunchQuadros.java e, desde a build
129, a tela inicial: InicioDaTv, PunchInicioAtivo e PunchLigou). O AAR
pronto ja vem no projeto; so e preciso rodar isto se uma classe mudar.

O MANIFESTO (abaixo) entra no do APK na geracao (o Gradle junta os dois):
  - a permissao de receber o "ligou" (RECEIVE_BOOT_COMPLETED);
  - <queries> das telas iniciais (o Android 11+ esconde as outras sem isso);
  - PunchInicioAtivo: a tela inicial (HOME) invisivel que abre o jogo;
  - PunchLigou: o aviso de "ligou" (BOOT_COMPLETED / QUICKBOOT_POWERON).
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
SAIDA = RAIZ / "android" / "plugins" / "PunchQuadros-release.aar"
MANIFESTO = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.lazersport.punch.quadros">
    <uses-sdk android:minSdkVersion="19" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <queries>
        <intent>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.HOME" />
        </intent>
    </queries>
    <application>
        <meta-data
            android:name="org.godotengine.plugin.v1.PunchQuadros"
            android:value="com.lazersport.punch.quadros.PunchQuadros" />
        <activity
            android:name="com.lazersport.punch.quadros.PunchInicioAtivo"
            android:excludeFromRecents="true"
            android:exported="true"
            android:noHistory="true"
            android:stateNotNeeded="true"
            android:theme="@android:style/Theme.Translucent.NoTitleBar">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>
        <receiver
            android:name="com.lazersport.punch.quadros.PunchLigou"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
"""


def main():
    godot_aar, android_jar = sys.argv[1], sys.argv[2]
    with tempfile.TemporaryDirectory() as t:
        t = Path(t)
        with zipfile.ZipFile(godot_aar) as z:
            (t / "godot.jar").write_bytes(z.read("classes.jar"))
        (t / "out").mkdir()
        subprocess.check_call(["javac", "--release", "8", "-nowarn",
                               "-cp", "%s%s%s" % (android_jar, ":" if sys.platform != "win32" else ";", t / "godot.jar"),
                               "-d", str(t / "out")] + [str(f) for f in sorted(AQUI.glob("*.java"))])
        with zipfile.ZipFile(t / "classes.jar", "w", zipfile.ZIP_DEFLATED) as j:
            for f in sorted((t / "out").rglob("*.class")):
                j.write(f, f.relative_to(t / "out").as_posix())
        with zipfile.ZipFile(SAIDA, "w", zipfile.ZIP_DEFLATED) as a:
            a.writestr("AndroidManifest.xml", MANIFESTO)
            a.write(t / "classes.jar", "classes.jar")
            a.writestr("R.txt", "")
    print("ok", SAIDA)


if __name__ == "__main__":
    main()
