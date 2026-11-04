"""The BB Port's own menu texts (its out/quit_text and out/rebirth layers, below every mod) merged with the texts of our
mods (manager 2.1, 04/11/2026). Needs a real BB Port's scripts/quit_menu.py + hud_layout.py (their text functions,
copied into the fake port, never into this repository) and the game's menu.msgbnd.dcx: set BB_PORT_SCRIPTS and
BB_GAME_MSG, or the tests are skipped. The merge runs with this Python (BR_PYTHON) instead of Bloodborne.exe --script."""
import importlib.util, json, os, shutil, sys, unittest
from pathlib import Path
from harness import Fake, Server, FOLDER

PORT_SCRIPTS = Path(os.environ.get('BB_PORT_SCRIPTS', r'L:\Hydra\PS4\BloodbornePC\bbport-windows\scripts'))
GAME_MSG = Path(os.environ.get('BB_GAME_MSG', r'L:\Hydra\PS4\BloodbornePC\CUSA03173\dvdroot_ps4\msg'))
TEXTS = 'Blood Reborn - zCompat BB Port texts'
READY = (PORT_SCRIPTS / 'quit_menu.py').is_file() and (GAME_MSG / 'engus' / 'menu.msgbnd.dcx').is_file()
if READY:
    _spec = importlib.util.spec_from_file_location('quit_menu', PORT_SCRIPTS / 'quit_menu.py')
    sys.path.insert(0, str(PORT_SCRIPTS)); Q = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(Q)


def edit_menu(changes, lang='engus'):
    """the game's menu.msgbnd.dcx with {fmg: {id: text}} applied"""
    raw = (GAME_MSG / lang / 'menu.msgbnd.dcx').read_bytes()
    bnd = Q.unpack_dcx(raw); files = {fid: bnd[o:o + n] for _, o, n, fid in Q.bnd4_files(bnd)}
    rep = {}
    for fid, texts in changes.items():
        s = Q.read_fmg(files[fid]); s.update(texts); rep[fid] = Q.write_fmg(files[fid], s)
    return Q.pack_dcx(raw, Q.rebuild_bnd4(bnd, rep))


def read_menu(path):
    bnd = Q.unpack_dcx(Path(path).read_bytes())
    return {fid: Q.read_fmg(bnd[o:o + n]) for _, o, n, fid in Q.bnd4_files(bnd)}


