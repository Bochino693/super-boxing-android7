$ErrorActionPreference = "Stop"
# Este script mora em tools\gerar_apk; o projeto e a pasta dois niveis acima.
#
# VERSAO 4.6 PRO: o jogo roda no GODOT 4.6.1 (OpenGL ES 3). E para TV Box
# com placa de video OpenGL ES 3.0 ou mais nova. A TV Box S905L (Mali-450,
# so OpenGL ES 2.0) continua com a versao Godot 3.6 (build 112).
$Scripts = $PSScriptRoot
$Raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $Raiz

# O NUMERO DA BUILD. Cada script desta versao carrega o mesmo carimbo
# (SUPERBOXING_BUILD=...): se a pasta tiver arquivos de builds diferentes
# misturados (zip novo extraido por cima de um velho), a geracao para aqui,
# antes de fazer qualquer coisa.
$Build = 208

$env:ANDROID_HOME = "C:\AndroidSdk"
$env:ANDROID_SDK_ROOT = "C:\AndroidSdk"
$ApkEsperado = Join-Path $Raiz "build\android\SuperBoxingPRO.apk"
$PluginPronto = Join-Path $Raiz "addons\PunchUsbSerial\bin\release\PunchUsbSerial-release.aar"

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
#      de importacao, plugin antigo. Um script do Godot 3 esquecido na pasta
#      e erro na importacao do Godot 4. Imagens, sons, APKs e relatorios
#      seus nunca sao apagados.
if (-not (Test-Path -LiteralPath (Join-Path $Raiz "addons\PunchUsbSerial\plugin.cfg"))) {
    Parar "Esta pasta nao e a versao 4.6 PRO (Godot 4.6). Pasta atual: $Raiz"
}
$ListaDaBuild = Join-Path $Scripts "arquivos_build.txt"
# A LISTA NUNCA SOME. Uma geracao anterior (build 200/201 antigas) guardava
# a propria lista como "sobra": na segunda vez faltava a lista. Se ela
# estiver nas sobras, volta para o lugar antes de tudo.
$ListaGuardada = Join-Path $Raiz "sobras_de_versoes_antigas\tools\gerar_apk\arquivos_build.txt"
if ((-not (Test-Path -LiteralPath $ListaDaBuild)) -and (Test-Path -LiteralPath $ListaGuardada)) {
    Move-Item -LiteralPath $ListaGuardada -Destination $ListaDaBuild -Force
    Write-Host "      Lista da build trazida de volta das sobras." -ForegroundColor Yellow
}
if (-not (Test-Path -LiteralPath $ListaDaBuild)) {
    Parar "Falta tools\gerar_apk\arquivos_build.txt. Extraia o zip da build $Build de novo (as duas partes)."
}
$DaBuild = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($Linha in [System.IO.File]::ReadAllLines($ListaDaBuild)) {
    if ($Linha.Trim()) { [void]$DaBuild.Add($Linha.Trim().Replace('/', '\')) }
}
# A CHAVE DE ASSINATURA TAMBEM MORA AQUI DENTRO (base64 do arquivo
# tools\gerar_apk\superboxing.keystore). Se o arquivo sumir (zip extraido
# pela metade, antivirus, ou guardado como "sobra"), ela volta IGUAL: a
# assinatura do APK nao muda nunca.
$ChaveDoJogoBase64 = "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"
$ArquivoDaChave = Join-Path $Raiz "tools\gerar_apk\superboxing.keystore"

# UM ARQUIVO DA BUILD GUARDADO COMO "SOBRA" (por uma geracao anterior com a
# lista desatualizada) VOLTA PARA O LUGAR antes da conferencia.
$PastaDeSobras = Join-Path $Raiz "sobras_de_versoes_antigas"
if (Test-Path -LiteralPath $PastaDeSobras) {
    foreach ($Item in $DaBuild) {
        $Destino = Join-Path $Raiz $Item
        $Guardado = Join-Path $PastaDeSobras $Item
        if ((-not (Test-Path -LiteralPath $Destino)) -and (Test-Path -LiteralPath $Guardado)) {
            New-Item -ItemType Directory -Path (Split-Path $Destino) -Force | Out-Null
            Move-Item -LiteralPath $Guardado -Destination $Destino -Force
            Write-Host "      Arquivo da build trazido de volta das sobras: $Item" -ForegroundColor Yellow
        }
    }
}
if (-not (Test-Path -LiteralPath $ArquivoDaChave)) {
    New-Item -ItemType Directory -Path (Split-Path $ArquivoDaChave) -Force | Out-Null
    [System.IO.File]::WriteAllBytes($ArquivoDaChave, [System.Convert]::FromBase64String($ChaveDoJogoBase64))
    Write-Host "      Chave de assinatura do jogo recriada (a mesma de sempre)." -ForegroundColor Yellow
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
$Guardadas = "sobras_de_versoes_antigas"
$PastasDoPC = @('.git', '.godot', '.import', 'build', 'android\build', $Guardadas,
    'tools\android_usb_plugin\.gradle', 'tools\android_usb_plugin\build', 'tools\android_usb_plugin\plugin\build')
$PastasDoPC += $Aninhadas
# Arquivos que os proprios .bat criam neste PC (nao vem no zip).
$ArquivosDoPC = @('tools\gerar_apk\arquivos_build.txt', 'android\.build_version', 'tools\android_usb_plugin\local.properties', 'CAMERA_RELATORIO.txt', 'ABERTURA_RELATORIO.txt', 'launchers_desligados.txt')
# As pastas do jogo (as que aparecem na lista da build): dentro delas,
# qualquer arquivo fora da lista e sobra de versao antiga. Na raiz, so os
# tipos de arquivo do jogo; o resto (seus arquivos) fica onde esta.
$PastasDoJogo = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($Item in $DaBuild) { if ($Item.Contains('\')) { [void]$PastasDoJogo.Add($Item.Split('\')[0]) } }
$ExtensoesDeJogo = @('.gd', '.tscn', '.tres', '.gdshader', '.shader', '.uid', '.import', '.cfg',
    '.gdns', '.gdnlib', '.aar', '.gdap', '.bat', '.ps1', '.kt', '.kts')
# NADA E APAGADO: as sobras sao MOVIDAS para sobras_de_versoes_antigas (que o
# Godot ignora), com o mesmo caminho de antes.
function Guardar-Sobra([string]$Caminho, [string]$Rel) {
    $Destino = Join-Path (Join-Path $Raiz $Guardadas) $Rel
    New-Item -ItemType Directory -Path (Split-Path $Destino) -Force | Out-Null
    if (Test-Path -LiteralPath $Destino) { Remove-Item -LiteralPath $Destino -Recurse -Force }
    Move-Item -LiteralPath $Caminho -Destination $Destino -Force
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $Raiz $Guardadas) ".gdignore"), "")
}
$Removidos = 0
$RaizBarra = $Raiz.TrimEnd('\') + '\'
foreach ($Arquivo in (Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force -ErrorAction SilentlyContinue)) {
    $Rel = $Arquivo.FullName.Substring($RaizBarra.Length)
    $DoPC = $false
    foreach ($Pasta in $PastasDoPC) { if ($Rel.StartsWith($Pasta + '\', [StringComparison]::OrdinalIgnoreCase)) { $DoPC = $true; break } }
    if ($DoPC -or $DaBuild.Contains($Rel) -or $Arquivo.Name -eq ".gdignore" -or $ArquivosDoPC -contains $Rel) { continue }
    $NaPastaDoJogo = $Rel.Contains('\') -and $PastasDoJogo.Contains($Rel.Split('\')[0])
    if ($NaPastaDoJogo -or ($ExtensoesDeJogo -contains $Arquivo.Extension.ToLower())) {
        Guardar-Sobra $Arquivo.FullName $Rel
        $Removidos++
    }
}
# A pasta de cache do Godot 3 (.import) de uma versao S905L extraida aqui
# antes: so cache, pode ir embora. O cache do Godot 4 (.godot) fica.
if (Test-Path -LiteralPath (Join-Path $Raiz '.import')) {
    Remove-Item -LiteralPath (Join-Path $Raiz '.import') -Recurse -Force
    $Removidos++
}
if ($Removidos -gt 0) {
    Write-Host "      Sobras de versoes antigas tiradas do projeto: $Removidos (guardadas em $Guardadas)." -ForegroundColor Yellow
}

# PASTAS QUE NAO SAO DO JOGO (fotos, backups, downloads guardados aqui):
# o Godot importaria e poria no APK tudo o que achasse nelas, e um arquivo
# estragado ali virava erro na exportacao. Um .gdignore faz o Godot ignorar
# a pasta; nada dela e apagado nem mexido.
foreach ($Pasta in (Get-ChildItem -LiteralPath $Raiz -Directory -Force -ErrorAction SilentlyContinue)) {
    if ($PastasDoJogo.Contains($Pasta.Name) -or @('.git', '.godot', '.import', 'build', $Guardadas) -contains $Pasta.Name) { continue }
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
if (-not ((Get-Content -LiteralPath (Join-Path $Raiz "scripts\versao.gd") -Raw) -match "const NUMERO :?= $Build\b")) { $Misturados += "scripts\versao.gd" }
if (-not ((Get-Content -LiteralPath (Join-Path $Raiz "export_presets.cfg") -Raw) -match "(?m)^version/code=$Build\b")) { $Misturados += "export_presets.cfg" }
if ($Misturados.Count -gt 0) {
    Parar ("Estes arquivos nao sao da build ${Build}:`n  " + ($Misturados -join "`n  ") +
        "`nExtraia o zip da build $Build de novo, respondendo SIM para substituir tudo.")
}

if (-not (Test-Path -LiteralPath $PluginPronto)) {
    Parar "Plugin USB nao encontrado em addons\PunchUsbSerial\bin\release. Extraia o zip de novo."
}
if (-not ((Get-Content -LiteralPath (Join-Path $Raiz "project.godot") -Raw) -match "addons/PunchUsbSerial/plugin\.cfg")) {
    Parar "O project.godot nao liga o plugin PunchUsbSerial. Extraia o zip de novo."
}

# Apaga o resultado ANTES de qualquer compilacao. Assim uma falha no plugin
# jamais deixa o APK da execucao anterior parecendo ser o novo.
if (Test-Path $ApkEsperado) {
    Remove-Item -LiteralPath $ApkEsperado -Force
}

Write-Host "Projeto confirmado: Super Boxing PRO - build $Build - Godot 4.6.1 (OpenGL ES 3)" -ForegroundColor Green

# ------------------------------------------------------------------
# ESPACO EM DISCO. Sem espaco o Gradle falha no meio ("Espaco insuficiente
# no disco") e o Godot chega a corromper o proprio arquivo de configuracao
# (perdendo o caminho do Java). Com pouco espaco, os temporarios do Gradle
# e do Godot sao limpos antes de comecar.
function Espaco-Livre-GB([string]$Caminho) {
    $raizDisco = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $Caminho).Path)
    $info = New-Object System.IO.DriveInfo($raizDisco)
    return [math]::Round($info.AvailableFreeSpace / 1GB, 1)
}
function Limpar-Temporarios {
    $alvos = @(
        (Join-Path $env:TEMP "PunchChallenge-Godot-4.6.1"),
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
    Get-ChildItem (Join-Path $env:USERPROFILE ".gradle\daemon") -Recurse -Filter "*.log" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
function Espaco-Minimo {
    return [math]::Min((Espaco-Livre-GB $Raiz), (Espaco-Livre-GB $env:USERPROFILE))
}
$Livre = Espaco-Minimo
if ($Livre -lt 6) {
    Write-Host "Pouco espaco em disco ($Livre GB). Limpando temporarios do Gradle e do Godot..." -ForegroundColor Yellow
    Limpar-Temporarios
    $Livre = Espaco-Minimo
    Write-Host "      Espaco livre agora: $Livre GB" -ForegroundColor Yellow
}
if ($Livre -lt 3) {
    Parar "DISCO CHEIO: so $Livre GB livres. Libere pelo menos 5 GB (esvazie a Lixeira, apague videos e downloads antigos) e rode de novo."
}

if (-not (Test-Path "$env:ANDROID_HOME\platform-tools\adb.exe")) {
    Parar "SDK Android invalido em C:\AndroidSdk. Falta platform-tools\adb.exe."
}

$Godot = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like "Godot*" -and $_.Path } |
    Select-Object -First 1 -ExpandProperty Path

if (-not $Godot) {
    $Godot = Get-ChildItem `
        "$env:USERPROFILE\Downloads", `
        "$env:USERPROFILE\Documents" `
        -Recurse -File -Include "Godot_v4.6.1-stable_win64*.exe" `
        -ErrorAction SilentlyContinue |
        Sort-Object { if ($_.Name -like "*console*") { 0 } else { 1 } } |
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $Godot -or -not (Test-Path $Godot)) {
    Parar "Godot 4.6.1 nao encontrado. Abra o editor e execute este arquivo novamente."
}

# O modelo Android do projeto depende dos Export Templates globais. O Godot
# nao os baixa com --install-android-build-template; esse comando apenas copia
# o template global ja instalado. Instale automaticamente a versao EXATA.
$TemplateDir = Join-Path $env:APPDATA "Godot\export_templates\4.6.1.stable"
$AndroidDebugTemplate = Join-Path $TemplateDir "android_debug.apk"
$AndroidReleaseTemplate = Join-Path $TemplateDir "android_release.apk"
$AndroidSourceTemplate = Join-Path $TemplateDir "android_source.zip"
if (-not (Test-Path $AndroidDebugTemplate) -or
    -not (Test-Path $AndroidReleaseTemplate) -or
    -not (Test-Path $AndroidSourceTemplate)) {
    Write-Host "[0/4] Baixando Export Templates oficiais do Godot 4.6.1..." -ForegroundColor Cyan
    Write-Host "      Primeira vez: o download e grande e pode demorar." -ForegroundColor Yellow
    $TemplateUrl = "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=4.6.1"
    $TempBase = Join-Path $env:TEMP "PunchChallenge-Godot-4.6.1"
    $TemplateZip = Join-Path $TempBase "export_templates_4.6.1.zip"
    $TemplateExtraido = Join-Path $TempBase "extraido"
    New-Item -ItemType Directory -Path $TempBase -Force | Out-Null
    Remove-Item -LiteralPath $TemplateZip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $TemplateExtraido -Recurse -Force -ErrorAction SilentlyContinue

    & curl.exe -L --fail --retry 3 --output $TemplateZip $TemplateUrl
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $TemplateZip)) {
        Parar "Falha ao baixar Export Templates oficiais do Godot 4.6.1. Confira a internet e tente novamente."
    }
    Expand-Archive -LiteralPath $TemplateZip -DestinationPath $TemplateExtraido -Force
    $OrigemTemplates = Join-Path $TemplateExtraido "templates"
    if (-not (Test-Path (Join-Path $OrigemTemplates "android_debug.apk"))) {
        Parar "O pacote oficial foi baixado, mas nao contem android_debug.apk."
    }
    New-Item -ItemType Directory -Path $TemplateDir -Force | Out-Null
    Copy-Item -Path (Join-Path $OrigemTemplates "*") -Destination $TemplateDir -Recurse -Force
    if (-not (Test-Path $AndroidDebugTemplate) -or
        -not (Test-Path $AndroidReleaseTemplate) -or
        -not (Test-Path $AndroidSourceTemplate)) {
        Parar "Nao foi possivel instalar os modelos Android em $TemplateDir"
    }
    Write-Host "      Export Templates 4.6.1 instalados." -ForegroundColor Green
}

if (
    -not (Test-Path ".\android\build\build.gradle") -and
    -not (Test-Path ".\android\build.gradle")
) {
    Write-Host "[1/4] Extraindo modelo Android diretamente no projeto..." -ForegroundColor Cyan
    # Nao abre o editor: nesta maquina o Godot 4.6.1 cai com signal 11 depois
    # de importar os recursos. O botao do editor apenas extrai este mesmo ZIP.
    $AndroidBuildDir = Join-Path $Raiz "android\build"
    Remove-Item -LiteralPath $AndroidBuildDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $AndroidBuildDir -Force | Out-Null
    Expand-Archive -LiteralPath $AndroidSourceTemplate -DestinationPath $AndroidBuildDir -Force
    if (-not (Test-Path (Join-Path $AndroidBuildDir "build.gradle"))) {
        Parar "android_source.zip foi extraido, mas android\build\build.gradle nao apareceu."
    }
    Write-Host "      Modelo Android instalado sem abrir o editor." -ForegroundColor Green
}

# O POM antigo do AUSBC aponta para dois artefatos opcionais que existiam no
# JCenter e nao sao usados pela captura UVC do jogo. A exclusao tambem precisa
# existir no modelo Android do projeto; caso contrario o plugin compila, mas a
# exportacao final volta a tentar baixa-los.
$AndroidBuildGradle = Join-Path $Raiz "android\build\build.gradle"
if (-not (Test-Path -LiteralPath $AndroidBuildGradle)) {
    Parar "Modelo Android incompleto: nao encontrei $AndroidBuildGradle"
}
$MarcadorDependencias = "PUNCH_UVC_JCENTER_OPTIONALS_EXCLUDED_V2"
$AndroidGradleTexto = Get-Content -LiteralPath $AndroidBuildGradle -Raw
if ($AndroidGradleTexto -notmatch $MarcadorDependencias) {
    $BlocoExclusao = @'

// PUNCH_UVC_JCENTER_OPTIONALS_EXCLUDED_V2
// As dependencias remotas do Godot ficam no PROJETO RAIZ. A primeira regra
// corrige exatamente :standardDebugRuntimeClasspath.
configurations.configureEach {
    exclude group: "com.gyf.immersionbar", module: "immersionbar"
    exclude group: "com.zlc.glide", module: "webpdecoder"
}

// Mantem a mesma protecao caso uma versao futura mova as dependencias para
// app, asset packs ou outro subprojeto.
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
# [2/4] O PLUGIN USB (Arduino + webcam) VEM PRONTO em addons\PunchUsbSerial,
# com o PunchSerialSeguro (a leitura do Arduino que nao derruba o jogo) dentro
# do mesmo .aar. Ele nao e recompilado a cada APK: recompilar so trazia
# espera, internet e mensagens do Gradle. Quem mexer no Kotlin/Java roda
# tools\gerar_apk\RECOMPILAR_PLUGIN_USB.bat uma vez.
Write-Host "[2/4] Plugin USB/UVC pronto: $PluginPronto" -ForegroundColor Cyan

# ------------------------------------------------------------------
# A CONFIGURACAO DO GODOT (Java e SDK Android) SEMPRE CERTA. Se o arquivo
# de configuracao do editor estiver corrompido (acontece quando o disco
# enche no meio de uma gravacao) ele e refeito; se faltar o caminho do
# Java ou do SDK, ele e preenchido. Sem isto a exportacao para com "Um
# caminho valido para o Java SDK e necessario".
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
$Configuracao = Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"
$SemBom = New-Object System.Text.UTF8Encoding($false)
$Java = Achar-Java
$JavaGodot = if ($Java) { $Java -replace '\\', '/' } else { "" }
$Texto = ""
if (Test-Path -LiteralPath $Configuracao) {
    $Texto = [System.IO.File]::ReadAllText($Configuracao)
}
if (-not $Texto -or -not $Texto.TrimStart([char]0xFEFF, ' ', "`r", "`n", "`t").StartsWith("[gd_resource")) {
    if (Test-Path -LiteralPath $Configuracao) {
        Copy-Item -LiteralPath $Configuracao -Destination "$Configuracao.quebrado" -Force
        Write-Host "      Configuracao do Godot estava corrompida: refeita." -ForegroundColor Yellow
    }
    New-Item -ItemType Directory -Path (Split-Path $Configuracao) -Force | Out-Null
    $Texto = "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`n"
}
function Garantir-Chave([string]$Chave, [string]$Valor) {
    if (-not $Valor) { return }
    $linha = "$Chave = `"$Valor`""
    $padrao = [regex]::Escape($Chave) + '\s*=\s*"[^"]*"'
    if ($script:Texto -match $padrao) {
        $script:Texto = [regex]::Replace($script:Texto, $padrao, $linha.Replace('$', '$$'))
    } else {
        $script:Texto = $script:Texto.TrimEnd() + "`n" + $linha + "`n"
    }
}
$JavaAtual = ""
if ($Texto -match 'export/android/java_sdk_path\s*=\s*"([^"]*)"') { $JavaAtual = $Matches[1] }
if (-not $JavaAtual -or -not (Test-Path -LiteralPath (Join-Path $JavaAtual "bin\java.exe"))) {
    if (-not $JavaGodot) {
        Parar "Java 17 nao encontrado neste PC. Instale o Java 17 (Eclipse Temurin 17) e rode de novo."
    }
    Garantir-Chave "export/android/java_sdk_path" $JavaGodot
    Write-Host "      Java configurado no Godot: $JavaGodot" -ForegroundColor Green
}
Garantir-Chave "export/android/android_sdk_path" "C:/AndroidSdk"
[System.IO.File]::WriteAllText($Configuracao, $Texto, $SemBom)


# ------------------------------------------------------------------
# [3/4] A ASSINATURA. UMA CHAVE SO, DENTRO DO PROJETO
# (tools\gerar_apk\superboxing.keystore): o APK sai com a MESMA assinatura em
# qualquer PC, e a atualizacao instala por cima sem apagar ranking e ajustes.
$Chave = Join-Path $Raiz "tools\gerar_apk\superboxing.keystore"
if (-not (Test-Path -LiteralPath $Chave)) {
    [System.IO.File]::WriteAllBytes($Chave, [System.Convert]::FromBase64String($ChaveDoJogoBase64))
}
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Chave
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "superboxing"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = "superboxing"
Write-Host "[3/4] Assinatura: chave do jogo (superboxing.keystore)" -ForegroundColor Cyan

# ------------------------------------------------------------------
# [4/4] O APK.
Write-Host "[4/4] Exportando APK..." -ForegroundColor Cyan
& (Join-Path $Scripts "EXPORTAR_APK_ANDROID.bat") "$Godot"
if ($LASTEXITCODE -ne 0) {
    Parar "A exportacao do Godot falhou."
}

$Apk = Get-Item $ApkEsperado -ErrorAction Stop
if ($Apk.Length -lt 1MB) {
    Parar "APK incompleto: $($Apk.Length) bytes."
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
    $Dexes = ""
    foreach ($Dex in ($Zip.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' })) {
        $Leitor = New-Object System.IO.StreamReader($Dex.Open(), [System.Text.Encoding]::GetEncoding(28591))
        $Dexes += $Leitor.ReadToEnd()
        $Leitor.Close()
    }
    if (-not $Dexes.Contains("Lcom/lazersport/punch/usbserial/GodotAndroidPlugin;")) {
        Parar "O APK saiu SEM o plugin USB (Arduino e camera nao funcionariam)."
    }
    if (-not $Dexes.Contains("Lcom/lazersport/punch/usbserial/PunchSerialSeguro;")) {
        Parar "O APK saiu SEM o PunchSerialSeguro (a USB do Arduino voltaria a derrubar o jogo)."
    }
} finally {
    $Zip.Dispose()
}

# Os modelos de exportacao ja foram instalados: o pacote baixado (mais de
# 1 GB) nao precisa ficar ocupando o disco.
Remove-Item -LiteralPath (Join-Path $env:TEMP "PunchChallenge-Godot-4.6.1") -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "APK GERADO E CONFERIDO - build $Build (4.6 PRO), sem erros" -ForegroundColor Green
Write-Host "Conferido: motor ARM 32 e 64 bits e plugin USB (Arduino + camera) dentro do APK."
Write-Host "Arquivo: $($Apk.FullName)"
Write-Host "Tamanho: $([math]::Round($Apk.Length / 1MB, 2)) MB"
