import json
import unittest
from pathlib import Path


class GcpRunnerProfilesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).parents[2] / "infra" / "gcp" / "profiles.json"
        cls.profiles = json.loads(path.read_text(encoding="utf-8"))

    def test_l4_is_low_risk_taiwan_default(self):
        l4 = self.profiles["l4"]
        self.assertEqual(l4["zone"], "asia-east1-a")
        self.assertEqual(l4["machine_type"], "g2-standard-4")
        self.assertEqual(l4["gpu_count"], 1)
        self.assertLessEqual(l4["timeout_minutes"], 60)

    def test_h100_is_explicit_multi_gpu_profile(self):
        h100 = self.profiles["h100"]
        self.assertEqual(h100["zone"], "asia-east1-c")
        self.assertEqual(h100["machine_type"], "a3-highgpu-8g")
        self.assertEqual(h100["gpu_count"], 8)
        self.assertIn("multigpu", h100["labels"])
        self.assertIn("nvlink", h100["labels"])

    def test_every_profile_has_a_cost_timeout(self):
        for name, profile in self.profiles.items():
            with self.subTest(profile=name):
                self.assertGreater(profile["timeout_minutes"], 0)
                self.assertLessEqual(profile["timeout_minutes"], 90)


if __name__ == "__main__":
    unittest.main()
