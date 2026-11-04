# Phase 2 — Updates — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Blood Reborn manager shows the installed and the latest version of each mod, explains what changed, and updates or rolls back a mod from inside the manager, getting the new package from GitHub, Nexus Mods (Premium or free) or a zip dropped next to it.

**Architecture:** The manager stays PowerShell 5.1 + WPF. A new file `Atualizacoes.ps1` (dot-sourced by `BloodReborn.ps1`) holds everything about versions, the catalog, Nexus, downloads, apply and roll back; `BloodReborn.ps1` keeps packages, install and diagnostics; `BloodReborn_janela.ps1` keeps the window. Every engine feature is reachable headless (`-Acao`), and a Python test harness drives it against a fake BB Port, fake packages and a local HTTP server standing in for GitHub and Nexus.

**Tech Stack:** Windows PowerShell 5.1, .NET Framework (System.IO.Compression, WebClient, Invoke-RestMethod, DPAPI through `ConvertFrom-SecureString`), WPF; tests in Python 3 (`unittest`, `http.server`, `zipfile`) on the author's machine only.

## Global Constraints

- PowerShell 5.1 as shipped with Windows; no external modules, no compiled tools.
- PowerShell variable names are case-insensitive: no local variable may reuse a parameter name (`$Catalogo`, `$NexusApi`, `$PastaDados`, `$PastaDownloads`, `$ChaveNexus`, `$SemRede`, `$SemNavegador`, `$EsperaDownload`, `$Mods`, `$Acao`, …).
- Never write to the game files nor to folders of mods that are not Blood Reborn.
- Window texts exist in `pt`, `en`, `es`, `zh` (`$TXT`); a missing key falls back to `en`.
- Network: TLS 1.2, 15 s timeout, headers `Application-Name: BloodRebornManager` and `Application-Version: <manager version>`; no internet must never block the manager.
- Catalog URL: `https://raw.githubusercontent.com/joao-val/blood-reborn/main/catalog.json`. Nexus: `https://api.nexusmods.com` (GraphQL v2 at `/v2/graphql`, game domain `bloodborne`, game id `2708`; v1 download links at `/v1/games/bloodborne/mods/<mod>/files/<file>/download_link.json` with header `apikey`).
- Data folder: `%APPDATA%\BloodReborn` (tests: `-PastaDados`). Downloaded packages: `<data>\pacotes`. Previous version: `<data>\anterior\<mod folder>`. Caches: `<data>\catalogo_cache.json`, `<data>\nexus_cache.json` (24 h).
- Installed record: `<BB Port>\mods\<mod folder>\blood_reborn_installed.json`; the BB Port ignores files outside `dvdroot_ps4`, and the manager's integrity checks ignore this file.
- Every downloaded zip is accepted only if its SHA-256 matches `sha256` in the catalog.
- Commits in this public repository use the account's noreply e-mail (already set in the local git config).

## File structure

| File | Responsibility |
|---|---|
| `manager/Instalar Blood Reborn.bat` (moved) | starts the window (`instalador\BloodReborn.ps1`) |
| `manager/instalador/BloodReborn.ps1` (moved, modified) | parameters, texts, packages, install/remove, diagnostics, headless actions |
| `manager/instalador/Atualizacoes.ps1` (new) | installed record, catalog, Nexus, update state, downloads, update, roll back |
| `manager/instalador/BloodReborn_janela.ps1` (moved, modified) | window: version line, Update / What changed / Roll back, Check for updates, Nexus key |
| `manager/tests/harness.py` (new) | fake BB Port, fake packages, local HTTP server, headless runner |
| `manager/tests/test_updates.py` (new) | the scenarios of this phase |

---

### Task 1: Move the manager into the repository, add the test harness

**Files:**
- Create: `manager/Instalar Blood Reborn.bat`, `manager/instalador/BloodReborn.ps1`, `manager/instalador/BloodReborn_janela.ps1` (copies of `L:/Hydra/PS4/BB_Mod_Fases/ferramentas/distribuicao/instalador_unico/*`)
- Create: `L:/Hydra/PS4/BB_Mod_Fases/ferramentas/distribuicao/instalador_unico/LEIA-ME.txt`
- Create: `manager/tests/harness.py`, `manager/tests/test_updates.py`

**Interfaces:**
- Produces: `harness.Fake` (fake port, `package()`, `catalog()`, `run()`), `harness.Server` (local GitHub/Nexus), used by every later task.

- [ ] **Step 1: Copy the three files**

```bash
cd L:/Hydra/PS4/BB_Mod_Fases
mkdir -p blood-reborn/manager/instalador blood-reborn/manager/tests
cp -p "ferramentas/distribuicao/instalador_unico/Instalar Blood Reborn.bat" blood-reborn/manager/
cp -p ferramentas/distribuicao/instalador_unico/BloodReborn.ps1 ferramentas/distribuicao/instalador_unico/BloodReborn_janela.ps1 blood-reborn/manager/instalador/
printf 'O codigo do instalador mudou para o repositorio blood-reborn (pasta manager/). Nao edite aqui.\r\n' > ferramentas/distribuicao/instalador_unico/LEIA-ME.txt
```

- [ ] **Step 2: Write the harness**

`manager/tests/harness.py`:

