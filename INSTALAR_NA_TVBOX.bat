@echo off
setlocal
cd /d "%~dp0"
title Super Boxing S905L - Instalar na TV Box

rem Instala o APK por cima do atual (-r): ranking, fotos e ajustes ficam.
rem Com a TV Box na rede, passe o IP:  INSTALAR_NA_TVBOX.bat 192.168.0.50
rem
rem ASSINATURA: da build 110 em diante o APK sai sempre com a chave do
rem projeto (tools\gerar_apk\superboxing.keystore), igual em qualquer PC.
rem Se na TV Box estiver um Super Boxing assinado com a chave antiga (a de
rem cada PC), o Android recusa instalar por cima: este .bat desinstala o
rem antigo UMA vez e instala o novo. Depois disso, sempre por cima.
set "ADB=C:\AndroidSdk\platform-tools\adb.exe"
set "APK=build\android\SuperBoxing.apk"
set "PACOTE=com.lazersport.superboxing"
set "SAIDA=%TEMP%\superboxing_instalar.txt"
if not exist "%ADB%" (
  echo ERRO: adb nao encontrado em %ADB%
  pause
  exit /b 1
)
if not exist "%APK%" (
  echo ERRO: gere o APK antes com GERAR_APK_AGORA.bat
  pause
  exit /b 1
)
if not "%~1"=="" "%ADB%" connect %~1:5555

echo Instalando por cima do atual...
"%ADB%" install -r "%APK%" > "%SAIDA%" 2>&1
type "%SAIDA%"
findstr /c:"Success" "%SAIDA%" >nul && goto instalado

rem Versao mais nova ja instalada: aceita voltar a versao.
findstr /c:"VERSION_DOWNGRADE" "%SAIDA%" >nul && (
  echo.
  echo A TV Box tem uma build mais nova. Instalando esta por cima mesmo assim...
  "%ADB%" install -r -d "%APK%" > "%SAIDA%" 2>&1
  type "%SAIDA%"
  findstr /c:"Success" "%SAIDA%" >nul && goto instalado
)

rem Assinatura diferente (APK antigo gerado em outro PC / chave antiga).
findstr /c:"UPDATE_INCOMPATIBLE" /c:"INCONSISTENT_CERTIFICATES" /c:"signatures do not match" /c:"SHARED_USER_INCOMPATIBLE" "%SAIDA%" >nul && (
  echo.
  echo O Super Boxing da TV Box tem OUTRA ASSINATURA ^(chave antiga^).
  echo Desinstalando o antigo uma vez e instalando o novo...
  echo ^(o ranking e as fotos do antigo sao apagados nesta troca^)
  "%ADB%" uninstall %PACOTE%
  "%ADB%" install "%APK%" > "%SAIDA%" 2>&1
  type "%SAIDA%"
  findstr /c:"Success" "%SAIDA%" >nul && goto instalado
)

findstr /c:"INSUFFICIENT_STORAGE" "%SAIDA%" >nul && (
  echo.
  echo SEM ESPACO NA TV BOX. Apague videos/apps que nao usa e rode de novo.
)
echo.
echo FALHA NA INSTALACAO. Fotografe esta janela inteira.
pause
exit /b 1

:instalado
rem Camera liberada pela linha de comando: o jogo nao pergunta nunca.
"%ADB%" shell pm grant %PACOTE% android.permission.CAMERA
echo.
echo INSTALADO. Abra o Super Boxing na TV Box.
pause
exit /b 0
