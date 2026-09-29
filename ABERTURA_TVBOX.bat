@echo off
setlocal
cd /d "%~dp0"
title Super Boxing - Abertura na TV Box

rem SE O JOGO TRAVAR NO CARREGAMENTO OU FECHAR SOZINHO:
rem   1. abre o jogo do zero e espera 60 s;
rem   2. grava ABERTURA_RELATORIO.txt com cada etapa da abertura, a memoria
rem      da TV Box e o erro do Android (se o sistema fechou o jogo, diz por que).
rem Com a TV Box na rede, passe o IP:  ABERTURA_TVBOX.bat 192.168.0.50
set "ADB=C:\AndroidSdk\platform-tools\adb.exe"
set "PKG=com.lazersport.superboxing"
set "SAIDA=%~dp0ABERTURA_RELATORIO.txt"
if not exist "%ADB%" (
  echo ERRO: adb nao encontrado em %ADB%
  pause
  exit /b 1
)
if not "%~1"=="" "%ADB%" connect %~1:5555
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
  echo ERRO: nenhuma TV Box conectada no ADB.
  echo Ligue a depuracao USB/rede na TV Box ou passe o IP:  ABERTURA_TVBOX.bat 192.168.0.50
  pause
  exit /b 1
)

echo [1/3] Abrindo o jogo do zero...
"%ADB%" shell am force-stop %PKG%
"%ADB%" logcat -c
"%ADB%" shell am start -n %PKG%/com.godot.game.GodotApp >nul 2>&1
if errorlevel 1 "%ADB%" shell monkey -p %PKG% 1 >nul 2>&1

echo [2/3] Esperando a abertura (60 s, nao mexa)...
timeout /t 60 /nobreak >nul

echo [3/3] Gravando o relatorio...
> "%SAIDA%" echo SUPER BOXING - RELATORIO DA ABERTURA
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== APARELHO
"%ADB%" shell getprop ro.product.model >> "%SAIDA%" 2>&1
"%ADB%" shell getprop ro.build.version.release >> "%SAIDA%" 2>&1
"%ADB%" shell getprop ro.board.platform >> "%SAIDA%" 2>&1
"%ADB%" shell wm size >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== TELA (bordas pretas: overscan do Android ou posicao da tela da TV Box)
"%ADB%" shell wm density >> "%SAIDA%" 2>&1
"%ADB%" shell "dumpsys window displays | grep -i -E 'overscan|init=|cur=|app=' | head -10" >> "%SAIDA%" 2>&1
"%ADB%" shell "cat /sys/class/display/mode /sys/class/graphics/fb0/window_axis /sys/class/graphics/fb0/free_scale_axis /sys/class/video/axis 2>&1" >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== TELA INICIAL (quem e o launcher) E APPS DESLIGADOS
"%ADB%" shell "cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME 2>/dev/null | grep /" >> "%SAIDA%" 2>&1
"%ADB%" shell pm list packages -d >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== VERSAO INSTALADA
"%ADB%" shell "dumpsys package %PKG% | grep -i -E 'versionName|versionCode'" >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== O JOGO ESTA ABERTO?
"%ADB%" shell "ps | grep %PKG%" >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== MEMORIA DA TV BOX
"%ADB%" shell "head -5 /proc/meminfo" >> "%SAIDA%" 2>&1
"%ADB%" shell "dumpsys meminfo %PKG% | head -40" >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== ETAPAS DA ABERTURA, ERROS E FECHAMENTOS
"%ADB%" logcat -d -v time -s godot:* AndroidRuntime:E ActivityManager:I lowmemorykiller:* libc:F DEBUG:* >> "%SAIDA%" 2>&1
>> "%SAIDA%" echo.
>> "%SAIDA%" echo ===== QUEM O ANDROID DERRUBOU POR FALTA DE MEMORIA
"%ADB%" logcat -d -v time | findstr /i "lowmemorykiller Killing has.died crash FATAL" >> "%SAIDA%" 2>&1

echo.
echo PRONTO. O relatorio esta em:
echo   %SAIDA%
echo Mande esse arquivo para ver onde a abertura parou.
start "" notepad "%SAIDA%"
pause
exit /b 0