```python
"""Test harness of the Blood Reborn manager: a fake BB Port, fake packages (the layout of blood_reborn_pacotes.py), a
local HTTP server standing in for GitHub and Nexus, and a runner for BloodReborn.ps1 in headless mode (-Acao)."""
import hashlib, http.server, json, shutil, subprocess, tempfile, threading, zipfile
from pathlib import Path

MANAGER = Path(__file__).resolve().parents[1]
SCRIPT = MANAGER / 'instalador' / 'BloodReborn.ps1'
FOLDER = 'Blood Reborn - Test Mod'


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class Fake:
    def __init__(self):
        self.root = Path(tempfile.mkdtemp(prefix='br_test_'))
        self.port = self.root / 'BB Port'
        self.data = self.root / 'data'
        self.downloads = self.root / 'Downloads'
        self.web = self.root / 'web'
        for d in (self.port / 'mods', self.port / 'patches', self.data / 'pacotes', self.downloads, self.web / 'files'):
            d.mkdir(parents=True)
        (self.port / 'Play Bloodborne.exe').write_bytes(b'')
        (self.port / 'mods.json').write_text('{"order": [], "disabled": []}', encoding='utf-8')
        self.nexus = {}                 # GraphQL reply of the fake Nexus
        self.nexus_file = None          # file name served by the fake v1 download_link

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def package(self, version, files, patches=(), where=None, folder=FOLDER):
        """a package zip; returns its path (default: <data>\\pacotes, where the manager keeps downloads)"""
        where = Path(where or self.data / 'pacotes')
        top = '%s v%s' % (folder, version)
        z = where / ('Blood_Reborn_%s_v%s.zip' % (folder.split(' - ', 1)[1].replace(' ', '_'), version))
        with zipfile.ZipFile(z, 'w') as zf:
            zf.writestr(top + '/blood_reborn.json', json.dumps({'nome': folder.split(' - ', 1)[1], 'versao': version, 'pasta': folder,
                                                                  'patches': list(patches), 'compat': []}))
            zf.writestr(top + '/README_EN.txt', '\u2728 WHAT THIS MOD DOES\nTest mod %s\n\u2705 YOU NEED\n' % version)
            for rel, data in files.items():
                zf.writestr('%s/mods/%s/dvdroot_ps4/%s' % (top, folder, rel), data)
            for p in patches:
                zf.writestr(top + '/patches/' + p, '<Patch v="%s"/>' % version)
        return z

    def catalog(self, version, sha, download=None, nexus_mod=None, nexus_file=None, notes=None, folder=FOLDER):
        cat = {'schema': 1, 'updated': '2026-11-04', 'github': {'repository': 'test/test'},
               'nexus': {'game_domain': 'bloodborne', 'game_id': 2708},
               'mods': [{'key': 'test', 'name': 'Test Mod', 'folder': folder, 'version': version, 'status': 'released',
                         'package': 'Blood_Reborn_Test_Mod_v%s.zip' % version, 'sha256': sha, 'download': download,
                         'nexus_mod_id': nexus_mod, 'nexus_file_id': nexus_file,
                         'changes': notes or {version: {'en': 'Notes of %s' % version}}}]}
        (self.web / 'catalog.json').write_text(json.dumps(cat), encoding='utf-8')

    def run(self, acao, *extra, mods=None, report=True, timeout=180):
        """runs BloodReborn.ps1 headless; returns (returncode, report JSON or None, stdout+stderr)"""
        out = self.root / 'report.json'
        if out.exists():
            out.unlink()
        args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(SCRIPT),
                '-PastaPort', str(self.port), '-PastaDados', str(self.data), '-PastaDownloads', str(self.downloads),
                '-Acao', acao, '-SemTrava', '-SemNavegador', '-Lingua', 'en', '-Relatorio', str(out)] + list(extra)
        if mods:
            args += ['-Mods', mods]
        r = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
        rep = json.loads(out.read_text(encoding='utf-8-sig')) if report and out.exists() else None
        return r.returncode, rep, r.stdout + r.stderr

    def installed(self, rel):
        return (self.port / 'mods' / FOLDER / 'dvdroot_ps4' / rel).read_text(encoding='utf-8')


class Server:
    """local HTTP stand-in: GET /catalog.json and /files/<name>; POST /v2/graphql; GET .../download_link.json (apikey)"""
    def __init__(self, fake):
        self.fake = fake
        outer = self

        class H(http.server.BaseHTTPRequestHandler):
            def log_message(self, *a):
                pass

            def _send(self, code, body, kind='application/json'):
                self.send_response(code); self.send_header('Content-Type', kind); self.send_header('Content-Length', str(len(body)))
                self.end_headers(); self.wfile.write(body)

            def do_GET(self):
                if self.path == '/catalog.json':
                    return self._send(200, (outer.fake.web / 'catalog.json').read_bytes(), 'text/plain; charset=utf-8')
                if self.path.startswith('/files/'):
                    f = outer.fake.web / 'files' / self.path[len('/files/'):]
                    return self._send(200, f.read_bytes(), 'application/zip') if f.exists() else self._send(404, b'{}')
                if self.path.endswith('/download_link.json'):
                    if self.headers.get('apikey') != 'premium-key':
                        return self._send(403, b'{"message": "not premium"}')
                    return self._send(200, json.dumps([{'URI': outer.base + '/files/' + outer.fake.nexus_file}]).encode())
                self._send(404, b'{}')

            def do_POST(self):
                self.rfile.read(int(self.headers.get('Content-Length', 0)))
                self._send(200, json.dumps(outer.fake.nexus).encode())

        self.httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), H)
        self.base = 'http://127.0.0.1:%d' % self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def close(self):
        self.httpd.shutdown()
```

- [ ] **Step 3: Write the smoke test**

`manager/tests/test_updates.py`:

```python
import unittest
from harness import Fake, Server


class Base(unittest.TestCase):
    def setUp(self):
        self.f = Fake(); self.s = Server(self.f)

    def tearDown(self):
        self.s.close(); self.f.close()


class Smoke(Base):
    def test_verify_runs_on_an_empty_port(self):
        code, rep, out = self.f.run('verificar')
        self.assertEqual(code, 0, out)
        self.assertIsInstance(rep, list)


if __name__ == '__main__':
    unittest.main()
```

- [ ] **Step 4: Run it**

Run: `cd blood-reborn/manager/tests && python -m unittest test_updates -v`
Expected: it PASSES wrongly. Found while executing: the script's `param()` has no `[CmdletBinding()]`, so PowerShell sends unknown parameters silently to `$args` (`-PastaDados` would be ignored and a test would use the real data folder). Add `[CmdletBinding()]` above `param(` first: the test then FAILS with `NamedParameterNotFound`.

- [ ] **Step 5: Accept the parameters**

In `manager/instalador/BloodReborn.ps1`, replace the `param(...)` block (lines 14–23) with:

```powershell
[CmdletBinding()]
param(
    [string]$PastaPort = '',
    [string]$Acao = '',
    [string[]]$Mods = @(),
    [string]$Lingua = '',
    [string]$Captura = '',
    [string]$Pagina = 'mods',
    [string]$Relatorio = '',
    [switch]$SemTrava,
    # fase 2 (atualizações, 04/11/2026)
    [string]$PastaDados = '',
    [string]$PastaDownloads = '',
    [string]$Catalogo = 'https://raw.githubusercontent.com/joao-val/blood-reborn/main/catalog.json',
    [string]$NexusApi = 'https://api.nexusmods.com',
    [string]$ChaveNexus = '',
    [int]$EsperaDownload = 1800,
    [switch]$SemRede,
    [switch]$SemNavegador
)
```

