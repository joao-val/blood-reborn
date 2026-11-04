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


class State(Base):
    def test_reports_the_update_and_the_notes(self):
        self.f.package('1.0', {'chr/a.txt': 'one'})
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


if __name__ == '__main__':
    unittest.main()
