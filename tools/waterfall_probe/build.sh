#!/bin/bash
#
# Builds tools/waterfall_probe against the app's own engine.
#
# The Tax screen's "from your company to you" rows are whole euros that have to
# add up, agree with Home and agree with the settlement card on the same screen.
# WaterfallRows decides how they are rounded. This compiles that file and
# TaxEngine.swift, unmodified, and sweeps them, for the reason offer_probe gives:
# a Python copy of the rule would be a second implementation, and when the two
# disagreed there would be no way to tell which side was wrong.
#
# The output goes in .build/, which is gitignored. Run it after any change to
# WaterfallRows or to how TaxEngine builds a SalaryBreakdown:
#
#   tools/waterfall_probe/build.sh && .build/waterfall_probe
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .build
swiftc -O \
    -o .build/waterfall_probe \
    tools/waterfall_probe/main.swift \
    SalarySeed/Engine/WaterfallRows.swift \
    SalarySeed/Engine/TaxEngine.swift

echo "built .build/waterfall_probe"