and replace line 38 (`$CONFIG = ...`) with:

```powershell
$VERSAO_GERENCIADOR = '2.0.0'
$REGISTRO = 'blood_reborn_installed.json'
$script:Dados = if ($PastaDados) { $PastaDados } else { Join-Path $env:APPDATA 'BloodReborn' }
$CONFIG = Join-Path $script:Dados 'instalador.json'
```

- [ ] **Step 6: Run the test again**

Run: `cd blood-reborn/manager/tests && python -m unittest test_updates -v`
Expected: PASS (`test_verify_runs_on_an_empty_port ... ok`).

- [ ] **Step 7: Commit**

```bash
cd L:/Hydra/PS4/BB_Mod_Fases/blood-reborn
git add manager
git commit -m "Move the manager into the repository; add the test harness

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Installed-version record; Apply never upgrades by itself

**Files:**
- Create: `manager/instalador/Atualizacoes.ps1`
- Modify: `manager/instalador/BloodReborn.ps1` (Ler-Pacotes ~233–272, Conferir-Pasta line 322, Aplicar-Escolha 469–477, Diagnosticar 529–543, dot-source before the language block, texts)
- Test: `manager/tests/test_updates.py`

**Interfaces:**
- Consumes: Task 1 parameters, `$REGISTRO`, `$script:Dados`.
- Produces: `Sha-Arquivo([string]) -> string` (hex, lower case); `Gravar-Registro([string]$pasta, $pac, [string]$fonte)`; `Ler-Registro([string]$pasta) -> object|$null`; `Conferir-Registro([string]$pasta, [switch]$Rapido) -> int` (−1 = no record, 0 = ok, n = bad files); `Pacote-Da-Versao([string]$pasta, [string]$versao) -> package|$null`; `Versao-Instalada([string]$porto, [string]$pasta) -> string|$null` (`$null` = not installed, `'unknown'` = files match no known version); `$script:TodosPacotes` (every package found, all versions); `$script:FonteInstalacao` (`'zip'` by default).

- [ ] **Step 1: Write the failing tests**

Append to `manager/tests/test_updates.py` (before `if __name__`):

```python
import json
from harness import FOLDER


