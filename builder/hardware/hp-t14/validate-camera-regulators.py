#!/usr/bin/env python3
"""Reject unsupported children in the camera-related RPMh regulator providers.

Child names follow rpmh_*_vreg_data in drivers/regulator/qcom-rpmh-regulator.c.
One unknown child fails the entire provider, including unrelated boot supplies.
This targeted check is intentionally narrower than full DT schema validation.
"""

import subprocess
import sys


SUPPORTED = {
    "qcom,pm8550ve-rpmh-regulators": {
        *(f"smps{i}" for i in range(1, 9)),
        *(f"ldo{i}" for i in range(1, 4)),
    },
    "qcom,pm8010-rpmh-regulators": {f"ldo{i}" for i in range(1, 8)},
}


def validate(dtb):
    def query(*args):
        return subprocess.check_output(["fdtget", *args[:1], str(dtb), *args[1:]],
                                       text=True).split()

    errors = []
    root = "/soc@0/rsc@17500000"
    for name in query("-l", root):
        provider = f"{root}/{name}"
        if "compatible" not in query("-p", provider):
            continue
        compatibles = query("-ts", provider, "compatible")
        for compatible in compatibles:
            if compatible not in SUPPORTED:
                continue
            for child in query("-l", provider):
                if child not in SUPPORTED[compatible]:
                    errors.append(f"{provider}/{child}: unsupported by {compatible}")
    if errors:
        raise ValueError("\n".join(errors))


if __name__ == "__main__":
    try:
        validate(sys.argv[1])
    except (ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
    print(f"Camera regulator child checks passed: {sys.argv[1]}")
