import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]


class GcpRunnerContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (ROOT / ".github" / "workflows" / "gcp-gpu-baseline.yml").read_text(encoding="utf-8")
        cls.provision = (ROOT / "infra" / "gcp" / "scripts" / "gcp-runner.sh").read_text(encoding="utf-8")
        cls.startup = (ROOT / "infra" / "gcp" / "startup" / "gpu-runner.sh").read_text(encoding="utf-8")

    def test_workflow_is_manual_and_approval_gated(self):
        self.assertIn("workflow_dispatch:", self.workflow)
        self.assertNotIn("pull_request:", self.workflow)
        self.assertIn("environment: gcp-gpu-approval", self.workflow)

    def test_cleanup_runs_even_after_failure(self):
        self.assertIn("if: always()", self.workflow)
        self.assertIn("gcp-runner.sh delete", self.workflow)

    def test_vm_has_no_public_ip_and_a_hard_ttl(self):
        self.assertIn("--no-address", self.provision)
        self.assertIn("--max-run-duration=2h", self.provision)
        self.assertIn("--instance-termination-action=DELETE", self.provision)

    def test_runner_is_single_use(self):
        self.assertIn("--ephemeral", self.startup)
        self.assertIn("runner-secret", self.startup)


if __name__ == "__main__":
    unittest.main()
