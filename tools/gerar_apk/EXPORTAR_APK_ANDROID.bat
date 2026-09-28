@echo off
setlocal
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

rem IMPORTAR ANTES DE EXPORTAR. Com a importacao num passo proprio (e
rem repetida uma vez, se cair), a exportacao ja encontra tudo pronto.
rem O modelo 3D e reimportado do zero: uma cena importada antiga guardada em
rem .import pode apontar para texturas que mudaram.
if exist ".import" del /q ".import\boxeador.glb-*" 2>nul

echo Importando recursos do projeto...
"%~1" --no-window --path "%CD%" -e --quit
"%~1" --no-window --path "%CD%" -e --quit

rem APK DE RELEASE, e nao de depuracao: bibliotecas nativas otimizadas e o
rem GDScript sem as checagens de depuracao -- mais rapido na TV Box.
echo Gerando o APK...
"%~1" --no-window --path "%CD%" --export "Android" "build\android\SuperBoxing.apk"
if not exist "build\android\SuperBoxing.apk" (
  echo O Godot fechou antes de terminar. Tentando mais uma vez...
  "%~1" --no-window --path "%CD%" --export "Android" "build\android\SuperBoxing.apk"
)
if not exist "build\android\SuperBoxing.apk" (
  echo ERRO: o Godot terminou sem criar o APK.
  exit /b 6
)
echo APK criado em build\android\SuperBoxing.apk
exit /b 0
