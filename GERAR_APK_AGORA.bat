@echo off
setlocal
rem SUPERBOXING_BUILD=126
title Super Boxing - Gerar APK para TV Box Mali-450 (OpenGL ES 2.0)
cd /d "%~dp0"

echo ============================================================
echo   SUPER BOXING - BUILD 126 - TV BOX MALI-450 (TX9)
echo   GODOT 3.6 - OPENGL ES 2.0 - TEXTURAS ETC1
echo   GERA O APK COMPLETO (PLUGIN USB + JOGO)
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gerar_apk\GERAR_APK_COMPLETO.ps1"
if errorlevel 1 (
  echo.
  echo FALHA: o APK nao foi criado. Fotografe esta janela inteira.
  echo Nao copie os sinais PS, ^>^> ou mensagens de erro como comandos.
  pause
  exit /b 1
)

echo.
echo SUCESSO. APK criado em:
echo %~dp0build\android\SuperBoxing.apk
echo.
echo Copie o APK para a TV Box (pendrive) e instale por cima do atual:
echo ranking, fotos e ajustes ficam (a assinatura e sempre a mesma).
pause
exit /b 0
