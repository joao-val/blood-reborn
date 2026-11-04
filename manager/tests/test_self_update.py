"""Manager 2.2 (04/11/2026): it updates itself like the BB Port launcher (the catalog's "manager" entry, the small zip
from GitHub checked by SHA-256, a helper that swaps the files and keeps the previous version), downloads catalog mods
that are not on the PC, and updates every installed mod at once. The self-update always runs on a COPY of the manager:
the repository's own files are never touched."""
import os, re, shutil, subprocess, unittest, zipfile
from pathlib import Path
from harness import Fake, Server, FOLDER, MANAGER, sha256

CURRENT = re.search(r"\$VERSAO_GERENCIADOR = '([^']+)'", (MANAGER / 'manager' / 'BloodReborn.ps1').read_text(encoding='utf-8-sig')).group(1)


def manager_zip(dest, version, extra=None):
    """a small manager zip like the release one (Blood_Reborn_Mod_Manager/{the .bat, manager/*}), set to `version`"""
    top = 'Blood_Reborn_Mod_Manager/'
    with zipfile.ZipFile(dest, 'w') as z:
        z.write(MANAGER / 'Blood Reborn Mod Manager.bat', top + 'Blood Reborn Mod Manager.bat')
        for f in sorted((MANAGER / 'manager').iterdir()):
            if f.is_file() and f.suffix in ('.ps1', '.py', '.json'):
                data = f.read_bytes()
                if f.name == 'BloodReborn.ps1':
                    data = re.sub(rb"\$VERSAO_GERENCIADOR = '[^']+'", ("$VERSAO_GERENCIADOR = '%s'" % version).encode(), data)
                z.writestr(top + 'manager/' + f.name, data)
        for name, data in (extra or {}).items():
            z.writestr(name if name.startswith('..') else top + name, data)
    return dest


class Base(unittest.TestCase):
    def setUp(self):
        self.f = Fake(); self.s = Server(self.f)
        # the copy of the manager that the self-update may replace, with a mod zip beside it that must stay
        self.copy = self.f.root / 'Manager copy'
        shutil.copytree(MANAGER / 'manager', self.copy / 'manager', ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copy2(MANAGER / 'Blood Reborn Mod Manager.bat', self.copy)
        (self.copy / 'Blood_Reborn_Other_v1.0.zip').write_bytes(b'keep me')
        self.script = self.copy / 'manager' / 'BloodReborn.ps1'
        self.cat = ('-Catalogo', self.s.base + '/catalog.json')

    def tearDown(self):
        self.s.close(); self.f.close()

    def offer(self, version, sha=None, zipfile_path=None, notes=None):
        z = zipfile_path or manager_zip(self.f.web / 'files' / 'Blood_Reborn_Mod_Manager.zip', version)
        self.f.catalog('1.0', 'aa' * 32, manager={'version': version, 'package': 'Blood_Reborn_Mod_Manager.zip', 'sha256': sha or sha256(z),
                                                   'download': self.s.base + '/files/' + z.name,
                                                   'changes': notes or {version: {'en': 'Notes of the manager %s' % version}}})
        return z

    def version_of(self, folder):
        return re.search(r"\$VERSAO_GERENCIADOR = '([^']+)'", (folder / 'BloodReborn.ps1').read_text(encoding='utf-8-sig')).group(1)


class ManagerState(Base):
    def test_a_newer_manager_is_offered_with_its_notes(self):
        self.offer('9.9.9')
        code, rep, out = self.f.run('gerenciador', *self.cat)
        self.assertEqual(code, 0, out)
        self.assertTrue(rep['Atualizar'], rep)
        self.assertEqual((rep['Atual'], rep['Disponivel']), (CURRENT, '9.9.9'))
        self.assertEqual(rep['Notas'][0]['Versao'], '9.9.9')

    def test_the_same_version_is_not_an_update(self):
        self.offer(CURRENT)
        code, rep, out = self.f.run('gerenciador', *self.cat)
        self.assertFalse(rep['Atualizar'], rep)


class SelfUpdate(Base):
    def test_the_files_are_swapped_and_the_previous_version_is_kept(self):
        self.offer('9.9.9', zipfile_path=manager_zip(self.f.web / 'files' / 'Blood_Reborn_Mod_Manager.zip', '9.9.9',
                                                     {'manager/novo.txt': 'new file'}))
        code, rep, out = self.f.run('atualizar_gerenciador', *self.cat, script=self.script)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.version_of(self.copy / 'manager'), '9.9.9')
        self.assertEqual((self.copy / 'manager' / 'novo.txt').read_text(), 'new file')
        self.assertEqual((self.copy / 'Blood_Reborn_Other_v1.0.zip').read_bytes(), b'keep me')
        g = self.f.data / 'gerenciador'
        self.assertEqual(self.version_of(g / 'anterior' / 'manager'), CURRENT)
        self.assertEqual((g / 'atualizado.txt').read_text(encoding='utf-8'), '9.9.9')
        self.assertFalse((g / 'novo').exists())
        self.assertFalse((g / 'falhou.txt').exists())

    def test_a_wrong_sha_changes_nothing(self):
        self.offer('9.9.9', sha='bb' * 32)
        code, rep, out = self.f.run('atualizar_gerenciador', *self.cat, script=self.script)
        self.assertEqual(code, 3, out)
        self.assertEqual(self.version_of(self.copy / 'manager'), CURRENT)

    def test_a_zip_with_a_path_outside_is_refused(self):
        z = manager_zip(self.f.web / 'files' / 'Blood_Reborn_Mod_Manager.zip', '9.9.9', {'../evil.txt': 'x'})
        self.offer('9.9.9', zipfile_path=z)
        code, rep, out = self.f.run('atualizar_gerenciador', *self.cat, script=self.script)
        self.assertEqual(code, 3, out)
        self.assertEqual(self.version_of(self.copy / 'manager'), CURRENT)
        self.assertFalse(list(self.f.root.rglob('evil.txt')))


