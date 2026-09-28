$ErrorActionPreference = "Stop"
# Este script mora em tools\gerar_apk; o projeto e a pasta dois niveis acima.
#
# VERSAO TV BOX S905L: o jogo roda no GODOT 3.6.2, porque a placa de video
# dessa TV Box (Mali-450) so tem OpenGL ES 2.0 e o Godot 4 exige o 3.0.
# Este script acha (ou baixa) o Godot 3.6.2 e os modelos de exportacao,
# prepara o modelo Android, o plugin USB e gera o APK.
$Scripts = $PSScriptRoot
$Raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Raiz

# O NUMERO DA BUILD. Cada script desta versao carrega o mesmo carimbo
# (SUPERBOXING_BUILD=...): se a pasta tiver arquivos de builds diferentes
# misturados (zip novo extraido por cima de um velho), a geracao para aqui,
# antes de fazer qualquer coisa.
$Build = 96
$VersaoGodot = "3.6.2"
$VersaoModelos = "3.6.2.stable"
$UrlBase = "https://github.com/godotengine/godot/releases/download/3.6.2-stable"

$env:ANDROID_HOME = "C:\AndroidSdk"
$env:ANDROID_SDK_ROOT = "C:\AndroidSdk"
$ApkEsperado = Join-Path $Raiz "build\android\SuperBoxing.apk"
$PluginPronto = Join-Path $Raiz "android\plugins\PunchUsbSerial-release.aar"

