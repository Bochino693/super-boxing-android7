@echo off
setlocal
rem Roda de uma COPIA na pasta temporaria: o "git pull" pode trocar este
rem proprio arquivo, e o Windows se perde se o .bat mudar enquanto roda.
if /i not "%~1"=="--copia" (
  copy /y "%~f0" "%TEMP%\superboxing_s905l_atualizar.bat" >nul
  call "%TEMP%\superboxing_s905l_atualizar.bat" --copia "%~dp0"
  exit /b
)
cd /d "%~2"
title Super Boxing - Atualizar e gerar o APK

rem UM CLIQUE: baixa a versao nova do GitHub e ja gera o APK.
rem
rem O Godot reescreve sozinho alguns arquivos ao importar (os .import das
rem texturas do lutador). Isso travava o "git pull" com "Your local changes
rem would be overwritten". Aqui essas mudancas automaticas sao descartadas
rem antes de baixar - voce nao perde nada seu: ranking, fotos e ajustes
rem ficam na TV Box, nao nesta pasta.
where git >nul 2>&1
if errorlevel 1 (
  echo ERRO: o git nao esta instalado neste PC.
  pause
  exit /b 1
)

echo [1/2] Baixando a versao nova do jogo...
git checkout -- .
git pull --ff-only origin main
if errorlevel 1 (
  echo.
  echo FALHA ao baixar a versao nova. Confira a internet e rode de novo.
  echo Se continuar, mande uma foto desta janela.
  pause
  exit /b 1
)
rem O GitHub precisa ter a versao S905L (Godot 3.6). Se tiver a antiga
rem (Godot 4), para aqui em vez de gerar um APK que nao abre na TV Box.
if not exist "scripts\compat.gd" (
  echo.
  echo PARE: o GitHub ainda tem a versao ANTIGA do jogo, a do Godot 4, que nao
  echo abre na TV Box S905L. Suba a versao S905L para o GitHub primeiro, ou use o
  echo GERAR_APK_AGORA.bat na pasta do zip.
  pause
  exit /b 1
)
echo      Versao nova baixada.
echo.
echo [2/2] Gerando o APK...
call "%CD%\GERAR_APK_AGORA.bat"
exit /b %errorlevel%
