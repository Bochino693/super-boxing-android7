@echo off
setlocal
rem SUPERBOXING_BUILD=208
title Super Boxing PRO (Godot 4.6) - Gerar APK Android
cd /d "%~dp0"

echo ============================================================
echo   SUPER BOXING PRO - BUILD 208 - GODOT 4.6 (OPENGL ES 3)
echo   GERA O APK COMPLETO (PLUGIN USB + JOGO)
echo   Para TV Box com OpenGL ES 3. A S905L usa a build 114 (Godot 3.6).
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
echo %~dp0build\android\SuperBoxingPRO.apk
echo.
echo Agora conecte a TV Box e use INSTALAR_NA_TVBOX.bat.
pause
exit /b 0