@unittest.skipUnless(READY, 'needs a BB Port quit_menu.py and the game menu (BB_PORT_SCRIPTS, BB_GAME_MSG)')
class PortTexts(unittest.TestCase):
    PORT = {200: {119001: 'PC Settings', 401307: 'Quit to Desktop'}, 30: {15000170: 'Rebirth'}}

    def setUp(self):
        self.f = Fake(); self.s = Server(self.f)
        os.environ['BR_PYTHON'] = sys.executable
        scripts = self.f.port / 'scripts'; scripts.mkdir()
        for n in ('quit_menu.py', 'hud_layout.py'):
            shutil.copy2(PORT_SCRIPTS / n, scripts / n)
        self.layer('rebirth', self.PORT)
        # the mod: one text of its own (FMG 35) and one it must NOT bring along (FMG 30, as a leftover of another mod)
        self.f.package('1.0', {'msg/engus/menu.msgbnd.dcx': edit_menu({35: {13701: 'Pact A'}, 30: {1000: 'leftover'}}),
                               'chr/a.txt': 'x'}, info={'textos': {'35': [13701]}})
        self.menu = self.f.port / 'mods' / TEXTS / 'dvdroot_ps4' / 'msg' / 'engus' / 'menu.msgbnd.dcx'

    def tearDown(self):
        os.environ.pop('BR_PYTHON', None)
        self.s.close(); self.f.close()

    def layer(self, name, changes):
        p = self.f.port / 'out' / name / 'dvdroot_ps4' / 'msg' / 'engus' / 'menu.msgbnd.dcx'
        p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(edit_menu(changes))

    def errors(self, rep):
        return [i for i in rep if i['Nivel'] == 'erro']

    def test_install_merges_the_port_texts_with_the_mod_texts(self):
        code, rep, out = self.f.run('instalar', mods=FOLDER)
        self.assertEqual(code, 0, out)
        m, game = read_menu(self.menu), read_menu(GAME_MSG / 'engus' / 'menu.msgbnd.dcx')
        self.assertEqual(m[200][119001], 'PC Settings')
        self.assertEqual(m[200][401307], 'Quit to Desktop')
        self.assertEqual(m[30][15000170], 'Rebirth')
        self.assertEqual(m[35][13701], 'Pact A')
        self.assertEqual(m[30].get(1000), game[30].get(1000))          # the leftover stays out
        order = json.loads((self.f.port / 'mods.json').read_text(encoding='utf-8-sig'))['order']
        self.assertEqual(order[-1], TEXTS)
        self.assertFalse(self.errors(rep), rep)
        self.assertTrue([i for i in rep if i['Nivel'] == 'ok' and TEXTS in i['Texto']], rep)

    def test_a_changed_port_layer_is_found_and_fixed(self):
        self.f.run('instalar', mods=FOLDER)
        self.layer('rebirth', {200: {119001: 'PC Settings', 119002: 'Graphics', 401307: 'Quit to Desktop'}, 30: {15000170: 'Rebirth'}})
        code, rep, out = self.f.run('verificar')
        self.assertTrue([i for i in self.errors(rep) if TEXTS in i['Texto'] and i['Corrige']], rep)
        code, rep, out = self.f.run('corrigir')
        self.assertEqual(code, 0, out)
        self.assertEqual(read_menu(self.menu)[200][119002], 'Graphics')
        self.assertFalse(self.errors(rep), rep)

    def test_without_a_port_layer_the_folder_goes_and_a_hint_shows(self):
        self.f.run('instalar', mods=FOLDER)
        shutil.rmtree(self.f.port / 'out')
        code, rep, out = self.f.run('verificar')
        self.assertTrue([i for i in self.errors(rep) if TEXTS in i['Texto']], rep)
        code, rep, out = self.f.run('corrigir')
        self.assertFalse((self.f.port / 'mods' / TEXTS).exists())
        self.assertFalse(self.errors(rep), rep)
        self.assertTrue([i for i in rep if i['Nivel'] == 'aviso' and 'Check' in i['Texto']], rep)
        (self.f.port / 'bbport.ini').write_text('quit_to_desktop=0\npc_menu=0\nrebirth=0\n', encoding='utf-8')
        code, rep, out = self.f.run('verificar')
        self.assertFalse([i for i in rep if i['Nivel'] == 'aviso' and 'Check' in i['Texto']], rep)

    def test_quit_text_layer_is_used_when_there_is_no_rebirth_layer(self):
        shutil.rmtree(self.f.port / 'out' / 'rebirth')
        self.layer('quit_text', {200: {401307: 'Quit to Desktop'}})
        code, rep, out = self.f.run('instalar', mods=FOLDER)
        self.assertEqual(code, 0, out)
        m = read_menu(self.menu)
        self.assertEqual(m[200][401307], 'Quit to Desktop')
        self.assertEqual(m[35][13701], 'Pact A')

    def test_switching_the_mod_off_removes_the_texts_folder(self):
        self.f.run('instalar', mods=FOLDER)
        code, rep, out = self.f.run('instalar', mods='')
        self.assertEqual(code, 0, out)
        self.assertFalse((self.f.port / 'mods' / TEXTS).exists())
        order = json.loads((self.f.port / 'mods.json').read_text(encoding='utf-8-sig'))['order']
        self.assertNotIn(TEXTS, order)

    def test_a_mod_without_menu_texts_needs_no_folder(self):
        self.f.package('1.1', {'chr/a.txt': 'y'})          # a fresh install takes the newest package: no menu in it
        code, rep, out = self.f.run('instalar', mods=FOLDER)
        self.assertEqual(code, 0, out)
        self.assertFalse((self.f.port / 'mods' / TEXTS).exists())
        self.assertFalse(self.errors(rep), rep)

    def test_a_package_without_the_textos_key_uses_the_manager_list(self):
        # Arsenal 1.0 / 1.0.1 have no "textos" in blood_reborn.json: textos_ids.json in the manager folder has the list
        ids = json.loads((Path(__file__).resolve().parents[1] / 'manager' / 'textos_ids.json').read_text(encoding='utf-8'))
        arsenal = 'Blood Reborn - Hunters Arsenal'
        first = ids[arsenal]['35'][0]
        self.f.package('1.0', {'msg/engus/menu.msgbnd.dcx': edit_menu({35: {first: 'Arsenal pact'}})}, folder=arsenal)
        code, rep, out = self.f.run('instalar', mods=arsenal)
        self.assertEqual(code, 0, out)
        m = read_menu(self.menu)
        self.assertEqual(m[35][first], 'Arsenal pact')
        self.assertEqual(m[200][119001], 'PC Settings')


if __name__ == '__main__':
    unittest.main()
