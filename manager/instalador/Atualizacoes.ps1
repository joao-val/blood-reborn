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

# ---------------------------------------------------------------- catálogo (GitHub) e Nexus
function Web-Json([string]$url, [string]$metodo = 'GET', $corpo = $null, [hashtable]$cab = @{}) {
    if ($SemRede) { throw 'offline' }
    if ($url -notmatch '^https?://') { return ([IO.File]::ReadAllText($url, [Text.Encoding]::UTF8) | ConvertFrom-Json) }  # arquivo local
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $h = @{ 'Application-Name' = 'BloodRebornManager'; 'Application-Version' = $VERSAO_GERENCIADOR }
    foreach ($k in $cab.Keys) { $h[$k] = $cab[$k] }
    $pr = @{ Uri = $url; Method = $metodo; Headers = $h; TimeoutSec = 15; UseBasicParsing = $true }
    if ($corpo) { $pr.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $corpo -Depth 6 -Compress)); $pr.ContentType = 'application/json' }
    return Invoke-RestMethod @pr
}
function Ler-Cache([string]$nome, [double]$horas) {
    $f = Join-Path $script:Dados $nome
    if (-not [IO.File]::Exists($f)) { return $null }
    $c = [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8) | ConvertFrom-Json
    return [pscustomobject]@{ Dado = $c; Fresco = (((Get-Date) - [IO.File]::GetLastWriteTime($f)).TotalHours -lt $horas) }
}
function Gravar-Cache([string]$nome, $dado) {
    [void][IO.Directory]::CreateDirectory($script:Dados)
    [IO.File]::WriteAllText((Join-Path $script:Dados $nome), (ConvertTo-Json $dado -Depth 10), $script:Utf8)
}
function Ler-Catalogo([switch]$Forcar) {
    # o catálogo do GitHub (sem login), guardado por 24 h; sem rede: o guardado (mesmo velho) ou nada
    $c = Ler-Cache 'catalogo_cache.json' 24
    if ($c -and $c.Fresco -and -not $Forcar) { return $c.Dado }
    try { $cat = Web-Json $Catalogo; Gravar-Cache 'catalogo_cache.json' $cat; return $cat }
    catch { $script:AvisoRede = T 'u_semrede'; if ($c) { return $c.Dado }; return $null }
}
function Consultar-Nexus([int]$modId, [switch]$Forcar) {
    # versão e arquivos principais do mod no Nexus (API pública GraphQL v2, sem chave), guardados por 24 h
    $c = Ler-Cache ('nexus_{0}.json' -f $modId) 24
    if ($c -and $c.Fresco -and -not $Forcar) { return $c.Dado }
    $q = '{ legacyModsByDomain(ids: [{gameDomain: "bloodborne", modId: ' + $modId + '}]) { nodes { version updatedAt } } ' +
         'modFiles(modId: ' + $modId + ', gameId: 2708) { fileId name version category uri } }'
    try {
        $r = Web-Json ($NexusApi + '/v2/graphql') 'POST' @{ query = $q }
        $nx = [pscustomobject]@{ Versao = [string](@($r.data.legacyModsByDomain.nodes)[0].version)
                                 Arquivos = @($r.data.modFiles | Where-Object { $_.category -eq 'MAIN' }) }
        Gravar-Cache ('nexus_{0}.json' -f $modId) $nx; return $nx
    } catch { $script:AvisoRede = T 'u_semrede'; if ($c) { return $c.Dado }; return $null }
}
function Notas-Entre($cat, [string]$desde) {
    # as notas das versões depois de $desde (todas, se $desde vazio), da mais nova para a mais velha, no idioma da janela
    $out = @()
    if (-not $cat -or -not $cat.changes) { return $out }
    foreach ($p in $cat.changes.PSObject.Properties) {
        if ($desde -and $desde -ne 'unknown' -and (Versao-Num $p.Name) -le (Versao-Num $desde)) { continue }
        $t = $p.Value.$script:Ling; if (-not $t) { $t = $p.Value.en }
        $out += [pscustomobject]@{ Versao = $p.Name; Texto = [string]$t }
    }
    return @($out | Sort-Object { Versao-Num $_.Versao } -Descending)
}
function Estado-Atualizacoes([string]$porto, [switch]$Forcar) {
    $script:AvisoRede = $null
    $cat = Ler-Catalogo -Forcar:$Forcar
    $por = [ordered]@{}
    foreach ($p in $script:Pacotes) { $por[$p.Pasta] = [pscustomobject]@{ Pasta = $p.Pasta; Nome = $p.Nome; Local = $p.Versao; Cat = $null } }
    if ($cat) {
        foreach ($m in @($cat.mods)) {
            $k = [string]$m.folder
            if (-not $por.Contains($k)) { $por[$k] = [pscustomobject]@{ Pasta = $k; Nome = [string]$m.name; Local = $null; Cat = $null } }
            $por[$k].Cat = $m
        }
    }
    $out = @()
    foreach ($e in $por.Values) {
        $inst = if ($porto) { Versao-Instalada $porto $e.Pasta } else { $null }
        $disp = $e.Local; $fontes = @(); $nx = $null
        if ($e.Local) { $fontes += 'zip' }
        if ($e.Cat) {
            $cv = [string]$e.Cat.version
            if (-not $disp -or (Versao-Num $cv) -gt (Versao-Num $disp)) { $disp = $cv }
            if ($e.Cat.download) { $fontes += 'github' }
            if ($e.Cat.nexus_mod_id) {
                $nx = Consultar-Nexus ([int]$e.Cat.nexus_mod_id) -Forcar:$Forcar
                $fontes += 'nexus'
                if ($nx -and $nx.Versao -and (Versao-Num $nx.Versao) -gt (Versao-Num $disp)) { $disp = $nx.Versao }
            }
        }
        $novo = [bool]($inst -and $disp -and ($inst -eq 'unknown' -or (Versao-Num $disp) -gt (Versao-Num $inst)))
        $out += [pscustomobject]@{ Pasta = $e.Pasta; Nome = $e.Nome; Instalada = $inst; Disponivel = $disp; Atualizar = $novo
                                   Notas = @(Notas-Entre $e.Cat $inst); Fontes = $fontes; Cat = $e.Cat; Nexus = $nx }
    }
    return $out
}
