#!/bin/bash
#
# Builds tools/offer_probe against the app's own engines.
#
# Swift and not Python for the reason tools/payslip_corpus gives: a Python copy
# of TaxEngine, GrowthEngine, PercentileEngine and CohortEngine would be a
# second implementation of four engines, and when it disagreed with the app
# there would be no way to tell which side was wrong. This compiles the files
# that ship, unmodified, and checks what OfferComparison builds out of them.
#
# The one file here that is not shipping code is StoreShim.swift; it says why.
# The output goes in .build/, which is gitignored.

set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p .build

swiftc -O \
    -o .build/offer_probe \
    tools/offer_probe/main.swift \
    tools/offer_probe/StoreShim.swift \
    SalarySeed/Engine/OfferComparison.swift \
    SalarySeed/Engine/TaxEngine.swift \
    SalarySeed/Engine/WaterfallRows.swift \
    SalarySeed/Engine/GrowthEngine.swift \
    SalarySeed/Engine/PercentileEngine.swift \
    SalarySeed/Engine/CohortEngine.swift \
    SalarySeed/Engine/SalaryDataset.swift \
    SalarySeed/Engine/DistrictDataset.swift \
    SalarySeed/Models/ProfileSignals.swift \
    SalarySeed/Models/Concelhos.swift \
    SalarySeed/Models/SearchText.swift

echo "built .build/offer_probe"
