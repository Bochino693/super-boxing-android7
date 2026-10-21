"""Monta android/plugins/PunchQuadros-release.aar (plugin v1 do Godot 3.6).

    python tools/android_quadros_plugin/montar_aar.py GODOT_LIB_AAR ANDROID_JAR

GODOT_LIB_AAR: godot-lib.release.aar do android_source.zip do Godot 3.6.2
ANDROID_JAR:   android.jar (SDK) ou android-all 7.1 (robolectric)

Um plugin de uma classe Java so (PunchQuadros.java, ao lado). O AAR pronto
ja vem no projeto; so e preciso rodar isto se a classe mudar.
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
    <application>
        <meta-data
            android:name="org.godotengine.plugin.v1.PunchQuadros"
            android:value="com.lazersport.punch.quadros.PunchQuadros" />
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
                               "-d", str(t / "out"), str(AQUI / "PunchQuadros.java")])
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
