import json, threading, time, unittest
from harness import Fake, Server, FOLDER, sha256


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


if __name__ == '__main__':
    unittest.main()
