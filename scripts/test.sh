#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p .build
make test
swiftc app/AutoMountPolicy.swift test/AutoMountPolicyTests.swift -o .build/policy-tests
.build/policy-tests
if [[ -f test/NativeTests.swift ]]; then
  swiftc app/USBMonitor.swift app/MountTable.swift test/NativeTests.swift -framework IOKit -o .build/native-tests
  .build/native-tests
fi
if [[ -f packaging/Distribution.xml ]]; then xmllint --noout packaging/Distribution.xml; fi
if [[ -f test/DistributionTests.js ]]; then node test/DistributionTests.js; fi
for script in scripts/*.sh app/build-app.sh packaging/scripts/*; do
  [[ -f "$script" ]] && bash -n "$script"
done
