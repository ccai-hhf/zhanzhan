#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift run --package-path Core ShelfCoreChecks
