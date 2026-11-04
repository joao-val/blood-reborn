import unittest
from harness import Fake, Server


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


if __name__ == '__main__':
    unittest.main()
