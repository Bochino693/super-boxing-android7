@echo off
setlocal
cd /d "%~dp0"
title Super Boxing - Tela cheia na TV Box

rem BORDAS PRETAS EM VOLTA DA IMAGEM:
rem O Android de algumas TV Boxes guarda uma margem ("overscan") em volta
rem da tela. Este comando zera essa margem (vale para a TV Box inteira e
rem continua valendo depois de desligar). Depois abre o jogo de novo.
rem Com a TV Box na rede, passe o IP:  TELA_CHEIA_TVBOX.bat 192.168.0.50
set "ADB=C:\AndroidSdk\platform-tools\adb.exe"
set "PKG=com.lazersport.superboxing"
if not exist "%ADB%" (
  echo ERRO: adb nao encontrado em %ADB%
  pause
  exit /b 1
)
if not "%~1"=="" "%ADB%" connect %~1:5555
"%ADB%" get-state >nul 2>&1
if errorlevel 1 (
  echo ERRO: nenhuma TV Box conectada no ADB.
  echo Ligue a depuracao USB/rede na TV Box ou passe o IP:  TELA_CHEIA_TVBOX.bat 192.168.0.50
  pause
  exit /b 1
)
echo Zerando a margem (overscan) do Android...
"%ADB%" shell wm overscan reset
"%ADB%" shell wm overscan 0,0,0,0
echo Abrindo o jogo de novo...
"%ADB%" shell am force-stop %PKG%
"%ADB%" shell am start -n %PKG%/com.godot.game.GodotApp >nul 2>&1
if errorlevel 1 "%ADB%" shell monkey -p %PKG% 1 >nul 2>&1
echo.
echo PRONTO. Se AINDA sobrar borda preta, ela vem do ajuste de imagem da
echo propria TV Box: Configuracoes ^> Tela (Display) ^> Posicao da tela
echo (Screen position / Zoom) = 100%%. E na TV: formato de imagem
echo "Ajustar a tela" / "Just Scan" / "Pixel a pixel" (sem zoom da TV).
pause
exit /b 0
