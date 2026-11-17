"""Order of the compatibility folders (manager 2.2.5).

A player with Hunter's Arsenal, Merciless Night and Fogside Lantern needs four compatibility folders, and they share
files: the gameparam is in all four. The BB Port keeps the last one in mods.json, so the folder of the three mods must
come after the folders of two. Up to 2.2.4 the manager sorted them by name: "zCompat Merciless Night + Fogside" ended up
last and its gameparam (no Arsenal rows) covered the one of the three mods (17/11/2026, a friend's game: the Arsenal
data were missing). Now a folder comes after every folder whose mods are a part of its own; the check flags the wrong
order and the repair puts it right."""
import json, unittest, zipfile
from harness import Fake

ARSENAL, NIGHT, FOG = 'Blood Reborn - Hunters Arsenal', 'Blood Reborn - Merciless Night', 'Blood Reborn - Fogside Lantern'
COMPATS = {'Blood Reborn - zCompat Arsenal + Fogside': [ARSENAL, FOG],
           'Blood Reborn - zCompat Arsenal + Merciless Night': [ARSENAL, NIGHT],
           'Blood Reborn - zCompat Arsenal + Merciless Night + Fogside': [ARSENAL, NIGHT, FOG],
           'Blood Reborn - zCompat Merciless Night + Fogside': [NIGHT, FOG]}
TRIPLE = 'Blood Reborn - zCompat Arsenal + Merciless Night + Fogside'
PARAM = 'param/gameparam/gameparam.parambnd.dcx'


def package(fake, folder, version):
    top = '%s v%s' % (folder, version)
    z = fake.data / 'pacotes' / ('Blood_Reborn_%s_v%s.zip' % (folder.split(' - ', 1)[1].replace(' ', '_'), version))
    with zipfile.ZipFile(z, 'w') as zf:
        zf.writestr(top + '/blood_reborn.json', json.dumps({'nome': folder.split(' - ', 1)[1], 'versao': version, 'pasta': folder,
                                                            'patches': [], 'compat': [{'pasta': c, 'mods': m} for c, m in COMPATS.items()]}))
        zf.writestr(top + '/README_EN.txt', 'test\n')
        zf.writestr('%s/mods/%s/dvdroot_ps4/%s' % (top, folder, PARAM), folder + ' alone')
        for c in COMPATS:
            zf.writestr('%s/Compatibilidade - Compatibility/%s/dvdroot_ps4/%s' % (top, c, PARAM), c)


class CompatOrder(unittest.TestCase):
    def setUp(self):
        self.f = Fake()
        package(self.f, ARSENAL, '1.1.2'); package(self.f, NIGHT, '1.38'); package(self.f, FOG, '1.7')

    def tearDown(self):
        self.f.close()

    def order(self):
        return json.loads((self.f.port / 'mods.json').read_text(encoding='utf-8-sig'))['order']

    def assert_supersets_last(self, order):
        for c, mods in COMPATS.items():
            for d, outros in COMPATS.items():
                if c != d and set(mods) < set(outros):
                    self.assertLess(order.index(c), order.index(d), order)
        self.assertEqual(order[-1], TRIPLE, order)

    def test_install_puts_the_folder_of_three_mods_last(self):
        code, rep, out = self.f.run('instalar', mods=','.join((ARSENAL, NIGHT, FOG)))
        self.assertEqual(code, 0, out)
        self.assertFalse([i for i in rep if i['Nivel'] == 'erro'], rep)
        self.assert_supersets_last(self.order())

    def test_the_wrong_order_of_older_managers_is_flagged_and_repaired(self):
        code, rep, out = self.f.run('instalar', mods=','.join((ARSENAL, NIGHT, FOG)))
        self.assertEqual(code, 0, out)
        cfg = json.loads((self.f.port / 'mods.json').read_text(encoding='utf-8-sig'))
        cfg['order'] = [x for x in cfg['order'] if x not in COMPATS] + sorted(COMPATS)      # the 2.2.4 order: by name
        (self.f.port / 'mods.json').write_text(json.dumps(cfg), encoding='utf-8')
        code, rep, out = self.f.run('verificar')
        self.assertEqual(code, 0, out)
        self.assertTrue([i for i in rep if i['Nivel'] == 'erro' and TRIPLE in i.get('Texto', json.dumps(i))], rep)
        code, rep, out = self.f.run('corrigir')
        self.assertEqual(code, 0, out)
        self.assertFalse([i for i in rep if i['Nivel'] == 'erro'], rep)
        self.assert_supersets_last(self.order())


if __name__ == '__main__':
    unittest.main()
