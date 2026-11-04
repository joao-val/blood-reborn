"""Test harness of the Blood Reborn manager: a fake BB Port, fake packages (the layout of blood_reborn_pacotes.py), a
local HTTP server standing in for GitHub and Nexus, and a runner for BloodReborn.ps1 in headless mode (-Acao)."""
import hashlib, http.server, json, shutil, subprocess, tempfile, threading, zipfile
from pathlib import Path

MANAGER = Path(__file__).resolve().parents[1]
SCRIPT = MANAGER / 'manager' / 'BloodReborn.ps1'
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

    def package(self, version, files, patches=(), where=None, folder=FOLDER, info=None):
        """a package zip; returns its path (default: <data>\\pacotes, where the manager keeps downloads).
        files: {path under dvdroot_ps4: str or bytes}; info: extra blood_reborn.json keys (e.g. "textos")"""
        where = Path(where or self.data / 'pacotes')
        top = '%s v%s' % (folder, version)
        z = where / ('Blood_Reborn_%s_v%s.zip' % (folder.split(' - ', 1)[1].replace(' ', '_'), version))
        with zipfile.ZipFile(z, 'w') as zf:
            zf.writestr(top + '/blood_reborn.json', json.dumps(dict({'nome': folder.split(' - ', 1)[1], 'versao': version, 'pasta': folder,
                                                                       'patches': list(patches), 'compat': []}, **(info or {}))))
            zf.writestr(top + '/README_EN.txt', '✨ WHAT THIS MOD DOES\nTest mod %s\n✅ YOU NEED\n' % version)
            for rel, data in files.items():
                zf.writestr('%s/mods/%s/dvdroot_ps4/%s' % (top, folder, rel), data)
            for p in patches:
                zf.writestr(top + '/patches/' + p, '<Patch v="%s"/>' % version)
        return z

    def catalog(self, version, sha, download=None, nexus_mod=None, nexus_file=None, notes=None, folder=FOLDER, manager=None, summary=None):
        """the fake catalog; manager: the "manager" entry (2.2 self-update); summary: {lang: text} of the mod"""
        cat = {'schema': 1, 'updated': '2026-11-04', 'github': {'repository': 'test/test'},
               'nexus': {'game_domain': 'bloodborne', 'game_id': 2708},
               'mods': [{'key': 'test', 'name': 'Test Mod', 'folder': folder, 'version': version, 'status': 'released',
                         'package': 'Blood_Reborn_Test_Mod_v%s.zip' % version, 'sha256': sha, 'download': download,
                         'nexus_mod_id': nexus_mod, 'nexus_file_id': nexus_file,
                         'changes': notes or {version: {'en': 'Notes of %s' % version}}}]}
        if summary:
            cat['mods'][0]['summary'] = summary
        if manager:
            cat['manager'] = manager
        (self.web / 'catalog.json').write_text(json.dumps(cat), encoding='utf-8')

    def run(self, acao, *extra, mods=None, report=True, timeout=180, script=None):
        """runs BloodReborn.ps1 headless; returns (returncode, report JSON or None, stdout+stderr).
        script: another copy of the manager (self-update tests must never touch the repository's own files)"""
        out = self.root / 'report.json'
        if out.exists():
            out.unlink()
        args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(script or SCRIPT),
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
