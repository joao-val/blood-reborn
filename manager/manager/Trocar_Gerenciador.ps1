<#
Blood Reborn Mod Manager - troca de versão do próprio gerenciador (2.2, 04/11/2026), como o lançador do BB Port faz.
O gerenciador copia este arquivo para a pasta temporária e o roda escondido; ele:
  1. espera a janela do gerenciador fechar (-Espera = o processo dela);
  2. guarda a versão atual (a pasta manager\ e os arquivos de cima que a nova traz) em <dados>\gerenciador\anterior;
  3. troca a pasta manager\ inteira pela nova e copia os arquivos de cima (o .bat, o LEIA-ME); os zips de mods ao lado
     do gerenciador e a pasta "2 - Mods" não são tocados;
  4. confere cada arquivo pelo SHA-256; se algo falhar, volta a versão anterior e deixa o motivo em falhou.txt;
  5. abre o gerenciador de novo (-Continuar: ele segue atualizando os mods).
#>
param([string]$Origem, [string]$Destino, [string]$Dados, [string]$Versao = '', [int]$Espera = 0, [switch]$Continuar, [switch]$SemReabrir)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $Dados 'gerenciador'; $ant = Join-Path $dir 'anterior'
$utf8 = New-Object Text.UTF8Encoding $false
[void][IO.Directory]::CreateDirectory($dir)
function Sha([string]$f) { return (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }
$codigo = 0
try {
    if ($Espera -gt 0) {
        try { Wait-Process -Id $Espera -Timeout 120 -ErrorAction Stop } catch { }
        if (Get-Process -Id $Espera -ErrorAction SilentlyContinue) { throw 'a janela do gerenciador não fechou' }
    }
    $base = $Origem.TrimEnd('\').Length + 1
    $novos = @([IO.Directory]::GetFiles($Origem, '*', 'AllDirectories') | ForEach-Object { $_.Substring($base) })
    if (-not ($novos -contains 'manager\BloodReborn.ps1')) { throw 'a versão nova não tem manager\BloodReborn.ps1' }
    $cima = @($novos | Where-Object { -not $_.StartsWith('manager\') })
    # 2. cópia da versão atual
    if ([IO.Directory]::Exists($ant)) { Remove-Item -LiteralPath $ant -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($ant)
    Copy-Item -LiteralPath (Join-Path $Destino 'manager') -Destination (Join-Path $ant 'manager') -Recurse
    foreach ($r in $cima) {
        $f = Join-Path $Destino $r
        if ([IO.File]::Exists($f)) { $d = Join-Path $ant $r; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $d)); Copy-Item -LiteralPath $f -Destination $d }
    }
    try {
        # 3. troca
        Remove-Item -LiteralPath (Join-Path $Destino 'manager') -Recurse -Force
        foreach ($r in $novos) {
            $d = Join-Path $Destino $r; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $d))
            Copy-Item -LiteralPath (Join-Path $Origem $r) -Destination $d -Force
        }
        # 4. conferência
        foreach ($r in $novos) { if ((Sha (Join-Path $Origem $r)) -ne (Sha (Join-Path $Destino $r))) { throw ('cópia diferente: ' + $r) } }
    } catch {
        $erro = $_.Exception.Message
        if ([IO.Directory]::Exists((Join-Path $Destino 'manager'))) { Remove-Item -LiteralPath (Join-Path $Destino 'manager') -Recurse -Force }
        Copy-Item -LiteralPath (Join-Path $ant 'manager') -Destination (Join-Path $Destino 'manager') -Recurse
        $b2 = $ant.TrimEnd('\').Length + 1
        foreach ($f in [IO.Directory]::GetFiles($ant, '*', 'AllDirectories')) {
            $r = $f.Substring($b2); if (-not $r.StartsWith('manager\')) { Copy-Item -LiteralPath $f -Destination (Join-Path $Destino $r) -Force }
        }
        throw $erro
    }
    [IO.File]::WriteAllText((Join-Path $dir 'atualizado.txt'), $Versao, $utf8)
    Remove-Item -LiteralPath (Split-Path -Parent $Origem) -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    [IO.File]::WriteAllText((Join-Path $dir 'falhou.txt'), [string]$_.Exception.Message, $utf8)
    $codigo = 1
}
if (-not $SemReabrir) {
    $a = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $Destino 'manager\BloodReborn.ps1') + '" -PastaDados "' + $Dados.TrimEnd('\') + '"'
    if ($Continuar -and $codigo -eq 0) { $a += ' -Continuar' }
    Start-Process powershell -ArgumentList $a -WindowStyle Hidden
}
exit $codigo
