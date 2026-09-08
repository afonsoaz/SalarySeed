#!/bin/bash
#
# Builds tools/payslip_probe against the app's own Engine and Payslip sources.
#
# It compiles the shipping files rather than copies of them, for the same
# reason verify_tax_engine.py parses the tables out of TaxEngine.swift: a probe
# built from a duplicate verifies the duplicate. Everything it needs imports
# only Foundation, PDFKit, CoreGraphics, ImageIO and Vision, none of which are
# iOS-only, which is why this is possible at all without a test target.
#
# The output goes in .build/, which is gitignored.

set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p .build

swiftc -O \
    -o .build/payslip_probe \
    tools/payslip_probe/main.swift \
    SalarySeed/Engine/PayslipText.swift \
    SalarySeed/Engine/PayslipNumber.swift \
    SalarySeed/Engine/PayslipLayout.swift \
    SalarySeed/Engine/PayslipLexicon.swift \
    SalarySeed/Engine/PayslipDocument.swift \
    SalarySeed/Engine/PayslipClassifier.swift \
    SalarySeed/Engine/PayslipFacts.swift \
    SalarySeed/Engine/PayslipFinding.swift \
    SalarySeed/Engine/PayslipReconciler.swift \
    SalarySeed/Engine/TaxEngine.swift \
    SalarySeed/Models/SearchText.swift \
    SalarySeed/Features/Payslip/PayslipPDF.swift \
    SalarySeed/Features/Payslip/PayslipOCR.swift

echo "built .build/payslip_probe"