class Record(Base):
    def test_install_writes_the_record_and_verify_is_clean(self):
        self.f.package('1.0', {'chr/a.txt': 'one'}, patches=['TestMod.xml'])
        code, rep, out = self.f.run('instalar', mods=FOLDER)
        self.assertEqual(code, 0, out)
        rec = json.loads((self.f.port / 'mods' / FOLDER / 'blood_reborn_installed.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(rec['version'], '1.0')
        self.assertEqual(rec['patches'], ['TestMod.xml'])
        self.assertIn('dvdroot_ps4/chr/a.txt', rec['files'])
        self.assertFalse([i for i in rep if i['Nivel'] == 'erro'], rep)

    def test_apply_keeps_the_installed_version(self):
        self.f.package('1.0', {'chr/a.txt': 'one'})
        self.f.run('instalar', mods=FOLDER)
        self.f.package('1.1', {'chr/a.txt': 'two'})
        code, rep, out = self.f.run('instalar', mods=FOLDER)
        self.assertEqual(self.f.installed('chr/a.txt'), 'one')
        self.assertTrue([i for i in rep if i['Nivel'] == 'aviso' and '1.1' in i['Texto']], rep)
        self.assertFalse([i for i in rep if i['Nivel'] == 'erro'], rep)
```

- [ ] **Step 2: Run them**

Run: `cd blood-reborn/manager/tests && python -m unittest test_updates.Record -v`
Expected: FAIL — no `blood_reborn_installed.json`; the second test sees `two` (silent upgrade).

- [ ] **Step 3: Create `Atualizacoes.ps1` with the record functions**

```powershell
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
```

- [ ] **Step 4: Wire it into `BloodReborn.ps1`**

1. In `Ler-Pacotes`, change the first two lines of the function to also read `<data>\pacotes` and keep every version:

```powershell
function Ler-Pacotes {
    $achados = @{}; $cima = Split-Path -Parent $script:Aqui; $todos = New-Object Collections.ArrayList
    $lugares = @($script:Aqui, (Join-Path $script:Aqui '2 - Mods'), $cima, (Join-Path $cima '2 - Mods'), (Join-Path $script:Dados 'pacotes'))
```

   right after the `$pac = [pscustomobject]@{ ... }` statement add `[void]$todos.Add($pac)`, and after the outer `foreach ($lugar ...)` loop add `$script:TodosPacotes = @($todos)`.

2. In `Conferir-Pasta`, replace line 322 with:

```powershell
    foreach ($f in [IO.Directory]::GetFiles($pasta, '*', 'AllDirectories')) { $r = $f.Substring($base); if ($r -ne $REGISTRO -and -not $vistos.Contains($r)) { $ruins++ } }
```

3. In `Aplicar-Escolha`, replace the `if ($quero -contains $p.Pasta) { ... }` block (lines 471–477) with:

```powershell
        if ($quero -contains $p.Pasta) {
            Passo $p.Nome
            # 04/11: o APLICAR instala e conserta, mas não troca de versão sozinho (isso é do botão Atualizar)
            $reg = Ler-Registro $alvo; $pv = $p
            if ($reg -and $reg.version) { $pv = Pacote-Da-Versao $p.Pasta ([string]$reg.version) }
            $estadoReg = Conferir-Registro $alvo
            if (-not [IO.Directory]::Exists($alvo) -or ($estadoReg -gt 0 -and $pv) -or ($estadoReg -lt 0 -and (Conferir-Pasta $p.Zip $p.Prefixo $alvo) -ne 0)) {
                if (-not $pv) { $pv = $p }
                Extrair-Pasta $pv.Zip $pv.Prefixo $alvo; Gravar-Registro $alvo $pv $script:FonteInstalacao; $feitos += $pv.Nome
            } elseif ($estadoReg -lt 0) { Gravar-Registro $alvo $p 'zip' }
            if ($pv) {
                foreach ($x in $pv.Patches) {
                    $e = $pv.Topo + 'patches/' + $x; $f = Join-Path $dp $x
                    if (-not (Conferir-Arquivo $pv.Zip $e $f)) { Extrair-Arquivo $pv.Zip $e $f }
                }
            }
        } else {
```

4. In `Diagnosticar`, replace the integrity line `$ruins = Conferir-Pasta $p.Zip $p.Prefixo $alvo` (line 533) and the next line with:

```powershell
            $ruins = Conferir-Registro $alvo
            if ($ruins -lt 0) { $ruins = Conferir-Pasta $p.Zip $p.Prefixo $alvo }
            if ($ruins -gt 0) { [void]$L.Add((Item 'erro' ((T 'd_ruim') -f $p.Nome, $ruins) $true)); $ok = $false }
            $vi = Versao-Instalada $porto $p.Pasta
            if ($vi -and $vi -ne 'unknown' -and (Versao-Num $p.Versao) -gt (Versao-Num $vi)) {
                [void]$L.Add((Item 'aviso' ((T 'd_nova') -f $p.Nome, $vi, $p.Versao) $false))
            }
            $pv = Pacote-Da-Versao $p.Pasta $vi; if (-not $pv) { $pv = $p }
```

   and in the patch loop right below, use `$pv` instead of `$p` (`foreach ($x in $pv.Patches) { if (-not (Conferir-Arquivo $pv.Zip ($pv.Topo + 'patches/' + $x) (Join-Path $dp $x))) ...`).

5. Before the line `# ---------------------------------------------------------------- idioma`, add:

```powershell
$script:FonteInstalacao = 'zip'
. (Join-Path $script:Aqui 'Atualizacoes.ps1')
```

6. Add the key `d_nova` to the four languages of `$TXT`:

```powershell
  d_nova = '{0}: versão {1} instalada, {2} disponível (use Atualizar na página Mods).'      # pt
  d_nova = '{0}: version {1} installed, {2} available (use Update on the Mods page).'       # en
  d_nova = '{0}: versión {1} instalada, {2} disponible (usa Actualizar en la página Mods).'  # es
  d_nova = '{0}：已安装版本 {1}，可用版本 {2}（请在“模组”页面点击“更新”）。'                  # zh
```

- [ ] **Step 5: Run the tests**

Run: `cd blood-reborn/manager/tests && python -m unittest test_updates -v`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add manager && git commit -m "Record the installed version; Apply no longer upgrades by itself

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Catalog, Nexus and the update state

**Files:**
- Modify: `manager/instalador/Atualizacoes.ps1` (append), `manager/instalador/BloodReborn.ps1` (headless switch, texts)
- Test: `manager/tests/test_updates.py`

**Interfaces:**
- Consumes: `Versao-Instalada`, `Versao-Num`, `$script:Pacotes`, `T`.
- Produces: `Web-Json([string]$url, [string]$metodo = 'GET', $corpo = $null, [hashtable]$cab = @{}) -> object`; `Ler-Catalogo([switch]$Forcar) -> object|$null`; `Consultar-Nexus([int]$modId, [switch]$Forcar) -> @{ Versao; Arquivos }|$null`; `Estado-Atualizacoes([string]$porto, [switch]$Forcar) -> list of [pscustomobject]@{ Pasta; Nome; Instalada; Disponivel; Atualizar; Notas; Fontes; Cat; Nexus }`; `$script:AvisoRede` (text or `$null`); headless `-Acao atualizacoes` writes that list to `-Relatorio`.

- [ ] **Step 1: Write the failing tests**

```python
class State(Base):
    def test_reports_the_update_and_the_notes(self):
        z = self.f.package('1.0', {'chr/a.txt': 'one'})
        self.f.run('instalar', mods=FOLDER)
        self.f.catalog('1.1', 'aa' * 32, notes={'1.1': {'en': 'Harder bosses'}, '1.0': {'en': 'First'}})
        code, rep, out = self.f.run('atualizacoes', '-Catalogo', self.s.base + '/catalog.json')
        self.assertEqual(code, 0, out)
        e = [x for x in rep if x['Pasta'] == FOLDER][0]
        self.assertEqual((e['Instalada'], e['Disponivel'], e['Atualizar']), ('1.0', '1.1', True))
        self.assertEqual([n['Versao'] for n in e['Notas']], ['1.1'])
        self.assertEqual(e['Notas'][0]['Texto'], 'Harder bosses')

    def test_works_offline(self):
        self.f.package('1.0', {'chr/a.txt': 'one'})
        self.f.run('instalar', mods=FOLDER)
        code, rep, out = self.f.run('atualizacoes', '-SemRede')
        self.assertEqual(code, 0, out)
        e = [x for x in rep if x['Pasta'] == FOLDER][0]
        self.assertEqual((e['Instalada'], e['Disponivel'], e['Atualizar']), ('1.0', '1.0', False))

    def test_a_newer_version_on_nexus_counts(self):
        self.f.package('1.0', {'chr/a.txt': 'one'})
        self.f.run('instalar', mods=FOLDER)
        self.f.catalog('1.0', 'aa' * 32, nexus_mod=999, nexus_file=5)
        self.f.nexus = {'data': {'legacyModsByDomain': {'nodes': [{'version': '1.2', 'updatedAt': '2026-11-05T00:00:00Z'}]},
                                 'modFiles': [{'fileId': 7, 'name': 'Test', 'version': '1.2', 'category': 'MAIN', 'uri': 'Test-999-1-2.zip'}]}}
        code, rep, out = self.f.run('atualizacoes', '-Catalogo', self.s.base + '/catalog.json', '-NexusApi', self.s.base)
        e = [x for x in rep if x['Pasta'] == FOLDER][0]
        self.assertEqual((e['Disponivel'], e['Atualizar']), ('1.2', True))
        self.assertIn('nexus', e['Fontes'])
```

- [ ] **Step 2: Run them**

Run: `python -m unittest test_updates.State -v`
Expected: FAIL — `Unknown action: atualizacoes` (exit 2).

- [ ] **Step 3: Append to `Atualizacoes.ps1`**

```powershell
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
    $c = Ler-Cache ('nexus_%d.json' -f $modId) 24
    if ($c -and $c.Fresco -and -not $Forcar) { return $c.Dado }
    $q = '{ legacyModsByDomain(ids: [{gameDomain: "bloodborne", modId: ' + $modId + '}]) { nodes { version updatedAt } } ' +
         'modFiles(modId: ' + $modId + ', gameId: 2708) { fileId name version category uri } }'
    try {
        $r = Web-Json ($NexusApi + '/v2/graphql') 'POST' @{ query = $q }
        $nx = [pscustomobject]@{ Versao = [string](@($r.data.legacyModsByDomain.nodes)[0].version)
                                 Arquivos = @($r.data.modFiles | Where-Object { $_.category -eq 'MAIN' }) }
        Gravar-Cache ('nexus_%d.json' -f $modId) $nx; return $nx
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
```

- [ ] **Step 4: Headless action and texts in `BloodReborn.ps1`**

In the `switch ($Acao)` of the headless block, add before `default`:

```powershell
        'atualizacoes' {
            $est = @(Estado-Atualizacoes $PastaPort -Forcar)
            $json = ConvertTo-Json -InputObject $est -Depth 8
            if ($Relatorio) { [IO.File]::WriteAllText($Relatorio, $json, $script:Utf8) } else { $json }
            exit 0
        }
```

Add `u_semrede` to the four languages:

```powershell
  u_semrede = 'Sem internet ou GitHub/Nexus fora do ar: mostrando o que já está no computador.'   # pt
  u_semrede = 'No internet, or GitHub/Nexus is down: showing what is already on this PC.'        # en
  u_semrede = 'Sin internet o GitHub/Nexus caído: se muestra lo que ya está en el equipo.'       # es
  u_semrede = '没有网络，或 GitHub/Nexus 无法访问：显示本机已有的内容。'                           # zh
```

- [ ] **Step 5: Run the tests**

Run: `python -m unittest test_updates -v`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add manager && git commit -m "Read the catalog and Nexus; report installed and available versions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Download and update

**Files:**
- Modify: `manager/instalador/Atualizacoes.ps1` (append), `manager/instalador/BloodReborn.ps1` (headless switch, texts)
- Test: `manager/tests/test_updates.py`

**Interfaces:**
- Consumes: `Estado-Atualizacoes`, `Ler-Pacotes`, `Aplicar-Escolha`, `Pacote-Da-Versao`, `Ler-Registro`, `Sha-Arquivo`.
- Produces: `Baixar-Url([string]$url, [string]$dest)`; `Conferir-Sha([string]$f, [string]$esperado) -> bool`; `Pasta-Downloads -> string`; `Esperar-Download([string]$sha, [int]$segundos) -> string|$null`; `Ler-Chave-Nexus -> string`; `Gravar-Chave-Nexus([string]$chave)`; `Baixar-Pacote($estado) -> string|$null` (zip path in `<data>\pacotes`); `Guardar-Anterior([string]$porto, [string]$pasta)`; `Atualizar-Mod([string]$porto, [string]$pasta) -> string` (`'ok'` or throws); headless `-Acao atualizar -Mods <folder>`.

- [ ] **Step 1: Write the failing tests**

```python
import threading, time
from harness import sha256


class Update(Base):
    def _start(self, **cat):
        self.f.package('1.0', {'chr/a.txt': 'one'}, patches=['TestMod.xml'])
        self.f.run('instalar', mods=FOLDER)
        z = self.f.package('1.1', {'chr/a.txt': 'two'}, patches=['TestMod.xml'], where=self.f.web / 'files')
        self.f.catalog('1.1', cat.pop('sha', sha256(z)), **cat)
        return z

    def _update(self, *extra):
        return self.f.run('atualizar', '-Catalogo', self.s.base + '/catalog.json', '-NexusApi', self.s.base, *extra, mods=FOLDER)

    def test_from_github(self):
        z = self._start(download=self.s.base + '/files/Blood_Reborn_Test_Mod_v1.1.zip')
        code, rep, out = self._update()
        self.assertEqual(code, 0, out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'two')
        self.assertIn('1.1', (self.f.port / 'patches' / 'TestMod.xml').read_text())
        self.assertTrue((self.f.data / 'anterior' / FOLDER / 'mod' / 'dvdroot_ps4' / 'chr' / 'a.txt').exists())

    def test_wrong_sha_is_refused(self):
        self._start(download=self.s.base + '/files/Blood_Reborn_Test_Mod_v1.1.zip', sha='bb' * 32)
        code, rep, out = self._update('-EsperaDownload', '2')
        self.assertNotEqual(code, 0)
        self.assertEqual(self.f.installed('chr/a.txt'), 'one')

    def test_from_nexus_premium(self):
        z = self._start(nexus_mod=999, nexus_file=7)
        self.f.nexus_file = z.name
        self.f.nexus = {'data': {'legacyModsByDomain': {'nodes': [{'version': '1.1'}]}, 'modFiles': []}}
        code, rep, out = self._update('-ChaveNexus', 'premium-key')
        self.assertEqual(code, 0, out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'two')

    def test_from_nexus_free_by_watching_downloads(self):
        z = self._start(nexus_mod=999, nexus_file=7)
        self.f.nexus = {'data': {'legacyModsByDomain': {'nodes': [{'version': '1.1'}]}, 'modFiles': []}}

        def browser_saves_the_file():
            time.sleep(4)
            (self.f.downloads / 'Test Mod-999-1-1-1762300000.zip').write_bytes(z.read_bytes())
        threading.Thread(target=browser_saves_the_file, daemon=True).start()
        code, rep, out = self._update('-EsperaDownload', '60')
        self.assertEqual(code, 0, out)
        self.assertIn('nexusmods.com/bloodborne/mods/999?tab=files&file_id=7', out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'two')
```

- [ ] **Step 2: Run them**

Run: `python -m unittest test_updates.Update -v`
Expected: FAIL — `Unknown action: atualizar`.

- [ ] **Step 3: Append to `Atualizacoes.ps1`**

```powershell
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
        try { $s = ConvertTo-SecureString ([string]$cfg.nexus); return [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)) } catch { }
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
```

Also persist the encrypted key in `Gravar-Config` (`BloodReborn.ps1` line ~599): keep the key that is already in the file when `$script:ChaveCifrada` is not set, and add it to the JSON:

```powershell
function Gravar-Config {
    try {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $CONFIG))
        $nx = $script:ChaveCifrada
        if ($null -eq $nx) { $velha = Ler-Config; if ($velha -and $velha.nexus) { $nx = [string]$velha.nexus } }
        $t = '{"porto": ' + (ConvertTo-Json ([string]$script:Porto)) + ', "lingua": ' + (ConvertTo-Json ([string]$script:Ling)) +
             ', "nexus": ' + (ConvertTo-Json ([string]$nx)) + '}'
        [IO.File]::WriteAllText($CONFIG, $t, $script:Utf8)
    } catch { }
}
```

(`$script:ChaveCifrada` is `$null` until the player sets a key in this session, so the stored key is kept; `''` erases it.)

- [ ] **Step 4: Headless action and texts**

In the headless `switch ($Acao)` add:

```powershell
        'atualizar' { foreach ($x in $quero) { [void](Atualizar-Mod $PastaPort $x) } }
```

and wrap the whole `switch` in `try { ... } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }` so a failed update ends with a non-zero code.

Texts (four languages):

```powershell
  u_falhou = 'Não deu para baixar {0}: confira a internet ou baixe o zip e ponha na pasta do instalador.'                  # pt
  u_esperando = 'Esperando o download do Nexus na pasta Downloads... {0} s'
  u_falhou = 'Could not download {0}: check your internet, or download the zip and put it next to the manager.'           # en
  u_esperando = 'Waiting for the Nexus download in your Downloads folder... {0} s'
  u_falhou = 'No se pudo descargar {0}: revisa internet, o descarga el zip y ponlo en la carpeta del instalador.'         # es
  u_esperando = 'Esperando la descarga de Nexus en la carpeta Descargas... {0} s'
  u_falhou = '无法下载 {0}：请检查网络，或手动下载 zip 并放到管理器所在的文件夹。'                                         # zh
  u_esperando = '正在“下载”文件夹中等待 Nexus 的下载…… {0} 秒'
```

- [ ] **Step 5: Run the tests**

Run: `python -m unittest test_updates -v`
Expected: PASS (10 tests).

- [ ] **Step 6: Commit**

```bash
git add manager && git commit -m "Download from GitHub or Nexus (Premium or free) and update a mod

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Roll back

**Files:**
- Modify: `manager/instalador/Atualizacoes.ps1` (append), `manager/instalador/BloodReborn.ps1` (headless switch, texts)
- Test: `manager/tests/test_updates.py`

**Interfaces:**
- Consumes: `Guardar-Anterior` layout (`<data>\anterior\<folder>\mod`, `...\patches`), `Ler-Registro`.
- Produces: `Versao-Anterior([string]$pasta) -> string|$null`; `Voltar-Mod([string]$porto, [string]$pasta)`; headless `-Acao voltar -Mods <folder>`.

- [ ] **Step 1: Write the failing test**

```python
class Rollback(Update):
    def test_back_to_the_previous_version(self):
        self._start(download=self.s.base + '/files/Blood_Reborn_Test_Mod_v1.1.zip')
        self._update()
        code, rep, out = self.f.run('voltar', mods=FOLDER)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'one')
        self.assertIn('1.0', (self.f.port / 'patches' / 'TestMod.xml').read_text())
        rec = json.loads((self.f.port / 'mods' / FOLDER / 'blood_reborn_installed.json').read_text(encoding='utf-8-sig'))
        self.assertEqual(rec['version'], '1.0')
        self.assertFalse((self.f.data / 'anterior' / FOLDER).exists())
```

- [ ] **Step 2: Run it**

Run: `python -m unittest test_updates.Rollback -v`
Expected: FAIL — `Unknown action: voltar`.

- [ ] **Step 3: Append to `Atualizacoes.ps1`**

```powershell
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
}
```

- [ ] **Step 4: Headless action and texts**

```powershell
        'voltar' { foreach ($x in $quero) { Voltar-Mod $PastaPort $x } }
```

```powershell
  u_semanterior = 'Não há versão anterior guardada para voltar.'          # pt
  u_semanterior = 'There is no previous version saved to go back to.'      # en
  u_semanterior = 'No hay una versión anterior guardada para volver.'      # es
  u_semanterior = '没有保存可以回退的旧版本。'                              # zh
```

- [ ] **Step 5: Run the tests**

Run: `python -m unittest test_updates -v`
Expected: PASS (11 tests).

- [ ] **Step 6: Commit**

```bash
git add manager && git commit -m "Roll a mod back to the previous version

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The window

**Files:**
- Modify: `manager/instalador/BloodReborn_janela.ps1` (`Montar-Cartoes` 405–441, `Mostrar-Pagina` 361–385, `Ocupado` 493–497, events 568, start 595–601), `manager/instalador/BloodReborn.ps1` (texts)

**Interfaces:**
- Consumes: `Estado-Atualizacoes`, `Atualizar-Mod`, `Voltar-Mod`, `Versao-Anterior`, `Gravar-Chave-Nexus`, `Ler-Chave-Nexus`, `$script:AvisoRede`, `$script:Cancelar`.
- Produces: `$script:Estados` (last update state, by folder), `Procurar-UI([switch]$Forcar)`, `Atualizar-UI([string]$pasta)`, `Voltar-UI([string]$pasta)`, `Notas-UI([string]$pasta)`, `Chave-UI`.

- [ ] **Step 1: Texts (four languages) in `$TXT`**

```powershell
  # pt
  st_nova = 'Atualização disponível'; st_desc = 'Versão desconhecida'
  u_procurar = 'PROCURAR ATUALIZAÇÕES'; u_btn = 'Atualizar para v{0}'; u_notas = 'O que mudou'; u_voltar = 'Voltar para v{0}'
  u_cancelar = 'Cancelar'; u_linha = 'Instalada: v{0}  ·  Disponível: v{1}'; u_nada_novo = 'Todos os mods estão na versão mais nova.'
  u_titulo_notas = '{0}: o que mudou'; u_chave = 'Conta Premium do Nexus? Cole a sua chave da API (Nexus Mods ➜ Conta ➜ API Keys). Deixe vazio para apagar.'
  u_btn_chave = 'Chave do Nexus'; u_ok = '{0} atualizado para a versão {1}.'; u_voltou = '{0} voltou para a versão anterior.'
  # en
  st_nova = 'Update available'; st_desc = 'Unknown version'
  u_procurar = 'CHECK FOR UPDATES'; u_btn = 'Update to v{0}'; u_notas = 'What changed'; u_voltar = 'Back to v{0}'
  u_cancelar = 'Cancel'; u_linha = 'Installed: v{0}  ·  Available: v{1}'; u_nada_novo = 'Every mod is on the latest version.'
  u_titulo_notas = '{0}: what changed'; u_chave = 'Nexus Premium account? Paste your API key (Nexus Mods ➜ Account ➜ API Keys). Leave it empty to remove it.'
  u_btn_chave = 'Nexus key'; u_ok = '{0} updated to version {1}.'; u_voltou = '{0} went back to the previous version.'
  # es
  st_nova = 'Actualización disponible'; st_desc = 'Versión desconocida'
  u_procurar = 'BUSCAR ACTUALIZACIONES'; u_btn = 'Actualizar a v{0}'; u_notas = 'Qué cambió'; u_voltar = 'Volver a v{0}'
  u_cancelar = 'Cancelar'; u_linha = 'Instalada: v{0}  ·  Disponible: v{1}'; u_nada_novo = 'Todos los mods están en la versión más nueva.'
  u_titulo_notas = '{0}: qué cambió'; u_chave = '¿Cuenta Premium de Nexus? Pega tu clave de la API (Nexus Mods ➜ Cuenta ➜ API Keys). Déjalo vacío para borrarla.'
  u_btn_chave = 'Clave de Nexus'; u_ok = '{0} actualizado a la versión {1}.'; u_voltou = '{0} volvió a la versión anterior.'
  # zh
  st_nova = '有可用更新'; st_desc = '版本未知'
  u_procurar = '检查更新'; u_btn = '更新到 v{0}'; u_notas = '更新内容'; u_voltar = '回退到 v{0}'
  u_cancelar = '取消'; u_linha = '已安装：v{0}  ·  可用：v{1}'; u_nada_novo = '所有模组都已是最新版本。'
  u_titulo_notas = '{0}：更新内容'; u_chave = '有 Nexus 高级会员？请粘贴你的 API 密钥（Nexus Mods ➜ 账户 ➜ API Keys）。留空即删除。'
  u_btn_chave = 'Nexus 密钥'; u_ok = '{0} 已更新到版本 {1}。'; u_voltou = '{0} 已回退到之前的版本。'
```

- [ ] **Step 2: Cards with version line and buttons**

In `Montar-Cartoes`, before the `foreach ($p in $script:Pacotes)` loop add `$est = @{}; foreach ($x in @($script:Estados)) { $est[$x.Pasta] = $x }`, and replace the state computation and the chip column with:

```powershell
        $e = $est[$p.Pasta]; $vi = if ($dm) { Versao-Instalada $script:Porto $p.Pasta } else { $null }
        $estado = 'st_nao'; $inst = [bool]$vi
        if ($inst) {
            $alvo = Join-Path $dm $p.Pasta; $ruins = Conferir-Registro $alvo -Rapido
            if ($ruins -lt 0) { $ruins = Conferir-Pasta $p.Zip $p.Prefixo $alvo -Rapido }
            if ($ruins -gt 0) { $estado = 'st_rep' } elseif ($vi -eq 'unknown') { $estado = 'st_desc' } elseif ($e -and $e.Atualizar) { $estado = 'st_nova' } else { $estado = 'st_inst' }
        }
```

the version text becomes:

```powershell
        $txtVer = if ($inst -and $e -and $e.Disponivel -and $vi -ne $e.Disponivel) { (T 'u_linha') -f $vi, $e.Disponivel } elseif ($inst) { 'v' + $vi } else { 'v' + $p.Versao }
        $ver = Novo-Texto $txtVer 11.5 '#8F897E'; $ver.Margin = '9,5,0,0'; [void]$linha.Children.Add($ver)
```

and the right column (chip and buttons):

```powershell
        $cores = @{ st_inst = @('#7CC482', '#16241A'); st_nao = @('#8F897E', '#18181C'); st_rep = @('#E0AE4E', '#2A2214')
                    st_nova = @('#7FB2E5', '#14202B'); st_desc = @('#E0AE4E', '#2A2214') }
        $dir = New-Object Windows.Controls.StackPanel; $dir.Margin = '14,1,0,0'
        $chip = Novo-Chip (T $estado) $cores[$estado][0] $cores[$estado][1]; $chip.HorizontalAlignment = 'Right'; [void]$dir.Children.Add($chip)
        if ($e -and $e.Atualizar) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,8,0,0'
            $b.Content = (T 'u_btn') -f $e.Disponivel; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Atualizar-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        if ($e -and @($e.Notas).Count) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,6,0,0'
            $b.Content = T 'u_notas'; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Notas-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        $va = Versao-Anterior $p.Pasta
        if ($inst -and $va) {
            $b = New-Object Windows.Controls.Button; $b.Style = $script:Win.FindResource('BotaoEscuro'); $b.Margin = '0,6,0,0'
            $b.Content = (T 'u_voltar') -f $va; $b.Tag = $p.Pasta; $b.Add_Click({ param($s) Voltar-UI ([string]$s.Tag) }); [void]$dir.Children.Add($b)
        }
        [Windows.Controls.Grid]::SetColumn($dir, 2); [void]$g.Children.Add($dir)
```

- [ ] **Step 3: Actions**

Add after `Corrigir-UI`:

```powershell
function Procurar-UI([switch]$Forcar) {
    if (-not $script:Porto) { return }
    Ocupado $true; & $script:AoProgredir (T 'conferindo')
    try { $script:Estados = @(Estado-Atualizacoes $script:Porto -Forcar:$Forcar) } catch { $script:Estados = @() }
    Ocupado $false; Montar-Cartoes
    if ($script:AvisoRede) { Aviso $script:AvisoRede 'Warning' }
    elseif ($Forcar -and -not @($script:Estados | Where-Object { $_.Atualizar }).Count) { Aviso (T 'u_nada_novo') }
}
function Atualizar-UI([string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    $e = @($script:Estados | Where-Object { $_.Pasta -eq $pasta })[0]
    $script:Cancelar = $false; Ocupado $true
    $script:U.BtnSecundario.Visibility = 'Visible'; $script:U.BtnSecundario.IsEnabled = $true; $script:U.BtnSecundario.Content = T 'u_cancelar'
    try { [void](Atualizar-Mod $script:Porto $pasta); Ocupado $false; Procurar-UI; Aviso ((T 'u_ok') -f $e.Nome, $e.Disponivel) }
    catch { Ocupado $false; Montar-Cartoes; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
function Voltar-UI([string]$pasta) {
    if (-not $SemTrava -and (Jogo-Aberto)) { Aviso (T 'aberto') 'Warning'; return }
    Ocupado $true
    try { Voltar-Mod $script:Porto $pasta; Ocupado $false; Procurar-UI; Aviso ((T 'u_voltou') -f $pasta) }
    catch { Ocupado $false; Aviso ((T 'erro') -f $_.Exception.Message) 'Error' }
}
function Notas-UI([string]$pasta) {
    $e = @($script:Estados | Where-Object { $_.Pasta -eq $pasta })[0]
    $t = (@($e.Notas) | ForEach-Object { 'v' + $_.Versao + "`n" + $_.Texto }) -join "`n`n"
    [void][Windows.MessageBox]::Show($script:Win, $t, ((T 'u_titulo_notas') -f $e.Nome), 'OK', 'Information')
}
function Chave-UI {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $v = [Microsoft.VisualBasic.Interaction]::InputBox((T 'u_chave'), 'Blood Reborn', '')
    Gravar-Chave-Nexus $v.Trim()
}
```

`Ocupado` must leave the secondary button usable as *Cancel* while busy: in `Ocupado`, remove `'BtnSecundario'` from the list of controls it disables. `Atualizar-UI` turns it into *Cancel*; `Mostrar-Pagina` (called by `Ocupado $false`) restores it.

- [ ] **Step 4: The secondary button on the Mods page**

> **As built:** `BtnSecundario` lives inside the summary box of the *Error repair* page, which is collapsed on the Mods page, so it can never show there. The window got its own button instead: `BtnAtualizacoes`, right of the *Choose your mods* heading (in the `$script:U` list and in `Ocupado`'s list). It does *Check for updates*, turns into *Cancel* during an update, and carries the Nexus key menu. `BtnSecundario` stays as *Verify* only, and `Ocupado` keeps disabling it.

In `Mostrar-Pagina`, case `'mods'`, add:

```powershell
            $U.BtnSecundario.Visibility = 'Visible'; $U.BtnSecundario.Content = T 'u_procurar'; $U.BtnSecundario.IsEnabled = [bool]$script:Porto
```

Replace the event line 568 with:

```powershell
$U.BtnSecundario.Add_Click({
    if ($script:U.BtnSecundario.Content -eq (T 'u_cancelar')) { $script:Cancelar = $true; return }
    switch ($script:PaginaAtual) { 'mods' { Procurar-UI -Forcar } 'correcao' { Verificar-UI } }
})
```

Add a right-click menu on the secondary button for the Nexus key, after that line:

```powershell
$mk = New-Object Windows.Controls.ContextMenu; $mi = New-Object Windows.Controls.MenuItem; $mi.Header = T 'u_btn_chave'
$mi.Add_Click({ Chave-UI }); [void]$mk.Items.Add($mi); $U.BtnSecundario.ContextMenu = $mk
```

- [ ] **Step 5: Check on start**

In `Add_ContentRendered`, after the port search, add `if ($script:Porto) { Procurar-UI }` (uses the 24 h cache, so it is quick and quiet).

- [ ] **Step 6: Captures in the four languages**

Prepare a fake port with Test Mod 1.0 installed and a catalog with 1.1 (reuse the harness from a Python one-liner), then:

```bash
cd L:/Hydra/PS4/BB_Mod_Fases/blood-reborn/manager/tests
python -c "
import harness, subprocess
f = harness.Fake(); s = harness.Server(f)
f.package('1.0', {'chr/a.txt': 'one'}); f.run('instalar', mods=harness.FOLDER)
z = f.package('1.1', {'chr/a.txt': 'two'}, where=f.web / 'files'); f.catalog('1.1', harness.sha256(z), notes={'1.1': {'en': 'x', 'pt': 'x'}})
for lg in ('pt', 'en', 'es', 'zh'):
    subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', str(harness.SCRIPT), '-PastaPort', str(f.port),
                    '-PastaDados', str(f.data), '-Catalogo', s.base + '/catalog.json', '-Captura', 'captura_%s.png' % lg, '-Lingua', lg], check=True)
