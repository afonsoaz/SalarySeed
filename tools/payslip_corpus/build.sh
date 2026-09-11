#!/bin/bash
#
# Builds tools/payslip_corpus against the app's own TaxEngine and payslip
# vocabulary.
#
# Swift and not Python for one reason above the others: the truth on every
# generated payslip has to come from TaxEngine itself. A Python generator would
# be a second implementation of the 2026 withholding tables, and when it
# disagreed with the app there would be no way to tell a reader bug from a
# generator bug. Calling the shipping engine removes that failure mode. It also
# means the corpus's concept names ARE PayslipConcept, so its vocabulary cannot
# drift from the reader's.
#
# The output goes in .build/, which is gitignored.

set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p .build

swiftc -O \
    -o .build/payslip_corpus \
    tools/payslip_corpus/Truth.swift \
    tools/payslip_corpus/Corpus.swift \
    tools/payslip_corpus/HTML.swift \
    tools/payslip_corpus/Verify.swift \
    tools/payslip_corpus/Degrade.swift \
    tools/payslip_corpus/main.swift \
    SalarySeed/Engine/TaxEngine.swift \
    SalarySeed/Engine/PayslipText.swift \
    SalarySeed/Engine/PayslipNumber.swift \
    SalarySeed/Engine/PayslipLexicon.swift \
    SalarySeed/Models/SearchText.swift

echo "built .build/payslip_corpus"
