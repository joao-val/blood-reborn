"""The manager's shortcut with the Hunter's Mark icon (manager 2.2.6).

A .bat file cannot have its own icon on Windows. On every opening the manager keeps, in its own folder, a shortcut
"Blood Reborn Mod Manager.lnk" whose icon is the same red rune the window shows (emblema_marca.png in the data folder,
turned into BloodReborn.ico). The shortcut starts PowerShell directly (no black .bat window). It is rebuilt when it is
missing or points somewhere else."""
import os, shutil, struct, subprocess, unittest, zlib
from harness import Fake, MANAGER


def png(size=64):
    raw = b''.join(b'\0' + bytes((200, 0, 0, 255)) * size for _ in range(size))
    chunk = lambda kind, data: struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def shortcut(path):
    ps = ('[Console]::OutputEncoding = [Text.Encoding]::UTF8; $s = (New-Object -ComObject WScript.Shell).CreateShortcut("%s"); '
          '$s.TargetPath; $s.Arguments; $s.IconLocation' % path)
    out = subprocess.run(['powershell', '-NoProfile', '-Command', ps], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return out.stdout.strip().splitlines()


class Shortcut(unittest.TestCase):
    def setUp(self):
        self.f = Fake()
        self.copy = self.f.root / 'Manager copy'
        shutil.copytree(MANAGER / 'manager', self.copy / 'manager', ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copy2(MANAGER / 'Blood Reborn Mod Manager.bat', self.copy)
        self.script = self.copy / 'manager' / 'BloodReborn.ps1'
        self.lnk = self.copy / 'Blood Reborn Mod Manager.lnk'
        (self.f.data / 'emblema_marca.png').write_bytes(png())

    def tearDown(self):
        self.f.close()

    def run_shortcut(self):
        code, rep, out = self.f.run('atalho', script=self.script)
        self.assertEqual(code, 0, out)

    def test_the_shortcut_gets_the_rune_icon_and_opens_the_manager(self):
        self.run_shortcut()
        self.assertTrue(self.lnk.exists())
        ico = (self.f.data / 'BloodReborn.ico').read_bytes()
        self.assertEqual(ico[:4], b'\0\0\1\0')
        count = struct.unpack_from('<H', ico, 4)[0]
        self.assertGreaterEqual(count, 4)
        first = struct.unpack_from('<I', ico, 6 + 12)[0]
        self.assertEqual(ico[first:first + 8], b'\x89PNG\r\n\x1a\n')
        target, args, icon = shortcut(self.lnk)
        self.assertTrue(target.lower().endswith('powershell.exe'), target)
        self.assertIn(os.path.realpath(self.script).lower(), args.lower())
        self.assertIn('-WindowStyle Hidden', args)
        caminho, indice = icon.rsplit(',', 1)
        self.assertEqual(os.path.realpath(caminho).lower(), os.path.realpath(self.f.data / 'BloodReborn.ico').lower())
        self.assertEqual(indice, '0')

    def test_a_missing_or_wrong_shortcut_is_rebuilt(self):
        self.run_shortcut()
        self.lnk.unlink()
        self.run_shortcut()
        self.assertTrue(self.lnk.exists())
        ps = '$s = (New-Object -ComObject WScript.Shell).CreateShortcut("%s"); $s.Arguments = "-File x.ps1"; $s.Save()' % self.lnk
        subprocess.run(['powershell', '-NoProfile', '-Command', ps], check=True)
        self.run_shortcut()
        self.assertIn(os.path.realpath(self.script).lower(), shortcut(self.lnk)[1].lower())


if __name__ == '__main__':
    unittest.main()
