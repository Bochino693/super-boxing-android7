@echo off
setlocal
rem SUPERBOXING_BUILD=99
rem OPCIONAL: so para quem mexer no codigo do plugin USB (Kotlin, em
rem tools\android_usb_plugin). O GERAR_APK_AGORA.bat NAO compila o plugin:
rem ele usa o que ja vem pronto em android\plugins. Rode este arquivo uma vez
rem depois de mudar o Kotlin; o plugin novo substitui o pronto.
rem Precisa ter gerado um APK antes (o modelo Android fica em android\build).
cd /d "%~dp0..\.."

if not exist "android\build\libs\release\godot-lib.release.aar" (
  echo ERRO: o modelo Android do Godot 3.6.2 ainda nao foi extraido em android\build.
  exit /b 1
)
if not exist "tools\android_usb_plugin\gradlew.bat" (
  echo ERRO: fonte do plugin USB nao encontrado.
  exit /b 1
)

set "ANDROID_HOME=C:\AndroidSdk"
set "ANDROID_SDK_ROOT=C:\AndroidSdk"
if not exist "%ANDROID_HOME%\platform-tools\adb.exe" (
  echo ERRO: SDK Android invalido em %ANDROID_HOME%.
  exit /b 1
)
set "ANDROID_SDK_GRADLE=%ANDROID_HOME:\=/%"
>"tools\android_usb_plugin\local.properties" echo sdk.dir=%ANDROID_SDK_GRADLE%

echo [1/3] Compilando driver USB Android...
if exist "tools\android_usb_plugin\plugin\demo" rmdir /s /q "tools\android_usb_plugin\plugin\demo"
pushd "tools\android_usb_plugin"
call gradlew.bat clean assemble --refresh-dependencies --warning-mode none
if errorlevel 1 (
  popd
  echo ERRO: confira Java 17, Android SDK e a conexao com a internet.
  exit /b 1
)
popd

rem A tarefa Gradle cria uma copia de demonstracao com o mesmo UID do addon.
rem Ela nao pertence ao jogo e faria o Godot carregar o plugin duas vezes.
if exist "tools\android_usb_plugin\plugin\demo" rmdir /s /q "tools\android_usb_plugin\plugin\demo"
if exist "tools\android_usb_plugin\plugin\demo" (
  echo ERRO: nao consegui remover a copia temporaria do plugin.
  exit /b 1
)

echo [2/3] Instalando o plugin no projeto Godot 3...
rem Godot 3: o plugin mora em android\plugins (o .aar e o .gdap que o
rem descreve). O .gdap ja vem pronto no projeto.
if not exist "android\plugins" mkdir "android\plugins"
if not exist "tools\android_usb_plugin\plugin\build\outputs\aar\PunchUsbSerial-release.aar" (
  echo ERRO: o AAR release nao foi gerado.
  exit /b 1
)
copy /y "tools\android_usb_plugin\plugin\build\outputs\aar\PunchUsbSerial-release.aar" "android\plugins\PunchUsbSerial-release.aar" >nul

echo [3/3] Plugin pronto em android\plugins. Agora rode o GERAR_APK_AGORA.bat.
exit /b 0
