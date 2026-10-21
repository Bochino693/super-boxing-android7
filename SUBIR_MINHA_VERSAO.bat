@echo off
setlocal EnableExtensions
title Super Boxing - Subir a minha versao para o GitHub

rem SOBE A SUA VERSAO DO PC (a SuperBoxingPRO-build208) PARA O GITHUB.
rem
rem Vai para uma BRANCH SEPARADA, a "pro-build208". A "main" (a versao da
rem TV Box, Godot 3.6) NAO e tocada. A sua pasta tambem NAO e tocada:
rem nada e apagado nem mudado nela (o controle do git fica guardado em
rem %LOCALAPPDATA%\SuperBoxingSubir, fora da pasta do jogo).
rem
rem COMO USAR: dois cliques. Se a sua versao estiver em outra pasta,
rem arraste a PASTA do jogo para cima deste arquivo.
rem Pode rodar quantas vezes quiser: cada vez sobe o que mudou.
rem
rem Nao sobe: .godot, .import, build, android\build, APK/AAB/PCK/EXE/ZIP,
rem e arquivos acima de 95 MB (o GitHub recusa). A lista aparece na tela.

set "REPO=https://github.com/Bochino693/super-boxing-android7.git"
set "BRANCH=pro-build208"
set "PADRAO=C:\Users\LAZER GAMES\Documents\super-boxing-and10-att\SuperBoxingPRO-build208"

rem ---- 1. ACHAR A PASTA DO JOGO ----
set "PASTA="
if not "%~1"=="" set "PASTA=%~1"
if not defined PASTA if exist "%PADRAO%\" set "PASTA=%PADRAO%"
if not defined PASTA if exist "%~dp0project.godot" if not exist "%~dp0scripts\compat.gd" set "PASTA=%~dp0"
if not defined PASTA goto :sem_pasta
if "%PASTA:~-1%"=="\" set "PASTA=%PASTA:~0,-1%"
rem project.godot pode estar uma pasta abaixo (zip extraido dentro de outra pasta)
if not exist "%PASTA%\project.godot" for /d %%d in ("%PASTA%\*") do if exist "%%~fd\project.godot" set "PASTA=%%~fd"
if not exist "%PASTA%\project.godot" goto :sem_pasta

where git >nul 2>&1
if errorlevel 1 goto :sem_git

echo ============================================================
echo   SUBIR A MINHA VERSAO PARA O GITHUB
echo ============================================================
echo   Pasta:  %PASTA%
echo   Destino: %REPO%
echo   Branch: %BRANCH%   (a main NAO e tocada)
echo ============================================================
echo.

rem ---- 2. CONTROLE DO GIT FORA DA PASTA DO JOGO ----
set "GD=%LOCALAPPDATA%\SuperBoxingSubir\%BRANCH%.git"
if exist "%GD%\HEAD" goto :tem_controle
git init -q --bare "%GD%"
if errorlevel 1 goto :falha_init
:tem_controle
set G=git --git-dir="%GD%" --work-tree="%PASTA%"
%G% config core.bare false
%G% config core.autocrlf false
%G% config core.safecrlf false
%G% config core.longpaths true
%G% config core.quotepath off
%G% config http.postBuffer 524288000

rem ---- 3. O QUE NAO SOBE ----
if not exist "%GD%\info\" mkdir "%GD%\info"
> "%GD%\info\exclude" (
  echo .godot/
  echo .import/
  echo /build/
  echo /dist/
  echo /android/build/
  echo /android/.build_version
  echo /final_project/
  echo .telas/
  echo __pycache__/
  echo *.apk
  echo *.aab
  echo *.idsig
  echo *.pck
  echo *.exe
  echo *.zip
  echo *.tmp
  echo *.log
  echo ~*.dll
  echo ~*.so
  echo ~*.dylib
)
echo Procurando arquivos acima de 95 MB (o GitHub recusa)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$r=(Get-Item -LiteralPath $env:PASTA).FullName.TrimEnd('\'); Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 95MB } | ForEach-Object { '/' + $_.FullName.Substring($r.Length + 1).Replace('\','/') }" > "%GD%\grandes.txt"
type "%GD%\grandes.txt" >> "%GD%\info\exclude"
set "TAM=0"
for %%s in ("%GD%\grandes.txt") do set "TAM=%%~zs"
if "%TAM%"=="0" goto :sem_grandes
echo   Estes ficam de fora:
type "%GD%\grandes.txt"
:sem_grandes
echo.

rem ---- 4. CONTINUAR DE ONDE O GITHUB ESTA (se a branch ja existir) ----
echo [1/3] Conferindo o GitHub...
%G% fetch -q "%REPO%" "%BRANCH%" >nul 2>&1
if errorlevel 1 goto :branch_nova
%G% reset -q --soft FETCH_HEAD
echo      A branch %BRANCH% ja existe: vai subir so o que mudou.
goto :juntar
:branch_nova
echo      Primeira vez: a branch %BRANCH% vai ser criada.

rem ---- 5. JUNTAR E GUARDAR ----
:juntar
echo [2/3] Juntando os arquivos (pode levar alguns minutos)...
%G% add -A
if errorlevel 1 goto :falha_add
set "NOME="
set "EMAIL="
for /f "delims=" %%a in ('git config --global user.name 2^>nul') do set "NOME=%%a"
for /f "delims=" %%a in ('git config --global user.email 2^>nul') do set "EMAIL=%%a"
if not defined NOME set "NOME=LAZER GAMES"
if not defined EMAIL set "EMAIL=lazergames@users.noreply.github.com"
rem (sem mudanca e com versao anterior: so sobe de novo, sem commit vazio)
%G% diff --cached --quiet
if errorlevel 1 goto :guardar
%G% rev-parse -q --verify HEAD >nul 2>&1
if errorlevel 1 goto :guardar
echo      Nada mudou desde a ultima vez.
goto :subir
:guardar
%G% -c user.name="%NOME%" -c user.email="%EMAIL%" commit -q -m "SuperBoxingPRO build208 - versao do PC (%DATE% %TIME:~0,5%)"
if errorlevel 1 goto :falha_add

rem ---- 6. SUBIR ----
:subir
echo [3/3] Subindo para o GitHub (se pedir login, entre com a conta do GitHub)...
%G% push "%REPO%" HEAD:refs/heads/%BRANCH%
if errorlevel 1 goto :falha_push
echo.
echo ============================================================
echo   PRONTO. A sua versao esta no GitHub:
echo   https://github.com/Bochino693/super-boxing-android7/tree/%BRANCH%
echo   A main (versao da TV Box) continua igual.
echo ============================================================
pause
exit /b 0

:sem_pasta
echo.
echo ERRO: nao achei a pasta do jogo (a que tem o project.godot).
echo Procurei em: %PADRAO%
echo Arraste a PASTA do jogo para cima deste arquivo .bat.
pause
exit /b 1

:sem_git
echo.
echo ERRO: o git nao esta instalado neste PC (https://git-scm.com/download/win).
pause
exit /b 1

:falha_init
echo.
echo ERRO: nao consegui criar %GD%.
pause
exit /b 1

:falha_add
echo.
echo ERRO ao juntar os arquivos. Fotografe esta janela e mande.
pause
exit /b 1

:falha_push
echo.
echo FALHA ao subir. Confira a internet e o login do GitHub e rode de novo.
echo (rodar de novo continua de onde parou). Se continuar, fotografe esta janela.
pause
exit /b 1
