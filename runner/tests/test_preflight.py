import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
from preflight import parse_gpu_csv


class PreflightTest(unittest.TestCase):
    def test_parse_gpu_csv(self):
        rows = parse_gpu_csv("0, NVIDIA H100 80GB HBM3, GPU-1234, 81559, 9.0\n")
        self.assertEqual(rows[0]["memory_mib"], 81559)
        self.assertEqual(rows[0]["compute_capability"], "9.0")

    def test_rejects_unknown_shape(self):
        with self.assertRaises(ValueError):
            parse_gpu_csv("0, H100")


if __name__ == "__main__":
    unittest.main()
