# Blood Reborn - atualizações (fase 2, 04/11/2026): registro da versão instalada, catálogo do GitHub, Nexus, downloads,
# atualizar e voltar. Carregado pelo BloodReborn.ps1 (usa $TXT, T, Ler-Pacotes, Aplicar-Escolha, Conferir-Pasta...).

function Sha-Arquivo([string]$f) {
    $s = [IO.File]::OpenRead($f)
    try { return ([BitConverter]::ToString($script:Sha.ComputeHash($s)) -replace '-', '').ToLowerInvariant() } finally { $s.Close() }
}
function Gravar-Registro([string]$pasta, $pac, [string]$fonte) {
    # o que foi instalado: versão, de onde veio, os patches e o SHA-256 e o tamanho de cada arquivo (para conferir sem o zip)
    $arqs = [ordered]@{}; $base = $pasta.TrimEnd('\').Length + 1
    foreach ($f in [IO.Directory]::GetFiles($pasta, '*', 'AllDirectories')) {
        $rel = $f.Substring($base).Replace('\', '/')
        if ($rel -eq $REGISTRO) { continue }
        $arqs[$rel] = [ordered]@{ sha256 = (Sha-Arquivo $f); size = (New-Object IO.FileInfo $f).Length }
    }
    $reg = [ordered]@{ folder = $pac.Pasta; name = $pac.Nome; version = $pac.Versao; installed = (Get-Date).ToString('s')
                       source = $fonte; patches = @($pac.Patches); files = $arqs }
    [IO.File]::WriteAllText((Join-Path $pasta $REGISTRO), (ConvertTo-Json $reg -Depth 5), $script:Utf8)
}
function Ler-Registro([string]$pasta) {
    $f = Join-Path $pasta $REGISTRO
    if (-not [IO.File]::Exists($f)) { return $null }
    try { return ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json) } catch { return $null }
}
function Conferir-Registro([string]$pasta, [switch]$Rapido) {
    # -1 = sem registro; senão arquivos estragados, faltando ou sobrando contra o registro
    if (-not [IO.Directory]::Exists($pasta)) { return -1 }
    $r = Ler-Registro $pasta; if (-not $r -or -not $r.files) { return -1 }
    $ruins = 0; $vistos = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $r.files.PSObject.Properties) {
        [void]$vistos.Add($p.Name); $f = Join-Path $pasta ($p.Name.Replace('/', '\'))
        if (-not [IO.File]::Exists($f) -or (New-Object IO.FileInfo $f).Length -ne [long]$p.Value.size) { $ruins++; continue }
        if (-not $Rapido -and (Sha-Arquivo $f) -ne [string]$p.Value.sha256) { $ruins++ }
    }
    $base = $pasta.TrimEnd('\').Length + 1
    foreach ($f in [IO.Directory]::GetFiles($pasta, '*', 'AllDirectories')) {
        $rel = $f.Substring($base).Replace('\', '/')
        if ($rel -ne $REGISTRO -and -not $vistos.Contains($rel)) { $ruins++ }
    }
    return $ruins
}
function Pacote-Da-Versao([string]$pasta, [string]$versao) {
    return @($script:TodosPacotes | Where-Object { $_.Pasta -eq $pasta -and $_.Versao -eq $versao })[0]
}
function Versao-Instalada([string]$porto, [string]$pasta) {
    # $null = não instalado; a versão do registro; sem registro, a do pacote local igual à pasta; senão 'unknown'
    $alvo = Join-Path (Join-Path $porto 'mods') $pasta
    if (-not [IO.Directory]::Exists($alvo)) { return $null }
    $r = Ler-Registro $alvo
    if ($r -and $r.version) { return [string]$r.version }
    foreach ($p in @($script:TodosPacotes | Where-Object { $_.Pasta -eq $pasta })) {
        if ((Conferir-Pasta $p.Zip $p.Prefixo $alvo -Rapido) -eq 0) { return $p.Versao }
    }
    return 'unknown'
}
