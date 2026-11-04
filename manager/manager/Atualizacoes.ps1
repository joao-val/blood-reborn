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

# ---------------------------------------------------------------- download e atualização
function Baixar-Url([string]$url, [string]$dest) {
    if ($SemRede) { throw 'offline' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $w = New-Object Net.WebClient; $w.Headers.Add('User-Agent', 'BloodRebornManager/' + $VERSAO_GERENCIADOR)
    try { $w.DownloadFile($url, $dest) } finally { $w.Dispose() }
}
function Conferir-Sha([string]$f, [string]$esperado) {
    return [bool]([IO.File]::Exists($f) -and $esperado -and ((Sha-Arquivo $f) -eq $esperado.ToLowerInvariant()))
}
function Pasta-Downloads {
    if ($PastaDownloads) { return $PastaDownloads }
    # a pasta Downloads de verdade (pode ter sido movida): Known Folder {374DE290-123F-4565-9164-39C4925E467B}
    try {
        $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders').'{374DE290-123F-4565-9164-39C4925E467B}'
        if ($v) { $v = [Environment]::ExpandEnvironmentVariables($v); if ([IO.Directory]::Exists($v)) { return $v } }
    } catch { }
    return (Join-Path $env:USERPROFILE 'Downloads')
}
function Esperar-Download([string]$sha, [int]$segundos) {
    # depois de abrir a página do Nexus: o primeiro .zip da pasta Downloads com o SHA-256 do catálogo (inclusive um que já
    # estava lá); um arquivo ainda sendo gravado só falha na conferência e é visto de novo na volta seguinte
    $pasta = Pasta-Downloads; $inicio = Get-Date; $vistos = @{}
    while (((Get-Date) - $inicio).TotalSeconds -lt $segundos) {
        if ($script:Cancelar) { return $null }
        foreach ($f in [IO.Directory]::GetFiles($pasta, '*.zip')) {
            $t = [IO.File]::GetLastWriteTimeUtc($f).Ticks
            if ($vistos[$f] -eq $t) { continue }
            $vistos[$f] = $t
            try { if (Conferir-Sha $f $sha) { return $f } } catch { }
        }
        if ($script:AoProgredir) { & $script:AoProgredir ((T 'u_esperando') -f [int]((Get-Date) - $inicio).TotalSeconds) }
        Start-Sleep -Milliseconds 1500
    }
    return $null
}
function Ler-Chave-Nexus {
    if ($ChaveNexus) { return $ChaveNexus }
    $cfg = Ler-Config
    if ($cfg -and $cfg.nexus) {
        try {
            $s = ConvertTo-SecureString ([string]$cfg.nexus)
            return [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
        } catch { }
    }
    return $null
}
function Gravar-Chave-Nexus([string]$chave) {
    # a chave da API do Nexus fica cifrada para este usuário do Windows (DPAPI), nunca em texto puro; vazio apaga a chave
    $script:ChaveCifrada = if ($chave) { ConvertTo-SecureString $chave -AsPlainText -Force | ConvertFrom-SecureString } else { '' }
    Gravar-Config
}
function Baixar-Pacote($estado) {
    # o zip da versão disponível, conferido pelo SHA-256 do catálogo, em <dados>\pacotes; tenta GitHub, Nexus Premium e
    # Nexus grátis (abre a página e vigia a pasta Downloads); $null se nenhum deu certo
    $m = $estado.Cat
    if (-not $m -or -not $m.sha256) { return $null }
    $dir = Join-Path $script:Dados 'pacotes'; [void][IO.Directory]::CreateDirectory($dir)
    $dest = Join-Path $dir ([string]$m.package)
    if (Conferir-Sha $dest ([string]$m.sha256)) { return $dest }
    if ($m.download) {
        try { Baixar-Url ([string]$m.download) $dest; if (Conferir-Sha $dest ([string]$m.sha256)) { return $dest } } catch { }
        if ([IO.File]::Exists($dest)) { Remove-Item -LiteralPath $dest -Force }
    }
    if ($m.nexus_mod_id -and $m.nexus_file_id) {
        $chave = Ler-Chave-Nexus
        if ($chave) {
            try {
                $u = '{0}/v1/games/bloodborne/mods/{1}/files/{2}/download_link.json' -f $NexusApi, $m.nexus_mod_id, $m.nexus_file_id
                $links = @(Web-Json $u 'GET' $null @{ apikey = $chave })
                Baixar-Url ([string]$links[0].URI) $dest
                if (Conferir-Sha $dest ([string]$m.sha256)) { return $dest }
            } catch { }
            if ([IO.File]::Exists($dest)) { Remove-Item -LiteralPath $dest -Force }
        }
        $pagina = 'https://www.nexusmods.com/bloodborne/mods/{0}?tab=files&file_id={1}' -f $m.nexus_mod_id, $m.nexus_file_id
        # [Console]::Out e não Write-Output: dentro desta função, Write-Output entraria no valor devolvido
        if ($SemNavegador) { [Console]::Out.WriteLine('ABRIR ' + $pagina) } else { Start-Process $pagina }
        $z = Esperar-Download ([string]$m.sha256) $EsperaDownload
        if ($z) { Copy-Item -LiteralPath $z -Destination $dest -Force; return $dest }
    }
    return $null
}
function Guardar-Anterior([string]$porto, [string]$pasta) {
    # 1 versão anterior para o Voltar: a pasta do mod e os patches dela
    $dest = Join-Path (Join-Path $script:Dados 'anterior') $pasta
    if ([IO.Directory]::Exists($dest)) { Remove-Item -LiteralPath $dest -Recurse -Force }
    [void][IO.Directory]::CreateDirectory((Join-Path $dest 'patches'))
    Copy-Item -LiteralPath (Join-Path (Join-Path $porto 'mods') $pasta) -Destination (Join-Path $dest 'mod') -Recurse
    $reg = Ler-Registro (Join-Path $dest 'mod')
    foreach ($x in @($reg.patches)) {
        $f = Join-Path (Join-Path $porto 'patches') ([string]$x)
        if ($x -and [IO.File]::Exists($f)) { Copy-Item -LiteralPath $f -Destination (Join-Path $dest 'patches') }
    }
}
function Atualizar-Mod([string]$porto, [string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { throw (T 'aberto') }
    $e = @(Estado-Atualizacoes $porto | Where-Object { $_.Pasta -eq $pasta })[0]
    if (-not $e -or -not $e.Disponivel) { throw ((T 'u_falhou') -f $pasta) }
    $pac = Pacote-Da-Versao $pasta $e.Disponivel
    if (-not $pac) {
        $z = Baixar-Pacote $e
        if (-not $z) { throw ((T 'u_falhou') -f $e.Nome) }
        Ler-Pacotes; $pac = Pacote-Da-Versao $pasta $e.Disponivel
        if (-not $pac) { throw ((T 'u_falhou') -f $e.Nome) }
        $script:FonteInstalacao = if ($e.Cat.download) { 'github' } else { 'nexus' }
    }
    $dm = Join-Path $porto 'mods'; $alvo = Join-Path $dm $pasta
    if ([IO.Directory]::Exists($alvo)) { Guardar-Anterior $porto $pasta; Remove-Item -LiteralPath $alvo -Recurse -Force }
    $quero = @($script:Pacotes | Where-Object { $_.Pasta -eq $pasta -or [IO.Directory]::Exists((Join-Path $dm $_.Pasta)) } | ForEach-Object { $_.Pasta })
    [void](Aplicar-Escolha $porto $quero)
    $script:FonteInstalacao = 'zip'
    return 'ok'
}

# ---------------------------------------------------------------- voltar para a versão anterior
function Versao-Anterior([string]$pasta) {
    $r = Ler-Registro (Join-Path (Join-Path (Join-Path $script:Dados 'anterior') $pasta) 'mod')
    if ($r) { return [string]$r.version }
    return $null
}
function Voltar-Mod([string]$porto, [string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { throw (T 'aberto') }
    $src = Join-Path (Join-Path $script:Dados 'anterior') $pasta
    if (-not [IO.Directory]::Exists((Join-Path $src 'mod'))) { throw (T 'u_semanterior') }
    $alvo = Join-Path (Join-Path $porto 'mods') $pasta; $dp = Join-Path $porto 'patches'
    $agora = Ler-Registro $alvo
    foreach ($x in @($agora.patches)) { $f = Join-Path $dp ([string]$x); if ($x -and [IO.File]::Exists($f)) { Remove-Item -LiteralPath $f -Force } }
    if ([IO.Directory]::Exists($alvo)) { Remove-Item -LiteralPath $alvo -Recurse -Force }
    Copy-Item -LiteralPath (Join-Path $src 'mod') -Destination $alvo -Recurse
    foreach ($f in [IO.Directory]::GetFiles((Join-Path $src 'patches'))) { Copy-Item -LiteralPath $f -Destination $dp -Force }
    Remove-Item -LiteralPath $src -Recurse -Force
    # 04/11/2026: a versão que voltou pode ter outros textos: refaz a junção com os textos do BB Port
    [void](Juntar-Textos-Port $porto)
}