print('ok')"
```

For the capture mode, `Procurar-UI` must also run before rendering: in the `if ($Captura)` block add `if ($script:Porto) { $script:Estados = @(Estado-Atualizacoes $script:Porto -Forcar) }; Montar-Cartoes` as the first line.

Expected: four PNGs; open them and check the card shows *Installed: v1.0 · Available: v1.1*, the *Update to v1.1* and *What changed* buttons, and the *Check for updates* button, in each language with nothing cut off.

- [ ] **Step 7: Run the whole suite and commit**

Run: `python -m unittest test_updates -v`
Expected: PASS (11 tests).

```bash
git add manager && git commit -m "Window: versions, Update, What changed, Roll back, Check for updates, Nexus key

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs and push

**Files:**
- Modify: `README.md`, `README.pt-BR.md`, `README.es.md`, `README.zh-CN.md` (manager section: "Updates: done"), `docs/manager-design.md` (build order: phase 2 done)
- Modify: `L:/Hydra/PS4/BB_Mod_Fases/docs/02_MODS_INSTALADOS_E_DISTRIBUICAO.md` (where the manager code lives; how to run the tests)

- [ ] **Step 1: Update the four READMEs**

In the manager section of each README, after the bullet list, add one line (in the README's language):

```markdown
✅ Updates: ready. Next: conflicts with any mod (phase 3).
```

- [ ] **Step 2: Update the design build order**

In `docs/manager-design.md`, section 11, change item 2 to `2. Updates — done (plan: docs/plans/2026-11-04-phase-2-updates.md).`

- [ ] **Step 3: Note in the project docs (Portuguese)**

Add to docs/02 §4, under the manager bullet: `- Código do gerenciador: blood-reborn/manager/ (o instalador_unico antigo só tem um LEIA-ME apontando para lá). Testes: cd blood-reborn/manager/tests && python -m unittest test_updates -v.`

- [ ] **Step 4: Commit and push**

```bash
cd L:/Hydra/PS4/BB_Mod_Fases/blood-reborn
git add -A && git commit -m "Docs: phase 2 (updates) done

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin main
```

---

## Self-review notes

- Spec coverage (design §5, §6, §8, §9, §10): catalog read with 24 h cache (Task 3), Nexus check without key (Task 3), installed record (Task 2), "Installed · Available", What changed, Update (Tasks 3, 6), download sources in order GitHub → Nexus Premium → Nexus free → zip next to the manager (Task 4; a zip next to the manager is picked up by `Ler-Pacotes` and used without downloading), SHA-256 check (Task 4), wait for the game to close (Tasks 4, 5), backup and roll back (Tasks 4, 5), offline (Task 3), headless tests (all tasks), captures in four languages (Task 6).
- Known limit until phase 3: after a roll back, a prebuilt zCompat built for the newer version stays; phase 3 regenerates the merge after every change.
