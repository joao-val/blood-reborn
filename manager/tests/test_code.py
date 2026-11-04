"""Static checks of the manager's PowerShell files. BloodReborn.ps1 dot-sources Atualizacoes.ps1 and then the window
(BloodReborn_janela.ps1): a function defined again in a later file silently replaces the earlier one (PowerShell
names are case-insensitive). That happened in 2.1.0: the window's Atualizar-Textos (screen texts) replaced the merge of
the BB Port texts, so Apply and Fix all from the window never built the texts folder; the headless tests missed it."""
import re, unittest
from pathlib import Path

CODE = Path(__file__).resolve().parents[1] / 'manager'
FILES = ('BloodReborn.ps1', 'Atualizacoes.ps1', 'BloodReborn_janela.ps1')
STANDALONE = ('Trocar_Gerenciador.ps1',)   # run on its own from %TEMP% (not dot-sourced)


class Code(unittest.TestCase):
    def test_no_function_is_defined_twice(self):
        seen = {}
        for name in FILES:
            text = (CODE / name).read_text(encoding='utf-8-sig')
            for m in re.finditer(r'^\s*function\s+([\w-]+)', text, re.M | re.I):
                key = m.group(1).lower()
                self.assertNotIn(key, seen, '%s defined in %s and in %s' % (m.group(1), seen.get(key), name))
                seen[key] = name

    def test_scripts_keep_the_bom_for_powershell_5(self):
        # Windows PowerShell 5.1 reads a .ps1 without BOM as ANSI: the accents of the texts break
        for name in FILES + STANDALONE:
            self.assertEqual((CODE / name).read_bytes()[:3], b'\xef\xbb\xbf', name)


if __name__ == '__main__':
    unittest.main()