class CatalogMods(Base):
    def test_a_catalog_mod_not_on_the_pc_is_downloaded_and_installed(self):
        z = self.f.package('1.0', {'chr/a.txt': 'one'}, where=self.f.web / 'files')
        self.f.catalog('1.0', sha256(z), download=self.s.base + '/files/' + z.name)
        code, rep, out = self.f.run('baixar', *self.cat, mods=FOLDER)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'one')
        rec = (self.f.port / 'mods' / FOLDER / 'blood_reborn_installed.json').read_text(encoding='utf-8-sig')
        self.assertIn('github', rec)

    def test_update_all_updates_every_installed_mod(self):
        self.f.package('1.0', {'chr/a.txt': 'one'})
        self.f.run('instalar', mods=FOLDER)
        z = self.f.package('1.1', {'chr/a.txt': 'two'}, where=self.f.web / 'files')
        self.f.catalog('1.1', sha256(z), download=self.s.base + '/files/' + z.name)
        code, rep, out = self.f.run('atualizar_tudo', *self.cat)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.f.installed('chr/a.txt'), 'two')


class Window(Base):
    def test_the_window_draws_the_banner_and_the_catalog_cards(self):
        z = self.f.package('1.0', {'chr/a.txt': 'one'}, where=self.f.web / 'files')
        self.f.catalog('1.0', sha256(z), download=self.s.base + '/files/' + z.name, summary={'en': 'A test mod.', 'pt': 'Um mod de teste.'},
                       manager={'version': '9.9.9', 'package': 'Blood_Reborn_Mod_Manager.zip', 'sha256': 'aa' * 32,
                                'download': self.s.base + '/files/x.zip', 'changes': {'9.9.9': {'en': 'x'}}})
        png = Path(os.environ.get('BR_CAPTURE_DIR', str(self.f.root))) / 'capture_mods_pt.png'
        r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', str(self.script),
                            '-PastaPort', str(self.f.port), '-PastaDados', str(self.f.data), '-Captura', str(png), '-Pagina', 'mods',
                            '-Lingua', 'pt', '-SemNavegador'] + list(self.cat), capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertGreater(png.stat().st_size, 10000)


if __name__ == '__main__':
    unittest.main()
