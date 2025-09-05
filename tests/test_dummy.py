# Exemplo de teste automatizado (placeholder)
# Para rodar: python -m unittest tests/test_dummy.py
import unittest

class TestDummy(unittest.TestCase):
    def test_sanity(self):
        self.assertEqual(1+1, 2)

if __name__ == '__main__':
    unittest.main()