# Qualquer falha sai UMA vez, em portugues, sem o bloco tecnico do
# PowerShell (linha, caractere, CategoryInfo...).
function Parar([string]$Motivo) {
    Write-Host ""
    Write-Host $Motivo -ForegroundColor Red
    exit 1
}
trap {
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------
# A PASTA TEM EXATAMENTE OS ARQUIVOS DESTA BUILD.
#
# tools\gerar_apk\arquivos_build.txt e a lista de todos os arquivos que
# vieram no zip. Com ela:
#   1. se falta algum (zip extraido pela metade), a geracao para e diz qual;
#   2. arquivo de JOGO que sobrou de uma versao antiga (zip novo extraido por
#      cima do velho) e APAGADO sozinho: script, cena, shader, configuracao
#      de importacao, plugin antigo. Um script do Godot 4 esquecido na pasta
#      e erro na importacao do Godot 3. Imagens, sons, APKs e relatorios
#      seus nunca sao apagados.
if (-not (Test-Path -LiteralPath (Join-Path $Raiz "scripts\compat.gd"))) {
    Parar "Esta pasta nao e a versao S905L (Godot 3.6). Pasta atual: $Raiz"
}
$ListaDaBuild = Join-Path $Scripts "arquivos_build.txt"
if (-not (Test-Path -LiteralPath $ListaDaBuild)) {
    Parar "Falta tools\gerar_apk\arquivos_build.txt. Extraia o zip da build $Build de novo (as duas partes)."
}
$DaBuild = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($Linha in [System.IO.File]::ReadAllLines($ListaDaBuild)) {
    if ($Linha.Trim()) { [void]$DaBuild.Add($Linha.Trim().Replace('/', '\')) }
}
$Faltando = @($DaBuild | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Raiz $_)) })
if ($Faltando.Count -gt 0) {
    Parar ("O ZIP NAO FOI EXTRAIDO INTEIRO. Faltam $($Faltando.Count) arquivo(s), por exemplo:`n  " +
        (($Faltando | Select-Object -First 8) -join "`n  ") +
        "`nExtraia as DUAS partes do zip da build $Build (PARTE1 e PARTE2) na mesma pasta.")
}

# Uma segunda copia do projeto DENTRO desta pasta (zip extraido "aqui"
# dentro da pasta velha): o Godot a importaria junto. Um .gdignore faz o
# Godot ignorar a pasta inteira; nada dela e apagado nem mexido.
$Aninhadas = @()
foreach ($Sub in (Get-ChildItem -LiteralPath $Raiz -Directory -Recurse -Force -ErrorAction SilentlyContinue)) {
    if ($Sub.FullName -like "*\.git*") { continue }
    if (Test-Path -LiteralPath (Join-Path $Sub.FullName "project.godot")) {
        $Aninhadas += $Sub.FullName.Substring($Raiz.TrimEnd('\').Length + 1)
        if (-not (Test-Path -LiteralPath (Join-Path $Sub.FullName ".gdignore"))) {
            [System.IO.File]::WriteAllText((Join-Path $Sub.FullName ".gdignore"), "")
            Write-Host "      Outra copia do projeto dentro desta pasta, ignorada: $($Sub.FullName)" -ForegroundColor Yellow
        }
    }
}

# Pastas que sao so do PC (resultado, caches, modelo Android): nao entram
# na comparacao e nao sao mexidas aqui.
$PastasDoPC = @('.git', '.import', 'build', 'android\build',
    'tools\android_usb_plugin\.gradle', 'tools\android_usb_plugin\build', 'tools\android_usb_plugin\plugin\build')
$PastasDoPC += $Aninhadas
$ExtensoesDeJogo = @('.gd', '.tscn', '.tres', '.gdshader', '.shader', '.uid', '.import', '.cfg',
    '.gdns', '.gdnlib', '.aar', '.gdap', '.bat', '.ps1', '.kt', '.kts')
$Removidos = 0
$RaizBarra = $Raiz.TrimEnd('\') + '\'
foreach ($Arquivo in (Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $Rel = $Arquivo.FullName.Substring($RaizBarra.Length)
    $DoPC = $false
    foreach ($Pasta in $PastasDoPC) { if ($Rel.StartsWith($Pasta + '\', [StringComparison]::OrdinalIgnoreCase)) { $DoPC = $true; break } }
    if ($DoPC -or $DaBuild.Contains($Rel)) { continue }
    if ($ExtensoesDeJogo -contains $Arquivo.Extension.ToLower()) {
        Remove-Item -LiteralPath $Arquivo.FullName -Force
        $Removidos++
    }
}
# A pasta de cache do Godot 4 e o plugin antigo do Godot 4 inteiros.
foreach ($Velha in @('.godot', 'addons')) {
    $Caminho = Join-Path $Raiz $Velha
    if (Test-Path -LiteralPath $Caminho) {
        Remove-Item -LiteralPath $Caminho -Recurse -Force
        $Removidos++
    }
}
if ($Removidos -gt 0) {
    Write-Host "      Sobras de versoes antigas removidas desta pasta: $Removidos." -ForegroundColor Yellow
}

# PASTAS QUE NAO SAO DO JOGO (fotos, backups, downloads guardados aqui):
# o Godot importaria e poria no APK tudo o que achasse nelas, e um arquivo
# estragado ali virava erro na exportacao. Um .gdignore faz o Godot ignorar
# a pasta; nada dela e apagado nem mexido.
$PastasDoJogo = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($Item in $DaBuild) { if ($Item.Contains('\')) { [void]$PastasDoJogo.Add($Item.Split('\')[0]) } }
foreach ($Pasta in (Get-ChildItem -LiteralPath $Raiz -Directory -Force -ErrorAction SilentlyContinue)) {
    if ($PastasDoJogo.Contains($Pasta.Name) -or @('.git', '.import', 'build') -contains $Pasta.Name) { continue }
    $Marca = Join-Path $Pasta.FullName ".gdignore"
    if (-not (Test-Path -LiteralPath $Marca)) {
        [System.IO.File]::WriteAllText($Marca, "")
        Write-Host "      Pasta que nao e do jogo, ignorada pelo Godot: $($Pasta.Name)" -ForegroundColor Yellow
    }
}

# Os scripts que fazem a geracao sao desta build (carimbo SUPERBOXING_BUILD).
$Carimbados = @("GERAR_APK_AGORA.bat", "tools\gerar_apk\EXPORTAR_APK_ANDROID.bat", "tools\gerar_apk\RECOMPILAR_PLUGIN_USB.bat")
$Misturados = @()
foreach ($Arquivo in $Carimbados) {
    if (-not ((Get-Content -LiteralPath (Join-Path $Raiz $Arquivo) -Raw) -match "SUPERBOXING_BUILD=$Build\b")) { $Misturados += $Arquivo }
}
if (-not ((Get-Content -LiteralPath (Join-Path $Raiz "scripts\versao.gd") -Raw) -match "const NUMERO = $Build\b")) { $Misturados += "scripts\versao.gd" }
if (-not ((Get-Content -LiteralPath (Join-Path $Raiz "export_presets.cfg") -Raw) -match "(?m)^version/code=$Build\b")) { $Misturados += "export_presets.cfg" }
if ($Misturados.Count -gt 0) {
    Parar ("Estes arquivos nao sao da build ${Build}:`n  " + ($Misturados -join "`n  ") +
        "`nExtraia o zip da build $Build de novo, respondendo SIM para substituir tudo.")
}

$PluginGdap = Join-Path $Raiz "android\plugins\PunchUsbSerial.gdap"
if (-not (Test-Path -LiteralPath $PluginPronto) -or -not (Test-Path -LiteralPath $PluginGdap)) {
    Parar "Plugin USB nao encontrado em android\plugins (PunchUsbSerial-release.aar e .gdap). Extraia o zip de novo."
}

# Apaga o resultado ANTES de qualquer compilacao. Assim uma falha no plugin
# jamais deixa o APK da execucao anterior parecendo ser o novo.
if (Test-Path $ApkEsperado) {
    Remove-Item -LiteralPath $ApkEsperado -Force
}

Write-Host "Projeto confirmado: Super Boxing - build $Build - TV Box S905L (Android 7.1) - Godot $VersaoGodot" -ForegroundColor Green

# ------------------------------------------------------------------
# ESPACO EM DISCO. Sem espaco o Gradle falha no meio ("Espaco insuficiente
# no disco"). Com pouco espaco, os temporarios do Gradle sao limpos antes.
function Espaco-Livre-GB([string]$Caminho) {
    $raizDisco = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $Caminho).Path)
    $info = New-Object System.IO.DriveInfo($raizDisco)
    return [math]::Round($info.AvailableFreeSpace / 1GB, 1)
}
function Limpar-Temporarios {
    $alvos = @(
        (Join-Path $env:TEMP "SuperBoxing-Godot-$VersaoGodot"),
        (Join-Path $env:USERPROFILE ".gradle\.tmp"),
        (Join-Path $env:USERPROFILE ".gradle\caches\build-cache-1"),
        (Join-Path $Raiz "android\build\build"),
        (Join-Path $Raiz "android\build\.gradle"),
        (Join-Path $Raiz "tools\android_usb_plugin\plugin\build"),
        (Join-Path $Raiz "tools\android_usb_plugin\build"),
        (Join-Path $Raiz "tools\android_usb_plugin\.gradle")
    )
    foreach ($a in $alvos) {
        if (Test-Path -LiteralPath $a) {
            Remove-Item -LiteralPath $a -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
function Espaco-Minimo {
    return [math]::Min((Espaco-Livre-GB $Raiz), (Espaco-Livre-GB $env:USERPROFILE))
}
$Livre = Espaco-Minimo
if ($Livre -lt 6) {
    Write-Host "Pouco espaco em disco ($Livre GB). Limpando temporarios do Gradle..." -ForegroundColor Yellow
    Limpar-Temporarios
    $Livre = Espaco-Minimo
    Write-Host "      Espaco livre agora: $Livre GB" -ForegroundColor Yellow
}
if ($Livre -lt 3) {
    throw "DISCO CHEIO: so $Livre GB livres. Libere pelo menos 5 GB (esvazie a Lixeira, apague videos e downloads antigos) e rode de novo."
}

if (-not (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) {
    throw "SDK Android invalido em C:\AndroidSdk. Falta platform-tools\adb.exe."
}

function Baixar([string]$Url, [string]$Destino) {
    Remove-Item -LiteralPath $Destino -Force -ErrorAction SilentlyContinue
    & curl.exe -L --fail --retry 3 --output $Destino $Url
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Destino)) {
        throw "Falha ao baixar $Url. Confira a internet e tente novamente."
    }
}

# ------------------------------------------------------------------
# [0/4] O GODOT 3.6.2. Procura aberto, em Downloads/Documentos ou na pasta
# propria deste script; se nao achar, baixa (uma vez so, ~40 MB).
$PastaGodot = Join-Path $env:LOCALAPPDATA "SuperBoxing\Godot_v$VersaoGodot"
$Godot = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like "Godot*" -and $_.Path -and $_.Path -like "*$VersaoGodot*" } |
    Select-Object -First 1 -ExpandProperty Path
if (-not $Godot) {
    $Godot = Get-ChildItem "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents", $PastaGodot `
        -Recurse -File -Include "Godot_v$VersaoGodot-stable_win64*.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Host "[0/4] Baixando o Godot $VersaoGodot (primeira vez)..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $PastaGodot -Force | Out-Null
    $Zip = Join-Path $PastaGodot "godot.zip"
    Baixar "$UrlBase/Godot_v$VersaoGodot-stable_win64.exe.zip" $Zip
    Expand-Archive -LiteralPath $Zip -DestinationPath $PastaGodot -Force
    Remove-Item -LiteralPath $Zip -Force -ErrorAction SilentlyContinue
    $Godot = Get-ChildItem $PastaGodot -Recurse -File -Include "Godot_v$VersaoGodot-stable_win64*.exe" |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $Godot) {
        throw "O Godot $VersaoGodot foi baixado, mas o executavel nao apareceu em $PastaGodot."
    }
}
Write-Host "      Godot: $Godot" -ForegroundColor Green

# Os modelos de exportacao do Godot 3 moram em %APPDATA%\Godot\templates.
$TemplateDir = Join-Path $env:APPDATA "Godot\templates\$VersaoModelos"
$AndroidSourceTemplate = Join-Path $TemplateDir "android_source.zip"
if (-not (Test-Path (Join-Path $TemplateDir "android_release.apk")) -or
    -not (Test-Path $AndroidSourceTemplate)) {
    Write-Host "[0/4] Baixando os modelos de exportacao do Godot $VersaoGodot..." -ForegroundColor Cyan
    Write-Host "      Primeira vez: o download e grande (~600 MB) e pode demorar." -ForegroundColor Yellow
    $TempBase = Join-Path $env:TEMP "SuperBoxing-Godot-$VersaoGodot"
    $TemplateZip = Join-Path $TempBase "templates.zip"
    $TemplateExtraido = Join-Path $TempBase "extraido"
    New-Item -ItemType Directory -Path $TempBase -Force | Out-Null
    Remove-Item -LiteralPath $TemplateExtraido -Recurse -Force -ErrorAction SilentlyContinue
    Baixar "$UrlBase/Godot_v$VersaoGodot-stable_export_templates.tpz" $TemplateZip
    Expand-Archive -LiteralPath $TemplateZip -DestinationPath $TemplateExtraido -Force
    $OrigemTemplates = Join-Path $TemplateExtraido "templates"
    if (-not (Test-Path (Join-Path $OrigemTemplates "android_source.zip"))) {
        throw "O pacote oficial foi baixado, mas nao contem android_source.zip."
    }
    New-Item -ItemType Directory -Path $TemplateDir -Force | Out-Null
    Copy-Item -Path (Join-Path $OrigemTemplates "*") -Destination $TemplateDir -Recurse -Force
    Remove-Item -LiteralPath $TempBase -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $AndroidSourceTemplate)) {
        throw "Nao foi possivel instalar os modelos Android em $TemplateDir"
    }
    Write-Host "      Modelos $VersaoModelos instalados." -ForegroundColor Green
}

# ------------------------------------------------------------------
# [1/4] O MODELO ANDROID DENTRO DO PROJETO (android\build). O Godot 3 so
# aceita o modelo da MESMA versao: o arquivo android\.build_version diz qual.
$AndroidBuildDir = Join-Path $Raiz "android\build"
$VersaoDoModelo = Join-Path $Raiz "android\.build_version"
$ModeloOk = (Test-Path (Join-Path $AndroidBuildDir "build.gradle")) -and
    (Test-Path $VersaoDoModelo) -and ((Get-Content -LiteralPath $VersaoDoModelo -Raw).Trim() -eq $VersaoModelos)
if (-not $ModeloOk) {
    Write-Host "[1/4] Extraindo o modelo Android do Godot $VersaoGodot no projeto..." -ForegroundColor Cyan
    Remove-Item -LiteralPath $AndroidBuildDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $AndroidBuildDir -Force | Out-Null
    Expand-Archive -LiteralPath $AndroidSourceTemplate -DestinationPath $AndroidBuildDir -Force
    if (-not (Test-Path (Join-Path $AndroidBuildDir "build.gradle"))) {
        throw "android_source.zip foi extraido, mas android\build\build.gradle nao apareceu."
    }
    [System.IO.File]::WriteAllText($VersaoDoModelo, $VersaoModelos)
    # O Godot nao deve importar nada de dentro do modelo Android.
    [System.IO.File]::WriteAllText((Join-Path $AndroidBuildDir ".gdignore"), "")
    Write-Host "      Modelo Android instalado." -ForegroundColor Green
}

# TV BOX: o jogo aparece na tela inicial da TV (Leanback) e pode ser o
# aplicativo de inicio da maquina (HOME), como na versao do Godot 4. No
# Godot 3 isso e escrito no manifesto do modelo Android.
$Manifesto = Join-Path $AndroidBuildDir "AndroidManifest.xml"
$ManifestoTexto = [System.IO.File]::ReadAllText($Manifesto)
if ($ManifestoTexto -notmatch "SUPERBOXING_TV_BOX") {
    $Categorias = @'
<category android:name="android.intent.category.LAUNCHER" />
                <!-- SUPERBOXING_TV_BOX: tela inicial da TV e aplicativo de inicio -->
                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
'@
    $ManifestoTexto = $ManifestoTexto.Replace('<category android:name="android.intent.category.LAUNCHER" />', $Categorias.TrimEnd())
    $Recursos = @'
    <uses-feature android:name="android.software.leanback" android:required="false" />
    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />
    <uses-feature android:name="android.hardware.usb.host" android:required="false" />
<!--CHUNK_USER_PERMISSIONS_BEGIN-->
'@
    $ManifestoTexto = $ManifestoTexto.Replace('<!--CHUNK_USER_PERMISSIONS_BEGIN-->', $Recursos.TrimEnd())
    [System.IO.File]::WriteAllText($Manifesto, $ManifestoTexto, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "      Manifesto: TV Box (Leanback + inicio)." -ForegroundColor Green
}

# O POM antigo do AUSBC aponta para dois artefatos opcionais que existiam no
# JCenter e nao sao usados pela captura UVC do jogo. A exclusao precisa
# existir no modelo Android do projeto; caso contrario a exportacao tenta
# baixa-los e falha.
$AndroidBuildGradle = Join-Path $AndroidBuildDir "build.gradle"
$MarcadorDependencias = "PUNCH_UVC_JCENTER_OPTIONALS_EXCLUDED_V2"
$AndroidGradleTexto = Get-Content -LiteralPath $AndroidBuildGradle -Raw
if ($AndroidGradleTexto -notmatch $MarcadorDependencias) {
    $BlocoExclusao = @'

// PUNCH_UVC_JCENTER_OPTIONALS_EXCLUDED_V2
configurations.configureEach {
    exclude group: "com.gyf.immersionbar", module: "immersionbar"
    exclude group: "com.zlc.glide", module: "webpdecoder"
}
subprojects {
    configurations.configureEach {
        exclude group: "com.gyf.immersionbar", module: "immersionbar"
        exclude group: "com.zlc.glide", module: "webpdecoder"
    }
}
'@
    Add-Content -LiteralPath $AndroidBuildGradle -Value $BlocoExclusao -Encoding UTF8
    Write-Host "      Dependencias opcionais antigas do AUSBC desativadas." -ForegroundColor Green
}

# ------------------------------------------------------------------
# JAVA 17: o Gradle do modelo Android usa o JAVA_HOME.
function Achar-Java {
    $candidatos = @()
    if ($env:JAVA_HOME) { $candidatos += $env:JAVA_HOME }
    $candidatos += Get-ChildItem "C:\Program Files\Eclipse Adoptium", "C:\Program Files\Java", `
        "C:\Program Files\Microsoft", "C:\Program Files\Zulu", "C:\Program Files\OpenJDK" `
        -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '17' } |
        Sort-Object Name -Descending |
        Select-Object -ExpandProperty FullName
    $candidatos += "C:\Program Files\Android\Android Studio\jbr"
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($java) { $candidatos += (Split-Path (Split-Path $java.Source)) }
    foreach ($d in $candidatos) {
        if ($d -and (Test-Path -LiteralPath (Join-Path $d "bin\java.exe"))) {
            return (Resolve-Path -LiteralPath $d).Path
        }
    }
    return $null
}
$Java = Achar-Java
if (-not $Java) {
    throw "Java 17 nao encontrado neste PC. Instale o Java 17 (Eclipse Temurin 17) e rode de novo."
}
$env:JAVA_HOME = $Java
$env:Path = (Join-Path $Java "bin") + ";" + $env:Path

# ------------------------------------------------------------------
# [2/4] O PLUGIN USB (Arduino + webcam) VEM PRONTO em android\plugins (o
# .aar e o .gdap). Ele nao e recompilado a cada APK: e sempre o mesmo, e
# recompilar so trazia espera, internet e mensagens do Gradle. Quem mexer no
# Kotlin roda tools\gerar_apk\RECOMPILAR_PLUGIN_USB.bat uma vez.
Write-Host "[2/4] Plugin USB/UVC pronto: $PluginPronto" -ForegroundColor Cyan

# ------------------------------------------------------------------
# [3/4] A ASSINATURA. A mesma chave de sempre (a de depuracao do Godot, em
# %APPDATA%\Godot\keystores): o APK novo instala POR CIMA do anterior sem
# apagar ranking e ajustes. Se este PC nunca gerou APK, a chave e criada.
$Chave = Join-Path $env:APPDATA "Godot\keystores\debug.keystore"
if (-not (Test-Path $Chave)) {
    Write-Host "      Criando a chave de assinatura (primeira vez neste PC)..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path (Split-Path $Chave) -Force | Out-Null
    & (Join-Path $Java "bin\keytool.exe") -genkeypair -v -keystore $Chave -storepass android `
        -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=Android Debug,O=Android,C=US" | Out-Null
    if (-not (Test-Path $Chave)) { throw "Nao foi possivel criar a chave de assinatura em $Chave" }
}
$ChaveGodot = $Chave -replace '\\', '/'
$JavaGodot = $Java -replace '\\', '/'

# A configuracao do editor do Godot 3 (SDK, Java e a chave de depuracao).
$Configuracao = Join-Path $env:APPDATA "Godot\editor_settings-3.tres"
$SemBom = New-Object System.Text.UTF8Encoding($false)
$Texto = ""
if (Test-Path -LiteralPath $Configuracao) {
    $Texto = [System.IO.File]::ReadAllText($Configuracao)
}
if (-not $Texto -or -not $Texto.TrimStart([char]0xFEFF, ' ', "`r", "`n", "`t").StartsWith("[gd_resource")) {
    New-Item -ItemType Directory -Path (Split-Path $Configuracao) -Force | Out-Null
    $Texto = "[gd_resource type=`"EditorSettings`" format=2]`n`n[resource]`n"
}
function Garantir-Chave([string]$Nome, [string]$Valor) {
    $linha = "$Nome = `"$Valor`""
    $padrao = [regex]::Escape($Nome) + '\s*=\s*"[^"]*"'
    if ($script:Texto -match $padrao) {
        $script:Texto = [regex]::Replace($script:Texto, $padrao, $linha.Replace('$', '$$'))
    } else {
        $script:Texto = $script:Texto.TrimEnd() + "`n" + $linha + "`n"
    }
}
Garantir-Chave "export/android/android_sdk_path" "C:/AndroidSdk"
Garantir-Chave "export/android/java_sdk_path" $JavaGodot
Garantir-Chave "export/android/debug_keystore" $ChaveGodot
Garantir-Chave "export/android/debug_keystore_user" "androiddebugkey"
Garantir-Chave "export/android/debug_keystore_pass" "android"
[System.IO.File]::WriteAllText($Configuracao, $Texto, $SemBom)

# APK de RELEASE assinado com a mesma chave: o Godot 3 le a chave de release
# do preset de exportacao.
$Preset = Join-Path $Raiz "export_presets.cfg"
$PresetTexto = [System.IO.File]::ReadAllText($Preset)
$PresetTexto = [regex]::Replace($PresetTexto, '(?m)^keystore/release=.*$', "keystore/release=`"$ChaveGodot`"")
$PresetTexto = [regex]::Replace($PresetTexto, '(?m)^keystore/release_user=.*$', 'keystore/release_user="androiddebugkey"')
$PresetTexto = [regex]::Replace($PresetTexto, '(?m)^keystore/release_password=.*$', 'keystore/release_password="android"')
[System.IO.File]::WriteAllText($Preset, $PresetTexto, $SemBom)

# ------------------------------------------------------------------
# O CACHE DE IMPORTACAO (.import) E DESTA BUILD, OU NAO E USADO. Um cache de
# outra build (ou pela metade) fazia o Godot reclamar de arquivos que nao
# existiam. Sem a marca desta build: o cache e apagado e os .import voltam
# ao estado de fabrica; a exportacao importa tudo do zero, sem erro.
$Cache = Join-Path $Raiz ".import"
$MarcaDoCache = Join-Path $Cache ".superboxing_build"
$CacheDestaBuild = (Test-Path -LiteralPath $MarcaDoCache) -and
    ((Get-Content -LiteralPath $MarcaDoCache -Raw).Trim() -eq "$Build")
if (-not $CacheDestaBuild) {
    Write-Host "      Preparando a importacao do zero (primeira geracao desta build)..." -ForegroundColor Cyan
    if (Test-Path -LiteralPath $Cache) {
        Remove-Item -LiteralPath $Cache -Recurse -Force
    }
    Get-ChildItem -LiteralPath $Raiz -Recurse -File -Filter "*.import" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "*\android\build\*" } |
        ForEach-Object {
            $Texto = [System.IO.File]::ReadAllText($_.FullName)
            $Novo = [regex]::Replace($Texto, '(?m)^(path(\.\w+)?|dest_files)=.*\r?\n', '')
            $Novo = [regex]::Replace($Novo, '(?ms)^metadata=\{.*?^\}\r?\n', '')
            if ($Novo -ne $Texto) {
                [System.IO.File]::WriteAllText($_.FullName, $Novo, (New-Object System.Text.UTF8Encoding($false)))
            }
        }
}

# ------------------------------------------------------------------
# [4/4] O APK.
Write-Host "[4/4] Exportando APK..." -ForegroundColor Cyan
& (Join-Path $Scripts "EXPORTAR_APK_ANDROID.bat") "$Godot"
if ($LASTEXITCODE -ne 0) {
    throw "A exportacao do Godot falhou."
}

$Apk = Get-Item $ApkEsperado -ErrorAction Stop
if ($Apk.Length -lt 1MB) {
    Parar "APK incompleto: $($Apk.Length) bytes."
}

# O cache agora e desta build: as proximas geracoes nao importam tudo de novo.
if (Test-Path -LiteralPath $Cache) {
    [System.IO.File]::WriteAllText($MarcaDoCache, "$Build")
}

# CONFERE O QUE VAI PARA A TV BOX: o motor para as duas arquiteturas e o
# plugin USB (sem ele, nada de Arduino nem camera) dentro do APK.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Zip = [System.IO.Compression.ZipFile]::OpenRead($Apk.FullName)
try {
    $Nomes = $Zip.Entries | ForEach-Object { $_.FullName }
    foreach ($Lib in @("lib/armeabi-v7a/libgodot_android.so", "lib/arm64-v8a/libgodot_android.so")) {
        if ($Nomes -notcontains $Lib) { Parar "O APK saiu sem $Lib." }
    }
    $TemPlugin = $false
    foreach ($Dex in ($Zip.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' })) {
        $Leitor = New-Object System.IO.StreamReader($Dex.Open(), [System.Text.Encoding]::GetEncoding(28591))
        $Conteudo = $Leitor.ReadToEnd()
        $Leitor.Close()
        if ($Conteudo.Contains("Lcom/lazersport/punch/usbserial/GodotAndroidPlugin;")) { $TemPlugin = $true; break }
    }
    if (-not $TemPlugin) { Parar "O APK saiu SEM o plugin USB (Arduino e camera nao funcionariam)." }
} finally {
    $Zip.Dispose()
}

Write-Host ""
Write-Host "APK GERADO E CONFERIDO - build $Build, sem erros" -ForegroundColor Green
Write-Host "Conferido: motor ARM 32 e 64 bits e plugin USB (Arduino + camera) dentro do APK."
Write-Host "Arquivo: $($Apk.FullName)"
Write-Host "Tamanho: $([math]::Round($Apk.Length / 1MB, 2)) MB"
Write-Host "SHA256: $((Get-FileHash -LiteralPath $Apk.FullName -Algorithm SHA256).Hash)"
