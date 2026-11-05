"""Which zip a compatibility folder comes from (manager 2.2.2).

Every package zip carries every compatibility folder, built with the mod versions of its own build. Up to 2.2.1 the
folder came from the first zip in the preference order (the Arsenal's), so a player with Hunter's Arsenal 1.0.1
(built with Merciless Night 1.31) and Merciless Night 1.32 got the 1.31 gameparam over the new one. Now the zip whose
compatibility was built with the versions being installed ("versoes" in blood_reborn.json) wins; without one, the
order decides as before."""
import json, unittest, zipfile
from harness import Fake

ARSENAL, NIGHT = 'Blood Reborn - Hunters Arsenal', 'Blood Reborn - Merciless Night'
COMPAT = 'Blood Reborn - zCompat Arsenal + Merciless Night'
PARAM = 'param/gameparam/gameparam.parambnd.dcx'


def package(fake, folder, version, compat_text, versoes=None):
    top = '%s v%s' % (folder, version)
    z = fake.data / 'pacotes' / ('Blood_Reborn_%s_v%s.zip' % (folder.split(' - ', 1)[1].replace(' ', '_'), version))
    entry = {'pasta': COMPAT, 'mods': [ARSENAL, NIGHT]}
    if versoes:
        entry['versoes'] = versoes
    with zipfile.ZipFile(z, 'w') as zf:
        zf.writestr(top + '/blood_reborn.json', json.dumps({'nome': folder.split(' - ', 1)[1], 'versao': version,
                                                            'pasta': folder, 'patches': [], 'compat': [entry]}))
        zf.writestr(top + '/README_EN.txt', 'test\n')
        zf.writestr('%s/mods/%s/dvdroot_ps4/%s' % (top, folder, PARAM), '%s %s alone' % (folder, version))
        zf.writestr('%s/Compatibilidade - Compatibility/%s/dvdroot_ps4/%s' % (top, COMPAT, PARAM), compat_text)
    return z


class CompatSource(unittest.TestCase):
    def setUp(self):
        self.f = Fake()

    def tearDown(self):
        self.f.close()

    def installed_compat(self):
        code, rep, out = self.f.run('instalar', mods=ARSENAL + ',' + NIGHT)
        self.assertEqual(code, 0, out)
        self.assertFalse([i for i in rep if i['Nivel'] == 'erro'], rep)
        order = json.loads((self.f.port / 'mods.json').read_text(encoding='utf-8-sig'))['order']
        self.assertEqual(order[-1], COMPAT, order)
        return (self.f.port / 'mods' / COMPAT / 'dvdroot_ps4' / PARAM).read_text(encoding='utf-8')

    def test_the_zip_built_with_the_installed_versions_wins(self):
        package(self.f, ARSENAL, '1.0.1', 'built with Night 1.31')                      # an old zip: no versoes
        package(self.f, NIGHT, '1.33', 'built with Night 1.33', {ARSENAL: '1.0.1', NIGHT: '1.33'})
        self.assertEqual(self.installed_compat(), 'built with Night 1.33')

    def test_a_zip_built_with_other_versions_loses(self):
        package(self.f, ARSENAL, '1.0.1', 'built with Night 1.32', {ARSENAL: '1.0.1', NIGHT: '1.32'})   # first in the order
        package(self.f, NIGHT, '1.33', 'built with Night 1.33', {ARSENAL: '1.0.1', NIGHT: '1.33'})
        self.assertEqual(self.installed_compat(), 'built with Night 1.33')

    def test_without_versions_the_order_decides_as_before(self):
        package(self.f, ARSENAL, '1.0.1', 'from the Arsenal zip')
        package(self.f, NIGHT, '1.32', 'from the Night zip')
        self.assertEqual(self.installed_compat(), 'from the Arsenal zip')

    def test_repair_replaces_an_old_compat_folder(self):
        package(self.f, ARSENAL, '1.0.1', 'built with Night 1.31')
        package(self.f, NIGHT, '1.33', 'built with Night 1.33', {ARSENAL: '1.0.1', NIGHT: '1.33'})
        self.installed_compat()
        (self.f.port / 'mods' / COMPAT / 'dvdroot_ps4' / PARAM).write_text('built with Night 1.31', encoding='utf-8')
        code, rep, out = self.f.run('corrigir')
        self.assertEqual(code, 0, out)
        self.assertEqual((self.f.port / 'mods' / COMPAT / 'dvdroot_ps4' / PARAM).read_text(encoding='utf-8'),
                         'built with Night 1.33')


if __name__ == '__main__':
    unittest.main()
