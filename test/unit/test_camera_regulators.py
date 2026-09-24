"""A misplaced camera regulator must fail before it reaches a boot image."""

import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "camera_regulators", ROOT / "builder/hardware/hp-t14/validate-camera-regulators.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


@unittest.skipUnless(shutil.which("dtc") and shutil.which("fdtget"), "requires dtc")
class CameraRegulatorTest(unittest.TestCase):
    def validate(self, compatible, children):
        # Deliberately use a different provider number: compatibility, not the
        # arbitrary board node number or regulator label, defines valid children.
        with tempfile.TemporaryDirectory() as directory:
            dtb = Path(directory) / "test.dtb"
            dts = ('/dts-v1/; / { soc@0 { rsc@17500000 { regulators-42 { '
                   f'compatible = "{compatible}"; ' + children + ' }; }; }; };')
            subprocess.run(["dtc", "-q", "-I", "dts", "-O", "dtb", "-o", str(dtb)],
                           input=dts, text=True, check=True, capture_output=True)
            CHECK.validate(dtb)

    def test_existing_pm8550ve_boot_supplies(self):
        self.validate("qcom,pm8550ve-rpmh-regulators",
                      "smps4 {}; ldo1 {}; ldo2 {}; ldo3 {};")

    def test_misplaced_ldo7_fails_even_with_misleading_label(self):
        with self.assertRaisesRegex(ValueError, "ldo7: unsupported"):
            self.validate("qcom,pm8550ve-rpmh-regulators",
                          'smps4 {}; ldo7 { regulator-name = "vreg_l7b_2p8"; };')

    def test_camera_pmic_accepts_ldo7(self):
        self.validate("qcom,pm8010-rpmh-regulators", "ldo2 {}; ldo4 {}; ldo7 {};")

    def test_camera_pmic_rejects_switcher(self):
        with self.assertRaisesRegex(ValueError, "smps4: unsupported"):
            self.validate("qcom,pm8010-rpmh-regulators", "smps4 {};")
