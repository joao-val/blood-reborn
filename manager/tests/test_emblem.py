"""Manager 2.2.1 (04/11/2026): the window emblem is the red rune of the Hunter's Mark, made on the player's PC from
their own game (dvdroot_ps4/menu/menu_knowledge_00011.tpf.dcx) by emblema_marca.py; nothing of the game is in the
repository. Needs the game's icon file and a Python with Pillow (BB_GAME_DIR, BR_PIL_PATH); skipped otherwise.
The PS4 deswizzle is checked against a DDS exported by fxrtex when BR_ICON_DDS is given."""
import importlib.util, os, shutil, struct, sys, unittest, zlib
from pathlib import Path
from harness import Fake, Server, MANAGER

GAME = Path(os.environ.get('BB_GAME_DIR', r'L:\Hydra\PS4\BloodbornePC\CUSA03173'))
ICON = GAME / 'dvdroot_ps4' / 'menu' / 'menu_knowledge_00011.tpf.dcx'
PIL_PATH = Path(os.environ.get('BR_PIL_PATH', r'L:\Hydra\PS4\BB_Mod_Fases\ferramentas\texture_python'))
ICON_DDS = Path(os.environ.get('BR_ICON_DDS', ''))
READY = ICON.is_file() and (PIL_PATH / 'PIL').is_dir()

_spec = importlib.util.spec_from_file_location('emblema_marca', MANAGER / 'manager' / 'emblema_marca.py')
E = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(E)


@unittest.skipUnless(ICON.is_file(), 'needs the game icon (BB_GAME_DIR)')
class Texture(unittest.TestCase):
    def test_the_texture_is_bc7_400(self):
        dcx = ICON.read_bytes()
        w, h, fmt, data = E.tpf_textura(zlib.decompress(dcx[0x4C:]))
        self.assertEqual((w, h, fmt), (400, 400, 98))
        self.assertEqual(len(E.desembaralha_bc(data, w, h)), 100 * 100 * 16)

    @unittest.skipUnless(ICON_DDS.is_file(), 'needs the fxrtex export of the icon (BR_ICON_DDS)')
    def test_the_deswizzle_matches_fxrtex_byte_for_byte(self):
        w, h, fmt, data = E.tpf_textura(zlib.decompress(ICON.read_bytes()[0x4C:]))
        self.assertEqual(E.desembaralha_bc(data, w, h), ICON_DDS.read_bytes()[148:])


@unittest.skipUnless(READY, 'needs the game icon and Pillow (BB_GAME_DIR, BR_PIL_PATH)')
class Emblem(unittest.TestCase):
    def setUp(self):
        self.f = Fake(); self.s = Server(self.f)
        # the game beside the fake port, as the BB Port expects by default (CUSA03173 next to its folder)
        dst = self.f.root / 'CUSA03173' / 'dvdroot_ps4' / 'menu'; dst.mkdir(parents=True)
        shutil.copy2(ICON, dst / ICON.name)
        os.environ.update(BR_PYTHON=sys.executable, BR_PYTHON_PRE='-s', PYTHONPATH=str(PIL_PATH))   # -s (not -I): PYTHONPATH counts

    def tearDown(self):
        for k in ('BR_PYTHON', 'BR_PYTHON_PRE', 'PYTHONPATH'):
            os.environ.pop(k, None)
        self.s.close(); self.f.close()

    def test_the_red_rune_is_made_from_the_players_game(self):
        code, rep, out = self.f.run('emblema')
        self.assertEqual(code, 0, out)
        png = (self.f.data / 'emblema_marca.png').read_bytes()
        self.assertEqual(png[:8], b'\x89PNG\r\n\x1a\n')
        w, h, depth, color = struct.unpack('>IIBB', png[16:26])
        self.assertEqual((w, h, color), (256, 256, 6))              # 256x256 RGBA
        sys.path.insert(0, str(PIL_PATH))
        from PIL import Image
        im = Image.open(self.f.data / 'emblema_marca.png')
        r, g, b, a = im.getpixel((128, 60))                         # the vertical stroke of the rune: red and opaque
        self.assertTrue(a > 200 and r > 120 and g < 60 and b < 60, (r, g, b, a))
        self.assertEqual(im.getpixel((5, 5))[3], 0)                 # the corner: transparent

    def test_without_the_game_nothing_is_made(self):
        shutil.rmtree(self.f.root / 'CUSA03173')
        code, rep, out = self.f.run('emblema')
        if (Path(os.environ.get('APPDATA', '')) / 'bbport-launcher' / 'settings.json').is_file():
            self.skipTest('this PC has a launcher game folder')
        self.assertEqual(code, 3, out)
        self.assertFalse((self.f.data / 'emblema_marca.png').exists())


if __name__ == '__main__':
    unittest.main()
