"""Poe o plugin PunchSerialSeguro (Arduino, Java) DENTRO de
android/plugins/PunchUsbSerial-release.aar, ao lado do PunchUsbSerial
(camera, Kotlin).

    python tools/android_usb_plugin/serial_seguro/incluir_serial_seguro.py ANDROID_JAR GODOT_LIB_JAR

ANDROID_JAR: android.jar do SDK (qualquer API >= 24; android-all 7.1 serve).
GODOT_LIB_JAR: classes.jar de dentro do godot-lib.release.aar do Godot 3.6.2.
stubs/ tem so as assinaturas de usb-serial-for-android 3.11.0 para compilar
(conferidas com as que o plugin Kotlin usa); a biblioteca de verdade entra no
APK pela dependencia do .gdap.

O .java fica em plugin/src/main/java (junto do Kotlin): quem recompilar o
plugin inteiro com RECOMPILAR_PLUGIN_USB.bat tambem o leva.
"""
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile
import zipfile

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[2]
AAR = RAIZ / "android" / "plugins" / "PunchUsbSerial-release.aar"
FONTE = AQUI.parent / "plugin" / "src" / "main" / "java" / "com" / "lazersport" / "punch" / "usbserial" / "PunchSerialSeguro.java"
CLASSE = "com/lazersport/punch/usbserial/PunchSerialSeguro"
META = ('        <meta-data\n'
        '            android:name="org.godotengine.plugin.v1.PunchSerialSeguro"\n'
        '            android:value="com.lazersport.punch.usbserial.PunchSerialSeguro" />\n')


def main(android_jar: str, godot_jar: str) -> None:
    sep = os.pathsep
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        stubs_out, out = tmp / "stubs", tmp / "out"
        stubs_out.mkdir()
        out.mkdir()
        subprocess.run(["javac", "--release", "8", "-nowarn", "-d", str(stubs_out), "-cp", android_jar]
                       + [str(p) for p in (AQUI / "stubs").rglob("*.java")], check=True)
        subprocess.run(["javac", "--release", "8", "-Xlint:-options", "-d", str(out),
                        "-cp", sep.join([android_jar, godot_jar, str(stubs_out)]), str(FONTE)], check=True)
        novas = {p.relative_to(out).as_posix(): p.read_bytes() for p in out.rglob("*.class")}
        with zipfile.ZipFile(AAR) as z:
            itens = {i.filename: z.read(i.filename) for i in z.infolist() if not i.is_dir()}
        antigo = tmp / "classes_antigo.jar"
        antigo.write_bytes(itens["classes.jar"])
        novo = tmp / "classes.jar"
        with zipfile.ZipFile(antigo) as zi, zipfile.ZipFile(novo, "w", zipfile.ZIP_DEFLATED) as zo:
            for i in zi.infolist():
                if i.filename.startswith(CLASSE) or i.is_dir():
                    continue
                zo.writestr(i, zi.read(i.filename))
            for nome, dados in sorted(novas.items()):
                zo.writestr(nome, dados)
        itens["classes.jar"] = novo.read_bytes()
        manifesto = itens["AndroidManifest.xml"].decode("utf-8")
        if "org.godotengine.plugin.v1.PunchSerialSeguro" not in manifesto:
            manifesto = re.sub(r"(\s*)</application>", "\n" + META + r"\1</application>", manifesto, count=1)
        itens["AndroidManifest.xml"] = manifesto.encode("utf-8")
        with zipfile.ZipFile(AAR, "w", zipfile.ZIP_DEFLATED) as z:
            for nome, dados in itens.items():
                z.writestr(nome, dados)
    print("PunchSerialSeguro no", AAR, ":", ", ".join(sorted(novas)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
