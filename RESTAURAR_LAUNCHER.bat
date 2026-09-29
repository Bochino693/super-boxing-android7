@echo off
setlocal
cd /d "%~dp0"
title Super Boxing - Restaurar o launcher da TV Box

rem Desfaz o que o INSTALAR_NA_TVBOX.bat fez para dedicar a TV Box ao jogo:
rem religa o launcher de fabrica (LongLauncher e parecidos).
rem Com a TV Box na rede, passe o IP:  RESTAURAR_LAUNCHER.bat 192.168.0.50
set "ADB=C:\AndroidSdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo ERRO: adb nao encontrado em %ADB%
  pause
  exit /b 1
)
if not "%~1"=="" "%ADB%" connect %~1:5555
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
  echo ERRO: nenhuma TV Box conectada no ADB.
  pause
  exit /b 1
)
rem Religa os que foram desligados (lista do INSTALAR) e, por garantia,
rem qualquer launcher que esteja desligado na TV Box.
if exist "launchers_desligados.txt" (
  for /f "usebackq tokens=*" %%P in ("launchers_desligados.txt") do "%ADB%" shell pm enable %%P
)
"%ADB%" shell "for p in $(pm list packages -d 2>/dev/null | grep -i launcher | cut -d: -f2 | tr -d '\r '); do pm enable $p; done"
echo.
echo PRONTO. Aperte o botao de inicio (casinha) no controle e escolha o
echo launcher da TV Box.
pause
exit /b 0
