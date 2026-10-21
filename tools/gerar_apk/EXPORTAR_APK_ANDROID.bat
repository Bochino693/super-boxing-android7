@echo off
setlocal
rem SUPERBOXING_BUILD=208
rem Script interno: quem chama e o GERAR_APK_AGORA.bat (na raiz).
cd /d "%~dp0..\.."

if "%~1"=="" (
  echo USO: EXPORTAR_APK_ANDROID.bat "C:\caminho\Godot_v4.6.1-stable_win64_console.exe"
  exit /b 2
)
if not exist "%~1" (
  echo ERRO: executavel do Godot nao encontrado: %~1
  exit /b 2
)
if not exist "addons\PunchUsbSerial\bin\release\PunchUsbSerial-release.aar" (
  echo ERRO: falta o plugin USB. Extraia o zip de novo ou rode RECOMPILAR_PLUGIN_USB.bat.
  exit /b 3
)
if not exist "android\build\build.gradle" if not exist "android\build.gradle" (
  echo ERRO: no Godot, use Projeto ^> Instalar modelo de compilacao Android.
  exit /b 4
)

rem APK DE RELEASE, e nao de depuracao. O de depuracao leva as bibliotecas
rem nativas sem otimizar e sem remover simbolos (era o que fazia o APK
rem passar de 200 MB) e roda o GDScript com as checagens de depuracao
rem ligadas -- mais lento justamente na TV Box.
rem
rem A assinatura e a chave do jogo (tools\gerar_apk\superboxing.keystore):
rem o GERAR_APK_COMPLETO.ps1 passa o caminho, o usuario e a senha nas
rem variaveis GODOT_ANDROID_KEYSTORE_RELEASE_*.
if "%GODOT_ANDROID_KEYSTORE_RELEASE_PATH%"=="" (
  set "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=%CD%\tools\gerar_apk\superboxing.keystore"
  set "GODOT_ANDROID_KEYSTORE_RELEASE_USER=superboxing"
  set "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=superboxing"
)

if not exist "build\android" mkdir "build\android"
if exist "build\android\SuperBoxingPRO.apk" del /q "build\android\SuperBoxingPRO.apk"

rem IMPORTAR ANTES DE EXPORTAR. Quando uma fonte ou imagem muda, o Godot
rem reimporta tudo no inicio da exportacao e, no Windows, pode fechar no
rem meio disso sem criar o APK. Com a importacao feita num passo proprio
rem (e repetida uma vez, se cair), a exportacao ja encontra tudo pronto.
rem OS MODELOS 3D SAO REIMPORTADOS DO ZERO. Quando uma atualizacao troca
rem as texturas de um .glb (o boxeador, por exemplo), a cena importada
rem antiga guardada em .godot ainda aponta para as texturas que sumiram e
rem o Godot mostra "Unrecognized UID" -- inofensivo, mas assusta. Apagar
rem so as cenas .glb importadas resolve; o Godot as refaz em segundos.
if exist ".godot\imported" del /q ".godot\imported\*.glb-*.scn" ".godot\imported\*.glb-*.md5" 2>nul

echo Importando recursos do projeto...
"%~1" --headless --path "%CD%" --import
"%~1" --headless --path "%CD%" --import

echo Gerando o APK...
"%~1" --headless --path "%CD%" --export-release "Android" "build\android\SuperBoxingPRO.apk"
if not exist "build\android\SuperBoxingPRO.apk" (
  echo O Godot fechou antes de terminar. Tentando mais uma vez...
  "%~1" --headless --path "%CD%" --export-release "Android" "build\android\SuperBoxingPRO.apk"
)
if not exist "build\android\SuperBoxingPRO.apk" (
  echo ERRO: o Godot terminou sem criar o APK.
  exit /b 6
)
echo APK criado em build\android\SuperBoxingPRO.apk
exit /b 0
