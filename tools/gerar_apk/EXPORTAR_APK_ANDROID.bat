@echo off
setlocal
rem SUPERBOXING_BUILD=111
rem Script interno: quem chama e o GERAR_APK_AGORA.bat (na raiz), pelo
rem GERAR_APK_COMPLETO.ps1, que ja deixa o Godot 3.6.2, o modelo Android, o
rem plugin USB, o Java e a chave de assinatura prontos.
cd /d "%~dp0..\.."

if "%~1"=="" (
  echo USO: EXPORTAR_APK_ANDROID.bat "C:\caminho\Godot_v3.6.2-stable_win64.exe"
  exit /b 2
)
if not exist "%~1" (
  echo ERRO: executavel do Godot nao encontrado: %~1
  exit /b 2
)
if not exist "android\plugins\PunchUsbSerial-release.aar" (
  echo ERRO: plugin USB nao encontrado em android\plugins.
  exit /b 3
)
if not exist "android\build\build.gradle" (
  echo ERRO: modelo Android do Godot 3.6.2 nao encontrado em android\build.
  exit /b 4
)

if not exist "build\android" mkdir "build\android"
if exist "build\android\SuperBoxing.apk" del /q "build\android\SuperBoxing.apk"

rem A IMPORTACAO ACONTECE DENTRO DA EXPORTACAO. O --export do Godot 3 le a
rem pasta inteira e importa o que falta ANTES de montar o APK (e espera
rem terminar). Um passo de importacao separado ("-e --quit") fechava o
rem editor no meio da leitura ("Scan thread aborted").
rem Nada do cache (.import) e apagado a mao: o Godot 3 reimporta sozinho o
rem que mudou, e apagar um pedaco dele fazia o Godot reclamar do arquivo.

rem APK DE RELEASE, e nao de depuracao: bibliotecas nativas otimizadas e o
rem GDScript sem as checagens de depuracao -- mais rapido na TV Box.
rem --quiet: o Godot so escreve na janela se acontecer um erro de verdade.
rem Se o APK nao sair, a segunda tentativa roda sem --quiet e mostra tudo.
echo Gerando o APK (importa e monta tudo; pode levar alguns minutos)...
"%~1" --no-window --quiet --path "%CD%" --export "Android" "build\android\SuperBoxing.apk"
if not exist "build\android\SuperBoxing.apk" (
  echo O Godot fechou antes de terminar. Tentando mais uma vez, mostrando tudo...
  "%~1" --no-window --path "%CD%" --export "Android" "build\android\SuperBoxing.apk"
)
if not exist "build\android\SuperBoxing.apk" (
  echo ERRO: o Godot terminou sem criar o APK.
  exit /b 6
)
echo APK criado em build\android\SuperBoxing.apk
exit /b 0
