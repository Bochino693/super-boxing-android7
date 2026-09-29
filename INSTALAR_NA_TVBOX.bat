@echo off
setlocal
cd /d "%~dp0"
title Super Boxing S905L - Instalar na TV Box

rem Instala o APK por cima do atual (-r): ranking, fotos e ajustes ficam.
rem Com a TV Box na rede, passe o IP:  INSTALAR_NA_TVBOX.bat 192.168.0.50
set "ADB=C:\AndroidSdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo ERRO: adb nao encontrado em %ADB%
  pause
  exit /b 1
)
if not exist "build\android\SuperBoxing.apk" (
  echo ERRO: gere o APK antes com GERAR_APK_AGORA.bat
  pause
  exit /b 1
)
if not "%~1"=="" "%ADB%" connect %~1:5555
"%ADB%" install -r "build\android\SuperBoxing.apk"
if errorlevel 1 (
  echo.
  echo FALHA NA INSTALACAO. Se a mensagem falar de assinatura diferente,
  echo desinstale o jogo antigo da TV Box uma vez e rode de novo.
  pause
  exit /b 1
)
rem Camera liberada pela linha de comando: o jogo nao pergunta nunca.
"%ADB%" shell pm grant com.lazersport.superboxing android.permission.CAMERA

rem MAQUINA DEDICADA: o jogo vira a TELA INICIAL da TV Box (abre sozinho ao
rem ligar) e o launcher de fabrica (LongLauncher e parecidos) e DESLIGADO -
rem nao apagado. Na TV Box de 1 GB ele ficava parado em segundo plano; quando
rem a camera abria, o Android o derrubava por falta de memoria e aparecia
rem "LongLauncher parou" por cima do jogo. Desligado, ele nao roda nem quebra,
rem e a memoria dele fica para o jogo. Para voltar: RESTAURAR_LAUNCHER.bat
echo.
echo Deixando a TV Box dedicada ao jogo...
"%ADB%" shell pm set-home-activity com.lazersport.superboxing/com.godot.game.GodotApp >nul 2>&1
"%ADB%" shell "for p in $( (cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | grep / | grep -v = | cut -d/ -f1; pm list packages 2>/dev/null | grep -i launcher | cut -d: -f2) | tr -d '\r ' | sort -u ); do case $p in com.lazersport.superboxing|*settings*|*provision*) ;; *) pm disable-user --user 0 $p >/dev/null 2>&1 && echo $p;; esac; done" >> "launchers_desligados.txt"
echo Launchers desligados (guardado em launchers_desligados.txt):
type "launchers_desligados.txt" 2>nul
rem Abre o jogo como tela inicial.
"%ADB%" shell am start -a android.intent.action.MAIN -c android.intent.category.HOME >nul 2>&1
echo.
echo INSTALADO. O Super Boxing agora e a tela inicial da TV Box.
echo Se a TV Box perguntar qual aplicativo usar como inicio, escolha
echo Super Boxing e SEMPRE.
pause
exit /b 0
